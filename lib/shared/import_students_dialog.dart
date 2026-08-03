import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/student.dart';
import 'package:ireader_web/theme.dart';
import 'package:universal_html/html.dart' as html;

class _ParsedRow {
  final int rowNumber;
  final String lrn;
  final String firstname;
  final String middlename;
  final String lastname;
  final String gender;
  final String gstscore;
  final String? error;

  const _ParsedRow({
    required this.rowNumber,
    required this.lrn,
    required this.firstname,
    required this.middlename,
    required this.lastname,
    required this.gender,
    required this.gstscore,
    this.error,
  });

  bool get isValid => error == null;

  String get gradelevelread {
    final score = int.tryParse(gstscore) ?? 0;
    if (score <= 7) return 'Grade 1';
    if (score <= 13) return 'Grade 2';
    return 'NOT QUALIFIED';
  }
}

class ImportStudentsDialog extends StatefulWidget {
  final Section section;
  final SchoolYear schoolyear;

  const ImportStudentsDialog({
    super.key,
    required this.section,
    required this.schoolyear,
  });

  @override
  State<ImportStudentsDialog> createState() => _ImportStudentsDialogState();
}

class _ImportStudentsDialogState extends State<ImportStudentsDialog> {
  List<_ParsedRow> _rows = [];
  bool _filePicked = false;
  String _fileName = '';
  bool _importing = false;

  void _downloadTemplate() {
    const template =
        'LRN,First Name,Middle Name,Last Name,Gender,GST Score\r\n';
    final bytes = utf8.encode(template);
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'Phil_IRI_Student_Import_Template.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void _pickFile() {
    final input = html.FileUploadInputElement()..accept = '.csv';
    input.click();
    input.onChange.listen((_) {
      final file = input.files?.first;
      if (file == null) return;
      final reader = html.FileReader();
      reader.readAsText(file);
      reader.onLoad.listen((_) {
        final content = reader.result as String;
        if (mounted) {
          setState(() {
            _fileName = file.name;
            _filePicked = true;
            _rows = _parseCsv(content);
          });
        }
      });
    });
  }

  List<_ParsedRow> _parseCsv(String content) {
    final lines = content
        .split('\n')
        .map((l) => l.replaceAll('\r', '').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.length < 2) return [];

    final dataLines = lines.skip(1).toList();
    final rows = <_ParsedRow>[];

    for (int i = 0; i < dataLines.length; i++) {
      final parts = dataLines[i].split(',');

      if (parts.length < 6) {
        rows.add(_ParsedRow(
          rowNumber: i + 2,
          lrn: '', firstname: '', middlename: '', lastname: '', gender: '', gstscore: '',
          error: 'Invalid format — expected 6 columns',
        ));
        continue;
      }

      final lrn = parts[0].trim();
      final firstname = parts[1].trim();
      final middlename = parts[2].trim();
      final lastname = parts[3].trim();
      final gender = parts[4].trim();
      final gstscore = parts[5].trim();

      String? error;
      if (lrn.isEmpty) {
        error = 'LRN is required';
      } else if (firstname.isEmpty) {
        error = 'First name is required';
      } else if (lastname.isEmpty) {
        error = 'Last name is required';
      } else if (gender != 'Male' && gender != 'Female') {
        error = 'Gender must be Male or Female';
      } else {
        final gst = int.tryParse(gstscore);
        if (gst == null) {
          error = 'GST Score must be a number';
        } else if (gst >= 14) {
          error = 'GST ≥ 14 (not qualified)';
        }
      }

      rows.add(_ParsedRow(
        rowNumber: i + 2,
        lrn: lrn,
        firstname: firstname,
        middlename: middlename,
        lastname: lastname,
        gender: gender,
        gstscore: gstscore,
        error: error,
      ));
    }

    return rows;
  }

  Future<void> _importStudents() async {
    final validRows = _rows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) return;

    setState(() => _importing = true);

    final firestore = FirebaseFirestore.instance;
    int imported = 0;
    int skipped = 0;

    for (final row in validRows) {
      try {
        final existing = await firestore
            .collection('students')
            .where('lrn', isEqualTo: row.lrn)
            .where('schoolyearid', isEqualTo: widget.schoolyear.id)
            .where('sectionid', isEqualTo: widget.section.id)
            .get();

        if (existing.docs.isNotEmpty) {
          skipped++;
          continue;
        }

        final docId = firestore.collection('students').doc().id;
        await firestore.collection('students').doc(docId).set(
          Student(
            id: docId,
            lrn: row.lrn,
            sectionid: widget.section.id,
            schoolyearid: widget.schoolyear.id,
            firstname: row.firstname,
            middlename: row.middlename.isEmpty ? null : row.middlename,
            lastname: row.lastname,
            gstscore: row.gstscore,
            gradelevelread: row.gradelevelread,
            gender: row.gender,
            readlevel: 'Not Started',
            readingresult: 'Not Started',
            comprehensionresult: 'Not Started',
            status: 'ACTIVE',
          ).toMap(),
        );
        imported++;
      } catch (_) {
        skipped++;
      }
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Imported $imported student${imported == 1 ? '' : 's'}'
          '${skipped > 0 ? " · $skipped skipped (duplicates or errors)" : ""}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: imported > 0 ? AppTheme.secondaryColor : Colors.orange,
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: AppTheme.textSecondaryColor,
    letterSpacing: 0.5,
  );

