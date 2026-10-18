/**
 * One-shot backfill: writes the real current count for each tracked
 * collection into /metrics/totals.
 *
 * Run with:
 *   cd functions
 *   node backfill_metrics.js
 *
 * Uses Application Default Credentials, so make sure you've run:
 *   gcloud auth application-default login
 * or set GOOGLE_APPLICATION_CREDENTIALS to a service-account key.
 *
 * It's safe to re-run — it overwrites the totals doc with truth.
 */
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp({
  credential: applicationDefault(),
  projectId: "foliomed",
});

const db = getFirestore();

async function countCollection(name, where) {
  let q = db.collection(name);
  if (where) q = q.where(where[0], where[1], where[2]);
  const snap = await q.count().get();
  return snap.data().count;
}

(async () => {
  console.log("→ Counting collections…");
  const [users, wards, patients, notes, acks] = await Promise.all([
    countCollection("users"),
    countCollection("wards"),
    countCollection("patients"),
    countCollection("notes"),
    countCollection("notes", ["isAcknowledged", "==", true]),
  ]);

  // Comments live in subcollections — collectionGroup lets us count them
  // across every parent note in one query.
  const commentsSnap = await db.collectionGroup("comments").count().get();
  const comments = commentsSnap.data().count;

  console.log({ users, wards, patients, notes, acks, comments });

  await db.collection("metrics").doc("totals").set(
    {
      userCount: users,
      wardCount: wards,
      patientCount: patients,
      noteCount: notes,
      ackCount: acks,
      commentCount: comments,
      lastBackfillAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  console.log("✓ /metrics/totals updated");
  process.exit(0);
})().catch((e) => {
  console.error("✗ Backfill failed:", e);
  process.exit(1);
});
