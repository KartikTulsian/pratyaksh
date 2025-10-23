import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iem_attendance_app/models/student_model.dart';
import 'package:iem_attendance_app/services/database_service.dart';
import 'package:iem_attendance_app/services/attendance_service.dart';
import 'package:iem_attendance_app/widgets/face_registration.dart';
import 'package:iem_attendance_app/widgets/update_password.dart';
import 'package:iem_attendance_app/widgets/update_student.dart';
import 'package:percent_indicator/flutter_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentProfileScreen extends StatefulWidget {
  final StudentModel student;

  const StudentProfileScreen({super.key, required this.student});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  late StudentModel student;
  bool isLoading = false;
  String role = '';

  // Attendance data
  Map<String, dynamic> attendanceStats = {};
  bool isLoadingAttendance = false;
  String attendanceError = '';

  final AttendanceService _attendanceService = AttendanceService();

  @override
  void initState() {
    super.initState();
    student = widget.student;
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await loadRole();
    await loadAttendanceData();
  }

  Future<void> loadRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          role = prefs.getString('role') ?? '';
        });
      }
    } catch (e) {
      print('Error loading role: $e');
    }
  }

  Future<void> loadAttendanceData() async {
    if (isLoadingAttendance) return; // Prevent multiple simultaneous calls

    try {
      if (mounted) {
        setState(() {
          isLoadingAttendance = true;
          attendanceError = '';
        });
      }

      print('Loading attendance data for student: ${student.id}');

      // Get overall attendance statistics
      final stats = await _attendanceService.getAttendanceStatistics(
        userId: student.id,
      );

      print('Attendance stats received: $stats');

      if (mounted) {
        setState(() {
          attendanceStats = stats;
          isLoadingAttendance = false;
        });
      }
    } catch (e) {
      print('Error loading attendance data: $e');
      if (mounted) {
        setState(() {
          attendanceError = 'Failed to load attendance data: $e';
          isLoadingAttendance = false;
        });
      }
    }
  }

  // Method to refresh both student data and attendance
  Future<void> refreshData() async {
    if (isLoading) return; // Prevent multiple refresh calls

    try {
      setState(() {
        isLoading = true;
      });

      // Refresh student data
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(student.id)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          student = StudentModel.fromFirestore(doc);
        });
      }

      // Refresh attendance data
      await loadAttendanceData();

    } catch (e) {
      print('Error refreshing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error refreshing: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Color primary = const Color(0xFF765DBD);
    const bgColor = Color(0xFFCFB7E6);

    // Calculate overall attendance percentage safely
    double overallPercentage = 0.0;
    int totalPresent = 0;
    int totalClasses = 0;

    if (attendanceStats.isNotEmpty && attendanceStats.containsKey('overall')) {
      try {
        final overall = attendanceStats['overall'] as Map<String, dynamic>;
        totalPresent = (overall['presentCount'] as int?) ?? 0;
        totalClasses = (overall['totalClasses'] as int?) ?? 0;

        if (totalClasses > 0) {
          final percentageStr = overall['percentage'] as String? ?? '0.0';
          overallPercentage = (double.tryParse(percentageStr) ?? 0.0) / 100;
        }
      } catch (e) {
        print('Error parsing attendance stats: $e');
        overallPercentage = 0.0;
        totalPresent = 0;
        totalClasses = 0;
      }
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Student's Profile"),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          if (role == 'admin') ...[
            IconButton(
              icon: Icon(Icons.edit),
              tooltip: "Edit Profile",
              onPressed: () async {
                final updatedStudent = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UpdateStudentScreen(student: student),
                  ),
                );

                if (updatedStudent != null && mounted) {
                  setState(() {
                    this.student = updatedStudent;
                  });
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.white),
              tooltip: "Delete Profile",
              onPressed: () => _confirmDelete(context),
            )
          ],
          if (role == 'student') ...[
            IconButton(
              icon: Icon(Icons.password_sharp, color: Colors.white),
              tooltip: "Update Password",
              onPressed: () => _updatePassword(context),
            )
          ],
          IconButton(
            icon: Icon(isLoading ? Icons.hourglass_empty : Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: isLoading ? null : refreshData,
          )
        ],
      ),
      body: Container(
        color: Color(0xFFE9E6FF),
        padding: const EdgeInsets.all(11),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            child: ListView(
              children: [
                // Profile Header
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) =>
                                FaceRegistration(student: student)),
                          );
                        },
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(student.id)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return CircleAvatar(
                                radius: 45,
                                backgroundColor: Colors.grey[300],
                                child: const CircularProgressIndicator(),
                              );
                            }

                            final userDoc = snapshot.data!;
                            final data = userDoc.data() as Map<String, dynamic>?;
                            final profileImage = data?.containsKey('profileImage') == true
                                ? data!['profileImage'] as String
                                : '';

                            return profileImage.isNotEmpty
                                ? CircleAvatar(
                              radius: 45,
                              backgroundImage: NetworkImage(profileImage),
                            )
                                : CircleAvatar(
                              radius: 45,
                              backgroundColor: Colors.grey[300],
                              child: const Icon(Icons.person, size: 50, color: Colors.black54),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        student.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 13),
                Divider(thickness: 1.5, color: Colors.grey[500]),
                const SizedBox(height: 8),

                // Personal Info Section
                Text(
                  "Personal Info",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: "NotoSansBold",
                    color: primary,
                  ),
                ),
                const SizedBox(height: 10),
                InfoRow(label: "Student ID", value: student.enrollment, icon: Icons.person),
                InfoRow(label: "Department", value: student.dept, icon: Icons.school),
                InfoRow(label: "Year", value: student.year.toString(), icon: Icons.calendar_today),
                InfoRow(label: "Semester", value: student.semester.toString(), icon: Icons.calendar_month),
                const SizedBox(height: 10),
                Divider(thickness: 1.5, color: Colors.grey[500]),
                const SizedBox(height: 8),

                // Attendance Summary Section
                Text(
                  "Attendance Summary",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 10),

                // Loading State
                if (isLoadingAttendance)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text('Loading attendance data...'),
                        ],
                      ),
                    ),
                  )
                // Error State
                else if (attendanceError.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            'Error loading attendance',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              attendanceError,
                              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: loadAttendanceData,
                            child: Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                // Data Display
                else
                  Column(
                    children: [
                      // Overall Attendance Circle
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: CircularPercentIndicator(
                            animation: true,
                            animationDuration: 1000,
                            radius: 80,
                            lineWidth: 20,
                            percent: overallPercentage.clamp(0.0, 1.0),
                            progressColor: overallPercentage >= 0.75
                                ? Color(0xFF57BA9A)
                                : overallPercentage >= 0.60
                                ? Colors.orange
                                : Color(0xFFFF8080),
                            backgroundColor: const Color(0xFFD4C4D8),
                            circularStrokeCap: CircularStrokeCap.round,
                            center: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${(overallPercentage * 100).toInt()}%",
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  "Overall",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Attendance Stats Summary
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                Text(
                                  '$totalPresent',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  'Present',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: Colors.grey.shade400,
                            ),
                            Column(
                              children: [
                                Text(
                                  '$totalClasses',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: primary,
                                  ),
                                ),
                                Text(
                                  'Total Classes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: Colors.grey.shade400,
                            ),
                            Column(
                              children: [
                                Text(
                                  '${totalClasses - totalPresent}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                Text(
                                  'Absent',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Subject-wise breakdown
                      // if (attendanceStats.containsKey('subjects') &&
                      //     (attendanceStats['subjects'] as List).isNotEmpty) ...[
                      //   const SizedBox(height: 20),
                      //   Text(
                      //     "Subject-wise Attendance",
                      //     style: TextStyle(
                      //       fontSize: 16,
                      //       fontWeight: FontWeight.bold,
                      //       color: primary,
                      //     ),
                      //   ),
                      //   const SizedBox(height: 10),
                      //   ..._buildSubjectAttendanceList(),
                      // ],
                    ],
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSubjectAttendanceList() {
    try {
      final subjects = attendanceStats['subjects'] as List<dynamic>? ?? [];

      if (subjects.isEmpty) {
        return [
          Container(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                'No subject attendance data available',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ];
      }

      return subjects.map<Widget>((subject) {
        final subjectData = subject as Map<String, dynamic>;
        final subjectName = subjectData['subjectName'] ?? 'Unknown Subject';
        final presentCount = (subjectData['presentCount'] as int?) ?? 0;
        final totalClasses = (subjectData['totalClasses'] as int?) ?? 0;
        final percentageStr = subjectData['percentage'] as String? ?? '0.0';
        final percentage = double.tryParse(percentageStr) ?? 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subjectName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$presentCount/$totalClasses classes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: percentage >= 75
                          ? Colors.green.shade100
                          : percentage >= 60
                          ? Colors.orange.shade100
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: percentage >= 75
                            ? Colors.green.shade700
                            : percentage >= 60
                            ? Colors.orange.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (percentage / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  percentage >= 75
                      ? Colors.green
                      : percentage >= 60
                      ? Colors.orange
                      : Colors.red,
                ),
              ),
            ],
          ),
        );
      }).toList();
    } catch (e) {
      print('Error building subject attendance list: $e');
      return [
        Container(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Error loading subject data',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ];
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Confirm Delete", style: TextStyle(fontWeight: FontWeight.w600)),
            content: const Text("Are you sure you want to delete this profile?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _deleteStudent();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text("Delete"),
              )
            ],
          );
        }
    );
  }

  void _updatePassword(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdatePassword(student: student),
    );
  }

  Future<void> _deleteStudent() async {
    try {
      await DatabaseService().deleteStudent(widget.student.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Student deleted successfully")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting student: ${e.toString()}')),
        );
      }
    }
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
            children: [
              Icon(icon, color: Color(0xFF765DBD), size: 24),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  "$label",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: "NotoSansBold"
                  ),
                ),
              ),
              Expanded(
                  flex: 2,
                  child: Text(
                    "$value",
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.end,
                  )
              )
            ]
        )
    );
  }
}