import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/ward.dart';
import '../../providers/ward_provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/theme_provider.dart';

class AddWardScreen extends StatefulWidget {
  const AddWardScreen({super.key});

  @override
  State<AddWardScreen> createState() => _AddWardScreenState();
}

class _AddWardScreenState extends State<AddWardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _floorController = TextEditingController();
  final _capacityController = TextEditingController();
  final _headDoctorController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _floorController.dispose();
    _capacityController.dispose();
    _headDoctorController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ward = Ward(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      floor: _floorController.text.trim(),
      capacity: int.tryParse(_capacityController.text.trim()) ?? 0,
      headDoctorName: _headDoctorController.text.trim(),
      createdAt: DateTime.now(),
    );
    final ok = await context.read<WardProvider>().addWard(ward);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ward created successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('New Ward'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Ward name',
                  hintText: 'ICU Ward A',
                  prefixIcon: Icon(Icons.local_hospital_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _floorController,
                decoration: const InputDecoration(
                  labelText: 'Floor',
                  hintText: '3rd Floor',
                  prefixIcon: Icon(Icons.layers_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Capacity',
                  hintText: '20',
                  prefixIcon: Icon(Icons.bed_outlined),
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Valid number required';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _headDoctorController,
                decoration: const InputDecoration(
                  labelText: 'Head doctor name',
                  prefixIcon: Icon(Icons.medical_services_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.adminColor,
                ),
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
                        child: Text('Create Ward'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
