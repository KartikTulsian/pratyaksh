// Service to handle GPS activation updates
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class TimetableGPSService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Activate GPS-based attendance for a subject
  Future<bool> activateGPSAttendance({
    required String subjectId,
    required String teacherId,
    required double latitude,
    required double longitude,
    int durationMinutes = 60,
    double radius = 10.0,
  }) async {
    try {
      final now = DateTime.now();
      final expiresAt = now.add(Duration(minutes: durationMinutes));

      await _firestore.collection('timetable').doc(subjectId).update({
        'isActive': true,
        'gpsActivation.isGpsEnabled': true,
        'gpsActivation.activatedBy': teacherId,
        'gpsActivation.activatedAt': FieldValue.serverTimestamp(),
        'gpsActivation.teacherLocation.latitude': latitude,
        'gpsActivation.teacherLocation.longitude': longitude,
        'gpsActivation.radius': radius,
        'gpsActivation.activeDuration': durationMinutes,
        'gpsActivation.expiresAt': Timestamp.fromDate(expiresAt),
        'gpsActivation.studentsPresent': [],
        'attendanceStats.lastUpdated': FieldValue.serverTimestamp(),
      });

      print('GPS attendance activated for subject $subjectId');
      return true;
    } catch (e) {
      print('Error activating GPS attendance: $e');
      return false;
    }
  }

  /// Deactivate GPS-based attendance
  Future<bool> deactivateGPSAttendance(String subjectId) async {
    try {
      await _firestore.collection('timetable').doc(subjectId).update({
        'isActive': false,
        'gpsActivation.isGpsEnabled': false,
        'gpsActivation.expiresAt': null,
        'attendanceStats.lastUpdated': FieldValue.serverTimestamp(),
      });

      print('GPS attendance deactivated for subject $subjectId');
      return true;
    } catch (e) {
      print('Error deactivating GPS attendance: $e');
      return false;
    }
  }

  /// Check if GPS attendance is active for a subject
  Future<SubjectGPSInfo?> getActiveGPSSubject({
    required String subjectId,
    required double studentLatitude,
    required double studentLongitude,
    String? courseCode,
    int? year,
    int? semester,
    String? dept,
    String? day,
    int? period,
  }) async {
    try {
      print('🔍 Starting getActiveGPSSubject search for subjectId: $subjectId');
      print('📍 Student location: $studentLatitude, $studentLongitude');
      print('🔍 Filters: code=$courseCode, year=$year, sem=$semester, dept=$dept, day=$day, period=$period');

      // Start with basic active GPS query
      Query query = _firestore
          .collection('timetable')
          .where('isActive', isEqualTo: true)
          .where('gpsActivation.isGpsEnabled', isEqualTo: true);

      final querySnapshot = await query.get();
      print('📊 Found ${querySnapshot.docs.length} documents with active GPS');

      if (querySnapshot.docs.isEmpty) {
        print('❌ No active GPS subjects found at all');
        return null;
      }

      // Filter documents manually for better debugging
      for (final doc in querySnapshot.docs) {
        print('\n🔍 Checking document: ${doc.id}');

        final data = doc.data() as Map<String, dynamic>;
        print('📄 Document data preview: ${data.keys.toList()}');

        // Check if gpsActivation exists
        if (!data.containsKey('gpsActivation')) {
          print('❌ No gpsActivation field found');
          continue;
        }

        final gpsData = data['gpsActivation'] as Map<String, dynamic>;

        // Check expiration
        if (gpsData['expiresAt'] != null) {
          final expiresAt = (gpsData['expiresAt'] as Timestamp).toDate();
          if (expiresAt.isBefore(DateTime.now())) {
            print('⏰ Subject ${data['name']} expired at $expiresAt');
            continue;
          }
          print('✅ Subject ${data['name']} expires at $expiresAt (still valid)');
        }

        // Apply filters one by one with detailed logging
        bool matchesFilters = true;

        // Course code filter
        if (courseCode != null && courseCode.isNotEmpty) {
          final docCode = data['code']?.toString().trim().toUpperCase() ?? '';
          final searchCode = courseCode.trim().toUpperCase();
          if (docCode != searchCode) {
            print('❌ Course code mismatch: doc="$docCode" vs search="$searchCode"');
            matchesFilters = false;
            continue;
          }
          print('✅ Course code matches: $docCode');
        }

        // Year filter
        if (year != null) {
          final docYear = data['year'];
          if (docYear != year) {
            print('❌ Year mismatch: doc=$docYear vs search=$year');
            matchesFilters = false;
            continue;
          }
          print('✅ Year matches: $docYear');
        }

        // Semester filter
        if (semester != null) {
          final docSemester = data['semester'];
          if (docSemester != semester) {
            print('❌ Semester mismatch: doc=$docSemester vs search=$semester');
            matchesFilters = false;
            continue;
          }
          print('✅ Semester matches: $docSemester');
        }

        // Day filter
        if (day != null && day.isNotEmpty) {
          final docDay = data['day']?.toString().trim() ?? '';
          if (docDay.toLowerCase() != day.toLowerCase()) {
            print('❌ Day mismatch: doc="$docDay" vs search="$day"');
            matchesFilters = false;
            continue;
          }
          print('✅ Day matches: $docDay');
        }

        // Period filter
        if (period != null) {
          final docPeriod = data['period'];
          if (docPeriod != period) {
            print('❌ Period mismatch: doc=$docPeriod vs search=$period');
            matchesFilters = false;
            continue;
          }
          print('✅ Period matches: $docPeriod');
        }

        // Department filter (more flexible)
        if (dept != null && dept.isNotEmpty) {
          final docDept = data['dept']?.toString().toUpperCase() ?? '';
          final studentDept = dept.toUpperCase().trim();

          // Check if student's dept is included in document's dept field
          bool deptMatches = false;
          if (docDept.contains(',')) {
            // Multiple departments in document
            final deptList = docDept.split(',').map((d) => d.trim()).toList();
            deptMatches = deptList.contains(studentDept);
          } else {
            // Single department
            deptMatches = docDept == studentDept;
          }

          if (!deptMatches) {
            print('❌ Department mismatch: doc="$docDept" vs search="$studentDept"');
            matchesFilters = false;
            continue;
          }
          print('✅ Department matches: student="$studentDept" in doc="$docDept"');
        }

        if (!matchesFilters) {
          continue;
        }

        // Check teacher location and calculate distance
        if (!gpsData.containsKey('teacherLocation')) {
          print('❌ No teacherLocation found in gpsActivation');
          continue;
        }

        final teacherLocation = gpsData['teacherLocation'] as Map<String, dynamic>;
        final teacherLat = teacherLocation['latitude']?.toDouble() ?? 0.0;
        final teacherLng = teacherLocation['longitude']?.toDouble() ?? 0.0;
        final radius = (gpsData['radius']?.toDouble() ?? 10.0);

        print('📍 Teacher location: $teacherLat, $teacherLng');
        print('📏 Radius: ${radius}m');

        // Calculate distance
        final distance = Geolocator.distanceBetween(
          studentLatitude,
          studentLongitude,
          teacherLat,
          teacherLng,
        );

        print('📏 Distance calculated: ${distance.toStringAsFixed(2)}m');
        print('📏 Required radius: ${radius}m');

        if (distance <= radius) {
          print('✅ Student is within range! Creating SubjectGPSInfo...');

          return SubjectGPSInfo(
            subjectId: doc.id,
            subjectName: data['name'] ?? 'Unknown Subject',
            subjectCode: data['code'] ?? 'Unknown Code',
            teacherId: gpsData['activatedBy'] ?? '',
            teacherLatitude: teacherLat,
            teacherLongitude: teacherLng,
            radius: radius,
            distance: distance,
            expiresAt: gpsData['expiresAt'] != null
                ? (gpsData['expiresAt'] as Timestamp).toDate()
                : DateTime.now().add(Duration(hours: 1)),
            year: data['year'] ?? 0,
            semester: data['semester'] ?? 0,
            dept: data['dept']?.toString() ?? '',
            day: data['day']?.toString() ?? '',
            period: data['period'] ?? 0,
          );
        } else {
          print('❌ Student is out of range: ${distance.toStringAsFixed(2)}m > ${radius}m');
        }
      }

      print('❌ No matching subjects found within proximity');
      return null;

    } catch (e) {
      print('❌ Error in getActiveGPSSubject: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Update attendance for a subject
  Future<bool> markStudentPresent({
    required String subjectId,
    required String studentId,
  }) async {
    try {
      await _firestore.collection('timetable').doc(subjectId).update({
        'gpsActivation.studentsPresent': FieldValue.arrayUnion([studentId]),
        'attendanceStats.presentStudents': FieldValue.increment(1),
        'attendanceStats.lastUpdated': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error marking student present: $e');
      return false;
    }
  }
}

/// Subject GPS information class
class SubjectGPSInfo {
  final String subjectId;
  final String subjectName;
  final String subjectCode;
  final String teacherId;
  final double teacherLatitude;
  final double teacherLongitude;
  final double radius;
  final double distance;
  final DateTime expiresAt;
  final int year;
  final int semester;
  final String dept;
  final String day;
  final int period;

  SubjectGPSInfo({
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.teacherId,
    required this.teacherLatitude,
    required this.teacherLongitude,
    required this.radius,
    required this.distance,
    required this.expiresAt,
    required this.year,
    required this.semester,
    required this.dept,
    required this.day,
    required this.period,
  });
}