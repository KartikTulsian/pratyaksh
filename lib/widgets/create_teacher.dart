import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iem_attendance_app/models/student_model.dart';
import 'package:intl/intl.dart';

class CreateTeacherScreen extends StatefulWidget {
  const CreateTeacherScreen({super.key});

  @override
  State<CreateTeacherScreen> createState() => _CreateTeacherScreenState();
}

class _CreateTeacherScreenState extends State<CreateTeacherScreen> {

  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final enrollmentController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

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

    // Check match in real-time
    confirmPasswordController.addListener(() {
      setState(() {
        passwordsMatch =
            passwordController.text == confirmPasswordController.text;
      });
    });
  }

  Future<void> _createTeacher() async {
    if (!_formKey.currentState!.validate()) return;

    if (!passwordsMatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {

      // Extract values safely
      final String name = nameController.text.trim();
      final String enrollment = enrollmentController.text.trim();
      final String password = passwordController.text.trim();

      final docRef = FirebaseFirestore.instance.collection('users').doc();

      await docRef.set({
        'id': docRef.id,
        'name': name,
        'enrollment': enrollment,
        'password': password,
        'role': 'teacher',          // <- new field added
      });

      setState(() {
        isLoading = false;
      });

      showDialog(
          context: context,
          builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text(
                "Success",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Teacher profile created successfully."),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('👤 Name: $name'),
                        const SizedBox(height: 4),
                        Text('🆔 Enrollment No.: $enrollment'),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text(
                    "OK",
                    style: TextStyle(fontSize: 16),
                  ),
                )
              ]
          )
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error creating teacher: ${e.toString()}')
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Add Teacher",  style: TextStyle(fontWeight: FontWeight.w600)),
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
                        "Enter Teacher Details",
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
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _createTeacher,
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          label: const Text("Create Profile", style: TextStyle(fontSize: 16)),
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
