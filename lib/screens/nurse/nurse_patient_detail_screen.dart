import 'package:flutter/material.dart';
import '../../utils/app_typography.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/patient.dart';
import '../../providers/note_provider.dart';
import '../../providers/patient_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/note_card.dart';
import 'acknowledge_sheet.dart';
import '../../providers/theme_provider.dart';

class NursePatientDetailScreen extends StatefulWidget {
  final String patientId;

  const NursePatientDetailScreen({super.key, required this.patientId});

  @override
  State<NursePatientDetailScreen> createState() =>
      _NursePatientDetailScreenState();
}

class _NursePatientDetailScreenState extends State<NursePatientDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NoteProvider>().subscribeToPatient(widget.patientId);
    });
  }

  Patient? _resolve(PatientProvider provider) {
    for (final p in provider.patients) {
      if (p.id == widget.patientId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    final pp = context.watch<PatientProvider>();
    final patient = _resolve(pp);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(patient?.name ?? 'Patient')),
      body: patient == null
          ? const Center(child: CircularProgressIndicator.adaptive())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _infoCard(patient),
                ),
                Expanded(child: _notesList()),
              ],
            ),
    );
  }

  Widget _infoCard(Patient p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.nurseColor.withOpacity(0.1),
                child: Text(
                  p.initials,
                  style: const TextStyle(
                    color: AppColors.nurseColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
          const Divider(height: 24),
          Row(
            children: [
              _chip('Age', '${p.age}'),
              _chip('Gender', p.gender),
              _chip('Bed', p.bedNumber),
              _chip('Blood', p.bloodGroup ?? '-'),
            ],
          ),
          const SizedBox(height: 12),
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
                style: appText(
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

  Widget _chip(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: appText(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
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

  Widget _notesList() {
    return Consumer<NoteProvider>(
      builder: (context, np, _) {
        final notes = np.patientNotes;
        if (notes.isEmpty) {
          return Center(
            child: Text(
              'No notes for this patient yet',
              style: appText(color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: notes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => NoteCard(
            note: notes[i],
            onAcknowledge: notes[i].isAcknowledged
                ? null
                : () => showAcknowledgeSheet(context, notes[i]),
          ),
        );
      },
    );
  }
}
