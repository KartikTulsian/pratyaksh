import 'package:flutter/material.dart';
import 'package:iem_attendance_app/screens/auth/login_screen.dart';

import '../../services/auth_service.dart';

class LogoutScreen extends StatefulWidget {
  const LogoutScreen({super.key});

  @override
  State<LogoutScreen> createState() => _LogoutScreenState();
}

class _LogoutScreenState extends State<LogoutScreen> {

  void initState() {
    super.initState();
    _logout();
  }

  Future<void> _logout() async {
    final auhService = AuthService();
    await auhService.logout();

    await Future.delayed(const Duration(seconds: 1));
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
