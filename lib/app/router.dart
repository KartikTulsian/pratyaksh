import 'package:flutter/material.dart';
import 'package:iem_attendance_app/screens/admin/dashboard_screen.dart';
import 'package:iem_attendance_app/screens/auth/login_screen.dart';
import 'package:iem_attendance_app/screens/student/home_screen_student.dart';
import 'package:iem_attendance_app/screens/teacher/home_screen_teacher.dart';



final Map<String, WidgetBuilder> appRoutes = {
  '/login': (_) => const LoginScreen(),
  '/student_home': (_) => const StudentHomeScreen(),
  '/teacher_home': (_) => const TeacherHomeScreen(),
  '/admin_dashboard': (_) => const AdminDashboardScreen(),
};