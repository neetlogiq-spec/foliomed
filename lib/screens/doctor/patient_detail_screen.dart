import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/note.dart';
import '../../models/patient.dart';
import '../../providers/auth_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/patient_provider.dart';
import '../../utils/app_theme.dart';
import '../../services/patient_service.dart';
import '../../widgets/monitor/remote_video_viewer.dart';
import '../../widgets/monitor/web_stream_card.dart';
import '../../widgets/note_card.dart';
import 'add_note_screen.dart';
import '../../providers/theme_provider.dart';

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

  Patient? _resolvePatient(PatientProvider provider) {
    for (final p in provider.patients) {
      if (p.id == widget.patientId) return p;
    }
    return provider.selectedPatient;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    final patientProvider = context.watch<PatientProvider>();
    final patient = _resolvePatient(patientProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(patient?.name ?? 'Patient'),
      ),
      body: patient == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: patient.hlsStreamUrl.isNotEmpty
                      ? (kIsWeb
                          ? WebStreamCard(
                              patientName: patient.name,
                              hlsUrl: patient.hlsStreamUrl,
                            )
                          : RemoteVideoViewer(
                              patientName: patient.name,
                              hlsUrl: patient.hlsStreamUrl,
                            ))
                      : _SetStreamUrlCard(onTap: () => _setStreamUrl(patient)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _infoCard(patient),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  labelStyle: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Notes'),
                    Tab(text: 'History'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _notesTab(patient),
                      _historyTab(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: patient == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Note'),
              onPressed: () =>
                  showAddNoteBottomSheet(context, preselectedPatient: patient),
            ),
    );
  }

  Widget _infoCard(Patient p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
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
                      style: GoogleFonts.dmSans(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      p.diagnosis,
                      style: GoogleFonts.dmSans(
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
          const Divider(),
          const SizedBox(height: 14),
          Row(
            children: [
              _infoChip('Age', '${p.age}'),
              _infoChip('Gender', p.gender),
              _infoChip('Bed', p.bedNumber),
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
                style: GoogleFonts.dmSans(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
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
            style: GoogleFonts.dmSans(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.dmSans(
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
          return Center(
            child: Text(
              'No notes yet',
              style: GoogleFonts.dmSans(color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => NoteCard(
            note: notes[i],
            onAcknowledge: () {
              final name =
                  context.read<AuthProvider>().currentUser?.name ?? 'Staff';
              context
                  .read<NoteProvider>()
                  .acknowledgeNote(notes[i].id, name);
            },
            onUnacknowledge: () => context
                .read<NoteProvider>()
                .unacknowledgeNote(notes[i].id),
          ),
        );
      },
    );
  }

  Future<void> _setStreamUrl(Patient patient) async {
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Set Live Stream URL',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paste the HLS URL from your Cloudflare tunnel.',
                style: GoogleFonts.dmSans(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: GoogleFonts.dmSans(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://…/nicu/index.m3u8',
                hintStyle: GoogleFonts.dmSans(color: AppColors.textSecondary),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (url == null || url.isEmpty) return;
    try {
      await PatientService().saveHlsUrl(patient.id, url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stream URL saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
          return Center(
            child: Text(
              'No history yet',
              style: GoogleFonts.dmSans(color: AppColors.textSecondary),
            ),
          );
        }
        final grouped = <String, List<Note>>{};
        for (final n in notes) {
          final key = _dateHeader(n.createdAt);
          grouped.putIfAbsent(key, () => []).add(n);
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  entry.key,
                  style: GoogleFonts.dmSans(
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

class _SetStreamUrlCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SetStreamUrlCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_outlined,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set Live Stream URL',
                      style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontSize: 14)),
                  Text('Tap to connect a remote camera feed',
                      style: GoogleFonts.dmSans(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
