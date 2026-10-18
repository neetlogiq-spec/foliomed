/**
 * FolioMed — FCM fan-out on new notes.
 *
 * Trigger: a new doc in /notes/{noteId}
 * Action:  push a notification to every user whose `wardIds` array
 *          contains the note's wardId — except the author.
 *
 * Cost notes (Blaze pay-as-you-go):
 * - memory pinned at 256 MiB. The function does a small Firestore query
 *   plus an FCM multicast — there's no need for the v2 default of 256
 *   MiB to creep up; explicitly setting it locks in cost.
 * - minInstances: 0 → never keep a warm container. We accept a ~1s
 *   cold start in exchange for not paying for idle compute.
 * - concurrency: 80 → one container can fan out many notes at once,
 *   reducing total active container time.
 * - timeoutSeconds: 30 → bounded so a stuck FCM call can't burn budget.
 */
const {
  onDocumentCreated,
  onDocumentDeleted,
} = require('firebase-functions/v2/firestore');
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getAuth } = require('firebase-admin/auth');
// v1 needed for auth.user().onDelete trigger (not in v2 API surface).
const functionsV1 = require('firebase-functions/v1');

const resendApiKey = defineSecret('RESEND_API_KEY');

initializeApp();

const COMMON_OPTS = {
  region: 'us-central1',
  memory: '256MiB',
  minInstances: 0,
  concurrency: 80,
  timeoutSeconds: 30,
};

exports.onNoteCreated = onDocumentCreated(
  { ...COMMON_OPTS, document: 'notes/{noteId}' },
  async (event) => {
    const note = event.data?.data();
    if (!note) return;

    const wardId = note.wardId;
    const authorId = note.authorId;
    if (!wardId) return;

    const db = getFirestore();
    const usersSnap = await db
      .collection('users')
      .where('wardIds', 'array-contains', wardId)
      .get();

    const tokens = [];
    usersSnap.forEach((doc) => {
      if (doc.id === authorId) return; // don't push to the author
      const arr = doc.data().fcmTokens;
      if (Array.isArray(arr)) tokens.push(...arr);
    });

    if (tokens.length === 0) return;

    const isUrgent = (note.priority || '').toLowerCase() === 'urgent';
    const title = isUrgent
      ? `🚨 Urgent · ${note.patientName || 'patient'}`
      : `Note · ${note.patientName || 'patient'}`;
    const body =
      `${note.authorName || 'Someone'}: ${(note.content || '').slice(0, 140)}`;

    const messaging = getMessaging();
    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: {
        noteId: event.params.noteId,
        wardId: String(wardId),
        priority: String(note.priority || 'Normal'),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'foliomed_notes',
          priority: isUrgent ? 'max' : 'high',
        },
      },
      apns: {
        payload: {
          aps: { sound: 'default', badge: 1 },
        },
      },
    });

    // Clean up dead tokens.
    const dead = [];
    response.responses.forEach((r, i) => {
      if (!r.success) {
        const code = r.error?.code;
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token'
        ) {
          dead.push(tokens[i]);
        }
      }
    });
    if (dead.length) {
      const batch = db.batch();
      usersSnap.forEach((doc) => {
        const arr = doc.data().fcmTokens || [];
        const filtered = arr.filter((t) => !dead.includes(t));
        if (filtered.length !== arr.length) {
          batch.update(doc.ref, { fcmTokens: filtered });
        }
      });
      await batch.commit();
    }

    console.log(
      `FolioMed FCM: sent ${response.successCount}/${tokens.length} for ward ${wardId}`,
    );
  },
);

/**
 * FolioMed — clean up teammate wardIds when a ward is deleted.
 *
 * Trigger: a doc in /wards/{wardId} is deleted.
 * Action:  find every user whose `wardIds` array contains the dead
 *          ward id and remove it. The deleter handles their own doc
 *          client-side; this function takes care of every other member,
 *          which the security rules don't allow them to do directly.
 */
exports.onWardDeleted = onDocumentDeleted(
  { ...COMMON_OPTS, document: 'wards/{wardId}' },
  async (event) => {
    const wardId = event.params.wardId;
    if (!wardId) return;

    const db = getFirestore();
    const members = await db
      .collection('users')
      .where('wardIds', 'array-contains', wardId)
      .get();

    if (members.empty) {
      console.log(`FolioMed cleanup: no stale wardIds for ${wardId}`);
      return;
    }

    const batch = db.batch();
    members.forEach((doc) => {
      batch.update(doc.ref, {
        wardIds: FieldValue.arrayRemove(wardId),
      });
    });
    await batch.commit();
    console.log(
      `FolioMed cleanup: scrubbed ${wardId} from ${members.size} user docs`,
    );
  },
);

