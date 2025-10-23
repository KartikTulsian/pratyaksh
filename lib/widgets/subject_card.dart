import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iem_attendance_app/models/student_model.dart';
import 'package:iem_attendance_app/models/subject_model.dart';
import 'package:iem_attendance_app/widgets/face_attendance_screen.dart';
import 'package:iem_attendance_app/widgets/timetable_gps_service.dart';

class SubjectCard extends StatelessWidget {
  final SubjectModel subject;
  final String enrollment;
  final StudentModel? student;
  final VoidCallback onRefresh;
  final Position? currentPosition;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.enrollment,
    required this.student,
    required this.onRefresh,
    required this.currentPosition,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = subject.isActive;
    final hasMarked = subject.attended;

    print("📘 Rendering SubjectCard: ${subject.name}, isActive: ${subject.isActive}, attended: ${subject.attended}");

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor:
              isActive ? Colors.green.shade600 : Colors.grey.shade400,
          child: Text(
            subject.period.toString(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          subject.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subject.code),
            if (hasMarked)
              const Text(
                'Attendance marked ✓',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: hasMarked
            ? const Icon(Icons.check, color: Colors.green, size: 28)
            : isActive
                ? const Icon(Icons.fingerprint_rounded,
                    color: Colors.deepPurple, size: 28)
                : const Icon(Icons.schedule, color: Colors.grey, size: 28),
        onTap: () async {
          if (isActive && !hasMarked) {

            print('\n🎯 SubjectCard tapped for: ${subject.name}');
            print('📍 Current position: ${currentPosition?.latitude}, ${currentPosition?.longitude}');
            print('🎓 Student: ${student?.name} (${student?.enrollment})');
            print('📚 Subject details: ${subject.code}, Year: ${student?.year}, Sem: ${student?.semester}, Dept: ${student?.dept}');
            print('📅 Day: ${subject.day}, Period: ${subject.period}');
            // Check if GPS is active for this subject
            final gpsService = TimetableGPSService();
            // Get student's current location to check proximity
            try {
              if (currentPosition == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please relocate to fetch your current location before marking attendance.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              print('🔍 Calling getActiveGPSSubject with parameters:');
              print('   studentLatitude: ${currentPosition!.latitude}');
              print('   studentLongitude: ${currentPosition!.longitude}');
              print('   courseCode: ${subject.code}');
              print('   year: ${student!.year}');
              print('   semester: ${student!.semester}');
              print('   dept: ${student!.dept}');
              print('   day: ${subject.day}');
              print('   period: ${subject.period}');

              // final studentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
              final activeSubjectInfo = await gpsService.getActiveGPSSubject(
                subjectId: subject.id,
                studentLatitude: currentPosition!.latitude,
                studentLongitude: currentPosition!.longitude,
                courseCode: subject.code,
                year: student!.year,
                semester: student!.semester,
                dept: student!.dept,
                day: subject.day,
                period: subject.period,
              );

              if (activeSubjectInfo != null) {
                print('✅ Active subject found: ${activeSubjectInfo.subjectName}');
                print('📏 Distance: ${activeSubjectInfo.distance.toStringAsFixed(2)}m');
                print('🎯 Navigating to FaceAttendanceScreen...');

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FaceAttendanceScreen(
                      subject: subject,
                      student: student!,
                      activeSubjectInfo: activeSubjectInfo, // Pass the active GPS info
                    ),
                  ),
                );

                if (result == true) {
                  print('Attendance marked successfully! for ${subject.name} ✅');
                  onRefresh(); // Call the refresh callback
                }
              } else {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Debug Information'),
                      content: SingleChildScrollView(
                        child: Text(
                            'Search Parameters:\n'
                                'Student Location: ${currentPosition!.latitude.toStringAsFixed(6)}, ${currentPosition!.longitude.toStringAsFixed(6)}\n'
                                'Course Code: ${subject.code}\n'
                                'Year: ${student!.year}\n'
                                'Semester: ${student!.semester}\n'
                                'Department: ${student!.dept}\n'
                                'Day: ${subject.day}\n'
                                'Period: ${subject.period}\n\n'
                                'Result: No active GPS subject found.\n'
                                'This could mean:\n'
                                '1. No teacher has activated GPS for this subject\n'
                                '2. You are out of range from the teacher\n'
                                '3. The GPS activation has expired\n'
                                '4. Filter parameters don\'t match exactly'
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    );
                  },
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Attendance is not active for this period or you are out of range.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to get location or check attendance status: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } else if (hasMarked) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Attendance already marked for ${subject.name}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }
}