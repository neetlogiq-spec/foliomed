import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/note.dart';
import '../../models/patient.dart';
import '../../models/ward.dart';
import '../../providers/ward_provider.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_theme.dart';
import '../../widgets/note_card.dart';
import '../../widgets/patient_card.dart';
import '../../widgets/role_badge.dart';
import 'add_staff_bottom_sheet.dart';
import '../../providers/theme_provider.dart';

class WardDetailScreen extends StatefulWidget {
  final String wardId;

  const WardDetailScreen({super.key, required this.wardId});

  @override
  State<WardDetailScreen> createState() => _WardDetailScreenState();
}

class _WardDetailScreenState extends State<WardDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Ward? _ward;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WardProvider>().loadWardStaff(widget.wardId);
      _loadWard();
    });
  }

  Future<void> _loadWard() async {
    final doc = await FirebaseFirestore.instance
        .collection(AppConstants.wardsCollection)
        .doc(widget.wardId)
        .get();
    if (!mounted) return;
    if (doc.exists) setState(() => _ward = Ward.fromFirestore(doc));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(_ward?.name ?? 'Ward'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _ward == null ? null : () => _showEditSheet(_ward!),
          ),
        ],
      ),
      body: _ward == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _infoCard(_ward!),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  labelStyle:
                      GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Staff'),
                    Tab(text: 'Patients'),
                    Tab(text: 'Notes'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _staffTab(),
                      _patientsTab(),
                      _notesTab(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add Staff'),
              onPressed: () => showAddStaffBottomSheet(
                context,
                wardId: widget.wardId,
              ),
            )
          : null,
    );
  }

  void _showEditSheet(Ward ward) {
    final nameController = TextEditingController(text: ward.name);
    final floorController = TextEditingController(text: ward.floor);
    final capacityController =
        TextEditingController(text: '${ward.capacity}');
    final headController = TextEditingController(text: ward.headDoctorName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Edit Ward',
                  style: GoogleFonts.dmSans(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: floorController,
                  decoration: const InputDecoration(labelText: 'Floor'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Capacity'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: headController,
                  decoration:
                      const InputDecoration(labelText: 'Head doctor'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final updated = Ward(
                      id: ward.id,
                      name: nameController.text.trim(),
                      floor: floorController.text.trim(),
                      capacity:
                          int.tryParse(capacityController.text.trim()) ?? 0,
                      headDoctorName: headController.text.trim(),
                      createdAt: ward.createdAt,
                    );
                    await context.read<WardProvider>().updateWard(updated);
                    if (mounted) {
                      Navigator.pop(context);
                      setState(() => _ward = updated);
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoCard(Ward w) {
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
          Text(
            w.name,
            style: GoogleFonts.dmSans(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _chip(Icons.layers_outlined, w.floor),
              const SizedBox(width: 8),
              _chip(Icons.bed_outlined, 'Capacity ${w.capacity}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.medical_services_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                w.headDoctorName,
                style: GoogleFonts.dmSans(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.dmSans(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _staffTab() {
    return Consumer<WardProvider>(
      builder: (context, wp, _) {
        if (wp.wardStaff.isEmpty) {
          return Center(
            child: Text(
              'No staff assigned yet',
              style: GoogleFonts.dmSans(color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: wp.wardStaff.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _staffCard(wp.wardStaff[i]),
        );
      },
    );
  }

  Widget _staffCard(AppUser user) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: user.roleColor.withOpacity(0.15),
            child: Text(
              user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
              style: TextStyle(
                color: user.roleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: GoogleFonts.dmSans(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  user.email,
                  style: GoogleFonts.dmSans(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          RoleBadge(role: user.role, small: true),
        ],
      ),
    );
  }

  Widget _patientsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.patientsCollection)
          .where('wardId', isEqualTo: widget.wardId)
          .where('isActive', isEqualTo: true)
          .orderBy('admittedAt', descending: true)
          .limit(200) // hard cap on reads
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final patients =
            snap.data!.docs.map(Patient.fromFirestore).toList();
        if (patients.isEmpty) {
          return Center(
            child: Text(
              'No patients in this ward',
              style: GoogleFonts.dmSans(color: AppColors.textSecondary),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${patients.length} active patients',
                style: GoogleFonts.dmSans(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            for (final p in patients)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PatientCard(patient: p),
              ),
          ],
        );
      },
    );
  }

  Widget _notesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.notesCollection)
          .where('wardId', isEqualTo: widget.wardId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final notes = snap.data!.docs.map(Note.fromFirestore).toList();
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
          itemBuilder: (_, i) => NoteCard(note: notes[i]),
        );
      },
    );
  }
}

