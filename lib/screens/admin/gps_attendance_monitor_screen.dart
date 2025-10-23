import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iem_attendance_app/models/subject_model.dart';

class GpsAttendanceMonitorScreen extends StatefulWidget {
  const GpsAttendanceMonitorScreen({super.key});

  @override
  State<GpsAttendanceMonitorScreen> createState() => _GpsAttendanceMonitorScreenState();
}

class _GpsAttendanceMonitorScreenState extends State<GpsAttendanceMonitorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Color primary = const Color(0xFF765DBD);

  List<int> yearList = [1, 2, 3, 4];
  List<int> semList = [1, 2, 3, 4, 5, 6, 7, 8];
  List<String> deptList = ["CSE", "IT", "IOT", "IOTCSBT", "CSE(AIML)", "CSE(AI)", "CSBS", "ECE", "EEE", "ME", "CE"];

  int? selectedYear;
  int? selectedSemester;
  String? selectedDept;
  DateTime selectedDate = DateTime.now();

  List<Map<String, dynamic>> classAttendance = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    if (selectedYear == null || selectedSemester == null || selectedDept == null) return;

    setState(() {
      isLoading = true;
      classAttendance.clear();
    });

    try {
      // Fetch active subjects
      final subjectsQuery = await _firestore
          .collection('timetable')
          .where('isActive', isEqualTo: true)
          .where('gpsActivation.isGpsEnabled', isEqualTo: true)
          .where('year', isEqualTo: selectedYear)
          .where('semester', isEqualTo: selectedSemester)
          .where('dept', isEqualTo: selectedDept)
          .get();

      List<Map<String, dynamic>> tempAttendance = [];

      for (var doc in subjectsQuery.docs) {
        final subject = SubjectModel.fromFirestore(doc);
        final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

        // Path where attendance entries are stored
        final attendancePath =
            'attendance/${subject.year}/${subject.semester}/${subject.dept.split(',').first.trim()}/$dateStr/${subject.period}/entries';

        // Fetch present students
        final presentQuery = await _firestore.collection(attendancePath).get();
        final presentStudentIds = presentQuery.docs.map((d) => d['userId'] as String).toSet();

        // Fetch all enrolled students for the subject
        final studentsQuery = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'student')
            .where('year', isEqualTo: subject.year)
            .where('semester', isEqualTo: subject.semester)
            .where('dept', isEqualTo: subject.dept.split(',').first.trim())
            .get();

        tempAttendance.add({
          'subject': subject,
          'presentCount': presentStudentIds.length,
          'totalStudents': studentsQuery.docs.length,
        });
      }

      if (mounted) {
        setState(() {
          classAttendance = tempAttendance;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching attendance: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Attendance Monitor'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchAttendance,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildDropdown<int>("Year", yearList, selectedYear, (val) {
                  setState(() => selectedYear = val);
                  _fetchAttendance();
                }),
                const SizedBox(height: 8),
                _buildDropdown<int>("Semester", semList, selectedSemester, (val) {
                  setState(() => selectedSemester = val);
                  _fetchAttendance();
                }),
                const SizedBox(height: 8),
                _buildDropdown<String>("Department", deptList, selectedDept, (val) {
                  setState(() => selectedDept = val);
                  _fetchAttendance();
                }),
                const SizedBox(height: 8),
                _buildDateSelector(),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _fetchAttendance,
              child: classAttendance.isEmpty
                  ? const Center(child: Text('No active classes found.'))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: classAttendance.length,
                itemBuilder: (context, index) {
                  final subject = classAttendance[index]['subject'] as SubjectModel;
                  final presentCount = classAttendance[index]['presentCount'] as int;
                  final totalStudents = classAttendance[index]['totalStudents'] as int;

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      title: Text(
                        '${subject.name} (${subject.code})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                          'Period: ${subject.period} | Day: ${subject.day}\nAttendance: $presentCount / $totalStudents'),
                      trailing: CircleAvatar(
                        backgroundColor: primary,
                        child: Text(
                          presentCount.toString(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>(
      String title, List<T> items, T? selectedValue, void Function(T?) onChanged) {
    return Row(
      children: [
        Text(
          "$title:",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CustomDropdown(
            hintText: "Select $title",
            items: items,
            onChanged: onChanged,
            initialItem: selectedValue,
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Row(
      children: [
        const Text("Date:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(primary: primary),
                  ),
                  child: child!,
                ),
              );
              if (picked != null && picked != selectedDate) {
                setState(() => selectedDate = picked);
                _fetchAttendance();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: primary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(DateFormat('EEEE, MMM dd, yyyy').format(selectedDate)),
            ),
          ),
        ),
      ],
    );
  }
}
