import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/note_provider.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_theme.dart';
import 'add_patient_screen.dart';
import '../../providers/theme_provider.dart';

Future<void> showAddNoteBottomSheet(
  BuildContext context, {
  Patient? preselectedPatient,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddNoteBottomSheet(preselectedPatient: preselectedPatient),
  );
}

class AddNoteBottomSheet extends StatefulWidget {
  final Patient? preselectedPatient;

  const AddNoteBottomSheet({super.key, this.preselectedPatient});

  @override
  State<AddNoteBottomSheet> createState() => _AddNoteBottomSheetState();
}

class _AddNoteBottomSheetState extends State<AddNoteBottomSheet> {
  final _contentController = TextEditingController();

  Patient? _selectedPatient;
  String? _selectedWardId;
  String _category = 'General';
  String _priority = 'Normal';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedPatient = widget.preselectedPatient;
    _selectedWardId = widget.preselectedPatient?.wardId ??
        context.read<AuthProvider>().currentUser?.wardId;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Color _priorityColorFor(String p) {
    switch (p) {
      case 'Urgent':
        return AppColors.danger;
      case 'Low':
        return AppColors.textSecondary;
      case 'Normal':
      default:
        return AppColors.primary;
    }
  }

  Future<void> _submit() async {
    if (_selectedWardId == null || _selectedWardId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a ward')),
      );
      return;
    }
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a patient')),
      );
      return;
    }
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note cannot be empty')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final authProvider = context.read<AuthProvider>();
    final noteProvider = context.read<NoteProvider>();
    final user = authProvider.currentUser;
    if (user == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    final now = DateTime.now();
    final note = Note(
      id: const Uuid().v4(),
      patientId: _selectedPatient!.id,
      patientName: _selectedPatient!.name,
      wardId: _selectedWardId!,
      authorId: user.uid,
      authorName: user.name,
      authorRole: user.roleLabel,
      content: _contentController.text.trim(),
      category: _category,
      priority: _priority,
      createdAt: now,
      updatedAt: now,
    );

    final ok = await noteProvider.addNote(note);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note posted to ward')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Failed to post note'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Scaffold(
            backgroundColor: AppColors.card,
            body: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                child: Row(
                  children: [
                    Text(
                      'New Note',
                      style: GoogleFonts.dmSans(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Ward'),
                      const SizedBox(height: 8),
                      _wardChips(),
                      const SizedBox(height: 16),
                      _sectionLabel('Patient'),
                      const SizedBox(height: 8),
                      _patientSelectorStream(),
                      const SizedBox(height: 16),
                      _sectionLabel('Note'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _contentController,
                        minLines: 4,
                        maxLines: 10,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          hintText:
                              'Describe the update, observation or instruction...',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _sectionLabel('Category'),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final c in AppConstants.noteCategories)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _categoryChip(c),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sectionLabel('Priority'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final p in AppConstants.notePriorities)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: _priorityCard(p),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 4),
                                  child: Text('Post Note'),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _wardChips() {
    final me = context.watch<AuthProvider>().currentUser;
    final myWardIds = me?.wardIds ?? const <String>[];
    if (myWardIds.isEmpty) {
      return Text(
        'Join a ward first from the Wards tab.',
        style: GoogleFonts.dmSans(color: AppColors.textSecondary),
      );
    }
    // Firestore whereIn only allows up to 30 ids; trim if needed.
    final ids = myWardIds.length > 30 ? myWardIds.sublist(0, 30) : myWardIds;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.wardsCollection)
          .where(FieldPath.documentId, whereIn: ids)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            "Couldn't load wards. Pull down to retry.",
            style: GoogleFonts.dmSans(color: AppColors.danger),
          );
        }
        if (!snap.hasData) {
          return SizedBox(
            height: 40,
            child: Text(
              'Loading wards...',
              style: GoogleFonts.dmSans(color: AppColors.textSecondary),
            ),
          );
        }
        final wards = snap.data!.docs
            .map((d) => Ward.fromFirestore(d))
            .toList();
        if (wards.isEmpty) {
          return Text(
            'No wards yet. Create or join one from the Wards tab.',
            style: GoogleFonts.dmSans(color: AppColors.textSecondary),
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final w in wards)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _wardChip(w),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _wardChip(Ward w) {
    final selected = _selectedWardId == w.id;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() {
        _selectedWardId = w.id;
        if (_selectedPatient != null &&
            _selectedPatient!.wardId != w.id) {
          _selectedPatient = null;
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          w.name,
          style: GoogleFonts.dmSans(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _patientSelectorStream() {
    if (_selectedWardId == null || _selectedWardId!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          'Pick a ward first',
          style: GoogleFonts.dmSans(color: AppColors.textSecondary),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.patientsCollection)
          .where('wardId', isEqualTo: _selectedWardId)
          .where('isActive', isEqualTo: true)
          .limit(200) // hard cap on reads
          .snapshots(),
      builder: (context, snap) {
        final patients = snap.hasData
            ? snap.data!.docs.map(Patient.fromFirestore).toList()
            : <Patient>[];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            // isScrollControlled + explicit max height lets the sheet
            // take 80% of the screen instead of the ~50% default — fixes
            // the issue where the first real patient row got pushed below
            // the fold and was hard to reach with a thumb.
            final result = await showModalBottomSheet<Patient>(
              context: context,
              backgroundColor: AppColors.card,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (sheetCtx) {
                final maxH = MediaQuery.of(sheetCtx).size.height * 0.8;
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle.
                      Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 6),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                        child: Row(
                          children: [
                            Text(
                              'Select Patient',
                              style: GoogleFonts.dmSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${patients.length} '
                              '${patients.length == 1 ? 'patient' : 'patients'}',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Pinned "Add new patient" CTA — always reachable.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: AppColors.accent.withOpacity(0.25),
                            ),
                          ),
                          tileColor: AppColors.accent.withOpacity(0.06),
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.accent.withOpacity(0.15),
                            child: const Icon(Icons.add,
                                color: AppColors.accent),
                          ),
                          title: const Text('Add new patient'),
                          subtitle:
                              const Text('Create and use for this note'),
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AddPatientScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Divider(
                        color: AppColors.divider,
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                      ),
                      // Scrollable patient list — flexes to fill remaining
                      // height of the 80%-tall sheet.
                      Expanded(
                        child: patients.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'No patients in this ward yet.\n'
                                    'Tap "Add new patient" above.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    8, 8, 8, 16),
                                itemCount: patients.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: AppColors.divider.withOpacity(0.4),
                                  indent: 72,
                                  endIndent: 16,
                                ),
                                itemBuilder: (_, i) {
                                  final p = patients[i];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primary
                                          .withOpacity(0.1),
                                      child: Text(
                                        p.initials,
                                        style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    title: Text(p.name),
                                    subtitle: Text(
                                      p.bedNumber.isEmpty
                                          ? '—'
                                          : 'Bed ${p.bedNumber}',
                                    ),
                                    onTap: () =>
                                        Navigator.of(sheetCtx).pop(p),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
            if (result != null) setState(() => _selectedPatient = result);
          },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(Icons.person_outline, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedPatient == null
                    ? 'Select Patient'
                    : '${_selectedPatient!.name} · Bed ${_selectedPatient!.bedNumber}',
                style: GoogleFonts.dmSans(
                  color: _selectedPatient == null
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _categoryChip(String label) {
    final selected = _category == label;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _category = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _priorityCard(String label) {
    final color = _priorityColorFor(label);
    final selected = _priority == label;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _priority = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              color: selected ? color : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
