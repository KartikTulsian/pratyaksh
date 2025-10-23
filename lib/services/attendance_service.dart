import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> markAttendance({
    required String userId,
    required String subjectId,
    required int period,
    String status = 'present',
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      final year = userData['year'].toString();
      final semester = userData['semester'].toString();
      final department = userData['dept'].toString();
      final enrollment = userData['enrollment'].toString();
      final studentName = userData['name'].toString();

      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);

      final attendancePath = 'attendance/$year/$semester/$department/$dateStr/$period/entries';

      final existingAttendance = await _firestore
          .collection(attendancePath)
          .doc(userId)
          .get();

      if (existingAttendance.exists) {
        print('Attendance already marked for this period');
        return false;
      }

      final subjectDoc = await _firestore.collection('timetable').doc(subjectId).get();
      final subjectData = subjectDoc.exists ? subjectDoc.data()! : {};

      await _firestore.collection(attendancePath).doc(userId).set({
        'userId': userId,
        'enrollment': enrollment,
        'studentName': studentName,
        'subjectId': subjectId,
        'subjectName': subjectData['name'] ?? 'Unknown Subject',
        'subjectCode': subjectData['code'] ?? 'Unknown Code',
        'period': period,
        'status': status,
        'markedAt': FieldValue.serverTimestamp(),
        'markedBy': 'face_recognition',
        'year': int.parse(year),
        'semester': int.parse(semester),
        'department': department,
        'date': dateStr,
      });

      print('Attendance marked successfully for $enrollment');
      return true;

    } catch (e) {
      print('Error marking attendance: $e');
      return false;
    }
  }

  Future<bool> isAttendanceMarked({
    required String userId,
    required int period,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final year = userData['year'].toString();
      final semester = userData['semester'].toString();
      final department = userData['dept'].toString();

      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);

      final attendanceDoc = await _firestore
          .collection('attendance/$year/$semester/$department/$dateStr/$period/entries')
          .doc(userId)
          .get();

      return attendanceDoc.exists;

    } catch (e) {
      print('Error checking attendance status: $e');
      return false;
    }
  }

  // CORRECTED: Get all class sessions using the proper path structure
  Future<List<Map<String, dynamic>>> _getClassSessions({
    required String year,
    required String semester,
    required String department,
    DateTime? startDate,
  }) async {
    try {
      startDate ??= DateTime(2025, 9, 8); // Default start date: September 8, 2025
      final endDate = DateTime.now().add(const Duration(days: 1));

      print('=== Getting Class Sessions ===');
      print('Year: $year, Semester: $semester, Department: $department');
      print('Date range: $startDate to $endDate');

      // Build the path pattern: attendance/3/5/IT/2025-09-09/1/entries
      final basePath = 'attendance/$year/$semester/$department';

      List<Map<String, dynamic>> classSessions = [];
      Set<String> uniqueSessionKeys = {}; // To avoid duplicates

      // Iterate through dates from startDate to endDate
      DateTime currentDate = startDate;
      while (currentDate.isBefore(endDate)) {
        final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);
        print('Checking date: $dateStr');

        // Check each period (1 to 8)
        for (int period = 1; period <= 8; period++) {
          try {
            final entriesPath = '$basePath/$dateStr/$period/entries';
            print('Checking path: $entriesPath');

            // Get all entries for this date-period combination
            final entriesSnapshot = await _firestore.collection(entriesPath).limit(1).get();

            if (entriesSnapshot.docs.isNotEmpty) {
              // At least one student attended this class
              final sampleEntry = entriesSnapshot.docs.first.data();
              final subjectId = sampleEntry['subjectId'] as String? ?? 'Unknown';
              final subjectName = sampleEntry['subjectName'] as String? ?? 'Unknown Subject';

              final sessionKey = '$dateStr-$period-$subjectId';

              if (!uniqueSessionKeys.contains(sessionKey)) {
                uniqueSessionKeys.add(sessionKey);

                classSessions.add({
                  'date': dateStr,
                  'period': period,
                  'subjectId': subjectId,
                  'subjectName': subjectName,
                });

                print('Found class session: $dateStr Period $period - $subjectName');
              }
            }
          } catch (e) {
            // This date-period combination doesn't exist, which is normal
            // print('No entries for $dateStr period $period');
          }
        }

        currentDate = currentDate.add(const Duration(days: 1));
      }

      print('Total class sessions found: ${classSessions.length}');
      classSessions.forEach((session) {
        print('- ${session['date']} P${session['period']}: ${session['subjectName']}');
      });

      return classSessions;

    } catch (e) {
      print('Error getting class sessions: $e');
      return [];
    }
  }

  // CORRECTED: Get student attendance history using proper path structure
  Future<List<Map<String, dynamic>>> getStudentAttendanceHistory({
    required String userId,
    String? subjectId,
    int? period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      print('=== Getting Student Attendance History ===');
      print('Student ID: $userId');

      // Get user details
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('User not found');
        return [];
      }

      final userData = userDoc.data()!;
      final year = userData['year'].toString();
      final semester = userData['semester'].toString();
      final department = userData['dept'].toString();

      startDate ??= DateTime(2025, 9, 8);
      endDate ??= DateTime.now();

      print('Year: $year, Semester: $semester, Department: $department');
      print('Date range: $startDate to $endDate');

      final basePath = 'attendance/$year/$semester/$department';
      List<Map<String, dynamic>> attendanceRecords = [];

      // Iterate through dates
      DateTime currentDate = startDate;
      while (currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
        final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);

        // Check each period
        for (int p = 1; p <= 8; p++) {
          if (period != null && p != period) continue;

          try {
            final entriesPath = '$basePath/$dateStr/$p/entries';
            final studentDoc = await _firestore.collection(entriesPath).doc(userId).get();

            if (studentDoc.exists) {
              final data = studentDoc.data()!;
              final recordSubjectId = data['subjectId'] as String;

              // Apply subject filter
              if (subjectId != null && recordSubjectId != subjectId) continue;

              attendanceRecords.add({
                ...data,
                'date': dateStr,
                'period': p,
              });

              print('Found attendance record: $dateStr P$p - ${data['subjectName']} - ${data['status']}');
            }
          } catch (e) {
            // Document doesn't exist, which is normal for days the student was absent
          }
        }

        currentDate = currentDate.add(const Duration(days: 1));
      }

      // Sort by date and period (most recent first)
      attendanceRecords.sort((a, b) {
        final dateComparison = b['date'].compareTo(a['date']);
        if (dateComparison != 0) return dateComparison;
        return b['period'].compareTo(a['period']);
      });

      print('Total student attendance records: ${attendanceRecords.length}');
      return attendanceRecords;

    } catch (e) {
      print('Error getting attendance history: $e');
      return [];
    }
  }

  // CORRECTED: Calculate attendance statistics properly
  Future<Map<String, dynamic>> getAttendanceStatistics({
    required String userId,
    String? subjectId,
  }) async {
    try {
      print('=== Calculating Attendance Statistics ===');
      print('User ID: $userId');

      // Get user details first
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('User not found');
        return {};
      }

      final userData = userDoc.data()!;
      final year = userData['year'].toString();
      final semester = userData['semester'].toString();
      final department = userData['dept'].toString();

      // Get all class sessions (where at least one student attended)
      final classSessions = await _getClassSessions(
        year: year,
        semester: semester,
        department: department,
        startDate: DateTime(2025, 9, 8),
      );

      // Get student's attendance history
      final attendanceHistory = await getStudentAttendanceHistory(
        userId: userId,
        subjectId: subjectId,
      );

      print('Class sessions found: ${classSessions.length}');
      print('Student attendance records: ${attendanceHistory.length}');

      if (subjectId != null) {
        // Subject-specific statistics
        final subjectClassSessions = classSessions
            .where((session) => session['subjectId'] == subjectId)
            .toList();

        final subjectAttendance = attendanceHistory
            .where((record) => record['subjectId'] == subjectId)
            .toList();

        final presentCount = subjectAttendance
            .where((record) => record['status'] == 'present')
            .length;

        final totalClasses = subjectClassSessions.length;
        final percentage = totalClasses > 0 ? (presentCount / totalClasses) * 100 : 0.0;

        return {
          'subjectId': subjectId,
          'presentCount': presentCount,
          'totalClasses': totalClasses,
          'percentage': percentage.toStringAsFixed(2),
        };
      } else {
        // Overall statistics
        Map<String, Map<String, dynamic>> subjectStats = {};

        // Initialize subject stats from class sessions
        for (final session in classSessions) {
          final subId = session['subjectId'].toString();
          final subjectName = session['subjectName'].toString();

          if (!subjectStats.containsKey(subId)) {
            subjectStats[subId] = {
              'subjectId': subId,
              'subjectName': subjectName,
              'presentCount': 0,
              'totalClasses': 0,
            };
          }

          // Count total classes for this subject
          subjectStats[subId]!['totalClasses'] =
              (subjectStats[subId]!['totalClasses'] as int) + 1;
        }

        // Count student's attendance by subject
        for (final record in attendanceHistory) {
          final subId = record['subjectId'].toString();

          if (subjectStats.containsKey(subId) && record['status'] == 'present') {
            subjectStats[subId]!['presentCount'] =
                (subjectStats[subId]!['presentCount'] as int) + 1;
          }
        }

        // Calculate percentages for each subject
        subjectStats.forEach((key, value) {
          final present = value['presentCount'] as int;
          final total = value['totalClasses'] as int;
          value['percentage'] = total > 0 ?
          ((present / total) * 100).toStringAsFixed(2) : '0.00';
        });

        // Overall statistics
        final totalClasses = classSessions.length;
        final presentClasses = attendanceHistory
            .where((record) => record['status'] == 'present')
            .length;
        final overallPercentage = totalClasses > 0 ?
        (presentClasses / totalClasses) * 100 : 0.0;

        print('=== FINAL STATISTICS ===');
        print('Total classes (all subjects): $totalClasses');
        print('Student present classes: $presentClasses');
        print('Overall percentage: ${overallPercentage.toStringAsFixed(2)}%');
        print('Subject breakdown:');
        subjectStats.forEach((subId, stats) {
          print('- ${stats['subjectName']}: ${stats['presentCount']}/${stats['totalClasses']} (${stats['percentage']}%)');
        });

        return {
          'overall': {
            'presentCount': presentClasses,
            'totalClasses': totalClasses,
            'percentage': overallPercentage.toStringAsFixed(2),
          },
          'subjects': subjectStats.values.toList(),
        };
      }

    } catch (e) {
      print('Error getting attendance statistics: $e');
      return {};
    }
  }
}