import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iem_attendance_app/models/student_model.dart';
import 'package:iem_attendance_app/services/database_service.dart';
import 'package:intl/intl.dart';


class UpdateStudentScreen extends StatefulWidget {
  final StudentModel student;

  const UpdateStudentScreen({super.key, required this.student});

  @override
  State<UpdateStudentScreen> createState() => _UpdateStudentScreenState();
}

class _UpdateStudentScreenState extends State<UpdateStudentScreen> {

  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController enrollmentController;
  late TextEditingController passwordController;
  late TextEditingController confirmPasswordController;
  late TextEditingController deptController;
  late TextEditingController yearController;
  late TextEditingController semesterController;

  Color primary = const Color(0xFF765DBD);
  final LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF765DBD), Color(0xFF301B5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  bool isLoading = false;
  bool passwordsMatch = true;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.student.name);
    enrollmentController = TextEditingController(text: widget.student.enrollment);
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();
    deptController = TextEditingController(text: widget.student.dept);
    yearController = TextEditingController(text: widget.student.year.toString());
    semesterController = TextEditingController(text: widget.student.semester.toString());

    // Check match in real-time
    confirmPasswordController.addListener(() {
      setState(() {
        passwordsMatch =
            passwordController.text == confirmPasswordController.text;
      });
    });
  }

  Future<void> updateStudentData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final updateStudent = StudentModel(
        id: widget.student.id,
        name: nameController.text.trim(),
        enrollment: enrollmentController.text.trim(),
        dept: deptController.text.trim(),
        year: int.parse(yearController.text.trim()),
        semester: int.parse(semesterController.text.trim()),
        password: passwordController.text.trim().isNotEmpty
          ? passwordController.text.trim()
            : null, // Only update if user typed new password
      );

      await DatabaseService().updateStudent(updateStudent);

      if (mounted) {
        Navigator.pop(context, updateStudent);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Student profile updated successfully"))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating student: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Edit Student Profile",  style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator(color: primary))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(13.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Text(
                        "Update Student Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField("Name", nameController),
                      _buildTextField("Enrollment No.", enrollmentController),
                      _buildTextField("Password", passwordController),
                      _buildConfirmPasswordField(),
                      _buildTextField("Department", deptController),
                      _buildTextField("Year", yearController, keyboardType: TextInputType.number),
                      _buildTextField("Semester", semesterController, keyboardType: TextInputType.number),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: updateStudentData,
                          icon: const Icon(
                            Icons.save,
                            // color: Colors.white,
                          ),
                          label: const Text("Update Profile", style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                )
            ),
          ),
        )
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, {
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.grey),
          ),
        ),
        validator: (value) => value == null || value.isEmpty ? "Enter $label" : null,
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField("Confirm Password", confirmPasswordController, obscure: true),
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
                  passwordsMatch ? "Passwords match" : "Passwords do not match",
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
