import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../utils/app_typography.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/note.dart';
import '../../models/patient.dart';
import '../../providers/note_provider.dart';
import '../../utils/app_theme.dart';
import '../../services/patient_service.dart';
import '../../widgets/patient_actions.dart';
import '../../widgets/note_card.dart';
import 'add_note_screen.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/large_title_app_bar.dart';
import '../../widgets/empty_state.dart';
import '../../utils/layout.dart';
import '../../widgets/reminder_widgets.dart';
import '../../widgets/newborn_section.dart';
import '../../widgets/newborn_tracking_section.dart';
import '../../providers/unit_provider.dart';
import '../../widgets/note_list_items.dart';
import '../../utils/app_utils.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;

  const PatientDetailScreen({super.key, required this.patientId});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Captured once so we can safely call it from dispose without touching
  // `context` after the widget tree is torn down.
  NoteProvider? _noteProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _noteProvider = context.read<NoteProvider>();
      _noteProvider!.subscribeToPatient(widget.patientId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Stop the per-patient notes stream so it doesn't keep billing reads
    // after the user leaves this screen.
    _noteProvider?.unsubscribeFromPatient();
    super.dispose();
  }

  /// Live: status, ward and bed update when a teammate discharges or
  /// transfers the patient. Created once (not per build).
  late final Stream<Patient?> _patientStream =
      PatientService().watchPatient(widget.patientId);

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change
    return StreamBuilder<Patient?>(
      stream: _patientStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(title: const Text('Patient')),
            body: const Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        final patient = snap.data;
        if (patient == null) {
          // Deleted, or transferred to a ward you don't belong to.
          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(title: const Text('Patient')),
            body: const EmptyState(
              icon: Icons.lock_outline,
              title: 'Not available',
              subtitle: 'This patient was moved to a ward you are not a '
                  'member of, or removed.',
            ),
          );
        }
        return _detail(context, patient);
      },
    );
  }

  Widget _detail(BuildContext context, Patient patient) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      // The patient's name is the large title — the most important
      // identifier on the screen — and folds into the bar on scroll.
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          LargeTitleAppBar(
            title: patient.name,
            showBackButton: true,
            actions: [
              if (patient.isActive)
                ChromeIconButton(
                  icon: Icons.edit_square,
                  tooltip: 'New note',
                  onPressed: () => showAddNoteBottomSheet(context,
                      preselectedPatient: patient),
                ),
              PatientActionsButton(patient: patient),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList.list(
              children: [
                if (patient.isDischarged) ...[
                  _DischargedBanner(patient: patient),
                  const SizedBox(height: 16),
                ],
                const GroupedSectionHeader('Patient info'),
                _infoCard(patient),
                const SizedBox(height: 16),
                if (patient.bornAt != null) ...[
                  NewbornSection(patient: patient),
                  const SizedBox(height: 16),
                  NewbornTrackingSection(patient: patient),
                  const SizedBox(height: 16),
                ],
                PatientRemindersSection(patient: patient),
                const SizedBox(height: 16),
              ],
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedSegments(
              controller: _tabController,
              labels: const ['Notes', 'History'],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [_notesTab(patient), _historyTab()],
        ),
      ),
    );
  }

  Widget _infoCard(Patient p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  p.initials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: appText(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      p.diagnosis,
                      style: appText(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PatientIds(patient: p),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 14),
          Row(
            children: [
              _infoChip('Age', p.ageLabel),
              _infoChip('Gender', p.gender),
              _infoChip('Bed', p.bedNumber),
              if (context.watch<UnitProvider>().unitsOf(p.wardId).isNotEmpty)
                _infoChip('Unit',
                    context.watch<UnitProvider>().unitById(p.unitId)?.name ?? '—'),
              _infoChip('Blood', p.bloodGroup ?? '-'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Admitted ${DateFormat.yMMMd().format(p.admittedAt)}',
                style: appText(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          if (p.bornAt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.child_friendly_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Born ${formatDueTime(p.bornAt!)} · ${p.hoursSinceBirth()} h of life',
                    style:
                        appText(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: appText(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: appText(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _notesTab(Patient patient) {
    return Consumer<NoteProvider>(
      builder: (context, provider, _) {
        final notes = provider.patientNotes;
        if (notes.isEmpty) {
          return EmptyState(
            icon: Icons.notes_outlined,
            title: 'No notes yet',
            subtitle: 'Notes about ${patient.name} will appear here.',
            buttonLabel: patient.isActive ? 'New note' : null,
            onButtonTap: patient.isActive
                ? () => showAddNoteBottomSheet(context, preselectedPatient: patient)
                : null,
          );
        }
        return ListView.separated(
          padding: withBottomBarInset(
            context,
            const EdgeInsets.fromLTRB(16, 16, 16, 96),
          ),
          itemCount: notes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => WiredNoteCard(note: notes[i]),
        );
      },
    );
  }

  String _dateHeader(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('d MMM').format(d);
  }

  Widget _historyTab() {
    return Consumer<NoteProvider>(
      builder: (context, provider, _) {
        final notes = provider.patientNotes;
        if (notes.isEmpty) {
          return const EmptyState(
            icon: Icons.history,
            title: 'No history yet',
            subtitle: 'A day-by-day timeline builds up as notes are added.',
          );
        }
        final grouped = <String, List<Note>>{};
        for (final n in notes) {
          final key = _dateHeader(n.createdAt);
          grouped.putIfAbsent(key, () => []).add(n);
        }
        return ListView(
          padding: withBottomBarInset(
            context,
            const EdgeInsets.fromLTRB(16, 16, 16, 96),
          ),
          children: [
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  entry.key,
                  style: appText(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final n in entry.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: NoteCard(note: n),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// FolioMed's unique patient ID (monospaced, copyable) and the optional
/// hospital ID.
class _PatientIds extends StatelessWidget {
  const _PatientIds({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (patient.patientCode.isNotEmpty)
          _IdChip(label: 'Patient ID', value: patient.patientCode),
        if (patient.hospitalId != null)
          _IdChip(label: 'Hospital ID', value: patient.hospitalId!),
      ],
    );
  }
}

class _IdChip extends StatelessWidget {
  const _IdChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label $value. Double-tap to copy.',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label $value copied')),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text.rich(
            TextSpan(
              text: '$label  ',
              style: AppTypography.caption1(color: AppColors.textSecondary),
              children: [
                TextSpan(
                  text: value,
                  style: appMonoText(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ).copyWith(fontFeatures: AppTypography.tabular),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown on a discharged patient: when, and the discharge summary.
class _DischargedBanner extends StatelessWidget {
  const _DischargedBanner({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final when = patient.dischargedAt == null
        ? ''
        : ' on ${DateFormat('d MMM y, HH:mm').format(patient.dischargedAt!)}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.quaternaryFill,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.logout, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Discharged$when',
                    style: AppTypography.headline(color: AppColors.textPrimary)),
                if (patient.dischargeSummary != null) ...[
                  const SizedBox(height: 4),
                  Text(patient.dischargeSummary!,
                      style: AppTypography.subheadline(
                          color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 4),
                Text('Readmit from the actions menu (•••) to add notes again.',
                    style: AppTypography.footnote(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// iOS segmented control pinned under the navigation bar, driving the
/// Notes / History pages (which still swipe).
class _PinnedSegments extends SliverPersistentHeaderDelegate {
  _PinnedSegments({required this.controller, required this.labels});

  final TabController controller;
  final List<String> labels;

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => CupertinoSlidingSegmentedControl<int>(
              groupValue: controller.index,
              onValueChanged: (i) {
                if (i != null) controller.animateTo(i);
              },
              children: {
                for (final (i, l) in labels.indexed)
                  i: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(l,
                        style: AppTypography.subheadline(
                            color: AppColors.textPrimary, weight: FontWeight.w600)),
                  ),
              },
            ),
          ),
        ),
      );

  @override
  bool shouldRebuild(covariant _PinnedSegments oldDelegate) =>
      oldDelegate.controller != controller;
}
