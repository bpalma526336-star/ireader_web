import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/core/firestore_collections.dart';
import 'package:ireader_web/model/school.dart';
import 'package:ireader_web/theme.dart';

class MigrateSchoolDialog extends StatefulWidget {
  const MigrateSchoolDialog({super.key});

  @override
  State<MigrateSchoolDialog> createState() => _MigrateSchoolDialogState();
}

class _MigrateSchoolDialogState extends State<MigrateSchoolDialog> {
  final _firestore = FirebaseFirestore.instance;

  List<School> _schools = [];
  String? _selectedSchoolId;
  bool _loadingSchools = true;
  bool _migrating = false;
  bool _done = false;
  String _statusMessage = '';
  int _teacherCount = 0;
  int _studentCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    final snap = await _firestore.collection(FirestoreCollections.schools).get();
    if (!mounted) return;
    final schools = snap.docs.map((d) => School.fromMap(d.id, d.data())).toList();
    setState(() {
      _schools = schools;
      if (schools.length == 1) _selectedSchoolId = schools.first.id;
      _loadingSchools = false;
    });
  }

  Future<void> _runMigration() async {
    if (_selectedSchoolId == null) return;
    setState(() {
      _migrating = true;
      _done = false;
      _teacherCount = 0;
      _studentCount = 0;
      _statusMessage = 'Scanning teachers...';
    });

    try {
      // ── Teachers ──────────────────────────────────────────────────────────
      final teacherSnap = await _firestore.collection(FirestoreCollections.teachers).get();
      var batch = _firestore.batch();
      int ops = 0;

      for (final doc in teacherSnap.docs) {
        final existing = doc.data()['schoolid'];
        if (existing == null || existing.toString().isEmpty) {
          batch.update(doc.reference, {'schoolid': _selectedSchoolId});
          ops++;
          _teacherCount++;
          if (ops >= 499) {
            await batch.commit();
            batch = _firestore.batch();
            ops = 0;
          }
        }
      }
      if (ops > 0) await batch.commit();

      if (!mounted) return;
      setState(() => _statusMessage = 'Scanning students...');

      // ── Students ──────────────────────────────────────────────────────────
      final studentSnap = await _firestore.collection(FirestoreCollections.students).get();
      batch = _firestore.batch();
      ops = 0;

      for (final doc in studentSnap.docs) {
        final existing = doc.data()['schoolid'];
        if (existing == null || existing.toString().isEmpty) {
          batch.update(doc.reference, {'schoolid': _selectedSchoolId});
          ops++;
          _studentCount++;
          if (ops >= 499) {
            await batch.commit();
            batch = _firestore.batch();
            ops = 0;
          }
        }
      }
      if (ops > 0) await batch.commit();

      if (!mounted) return;
      setState(() {
        _migrating = false;
        _done = true;
        _statusMessage = 'Migration complete!';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _migrating = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final school = _schools.where((s) => s.id == _selectedSchoolId).isNotEmpty
        ? _schools.firstWhere((s) => s.id == _selectedSchoolId)
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Migrate Existing Data to School',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Assigns all teachers and students that have no school to the selected school.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _migrating ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_loadingSchools)
                const Center(child: CircularProgressIndicator())
              else if (_schools.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFECACA))),
                  child: const Text('No schools found. Please add a school first.', style: TextStyle(fontSize: 13, color: Color(0xFFB91C1C))),
                )
              else ...[
                DropdownButtonFormField<String>(
                  value: _selectedSchoolId,
                  decoration: const InputDecoration(
                    labelText: 'Target School',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  items: _schools.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: _migrating ? null : (v) => setState(() => _selectedSchoolId = v),
                ),
                const SizedBox(height: 16),

                // Warning box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will update all teachers and students that currently have no school assigned. Records already assigned to a school will not be changed.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Progress / result
                if (_migrating) ...[
                  Row(children: [
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Text(_statusMessage, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor)),
                  ]),
                  const SizedBox(height: 16),
                ] else if (_done) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBBF7D0))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                          SizedBox(width: 6),
                          Text('Migration complete!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF15803D))),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                          '• $_teacherCount teacher${_teacherCount == 1 ? '' : 's'} updated\n• $_studentCount student${_studentCount == 1 ? '' : 's'} updated\n• Assigned to: ${school?.name ?? ''}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (_statusMessage.startsWith('Error')) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFECACA))),
                    child: Text(_statusMessage, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!_done)
                      TextButton(
                        onPressed: _migrating ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    const SizedBox(width: 8),
                    if (_done)
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('Done'),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: (_migrating || _selectedSchoolId == null) ? null : _runMigration,
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('Run Migration'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
