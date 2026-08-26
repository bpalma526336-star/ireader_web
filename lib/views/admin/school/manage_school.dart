import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/core/firestore_collections.dart';
import 'package:ireader_web/model/division.dart';
import 'package:ireader_web/model/school.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/school/add_school_dialog.dart';
import 'package:ireader_web/views/admin/school/migrate_school_dialog.dart';
import 'package:ireader_web/widgets/admin_sidebar.dart';
import 'package:ireader_web/widgets/admin_top_header.dart';

class ManageSchoolScreen extends StatefulWidget {
  const ManageSchoolScreen({super.key});

  @override
  State<ManageSchoolScreen> createState() => _ManageSchoolScreenState();
}

class _ManageSchoolScreenState extends State<ManageSchoolScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'All';
  String? _selectedDivisionFilter;
  final TextEditingController _searchController = TextEditingController();
  List<Division> _divisions = [];

  @override
  void initState() {
    super.initState();
    _loadDivisions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDivisions() async {
    final snap = await _firestore.collection(FirestoreCollections.divisions).get();
    if (!mounted) return;
    setState(() {
      _divisions = snap.docs.map((d) => Division.fromMap(d.id, d.data())).toList();
    });
  }

  Stream<QuerySnapshot> _fetchSchools() =>
      _firestore.collection(FirestoreCollections.schools).snapshots();

  String _divisionName(String id) {
    final match = _divisions.where((d) => d.id == id);
    return match.isNotEmpty ? match.first.name : '—';
  }

  void _openAdd() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AddSchoolDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      drawer: isDesktop ? null : Drawer(child: AdminSidebar(activeRoute: AdminRoute.schools)),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) const AdminSidebar(activeRoute: AdminRoute.schools),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminTopHeader(
                  pageTitle: 'Manage Schools',
                  pageSubtitle: 'Assign schools to divisions',
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _fetchSchools(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const Center(child: Text('Error loading schools'));
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                      }

                      var schools = snapshot.data!.docs
                          .map((d) => School.fromMap(d.id, d.data() as Map<String, dynamic>))
                          .toList();

                      if (_selectedFilter != 'All') {
                        schools = schools.where((s) => s.status == _selectedFilter).toList();
                      }

                      if (_selectedDivisionFilter != null) {
                        schools = schools.where((s) => s.divisionid == _selectedDivisionFilter).toList();
                      }

                      final query = _searchController.text.trim().toLowerCase();
                      if (query.isNotEmpty) {
                        schools = schools.where((s) => s.name.toLowerCase().contains(query)).toList();
                      }

                      return Column(
                        children: [
                          _buildToolbar(),
                          Expanded(child: _buildTable(schools)),
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

  Widget _buildToolbar() {
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
                  hintText: 'Search schools',
                  hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondaryColor),
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (_divisions.isNotEmpty)
            SizedBox(
              height: 38,
              child: DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    border: Border.all(color: AppTheme.borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String?>(
                    value: _selectedDivisionFilter,
                    hint: const Text('All Divisions', style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Divisions', style: TextStyle(fontSize: 13))),
                      ..._divisions.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(fontSize: 13)))),
                    ],
                    onChanged: (v) => setState(() => _selectedDivisionFilter = v),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          _filterTab('All'),
          _filterTab('ACTIVE', label: 'Active'),
          _filterTab('INACTIVE', label: 'Inactive'),
          const SizedBox(width: 12),
          SizedBox(
            height: 38,
            child: OutlinedButton.icon(
              onPressed: () => showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const MigrateSchoolDialog(),
              ),
              icon: const Icon(Icons.sync, size: 16),
              label: const Text('Migrate Data'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              onPressed: _openAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add School'),
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
            border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
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

  Widget _buildTable(List<School> schools) {
    if (schools.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 52, color: AppTheme.textSecondaryColor.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('No schools found', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 15)),
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
                Expanded(flex: 4, child: Text('SCHOOL NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondaryColor, letterSpacing: 0.8))),
                Expanded(flex: 3, child: Text('DIVISION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondaryColor, letterSpacing: 0.8))),
                Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondaryColor, letterSpacing: 0.8))),
                SizedBox(width: 100, child: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondaryColor, letterSpacing: 0.8))),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: schools.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderColor),
              itemBuilder: (context, i) => _buildRow(schools[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(School school) {
    final isActive = school.status == 'ACTIVE';
    const avatarColors = [Color(0xFF6366F1), Color(0xFF0EA5E9), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF8B5CF6)];
    final avatarColor = avatarColors[school.name.isNotEmpty ? school.name.codeUnitAt(0) % avatarColors.length : 0];
    final initial = school.name.isNotEmpty ? school.name[0].toUpperCase() : 'S';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle),
                  child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(school.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryColor), overflow: TextOverflow.ellipsis),
                      if (school.address != null && school.address!.isNotEmpty)
                        Text(school.address!, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryColor), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(_divisionName(school.divisionid), style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor), overflow: TextOverflow.ellipsis),
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
                    Container(width: 5, height: 5, decoration: BoxDecoration(color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(isActive ? 'ACTIVE' : 'INACTIVE', style: TextStyle(color: isActive ? const Color(0xFF15803D) : const Color(0xFFB91C1C), fontSize: 11, fontWeight: FontWeight.w600)),
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
                  onTap: () => showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => AddSchoolDialog(school: school),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.borderColor)),
                    child: const Icon(Icons.edit_outlined, size: 15, color: AppTheme.textSecondaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: isActive,
                  activeThumbColor: const Color(0xFF16A34A),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (val) async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        title: Text(val ? 'Activate School' : 'Deactivate School'),
                        content: Text(val ? 'Set "${school.name}" as active?' : 'Set "${school.name}" as inactive?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
                        ],
                      ),
                    );
                    if (confirmed ?? false) {
                      _firestore.collection(FirestoreCollections.schools).doc(school.id).update({'status': val ? 'ACTIVE' : 'INACTIVE'});
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
