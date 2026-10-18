import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/patient.dart';
import '../../models/ward.dart';
import '../../providers/auth_provider.dart';
import '../../providers/camera_provider.dart';
import '../../providers/patient_provider.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_theme.dart';
import '../../widgets/support_action.dart';
import 'add_patient_screen.dart';
import 'patient_detail_screen.dart';
import '../../providers/theme_provider.dart';

class PatientsListScreen extends StatefulWidget {
  const PatientsListScreen({super.key});

  @override
  State<PatientsListScreen> createState() => _PatientsListScreenState();
}

class _PatientsListScreenState extends State<PatientsListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _query) setState(() => _query = q);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on theme change

    final myWardIds =
        context.watch<AuthProvider>().currentUser?.wardIds ?? const [];
    if (myWardIds.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: const Text('Patients'), actions: const [SupportAppBarAction()]),
        body: Center(
          child: Text(
            'Join a ward to see patients.',
            style: GoogleFonts.dmSans(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    final ids = myWardIds.length > 30 ? myWardIds.sublist(0, 30) : myWardIds;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.wardsCollection)
          .where(FieldPath.documentId, whereIn: ids)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Patients'), actions: const [SupportAppBarAction()]),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final wards = snap.data!.docs.map(Ward.fromFirestore).toList();
        if (wards.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(title: const Text('Patients'), actions: const [SupportAppBarAction()]),
            body: Center(
              child: Text(
                'No wards yet. Create one in the Wards tab.',
                style: GoogleFonts.dmSans(color: AppColors.textSecondary),
              ),
            ),
          );
        }
        final wardById = {for (final w in wards) w.id: w};
        final isSearching = _query.isNotEmpty;

        Widget body;
        if (isSearching) {
          body = _searchResults(wards, wardById);
        } else {
          body = DefaultTabController(
            length: wards.length,
            child: Column(
              children: [
                Container(
                  color: AppColors.appBarBg,
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    labelStyle:
                        GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                    tabs: wards.map((w) => Tab(text: w.name)).toList(),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: wards.map((w) => _wardPatients(w)).toList(),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(title: const Text('Patients'), actions: const [SupportAppBarAction()]),
          body: Column(
            children: [
              _searchBar(),
              Expanded(child: body),
            ],
          ),
          floatingActionButton: isSearching
              ? null
              : Builder(
                  builder: (ctx) => FloatingActionButton.extended(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Patient'),
                    onPressed: () {
                      // Without DefaultTabController in scope here, fall back
                      // to the first ward; AddPatientScreen lets the user
                      // change the ward anyway.
                      final activeWardId = wards.first.id;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddPatientScreen(
                              initialWardId: activeWardId),
                        ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }

  // ───────────────── Always-visible search bar ─────────────────

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(
              Icons.search,
              color: _query.isEmpty
                  ? AppColors.textSecondary
                  : AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                style: GoogleFonts.dmSans(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Search patients across all your wards…',
                  hintStyle: GoogleFonts.dmSans(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  filled: false,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_query.isNotEmpty)
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close, size: 20),
                color: AppColors.textSecondary,
                onPressed: () {
                  _searchController.clear();
                },
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────── Per-ward (no search) tab body ─────────────────

  Widget _wardPatients(Ward ward) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.patientsCollection)
          .where('wardId', isEqualTo: ward.id)
          .where('isActive', isEqualTo: true)
          .orderBy('admittedAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to load: ${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final patients = snap.data!.docs.map(Patient.fromFirestore).toList();
        if (patients.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 48,
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'No patients in ${ward.name}',
                  style: GoogleFonts.dmSans(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          itemCount: patients.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) =>
              _patientCard(patients[i], wardName: null),
        );
      },
    );
  }

  // ───────────────── Cross-ward search results ─────────────────

  Widget _searchResults(List<Ward> wards, Map<String, Ward> wardById) {
    final wardIds = wards.map((w) => w.id).toList();
    final ids = wardIds.length > 30 ? wardIds.sublist(0, 30) : wardIds;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.patientsCollection)
          .where('wardId', whereIn: ids)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "Couldn't search patients: ${snap.error}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        // Filter on client because Firestore can't do substring match.
        final all = snap.data!.docs.map(Patient.fromFirestore).toList();
        final q = _query;
        final results = all.where((p) {
          return p.name.toLowerCase().contains(q) ||
              p.bedNumber.toLowerCase().contains(q) ||
              p.diagnosis.toLowerCase().contains(q);
        }).toList()
          ..sort((a, b) {
            // Active patients first, then by recent admission.
            if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
            return b.admittedAt.compareTo(a.admittedAt);
          });

        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_search,
                    size: 48,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No patient matches "$_query"',
                    style: GoogleFonts.dmSans(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Searched across ${wards.length} ward${wards.length == 1 ? '' : 's'}',
                    style: GoogleFonts.dmSans(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
              child: Row(
                children: [
                  Text(
                    '${results.length} match${results.length == 1 ? '' : 'es'}',
                    style: GoogleFonts.dmSans(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '· across ${wards.length} ward${wards.length == 1 ? '' : 's'}',
                    style: GoogleFonts.dmSans(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                itemCount: results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = results[i];
                  final wardName = wardById[p.wardId]?.name;
                  return _patientCard(p, wardName: wardName);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ───────────────── Patient card (with optional highlight) ─────────────────

  Widget _patientCard(Patient p, {required String? wardName}) {
    final highlight = _query.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PatientDetailScreen(patientId: p.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlight
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.divider,
            width: highlight ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.doctorColor.withOpacity(0.1),
              child: Text(
                p.initials,
                style: const TextStyle(
                  color: AppColors.doctorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _highlightText(
                          p.name,
                          baseStyle: GoogleFonts.dmSans(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (p.bedNumber.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: _highlightText(
                            'Bed ${p.bedNumber}',
                            baseStyle: GoogleFonts.dmSans(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Builder(builder: (_) {
                        final hasEdge = context.watch<CameraProvider>().cameras
                            .any((c) => c.patientId == p.id && c.isEnabled);
                        if (!hasEdge) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.teal.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videocam, size: 10, color: Colors.teal.shade600),
                                const SizedBox(width: 3),
                                Text(
                                  'EDGE',
                                  style: GoogleFonts.dmSans(
                                    color: Colors.teal.shade600,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  if (p.diagnosis.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    _highlightText(
                      p.diagnosis,
                      baseStyle: GoogleFonts.dmSans(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        DateFormat.yMMMd().format(p.admittedAt),
                        style: GoogleFonts.dmSans(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusChip(p.isActive),
                      if (wardName != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.corporate_fare,
                                size: 11,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                wardName,
                                style: GoogleFonts.dmSans(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: AppColors.textSecondary,
              ),
              onSelected: (v) => _handleMenu(p, v),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete permanently',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Wraps [text] in a RichText that highlights every case-insensitive
  /// occurrence of the active search query, using the app's primary
  /// accent. If the search box is empty, falls back to a plain Text.
  Widget _highlightText(
    String text, {
    required TextStyle baseStyle,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    if (_query.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    final lower = text.toLowerCase();
    final q = _query;
    final spans = <TextSpan>[];
    int i = 0;
    while (i < text.length) {
      final hit = lower.indexOf(q, i);
      if (hit < 0) {
        spans.add(TextSpan(text: text.substring(i), style: baseStyle));
        break;
      }
      if (hit > i) {
        spans.add(
          TextSpan(text: text.substring(i, hit), style: baseStyle),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(hit, hit + q.length),
          style: baseStyle.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            backgroundColor: AppColors.primary.withOpacity(0.12),
          ),
        ),
      );
      i = hit + q.length;
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  Future<void> _handleMenu(Patient p, String action) async {
    final provider = context.read<PatientProvider>();
    if (action != 'delete') return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${p.name}?'),
        content: const Text(
          'This will permanently delete the patient and every note tagged to them — fully erased from our database. There is no backup and no way to recover this data once you tap Delete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await provider.deletePatient(p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '${p.name} deleted' : 'Failed to delete'),
        ),
      );
    }
  }

  Widget _statusChip(bool active) {
    final color = active ? AppColors.accent : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        active ? 'Active' : 'Discharged',
        style: GoogleFonts.dmSans(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