/**
 * FolioMed — full account cleanup on Firebase Auth user deletion.
 *
 * Trigger: a Firebase Auth user is deleted (by the user via delete-account
 *          flow, or by an admin).
 * Action:
 *   1. Cascade-delete every ward the user created (notes + comments +
 *      patients + ward doc).
 *   2. Remove the user's UID from memberIds on any ward they joined.
 *
 * Runs with Admin SDK → bypasses all Firestore security rules. This is
 * intentional: the client cannot cascade-delete across collections it
 * doesn't own, but the server can.
 */
exports.onUserDeletedCleanup = functionsV1
  .runWith({ memory: '256MB', timeoutSeconds: 120 })
  .auth.user()
  .onDelete(async (user) => {
    const uid = user.uid;
    const db = getFirestore();

    // Helper: cascade-delete a single ward (notes + their comments,
    // patients, then the ward doc itself). Uses batches of 400 ops.
    async function cascadeDeleteWard(wardId) {
      let batch = db.batch();
      let ops = 0;

      async function flushIfNeeded() {
        if (ops >= 400) {
          await batch.commit();
          batch = db.batch();
          ops = 0;
        }
      }

      // Notes + comment subcollections.
      const notes = await db
        .collection('notes')
        .where('wardId', '==', wardId)
        .get();
      for (const note of notes.docs) {
        const comments = await note.ref.collection('comments').get();
        for (const comment of comments.docs) {
          batch.delete(comment.ref);
          ops++;
          await flushIfNeeded();
        }
        batch.delete(note.ref);
        ops++;
        await flushIfNeeded();
      }

      // Patients.
      const patients = await db
        .collection('patients')
        .where('wardId', '==', wardId)
        .get();
      for (const patient of patients.docs) {
        batch.delete(patient.ref);
        ops++;
        await flushIfNeeded();
      }

      if (ops > 0) await batch.commit();

      // Ward doc last.
      await db.collection('wards').doc(wardId).delete();
      console.log(`FolioMed cleanup: deleted ward ${wardId}`);
    }

    // 1. Cascade-delete owned wards.
    const ownedWards = await db
      .collection('wards')
      .where('creatorId', '==', uid)
      .get();
    for (const w of ownedWards.docs) {
      await cascadeDeleteWard(w.id);
    }

    // 2. Remove UID from memberIds on joined (non-owned) wards.
    const joinedWards = await db
      .collection('wards')
      .where('memberIds', 'array-contains', uid)
      .get();
    if (!joinedWards.empty) {
      const batch = db.batch();
      joinedWards.forEach((w) => {
        batch.update(w.ref, { memberIds: FieldValue.arrayRemove(uid) });
      });
      await batch.commit();
    }

    console.log(
      `FolioMed cleanup: account ${uid} fully erased ` +
      `(${ownedWards.size} wards deleted, ` +
      `${joinedWards.size} memberships removed)`,
    );
  });

/**
 * FolioMed — password reset email via Resend.
 *
 * POST body: { "email": "user@example.com" }
 *
 * Generates a Firebase password-reset link (Admin SDK), then delivers it
 * through Resend so the email comes from a real domain instead of
 * noreply@foliomed.firebaseapp.com (which gets silently dropped by
 * many providers).
 *
 * Always responds 200 regardless of whether the address exists — avoids
 * email enumeration.
 */
