import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:iem_attendance_app/models/student_model.dart';
import 'package:iem_attendance_app/screens/admin/dashboard_screen.dart';
import 'package:iem_attendance_app/screens/student/home_screen_student.dart';
import 'package:iem_attendance_app/screens/teacher/home_screen_teacher.dart';
import 'package:iem_attendance_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TextEditingController idController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  double screenHeight = 0;
  double screenWidth = 0;

  Color primary = const Color(0xFF765DBD);
  final LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF8E76DC), Color(0xFF3F1D7C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final LinearGradient loginGradient = const LinearGradient(
    colors: [Color(0xFFAB96E8), Color(0xFF3F1D7C)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );



  late SharedPreferences sharedPreferences;

  // void _login() async {
  //   if (_formKey.currentState?.validate() != true) return;
  //
  //   setState(()=> _loading = true);
  //
  //   try {
  //     User? user = await _authService.loginWithEnrollment(
  //       _enrollmentController.text.trim(),
  //       _passwordController.text.trim(),
  //     );
  //
  //     if (user != null) {
  //       String? role = await _authService.getRole(user.uid);
  //       if (role != null) {
  //         _redirectToRoleScreen(role);
  //       } else {
  //         _showError('Failed to get role');
  //       }
  //     }
  //   } catch (e) {
  //     _showError('Role not found');
  //   }
  //
  //   setState(()=> _loading = false);
  // }

  // void _redirectToRoleScreen(String role) {
  //   switch (role) {
  //     case 'student':
  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(builder: (context) => const StudentHomeScreen()),
  //       );
  //       break;
  //     case 'teacher':
  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(builder: (context) => const TeacherHomeScreen()),
  //       );
  //       break;
  //     case 'admin':
  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
  //       );
  //       break;
  //     default:
  //       _showError('Invalid role');
  //   }
  // }

  // void _showError(String message) {
  //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  // }

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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: KeyboardVisibilityBuilder(
        builder: (context, isKeyboardVisible) {
          return Column(
            children: [
              isKeyboardVisible ? SizedBox(height:  screenHeight / 16,)
                  : Container(
                height: screenHeight / 3,
                width: screenWidth,
                decoration: BoxDecoration(
                  gradient: loginGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(screenWidth / 10),
                    bottomRight: Radius.circular(screenWidth / 10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.4),
                      offset: const Offset(0, 5),
                      blurRadius: 12,
                    )
                  ],
                ),
                child: Center(
                    child: ClipRect(
                      child: Image.asset(
                        'assets/Pratyaksh_Main2.png',
                        width: screenWidth / 1.5,
                        height: screenHeight / 3.5,
                        fit: BoxFit.cover,
                      ),
                    ),
                ),
              ),
              Container(
                margin: EdgeInsets.only(
                  top: screenHeight / 20,
                  bottom: screenHeight / 20,
                ),
                child: Text(
                  "Login",
                  style: TextStyle(
                    fontSize: screenWidth / 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: "NotoSansBold",
                    color: const Color(0xFF333333),
                    letterSpacing: 1,
                  ),
                ),
              ),
              Container(
                alignment: Alignment.centerLeft,
                margin: EdgeInsets.symmetric(
                  horizontal: screenWidth / 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    fieldTitle("User Id"),
                    customField("Enter Your Id", idController, false),
                    fieldTitle("Password"),
                    customField("Enter Your Password", passwordController, true),
                    GestureDetector(
                      onTap: () async {
                        FocusScope.of(context).unfocus();
                        String id = idController.text.trim();
                        String password = passwordController.text.trim();

                        if (id.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Enrollment no. cannot be empty")));
                          return;
                        } else if (password.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Password cannot be empty")));
                          return;
                        }

                        final authService = AuthService();
                        String? result = await authService.loginWithEnrollment(id, password);

                        if (result == null) {
                          SharedPreferences prefs = await SharedPreferences.getInstance();
                          String? role = prefs.getString('role');

                          if (role == "student") {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const StudentHomeScreen()),
                            );
                          } else if (role == "teacher") {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const TeacherHomeScreen()),
                            );
                          } else if (role == "admin") {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("User role not found or invalid.")),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(result)),
                          );
                        }
                      },
                      child: Container(
                        height: 55,
                        width: screenWidth,
                        margin: EdgeInsets.only(
                          top: screenHeight / 40,
                        ),
                        decoration: BoxDecoration(
                          gradient: primaryGradient,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(30),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            )
                          ],
                        ),
                        child: Center(
                          child: Text(
                            "LOGIN",
                            style: TextStyle(
                              fontFamily: "LatoBold",
                              fontSize: screenWidth / 20,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    )
                  ],
                )
              )
            ],
          );
        }
      )
    );
  }

  Widget fieldTitle(String title) {
    return Container(
      margin: EdgeInsets.only(
        bottom: 12,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: screenWidth / 21,
          fontFamily: "LatoRegular",
        ),
      ),
    );
  }

  Widget customField(String hintText, TextEditingController controller, bool obscureText) {
    return Container(
      width: screenWidth,
      margin: EdgeInsets.only(
        bottom: 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(0, 5),
            blurRadius: 10,
          )
        ]
      ),
      child: Row(
        children: [
          Container(
            width: screenWidth / 6,
            child: Icon(
              Icons.person,
              color: primary,
              size: screenWidth / 15,
            ),
          ),
          Expanded(
            child: Padding(
                padding: EdgeInsets.only(right: screenWidth / 12),
                child: TextFormField(
                  controller: controller,
                  obscureText: obscureText,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: screenHeight / 35,
                    ),
                  ),
                  maxLines: 1,
                ),
            ),
          )
        ],
      ),
    );
  }
}

