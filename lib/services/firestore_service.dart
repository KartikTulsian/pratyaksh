import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:iem_attendance_app/models/subject_model.dart';
import 'package:intl/intl.dart';

class FirestoreService {
  Future<bool> isDayActive(String day) async {
    return true;
  }

  Future<List<SubjectModel>> getSubjectsForDay({
    required String year,
    required String dept,
    required String semester,
    required String day,
    required String enrollment,
  }) async {
    debugPrint("🔍 getSubjectsForDay() called with: year=$year, dept=$dept, sem=$semester, day=$day");

    try {
      final snap = await FirebaseFirestore.instance
          .collection("timetable")
          .where("year", isEqualTo: int.parse(year))
          .where("semester", isEqualTo: int.parse(semester))
          .where("day", isEqualTo: day)
          .get();

      debugPrint("Fetched ${snap.docs.length} subjects for $day");

      final subjects = <SubjectModel>[];

      // Get user ID once outside the loop
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('enrollment', isEqualTo: enrollment)
          .limit(1)
          .get();

      String? userId = userQuery.docs.isNotEmpty ? userQuery.docs.first.id : null;
      debugPrint("📋 User ID for enrollment $enrollment: $userId");

      final today = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(today);

      for (var doc in snap.docs) {
        debugPrint("🧾 Subject: ${doc.data()}");

        final subject = SubjectModel.fromFirestore(doc);
        bool hasMarked = false;

        // Filter by department
        final deptList = subject.dept.split(',').map((d) => d.trim()).toList();
        if (!deptList.contains(dept)) {
          debugPrint("❌ Subject ${subject.name} not for dept $dept (available: ${subject.dept})");
          continue;
        }

        debugPrint("✅ Subject ${subject.name} matches dept $dept");

        // Check if attendance exists (but don't let this block subject display)
        if (userId != null) {
          try {
            final attendancePath = 'attendance/$year/$semester/$dept/$dateStr/${subject.period}/entries';

            final attendanceDoc = await FirebaseFirestore.instance
                .collection(attendancePath)
                .doc(userId)
                .get();

            hasMarked = attendanceDoc.exists;
            debugPrint("📋 Checked attendance at: $attendancePath/$userId - Found: $hasMarked");
          } catch (e) {
            debugPrint("⚠️ Error checking attendance for ${subject.name}: $e (continuing anyway)");
            // Continue with hasMarked = false
          }
        } else {
          debugPrint("⚠️ No user ID found for enrollment $enrollment");
        }

        // Always add the subject regardless of attendance status
        subjects.add(subject.copyWith(attended: hasMarked));
        debugPrint("📦 Added SubjectModel: ${subject.name}, attended: $hasMarked");
      }

      subjects.sort((a, b) => a.period.compareTo(b.period));
      debugPrint("✅ Returning ${subjects.length} subjects to UI");

      return subjects;

    } catch (e) {
      debugPrint("❌ Error in getSubjectsForDay: $e");
      return []; // Return empty list instead of throwing
    }
  }
}