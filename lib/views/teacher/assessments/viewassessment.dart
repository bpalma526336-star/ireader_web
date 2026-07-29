import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/assessment.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/theme.dart';

class ViewAssessment extends StatefulWidget {
  final SchoolYear schoolyear;
  const ViewAssessment({super.key, required this.schoolyear});

  @override
  State<ViewAssessment> createState() => _ViewAssessmentState();
}

class _ViewAssessmentState extends State<ViewAssessment> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> _fetchAssessments() {
    return _firestore
        .collection('assessment')
        .where('schoolyearid', isEqualTo: widget.schoolyear.id)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final bool isMobileS = screenWidth <= 320;
    final bool isMobile = screenWidth <= 600;
    final bool isTablet = screenWidth > 600 && screenWidth <= 1024;

    double horizontalPadding = isMobileS
        ? 12
        : isMobile
        ? 16
        : isTablet
        ? 32
        : 60;

    double titleFontSize = isMobileS
        ? 16
        : isMobile
        ? 18
        : isTablet
        ? 22
        : 26;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: true,
      ),

      // 🔥 BODY
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: isMobile ? 20 : 30),

            // ✅ CENTERED TITLE (Moved from AppBar)
            Text(
              "Assessments\nSchool Year ${widget.schoolyear.schoolyearstart}-${widget.schoolyear.schoolyearend}",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),

            SizedBox(height: isMobile ? 20 : 30),

            // 🔥 LIST SECTION
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _fetchAssessments(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "No assessments found.",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  final assessments = snapshot.data!.docs
                      .map(
                        (doc) => Assessment.fromMap(
                          doc.id,
                          doc.data() as Map<String, dynamic>,
                        ),
                      )
                      .toList();

                  int getStageNumber(String title) {
                    final regex = RegExp(
                      r'Stage\s*(\d+)',
                      caseSensitive: false,
                    );
                    final match = regex.firstMatch(title);
                    return match != null ? int.parse(match.group(1)!) : 0;
                  }

                  assessments.sort(
                    (a, b) => getStageNumber(
                      a.assessmenttitle,
                    ).compareTo(getStageNumber(b.assessmenttitle)),
                  );

                  return ListView.builder(
                    itemCount: assessments.length,
                    itemBuilder: (context, index) {
                      final assessment = assessments[index];

                      return Container(
                        margin: EdgeInsets.only(bottom: isMobile ? 14 : 18),
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 14 : 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // TITLE ROW
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        assessment.assessmenttitle,
                                        style: TextStyle(
                                          fontSize: isMobile ? 15 : 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // DETAILS (Responsive Wrap)
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    _infoItem(
                                      Icons.remove_red_eye,
                                      "Visibility: ${assessment.visibility}",
                                    ),
                                    _infoItem(
                                      Icons.date_range,
                                      "Date: ${assessment.date}",
                                    ),
                                    _infoItem(
                                      Icons.vpn_key,
                                      "Code: ${assessment.accesscode}",
                                    ),
                                    _infoItem(
                                      Icons.timer,
                                      "Limit: ${assessment.timelimit} min",
                                    ),
                                    _infoItem(
                                      Icons.abc,
                                      "Total Words: ${assessment.totalwords}",
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 4),
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