  @override
  Widget build(BuildContext context) {
    final validCount = _rows.where((r) => r.isValid).length;
    final errorCount = _rows.where((r) => !r.isValid).length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 660),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Import Students from Spreadsheet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.section.sectionname} · SY ${widget.schoolyear.schoolyearstart}–${widget.schoolyear.schoolyearend}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _importing ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18, color: AppTheme.textSecondaryColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.borderColor, height: 1),
            const SizedBox(height: 16),

            // ── Step 1: Download template ────────────────────────────────────
            _buildStep(
              '1',
              'Download the CSV Template',
              'Fill it in using Google Sheets or Excel. Do not change the column headers.',
              OutlinedButton.icon(
                onPressed: _importing ? null : _downloadTemplate,
                icon: const Icon(Icons.download, size: 15),
                label: const Text('Download Template'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Step 2: Upload ───────────────────────────────────────────────
            _buildStep(
              '2',
              'Upload the Filled File',
              'In Google Sheets: File → Download → CSV. In Excel: Save As → CSV.',
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _importing ? null : _pickFile,
                    icon: const Icon(Icons.upload_file, size: 15),
                    label: const Text('Choose CSV File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (_filePicked) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.check_circle, size: 15, color: Color(0xFF22C55E)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _fileName,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Preview table ────────────────────────────────────────────────
            if (_filePicked && _rows.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Preview',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor),
                  ),
                  const SizedBox(width: 8),
                  if (validCount > 0) _badge('$validCount ready', const Color(0xFFDCFCE7), const Color(0xFF15803D)),
                  if (errorCount > 0) ...[
                    const SizedBox(width: 6),
                    _badge('$errorCount will be skipped', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(width: 30, child: Text('#', style: _headerStyle)),
                            Expanded(flex: 3, child: Text('LRN', style: _headerStyle)),
                            Expanded(flex: 5, child: Text('NAME', style: _headerStyle)),
                            Expanded(flex: 2, child: Text('GENDER', style: _headerStyle)),
                            Expanded(flex: 2, child: Text('GST', style: _headerStyle)),
                            SizedBox(width: 100, child: Text('STATUS', style: _headerStyle)),
                          ],
                        ),
                      ),
                      const Divider(color: AppTheme.borderColor, height: 1),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _rows.length,
                          separatorBuilder: (_, __) => const Divider(color: AppTheme.borderColor, height: 1),
                          itemBuilder: (_, i) {
                            final row = _rows[i];
                            final isError = !row.isValid;
                            return Container(
                              color: isError ? const Color(0xFFFFF5F5) : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 30,
                                    child: Text('${row.rowNumber}',
                                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryColor)),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(row.lrn,
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimaryColor)),
                                  ),
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      [row.firstname, if (row.middlename.isNotEmpty) row.middlename, row.lastname]
                                          .where((s) => s.isNotEmpty)
                                          .join(' '),
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textPrimaryColor),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(row.gender,
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(row.gstscore,
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: isError
                                        ? Tooltip(
                                            message: row.error ?? '',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.error_outline, size: 13, color: Color(0xFFEF4444)),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    row.error ?? '',
                                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFFEF4444)),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : const Row(
                                            children: [
                                              Icon(Icons.check_circle, size: 13, color: Color(0xFF22C55E)),
                                              SizedBox(width: 4),
                                              Text('Ready',
                                                  style: TextStyle(fontSize: 11, color: Color(0xFF22C55E))),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_filePicked && _rows.isEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, size: 16, color: Color(0xFF92400E)),
                    SizedBox(width: 8),
                    Text('No data rows found. Make sure the file has data below the header row.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(color: AppTheme.borderColor, height: 1),
            const SizedBox(height: 14),

            // ── Footer ──────────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.info_outline, size: 13, color: AppTheme.textSecondaryColor),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Duplicate students (same LRN in this section & school year) will be skipped automatically.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _importing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryColor)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: (_filePicked && validCount > 0 && !_importing) ? _importStudents : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    disabledBackgroundColor: AppTheme.borderColor,
                  ),
                  child: _importing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Import $validCount Student${validCount == 1 ? "" : "s"}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String step, String title, String subtitle, Widget action) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor)),
              Text(subtitle,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryColor, height: 1.4)),
              const SizedBox(height: 8),
              action,
            ],
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
