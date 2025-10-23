import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iem_attendance_app/models/subject_model.dart';
import 'package:iem_attendance_app/models/teacher_model.dart';
import 'package:iem_attendance_app/screens/auth/logout_screen.dart';
import 'package:iem_attendance_app/screens/teacher/class_list_screen.dart';
import 'package:iem_attendance_app/screens/teacher/student_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  double screenHeight = 0;
  double screenWidth = 0;

  int _currentIndex = 0;

  TeacherModel? teacher;

  Color primary = const Color(0xFF765DBD);
  final LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF765DBD), Color(0xFF301B5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  List<IconData> navigationIcons = [
    FontAwesomeIcons.chalkboardUser,
    FontAwesomeIcons.check,
    FontAwesomeIcons.rightFromBracket,
  ];

  List<String> navigationLable = [
    'Classes',
    'Checklist',
    'LogOut'
  ];

  SubjectModel? selectedSubject;

  void initState() {
    super.initState();
    _loadTeacher();
  }

  Future<void> _loadTeacher() async {
    try {
      print("📚 Starting to load teacher data...");

      final prefs = await SharedPreferences.getInstance();

      // Debug: Print all stored preferences
      print("📦 All SharedPreferences keys: ${prefs.getKeys()}");

      // Try different approaches to get teacher ID
      String? teacherId = prefs.getString("id");
      String? enrollment = prefs.getString("enrollment");
      String? role = prefs.getString("role");

      print("🔍 Debug SharedPreferences:");
      print("   - ID: $teacherId");
      print("   - Enrollment: $enrollment");
      print("   - Role: $role");

      if (teacherId != null && teacherId.isNotEmpty) {
        // Method 1: Load by document ID (preferred, like student)
        print("📝 Loading teacher by ID: $teacherId");

        final teacherDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(teacherId)
            .get();

        if (teacherDoc.exists) {
          print("✅ Teacher document found by ID");
          final teacherData = teacherDoc.data()!;
          print("👨‍🏫 Teacher data: $teacherData");

          if (mounted) {
            setState(() {
              teacher = TeacherModel.fromFirestore(teacherDoc);
            });
          }
          print("✅ Teacher loaded successfully: ${teacher?.name}");
          return;
        } else {
          print("❌ Teacher document not found by ID: $teacherId");
        }
      }

      if (enrollment != null && enrollment.isNotEmpty) {
        // Method 2: Load by enrollment (fallback)
        print("📝 Loading teacher by enrollment: $enrollment");

        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('enrollment', isEqualTo: enrollment)
            .where('role', isEqualTo: 'teacher') // Add role filter for safety
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          print("✅ Teacher document found by enrollment");
          final doc = snapshot.docs.first;
          final teacherData = doc.data();
          print("👨‍🏫 Teacher data: $teacherData");

          if (mounted) {
            setState(() {
              teacher = TeacherModel.fromFirestore(doc);
            });
          }
          print("✅ Teacher loaded successfully: ${teacher?.name}");
          return;
        } else {
          print("❌ Teacher document not found by enrollment: $enrollment");
        }
      }

      // If we reach here, something went wrong
      print("❌ ERROR: Could not load teacher data");
      print("   - No valid ID or enrollment found in SharedPreferences");
      print("   - Available keys: ${prefs.getKeys()}");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load teacher data. Please login again.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Login',
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LogoutScreen()),
                );
              },
            ),
          ),
        );
      }

    } catch (e) {
      print("❌ Exception loading teacher data: $e");
      print("Stack trace: ${StackTrace.current}");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading teacher data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    screenHeight = MediaQuery
        .of(context)
        .size
        .height;

    if (teacher == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final List<Widget> _tabs = [
      ClassListScreen(
        teacher: teacher!,
        onSubjectSelected: (subject) {
          setState(() {
            selectedSubject = subject;
            _currentIndex = 1;
          });
        }
      ),
      StudentDetailScreen(subject: selectedSubject),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex < 2 ? _currentIndex : 0, // Avoid error if logout is selected
        children: _tabs,
      ),

      bottomNavigationBar: Container(
        height: 70,
        width: screenWidth,
        margin: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).viewPadding.bottom + 8,
        ),
        decoration: BoxDecoration(
            gradient: primaryGradient,
            borderRadius: const BorderRadius.all(
              Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                offset: const Offset(2, 2),
                blurRadius: 10,
              )
            ]
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(
            Radius.circular(30),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i=0; i< navigationIcons.length; i++)...<Expanded> {
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (i==2) {
                        showLogoutPopup(context);
                      } else {
                        setState(() {
                          _currentIndex = i;
                        });
                      }
                    },
                    child: Container(
                      height: screenHeight,
                      width: screenWidth,
                      color: Colors.transparent,
                      child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                navigationIcons[i],
                                color: i == _currentIndex ? Colors.white70 : Colors.black87,
                                size: i == _currentIndex ? 30 : 26,
                              ),
                              i == _currentIndex ? Container(
                                margin: const EdgeInsets.only(
                                  top: 6,
                                ),
                                height: 3,
                                width: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white70,
                                  borderRadius: const BorderRadius.all(Radius.circular(40)),
                                ),
                              ) : const SizedBox(),
                            ],
                          )
                      ),
                    ),
                  ),
                )
              }
            ],
          ),
        ),
      ),
    );
  }

  void showLogoutPopup(BuildContext context) {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            )
        ),
        builder: (BuildContext context) {
          return Container(
            padding: const EdgeInsets.all(20),
            height: 180,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Are you sure you want to logout?",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                      icon: const Icon(Icons.logout, color: Colors.white,),
                      label: const Text("Logout"),
                      onPressed: () {
                        Navigator.pop(context); // Close popup
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LogoutScreen()),
                        );
                      },
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFDEBFF),
                      ),
                      child: const Text("Cancel"),
                      onPressed: () {
                        Navigator.pop(context); // Just close popup
                      },
                    )
                  ],
                )
              ],
            ),
          );
        }
    );
  }
}
