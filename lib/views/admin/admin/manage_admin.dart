import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/widgets/admin_sidebar.dart';
import 'package:ireader_web/widgets/admin_top_header.dart';
import 'package:ireader_web/model/admin.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/admin/add_admin.dart';
import 'package:ireader_web/views/admin/admin/add_admin_dialog.dart';

class ManageAdminScreen extends StatefulWidget {
  const ManageAdminScreen({super.key});

  @override
  State<ManageAdminScreen> createState() => _ManageAdminScreenState();
}

class _ManageAdminScreenState extends State<ManageAdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  Stream<QuerySnapshot> _fetchAdmins() {
    return _firestore.collection('admins').snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddAdmin() {
    final isMobile = MediaQuery.of(context).size.width <= 768;
    if (isMobile) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAdminScreen()));
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AddAdminDialog(admin: null),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      drawer: isDesktop ? null : Drawer(child: AdminSidebar(activeRoute: AdminRoute.admins)),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) const AdminSidebar(activeRoute: AdminRoute.admins),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminTopHeader(
                  pageTitle: 'Manage Admins',
                  pageSubtitle: 'Administrator accounts and access control',
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _fetchAdmins(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(child: Text('Error loading admins'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppTheme.primaryColor),
                        );
                      }

                      var admins = snapshot.data!.docs
                          .map((doc) => Admin.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                          .toList();

                      if (_selectedFilter != 'All') {
                        admins = admins.where((a) => a.status == _selectedFilter).toList();
                      }

                      final query = _searchController.text.trim().toLowerCase();
                      if (query.isNotEmpty) {
                        admins = admins.where((a) {
                          final name = '${a.firstname} ${a.middlename ?? ''} ${a.lastname}'.toLowerCase();
                          return name.contains(query) || a.email.toLowerCase().contains(query);
                        }).toList();
                      }

                      return Column(
                        children: [
                          _buildToolbar(admins.length, snapshot.data!.docs.length),
                          Expanded(child: _buildTable(admins)),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(int shown, int total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search admins by name or email',
                  hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondaryColor),
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _filterTab('All'),
          _filterTab('ACTIVE', label: 'Active'),
          _filterTab('INACTIVE', label: 'Inactive'),
          const SizedBox(width: 12),
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              onPressed: _openAddAdmin,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Admin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterTab(String value, {String? label}) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => _selectedFilter = value),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            ),
          ),
          child: Center(
            child: Text(
              label ?? value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textSecondaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTable(List<Admin> admins) {
    if (admins.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 52, color: AppTheme.textSecondaryColor.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('No admins found', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 15)),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.backgroundColor,
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondaryColor, letterSpacing: 0.8))),
                Expanded(flex: 3, child: Text('EMAIL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondaryColor, letterSpacing: 0.8))),
                Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondaryColor, letterSpacing: 0.8))),
                SizedBox(width: 100, child: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondaryColor, letterSpacing: 0.8))),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: admins.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderColor),
              itemBuilder: (context, index) => _buildRow(admins[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(Admin admin) {
    final isActive = admin.status == 'ACTIVE';
    final fullName = '${admin.firstname} ${admin.middlename != null && admin.middlename!.isNotEmpty ? "${admin.middlename} " : ""}${admin.lastname}'.trim();
    final initial = admin.firstname.isNotEmpty ? admin.firstname[0].toUpperCase() : 'A';

    final avatarColors = [
      const Color(0xFF6366F1),
      const Color(0xFF0EA5E9),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
    ];
    final avatarColor = avatarColors[fullName.codeUnitAt(0) % avatarColors.length];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fullName,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              admin.email,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isActive ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        color: isActive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    final isMobile = MediaQuery.of(context).size.width <= 768;
                    if (isMobile) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AddAdminScreen(admin: admin)));
                    } else {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => AddAdminDialog(admin: admin),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: const Icon(Icons.edit_outlined, size: 15, color: AppTheme.textSecondaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: isActive,
                  activeThumbColor: const Color(0xFF16A34A),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (val) async {
                    final newStatus = val ? 'ACTIVE' : 'INACTIVE';
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        title: Text(val ? 'Activate Admin' : 'Deactivate Admin'),
                        content: Text(
                          val
                              ? 'Set this admin as active?'
                              : 'Set this admin as inactive?',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
                        ],
                      ),
                    );
                    if (confirmed ?? false) {
                      _firestore.collection('admins').doc(admin.id).update({'status': newStatus});
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