exports.sendPasswordResetEmail = onRequest(
  { ...COMMON_OPTS, cors: true, secrets: [resendApiKey], timeoutSeconds: 30 },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    const email = (req.body?.email || '').trim().toLowerCase();
    if (!email) {
      // Still 200 — don't reveal anything useful to an attacker.
      res.status(200).json({ ok: true });
      return;
    }

    try {
      // 1. Confirm the account exists via Admin SDK.
      //    getUserByEmail() is NOT affected by Email Enumeration Protection
      //    (it's an admin call), so we get a clean auth/user-not-found throw
      //    for unknown addresses instead of the silent oobLink-missing failure
      //    that generatePasswordResetLink hits when protection is ON.
      try {
        await getAuth().getUserByEmail(email);
      } catch (userErr) {
        if (userErr?.code === 'auth/user-not-found') {
          // Unknown address — respond 200 silently (no enumeration leakage).
          console.log(`FolioMed: no account for ${email}, skipping reset email`);
          res.status(200).json({ ok: true });
          return;
        }
        throw userErr; // unexpected error — bubble up to outer catch
      }

      // 2. User confirmed to exist — generate the Firebase reset link.
      //    Now that we've verified the user exists, this call will always
      //    return a proper oobLink (Email Enumeration Protection doesn't
      //    suppress links when the account is confirmed server-side).
      const link = await getAuth().generatePasswordResetLink(email);

      // 3. Send via Resend.
      const { Resend } = require('resend');
      const resend = new Resend(resendApiKey.value());

      await resend.emails.send({
        from: 'FolioMed <onboarding@resend.dev>',
        to: email,
        subject: 'Reset your FolioMed password',
        html: `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
</head>
<body style="margin:0;padding:0;background:#f4f6f9;font-family:'DM Sans',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f9;padding:40px 0;">
    <tr>
      <td align="center">
        <table width="480" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08);">
          <!-- Header -->
          <tr>
            <td style="background:#0A5C8A;padding:32px 40px;text-align:center;">
              <h1 style="margin:0;color:#ffffff;font-size:24px;font-weight:700;letter-spacing:-0.5px;">FolioMed</h1>
              <p style="margin:4px 0 0;color:rgba(255,255,255,0.8);font-size:13px;">Clinical Notes for Ward Teams</p>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding:40px;">
              <h2 style="margin:0 0 12px;color:#1a1a2e;font-size:20px;font-weight:600;">Reset your password</h2>
              <p style="margin:0 0 24px;color:#555;font-size:15px;line-height:1.6;">
                We received a request to reset the password for your FolioMed account
                (<strong>${email}</strong>).<br><br>
                Click the button below to set a new password. This link expires in 1 hour.
              </p>
              <table cellpadding="0" cellspacing="0" style="margin:0 auto 32px;">
                <tr>
                  <td align="center" style="background:#0A5C8A;border-radius:8px;">
                    <a href="${link}"
                       style="display:inline-block;padding:14px 32px;color:#ffffff;font-size:15px;font-weight:600;text-decoration:none;border-radius:8px;">
                      Reset Password
                    </a>
                  </td>
                </tr>
              </table>
              <p style="margin:0 0 8px;color:#888;font-size:13px;line-height:1.5;">
                If the button doesn't work, copy and paste this link into your browser:
              </p>
              <p style="margin:0 0 32px;word-break:break-all;">
                <a href="${link}" style="color:#0A5C8A;font-size:12px;">${link}</a>
              </p>
              <hr style="border:none;border-top:1px solid #eee;margin:0 0 24px;">
              <p style="margin:0;color:#aaa;font-size:12px;line-height:1.5;">
                If you didn't request a password reset, you can safely ignore this email.
                Your password won't change until you click the link above.
              </p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background:#f8f9fb;padding:20px 40px;text-align:center;border-top:1px solid #eee;">
              <p style="margin:0;color:#bbb;font-size:12px;">
                © ${new Date().getFullYear()} FolioMed &nbsp;·&nbsp;
                <a href="https://www.foliomed.com/support" style="color:#0A5C8A;text-decoration:none;">Support</a>
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`,
      });

      console.log(`FolioMed: password reset email sent to ${email}`);
    } catch (e) {
      // Swallow all errors — never leak whether the address is registered.
      console.warn('sendPasswordResetEmail suppressed error:', e?.message ?? e);
    }

    res.status(200).json({ ok: true });
  },
);

/**
 * FolioMed — one-shot metrics backfill.
 *
 * GET https://us-central1-foliomed.cloudfunctions.net/backfillMetrics?token=SECRET
 *
 * Recomputes the real count for every collection we track and writes
 * it into /metrics/totals. Safe to re-run. Gated by a token query
 * parameter so random hits can't trigger writes.
 */
exports.backfillMetrics = onRequest(
  { ...COMMON_OPTS, timeoutSeconds: 120 },
  async (req, res) => {
    const expected = 'foliomed-backfill-2026';
    if (req.query.token !== expected) {
      res.status(401).send('Unauthorized');
      return;
    }
    try {
      const db = getFirestore();
      const [users, wards, patients, notes, acks] = await Promise.all([
        db.collection('users').count().get(),
        db.collection('wards').count().get(),
        db.collection('patients').count().get(),
        db.collection('notes').count().get(),
        db
          .collection('notes')
          .where('isAcknowledged', '==', true)
          .count()
          .get(),
      ]);
      const comments = await db.collectionGroup('comments').count().get();

      const totals = {
        userCount: users.data().count,
        wardCount: wards.data().count,
        patientCount: patients.data().count,
        noteCount: notes.data().count,
        ackCount: acks.data().count,
        commentCount: comments.data().count,
        lastBackfillAt: FieldValue.serverTimestamp(),
      };

      await db.collection('metrics').doc('totals').set(totals, { merge: true });
      res.status(200).json({ ok: true, totals });
    } catch (e) {
      console.error('backfillMetrics failed', e);
      res.status(500).json({ ok: false, error: String(e) });
    }
  },
);
