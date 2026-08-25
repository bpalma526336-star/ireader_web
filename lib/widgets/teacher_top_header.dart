import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/teacher.dart';
import 'package:ireader_web/theme.dart';

class TeacherHeader extends StatelessWidget {
  final Teacher teacher;
  final SchoolYear schoolyear;
  final VoidCallback? onMenuPressed;

  const TeacherHeader({
    super.key,
    required this.teacher,
    required this.schoolyear,
    this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    final teacherName = '${teacher.firstname} ${teacher.lastname}'.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: [
          if (onMenuPressed != null) ...[
            IconButton(
              onPressed: onMenuPressed,
              icon: const Icon(Icons.menu, size: 20),
              tooltip: 'Open navigation',
            ),
            const SizedBox(width: 4),
          ],
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'iR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'iReader',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      teacher.firstname.isNotEmpty
                          ? teacher.firstname[0].toUpperCase()
                          : 'T',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      teacherName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    Text(
                      'SY ${schoolyear.schoolyearstart}-${schoolyear.schoolyearend}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
