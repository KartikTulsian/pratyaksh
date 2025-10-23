import 'package:flutter/material.dart';
import 'package:iem_attendance_app/models/student_model.dart';
import 'package:iem_attendance_app/services/database_service.dart';

class UpdatePassword extends StatefulWidget {

  final StudentModel student;

  const UpdatePassword({super.key, required this.student});

  @override
  State<UpdatePassword> createState() => _UpdatePasswordState();
}

class _UpdatePasswordState extends State<UpdatePassword> {

  final _formKey = GlobalKey<FormState>();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool passwordMatch = true;

  void _checkPasswordMatch() {
    setState(() {
      passwordMatch = passwordController.text == confirmPasswordController.text;
    });
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (!passwordMatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await DatabaseService().updateStudentPassword(widget.student, passwordController.text.trim());

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password updated successfully"))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating password: ${e.toString()}"))
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    confirmPasswordController.addListener(_checkPasswordMatch);

    print("🔥 Firestore doc ID used for password update: ${widget.student.id}");
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Update Password"),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: isLoading
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
          : Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
              validator: (value) =>
              value == null || value.isEmpty ? 'Enter new password' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
              validator: (value) =>
              value == null || value.isEmpty ? 'Confirm your password' : null,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: passwordController.text.isEmpty && confirmPasswordController.text.isEmpty
                  ? const SizedBox.shrink()
                  : Row(
                children: [
                  Icon(
                    passwordMatch ? Icons.check_circle : Icons.cancel,
                    color: passwordMatch ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    passwordMatch ? "Passwords match" : "Passwords do not match",
                    style: TextStyle(
                      color: passwordMatch ? Colors.green : Colors.red,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _updatePassword,
          child: const Text("Update"),
        ),
      ],
    );
  }
}