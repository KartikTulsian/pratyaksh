import 'package:flutter/material.dart';
import 'package:iem_attendance_app/models/teacher_model.dart';
import 'package:iem_attendance_app/services/database_service.dart';

class UpdateTeacherScreen extends StatefulWidget {
  final TeacherModel teacher;

  const UpdateTeacherScreen({super.key, required this.teacher});

  @override
  State<UpdateTeacherScreen> createState() => _UpdateTeacherScreenState();
}

class _UpdateTeacherScreenState extends State<UpdateTeacherScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController enrollmentController;
  late TextEditingController passwordController;
  late TextEditingController confirmPasswordController;

  Color primary = const Color(0xFF765DBD);

  bool isLoading = false;
  bool passwordsMatch = true;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.teacher.name);
    enrollmentController = TextEditingController(text: widget.teacher.enrollment);
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();

    // live password match check
    confirmPasswordController.addListener(() {
      setState(() {
        passwordsMatch =
            passwordController.text == confirmPasswordController.text;
      });
    });
  }

  Future<void> updateTeacherData() async {
    if (!_formKey.currentState!.validate()) return;
    if (!passwordsMatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final updatedTeacher = TeacherModel(
        id: widget.teacher.id,
        name: nameController.text.trim(),
        enrollment: enrollmentController.text.trim(),
        password: passwordController.text.trim().isNotEmpty
            ? passwordController.text.trim()
            : widget.teacher.password, // keep old password if not changed
      );

      await DatabaseService().updateTeacher(updatedTeacher);

      if (mounted) {
        Navigator.pop(context, updatedTeacher);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Teacher profile updated successfully")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating teacher: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Edit Teacher Profile",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(13.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    "Update Teacher Details",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField("Name", nameController),
                  _buildTextField("Enrollment No.", enrollmentController),
                  _buildTextField("Password", passwordController,
                      obscure: true),
                  _buildConfirmPasswordField(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: updateTeacherData,
                      icon: const Icon(Icons.save),
                      label: const Text("Update Profile",
                          style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller, {
        bool obscure = false,
        TextInputType keyboardType = TextInputType.text,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.grey),
          ),
        ),
        validator: (value) =>
        value == null || value.isEmpty ? "Enter $label" : null,
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField("Confirm Password", confirmPasswordController,
            obscure: true),
        if (confirmPasswordController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4.0, top: 4.0),
            child: Row(
              children: [
                Icon(
                  passwordsMatch ? Icons.check_circle : Icons.cancel,
                  color: passwordsMatch ? Colors.green : Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  passwordsMatch
                      ? "Passwords match"
                      : "Passwords do not match",
                  style: TextStyle(
                    color: passwordsMatch ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
