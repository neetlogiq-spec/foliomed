import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/patient.dart';
import '../../models/ward.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_theme.dart';
import '../../utils/friendly_error.dart';
import '../../providers/theme_provider.dart';

class AddPatientScreen extends StatefulWidget {
  final String? initialWardId;

  const AddPatientScreen({super.key, this.initialWardId});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _bedController = TextEditingController();
  final _diagnosisController = TextEditingController();

  String _gender = 'Male';
  String? _bloodGroup;
  String? _wardId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _wardId = widget.initialWardId;
  }

  static const List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bedController.dispose();
    _diagnosisController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final patientProvider = context.read<PatientProvider>();
    final wardId = _wardId ?? context.read<AuthProvider>().currentUser?.wardId ?? '';
    if (wardId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a ward first')),
      );
      return;
    }

    setState(() => _saving = true);
    final patient = Patient(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      age: int.tryParse(_ageController.text.trim()) ?? 0,
      gender: _gender,
      wardId: wardId,
      bedNumber: _bedController.text.trim(),
      diagnosis: _diagnosisController.text.trim(),
      bloodGroup: _bloodGroup,
      admittedAt: DateTime.now(),
    );

    final ok = await patientProvider.addPatient(patient);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient added successfully')),
      );
    } else {
      final err = patientProvider.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(
            err == null
                ? "Couldn't add patient — please try again."
                : 'Could not add patient — ${friendlyError(err)}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Add Patient'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('Ward (required)'),
              const SizedBox(height: 8),
              _wardPicker(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name (required)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age (optional)',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
              ),
              const SizedBox(height: 16),
              _label('Gender'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final g in ['Male', 'Female', 'Other'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _toggleChip(g, _gender == g, () {
                        setState(() => _gender = g);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bedController,
                decoration: const InputDecoration(
                  labelText: 'Bed number (optional)',
                  prefixIcon: Icon(Icons.bed_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _diagnosisController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Diagnosis (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _bloodGroup,
                decoration: const InputDecoration(
                  labelText: 'Blood group (optional)',
                  prefixIcon: Icon(Icons.bloodtype_outlined),
                ),
                items: _bloodGroups
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _bloodGroup = v),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text('Add Patient'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _wardPicker() {
    final me = context.watch<AuthProvider>().currentUser;
    final myWardIds = me?.wardIds ?? const <String>[];
    if (myWardIds.isEmpty) {
      return Text(
        'Join a ward first from the Wards tab.',
        style: GoogleFonts.dmSans(color: AppColors.textSecondary),
      );
    }
    // Firestore whereIn is limited to 30 ids — trim defensively.
    final ids = myWardIds.length > 30 ? myWardIds.sublist(0, 30) : myWardIds;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.wardsCollection)
          .where(FieldPath.documentId, whereIn: ids)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            "Couldn't load wards. Pull down and try again.",
            style: GoogleFonts.dmSans(color: AppColors.danger),
          );
        }
        if (!snap.hasData) {
          return Text(
            'Loading wards...',
            style: GoogleFonts.dmSans(color: AppColors.textSecondary),
          );
        }
        final wards =
            snap.data!.docs.map((d) => Ward.fromFirestore(d)).toList();
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
                  child: _toggleChip(
                    w.name,
                    _wardId == w.id,
                    () => setState(() => _wardId = w.id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _toggleChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
