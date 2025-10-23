import 'package:flutter/material.dart';
import 'package:iem_attendance_app/models/subject_model.dart';
import 'package:iem_attendance_app/services/database_service.dart';

class UpdatePeriod extends StatefulWidget {

  final SubjectModel subject;

  const UpdatePeriod({super.key, required this.subject});

  @override
  State<UpdatePeriod> createState() => _UpdatePeriodState();
}

class _UpdatePeriodState extends State<UpdatePeriod> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController codeController;
  late TextEditingController deptController;
  late TextEditingController yearController;
  late TextEditingController semesterController;
  late TextEditingController periodController;
  late TextEditingController dayController;

  bool isLoading = false;

  Color primary = const Color(0xFF765DBD);
  final LinearGradient primaryGradient = const LinearGradient(
    colors: [Color(0xFF765DBD), Color(0xFF301B5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.subject.name);
    codeController = TextEditingController(text: widget.subject.code);
    deptController = TextEditingController(text: widget.subject.dept);
    yearController = TextEditingController(text: widget.subject.year.toString());
    semesterController =
        TextEditingController(text: widget.subject.semester.toString());
    periodController =
        TextEditingController(text: widget.subject.period.toString());
    dayController = TextEditingController(text: widget.subject.day);
  }

  Future<void> _updatePeriod() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final updatedSubject = SubjectModel(
        id: widget.subject.id,
        name: nameController.text.trim(),
        code: codeController.text.trim(),
        dept: deptController.text.trim(),
        year: int.parse(yearController.text.trim()),
        semester: int.parse(semesterController.text.trim()),
        period: int.parse(periodController.text.trim()),
        isActive: widget.subject.isActive,
        day: dayController.text.trim(),
      );

      await DatabaseService().updateSubject(updatedSubject);

      if (mounted) {
        Navigator.pop(context, updatedSubject);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Period updated successfully")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating period: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
        const Text("Edit Period", style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
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
              ElevatedButton.icon(
                onPressed: _updatePeriod,
                icon: const Icon(Icons.save),
                label: const Text("Update Period"),
              )
            ],
          ),
        ),
      ),
    );
  }
}