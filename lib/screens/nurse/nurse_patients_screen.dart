import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/patient_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/patient_card.dart';
import '../../widgets/support_action.dart';
import 'nurse_patient_detail_screen.dart';
import '../../providers/theme_provider.dart';

class NursePatientsScreen extends StatefulWidget {
  const NursePatientsScreen({super.key});

  @override
  State<NursePatientsScreen> createState() => _NursePatientsScreenState();
}

class _NursePatientsScreenState extends State<NursePatientsScreen> {
  bool _searching = false;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search patients',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
              )
            : Consumer<PatientProvider>(
                builder: (context, pp, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Patients'),
                      Text(
                        '${pp.patientCount} active patients',
                        style: GoogleFonts.dmSans(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                },
              ),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              if (_searching) {
                _searchController.clear();
                _query = '';
              }
              _searching = !_searching;
            }),
          ),
          const SupportAppBarAction(),
        ],
      ),
      body: Consumer<PatientProvider>(
        builder: (context, pp, _) {
          final patients = pp.patients.where((p) {
            if (_query.isEmpty) return true;
            return p.name.toLowerCase().contains(_query) ||
                p.bedNumber.toLowerCase().contains(_query);
          }).toList();
          if (patients.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'No patients',
              subtitle: 'No active patients in this ward yet.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: patients.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => PatientCard(
              patient: patients[i],
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NursePatientDetailScreen(
                      patientId: patients[i].id,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
