import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iem_attendance_app/models/student_model.dart';
import 'package:iem_attendance_app/screens/auth/logout_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_screen.dart';

import 'attendance_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {

  double screenHeight = 0;
  double screenWidth = 0;

  int _currentIndex = 0;


  StudentModel? student;

  Color primary = const Color(0xFF765DBD);
  final LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF765DBD), Color(0xFF301B5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  List<IconData> navigationIcons = [
    FontAwesomeIcons.calendarDay,
    FontAwesomeIcons.user,
    FontAwesomeIcons.rightFromBracket,
  ];

  List<String> navigationLable = [
    'Attendance',
    'Profile',
    'LogOut'
  ];

  void initState() {
    super.initState();
    _loadStudent();
  }

  Future<void> _loadStudent() async {
    final prefs = await SharedPreferences.getInstance();
    String enrollment = prefs.getString("enrollment") ?? "";

    // setState(() {
    //   student = StudentModel (
    //     id: prefs.getString("id") ?? "N/A",
    //     name: prefs.getString("name") ?? "Unknown",
    //     enrollment: prefs.getString("enrollment") ?? "N/A",
    //     dept: prefs.getString("dept") ?? "N/A",
    //     year: int.parse(prefs.getString("year") ?? "N/A"),
    //     semester: int.parse(prefs.getString("semester") ?? "N/A"),
    //   );
    // });

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('enrollment', isEqualTo: enrollment)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      setState(() {
        student = StudentModel.fromFirestore(doc); // ✅ this sets the correct Firestore ID
      });
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

    if (student == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final List<Widget> _tabs = [
      const StudentAttendanceScreen(),
      StudentProfileScreen(student: student!),
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
