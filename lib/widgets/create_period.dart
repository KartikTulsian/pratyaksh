import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iem_attendance_app/models/subject_model.dart';
import 'package:iem_attendance_app/services/database_service.dart';

class CreatePeriod extends StatefulWidget {
  const CreatePeriod({super.key});

  @override
  State<CreatePeriod> createState() => _CreatePeriodState();
}

class _CreatePeriodState extends State<CreatePeriod> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final codeController = TextEditingController();
  final deptController = TextEditingController();
  final yearController = TextEditingController();
  final semesterController = TextEditingController();
  final periodController = TextEditingController();
  final dayController = TextEditingController();

  bool isLoading = false;

  Color primary = const Color(0xFF765DBD);

  Future<void> _createPeriod() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('timetable').doc();

      final subject = SubjectModel(
        id: docRef.id,
        name: nameController.text.trim(),
        code: codeController.text.trim(),
        dept: deptController.text.trim(),
        year: int.parse(yearController.text.trim()),
        semester: int.parse(semesterController.text.trim()),
        period: int.parse(periodController.text.trim()),
        isActive: false,
        day: dayController.text.trim(),
      );

      await DatabaseService().addSubject(subject);

      if (!mounted) return;

      setState(() => isLoading = false);

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
              const Text("Period created successfully."),
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
                    Text('📘 Subject: ${subject.name} (${subject.code})'),
                    const SizedBox(height: 4),
                    Text('🏫 Department: ${subject.dept}'),
                    const SizedBox(height: 4),
                    Text('🎓 Year: ${subject.year}'),
                    const SizedBox(height: 4),
                    Text('📖 Semester: ${subject.semester}'),
                    const SizedBox(height: 4),
                    Text('⏰ Period: ${subject.period}'),
                    const SizedBox(height: 4),
                    Text('📅 Day: ${subject.day}'),
                  ],
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context, true); // close screen & return success
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                "OK",
                style: TextStyle(fontSize: 16),
              ),
            )
          ],
        ),
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creating period: $e")),
      );
    }
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller, {
        TextInputType keyboardType = TextInputType.text,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text("Add Period", style: TextStyle(fontWeight: FontWeight.w600)),
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
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    "Enter Period Details",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField("Subject Name", nameController),
                  _buildTextField("Subject Code", codeController),
                  _buildTextField("Department", deptController),
                  _buildTextField("Year", yearController,
                      keyboardType: TextInputType.number),
                  _buildTextField("Semester", semesterController,
                      keyboardType: TextInputType.number),
                  _buildTextField("Period No.", periodController,
                      keyboardType: TextInputType.number),
                  _buildTextField("Day (e.g. Monday)", dayController),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _createPeriod,
                      icon: const Icon(Icons.check_circle,
                          color: Colors.green),
                      label: const Text("Create Period",
                          style: TextStyle(fontSize: 16)),
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
            ),
          ),
        ),
      ),
    );
  }
}
