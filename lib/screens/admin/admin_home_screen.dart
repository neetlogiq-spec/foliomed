import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/ward.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/ward_provider.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../utils/share_helper.dart';
import '../../widgets/support_sheet.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../widgets/foliomed_brand.dart';
import 'add_ward_screen.dart';
import 'ward_detail_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  // Cheap analytics surface — most counts come from Firestore aggregation
  // queries (each costs 1 read per up to 1000 docs counted, vs N reads
  // for fetching them).
  int _staffCount = 0;
  int _wardCount = 0;
  int _activePatientCount = 0;
  int _totalPatientCount = 0;
  int _totalNoteCount = 0;
  int _notesToday = 0;
  int _ackedNoteCount = 0;
  int _commentCount = 0;
  int _urgentNoteCount = 0;
  bool _loadingCounts = true;
  List<_RecentActivityItem> _recent = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WardProvider>().subscribeToWards();
      _loadCounts();
    });
  }

  Future<void> _loadCounts() async {
    final db = FirebaseFirestore.instance;
    setState(() => _loadingCounts = true);
    try {
      // Use count() aggregation everywhere we just need a number — way
      // cheaper than fetching the docs. Each call is at most a few reads
      // regardless of collection size.
      final startOfDay = DateTime.now();
      final midnight = DateTime(
        startOfDay.year,
        startOfDay.month,
        startOfDay.day,
      );

      final results = await Future.wait<dynamic>([
        db
            .collection(AppConstants.usersCollection)
            .count()
            .get(), // 0
        db.collection(AppConstants.wardsCollection).count().get(), // 1
        db
            .collection(AppConstants.patientsCollection)
            .where('isActive', isEqualTo: true)
            .count()
            .get(), // 2
        db.collection(AppConstants.patientsCollection).count().get(), // 3
        db.collection(AppConstants.notesCollection).count().get(), // 4
        db
            .collection(AppConstants.notesCollection)
            .where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(midnight))
            .count()
            .get(), // 5
        db
            .collection(AppConstants.notesCollection)
            .where('isAcknowledged', isEqualTo: true)
            .count()
            .get(), // 6
        db
            .collection(AppConstants.notesCollection)
            .where('priority', isEqualTo: 'Urgent')
            .count()
            .get(), // 7
        // Recent activity feed — cheap, capped at 5.
        db
            .collection(AppConstants.notesCollection)
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get(), // 8
        // Cumulative comment counter — read the metrics totals doc.
        db.collection('metrics').doc('totals').get(), // 9
      ]);

      final users = results[0] as AggregateQuerySnapshot;
      final wards = results[1] as AggregateQuerySnapshot;
      final activePatients = results[2] as AggregateQuerySnapshot;
      final allPatients = results[3] as AggregateQuerySnapshot;
      final allNotes = results[4] as AggregateQuerySnapshot;
      final notesToday = results[5] as AggregateQuerySnapshot;
      final ackedNotes = results[6] as AggregateQuerySnapshot;
      final urgentNotes = results[7] as AggregateQuerySnapshot;
      final recentNotes = results[8] as QuerySnapshot<Map<String, dynamic>>;
      final totalsDoc = results[9] as DocumentSnapshot<Map<String, dynamic>>;

      final commentCount =
          (totalsDoc.data()?['commentCount'] as num?)?.toInt() ?? 0;

      final recent = recentNotes.docs.map((d) {
        final data = d.data();
        return _RecentActivityItem(
          authorName: data['authorName'] as String? ?? '',
          patientName: data['patientName'] as String? ?? '',
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _staffCount = users.count ?? 0;
        _wardCount = wards.count ?? 0;
        _activePatientCount = activePatients.count ?? 0;
        _totalPatientCount = allPatients.count ?? 0;
        _totalNoteCount = allNotes.count ?? 0;
        _notesToday = notesToday.count ?? 0;
        _ackedNoteCount = ackedNotes.count ?? 0;
        _urgentNoteCount = urgentNotes.count ?? 0;
        _commentCount = commentCount;
        _recent = recent;
        _loadingCounts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCounts = false);
    }
  }

  /// Acknowledgement rate as a 0-100 integer percent. Returns null when
  /// there are no notes yet.
  int? get _ackRatePct {
    if (_totalNoteCount == 0) return null;
    return ((_ackedNoteCount / _totalNoteCount) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _header(user?.name ?? 'Admin'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadCounts,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statsGrid(),
                      const SizedBox(height: 24),
                      _wardsOverview(),
                      const SizedBox(height: 24),
                      _staffActivity(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'admin_home_fab',
        backgroundColor: AppColors.adminColor,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddWardScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _header(String name) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.appBarBg,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const FolioMedBrand(size: 36),
          const Spacer(),
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Share FolioMed',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => ShareHelper.shareApp(),
          ),
          IconButton(
            tooltip: 'Support the developer',
            icon: const Icon(
              Icons.local_cafe_outlined,
              color: Color(0xFFE57F00),
            ),
            onPressed: () => showSupportSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid() {
    final ackPct = _ackRatePct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Analytics',
            style: GoogleFonts.dmSans(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _statCard(
              'Total Wards',
              '$_wardCount',
              Icons.corporate_fare,
              AppColors.adminColor,
            ),
            _statCard(
              'Total Users',
              '$_staffCount',
              Icons.people_outline,
              AppColors.doctorColor,
            ),
            _statCard(
              'Active Patients',
              '$_activePatientCount',
              Icons.favorite_outline,
              AppColors.accent,
            ),
            _statCard(
              'Total Patients',
              '$_totalPatientCount',
              Icons.person_outline,
              AppColors.primary,
            ),
            _statCard(
              'Total Notes',
              '$_totalNoteCount',
              Icons.notes_outlined,
              AppColors.primary,
            ),
            _statCard(
              'Notes Today',
              '$_notesToday',
              Icons.today_outlined,
              AppColors.warning,
            ),
            _statCard(
              'Urgent Notes',
              '$_urgentNoteCount',
              Icons.priority_high,
              AppColors.danger,
            ),
            _statCard(
              'Acknowledged',
              '$_ackedNoteCount',
              Icons.check_circle_outline,
              AppColors.accent,
            ),
            _statCard(
              'Replies',
              '$_commentCount',
              Icons.forum_outlined,
              AppColors.primary,
            ),
            _statCard(
              'Ack Rate',
              ackPct == null ? '—' : '$ackPct%',
              Icons.verified_outlined,
              AppColors.accent,
            ),
          ],
        ),
        if (_loadingCounts)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                const SizedBox(width: 8),
                Text(
                  'Refreshing analytics…',
                  style: GoogleFonts.dmSans(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
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
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.dmSans(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _wardsOverview() {
    return Consumer<WardProvider>(
      builder: (context, wp, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Wards Overview',
                    style: GoogleFonts.dmSans(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddWardScreen(),
                      ),
                    );
                  },
                  child: const Text('Add Ward'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (wp.wards.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(
                  'No wards yet',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(color: AppColors.textSecondary),
                ),
              )
            else
              for (final w in wp.wards)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _wardCard(w),
                ),
          ],
        );
      },
    );
  }

  Widget _wardCard(Ward w) {
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
              Expanded(
                child: Text(
                  w.name,
                  style: GoogleFonts.dmSans(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(
                  w.floor,
                  style: GoogleFonts.dmSans(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                w.headDoctorName,
                style: GoogleFonts.dmSans(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Capacity: ${w.capacity}',
                style: GoogleFonts.dmSans(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WardDetailScreen(wardId: w.id),
                    ),
                  );
                },
                child: const Text('Manage'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _staffActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Staff Activity',
          style: GoogleFonts.dmSans(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              if (_recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No recent activity',
                    style: GoogleFonts.dmSans(
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                for (int i = 0; i < _recent.length; i++) ...[
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: getAvatarColor(_recent[i].authorName)
                          .withOpacity(0.15),
                      child: Text(
                        getInitials(_recent[i].authorName),
                        style: TextStyle(
                          color: getAvatarColor(_recent[i].authorName),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text(
                      _recent[i].authorName,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'added a note to ${_recent[i].patientName}',
                      style: GoogleFonts.dmSans(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Text(
                      timeago.format(_recent[i].createdAt, locale: 'en_short'),
                      style: GoogleFonts.dmSans(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (i < _recent.length - 1) const Divider(height: 1),
                ],
              TextButton(
                onPressed: () {},
                child: const Text('View All Activity'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentActivityItem {
  final String authorName;
  final String patientName;
  final DateTime createdAt;

  _RecentActivityItem({
    required this.authorName,
    required this.patientName,
    required this.createdAt,
  });
}
