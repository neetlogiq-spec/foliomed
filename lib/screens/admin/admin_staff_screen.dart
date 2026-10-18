import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_user.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_theme.dart';
import '../../widgets/role_badge.dart';
import '../../widgets/support_action.dart';
import 'add_staff_bottom_sheet.dart';
import '../../providers/theme_provider.dart';

class AdminStaffScreen extends StatefulWidget {
  const AdminStaffScreen({super.key});

  @override
  State<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  bool _searching = false;
  String _query = '';
  String _filter = 'All';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(AppUser u) {
    switch (_filter) {
      case 'Doctors':
        return u.role == UserRole.doctor;
      case 'Nurses':
        return u.role == UserRole.nurse;
      case 'Admins':
        return u.role == UserRole.admin;
      case 'All':
      default:
        return true;
    }
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
                  hintText: 'Search staff',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
              )
            : const Text('Staff Management'),
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
      body: Column(
        children: [
          _filterChips(),
          Expanded(
            // One-shot get() rather than a live stream over the whole
            // users collection. The admin sees a snapshot of all staff at
            // open-time; pull-to-refresh would re-fetch. A live stream
            // here billed reads on every fcmToken refresh of every user.
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection(AppConstants.usersCollection)
                  .limit(500)
                  .get(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all =
                    snap.data!.docs.map(AppUser.fromFirestore).toList();
                final staff = all.where((u) {
                  if (!_matchesFilter(u)) return false;
                  if (_query.isEmpty) return true;
                  return u.name.toLowerCase().contains(_query) ||
                      u.email.toLowerCase().contains(_query);
                }).toList();
                if (staff.isEmpty) {
                  return Center(
                    child: Text(
                      'No staff found',
                      style: GoogleFonts.dmSans(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: staff.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _staffCard(staff[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin_staff_fab',
        backgroundColor: AppColors.adminColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add Staff'),
        onPressed: () =>
            showAddStaffBottomSheet(context, showWardSelector: true),
      ),
    );
  }

  Widget _filterChips() {
    final filters = ['All', 'Doctors', 'Nurses', 'Admins'];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = filters[i];
          final selected = _filter == f;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _filter = f),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.divider,
                ),
              ),
              child: Text(
                f,
                style: GoogleFonts.dmSans(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _staffCard(AppUser user) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showStaffDetail(user),
      child: Container(
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
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      'Ward ${user.wardId}',
                      style: GoogleFonts.dmSans(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            RoleBadge(role: user.role, small: true),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: AppColors.textSecondary,
              ),
              onSelected: (value) {
                if (value == 'ward') {
                  _changeWard(user);
                } else if (value == 'remove') {
                  _removeStaff(user);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'ward', child: Text('Change Ward')),
                PopupMenuItem(value: 'remove', child: Text('Remove Staff')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStaffDetail(AppUser user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: user.roleColor.withOpacity(0.15),
              child: Text(
                user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                style: TextStyle(
                  color: user.roleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user.name,
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            RoleBadge(role: user.role),
            const SizedBox(height: 12),
            Text(
              user.email,
              style: GoogleFonts.dmSans(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              'Ward ${user.wardId}',
              style: GoogleFonts.dmSans(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeWard(AppUser user) async {
    final controller = TextEditingController(text: user.wardId);
    final newWard = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Ward'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Ward ID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newWard != null && newWard.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .update({'wardId': newWard});
    }
  }

  Future<void> _removeStaff(AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove staff?'),
        content: Text(
          'This removes ${user.name} from the staff directory.',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .delete();
    }
  }
}
