import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iem_attendance_app/models/subject_model.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class StudentDetailScreen extends StatefulWidget {
  final SubjectModel? subject;

  const StudentDetailScreen({super.key, this.subject});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  double screenHeight = 0;
  double screenWidth = 0;

  Color primary = const Color(0xFF765DBD);
  final LinearGradient primaryGradient = const LinearGradient(
    colors: [Color(0xFF765DBD), Color(0xFF301B5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> presentRecords = [];
  List<Map<String, dynamic>> absentRecords = [];
  List<Map<String, dynamic>> filteredPresentRecords = [];
  List<Map<String, dynamic>> filteredAbsentRecords = [];

  DateTime selectedDate = DateTime.now();
  DateTime focusedDate = DateTime.now();
  bool isLoading = false;
  bool showCalendar = false;
  bool showPresent = true; // New state to toggle between present/absent lists

  // Statistics
  int totalPresent = 0;
  int totalEnrolledStudents = 0;

  @override
  void initState() {
    super.initState();
    // Initially show today's attendance
    if (widget.subject != null) {
      Future.microtask(() async {
        await _fetchAttendanceForDate(DateTime.now());
        if (mounted) {
          setState(() {
            selectedDate = DateTime.now();
            focusedDate = DateTime.now();
          });
        }
      });
    }
    searchController.addListener(_filterRecords);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StudentDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if the subject has changed.
    if (widget.subject != oldWidget.subject) {
      print("Subject changed, refreshing attendance for ${widget.subject?.name}");
      // If the new subject is not null, fetch data for it.
      if (widget.subject != null) {
        _fetchAttendanceForDate(selectedDate);
      } else {
        // If the subject is null, clear the attendance data.
        setState(() {
          presentRecords.clear();
          absentRecords.clear();
          filteredPresentRecords.clear();
          filteredAbsentRecords.clear();
          totalPresent = 0;
          totalEnrolledStudents = 0;
        });
      }
    }
  }

  /// Fetch attendance records for a specific date
  Future<void> _fetchAttendanceForDate(DateTime date) async {
    if (widget.subject == null) return;

    setState(() {
      isLoading = true;
      presentRecords.clear();
      absentRecords.clear();
      filteredPresentRecords.clear();
      filteredAbsentRecords.clear();
      totalPresent = 0;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final year = widget.subject!.year.toString();
      final semester = widget.subject!.semester.toString();
      final department = widget.subject!.dept.split(',').first.trim(); // This will need to be split and handled
      final period = widget.subject!.period.toString();

      final attendancePath = 'attendance/$year/$semester/$department/$dateStr/$period/entries';

      // Get present students from the attendance path
      final presentQuery = await FirebaseFirestore.instance
          .collection(attendancePath)
          .orderBy('markedAt', descending: false)
          .get();

      presentRecords = presentQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Get all enrolled students
      final studentsQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('year', isEqualTo: widget.subject!.year)
          .where('semester', isEqualTo: widget.subject!.semester)
          .where('dept', isEqualTo: department.split(',').first.trim())
          .get();

      totalEnrolledStudents = studentsQuery.docs.length;
      final presentStudentIds = presentRecords.map((r) => r['userId']).toSet();

      // Determine absent students
      absentRecords = studentsQuery.docs
          .where((doc) => !presentStudentIds.contains(doc.id))
          .map((doc) {
        final studentData = doc.data();
        return {
          'id': doc.id,
          'userId': doc.id,
          'studentName': studentData['name'] ?? 'Unknown',
          'enrollment': studentData['enrollment'] ?? 'N/A',
          'status': 'absent',
        };
      }).toList();

      presentRecords.sort((a,b) => a['studentName'].compareTo(b['studentName']));
      absentRecords.sort((a,b) => a['studentName'].compareTo(b['studentName']));

      setState(() {
        filteredPresentRecords = List.from(presentRecords);
        filteredAbsentRecords = List.from(absentRecords);
        totalPresent = presentRecords.length;
      });

    } catch (e) {
      if(mounted) {
        print('Error fetching attendance: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading attendance: $e')),
        );
      }
    } finally {
      if(mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// Filter records based on search input
  void _filterRecords() {
    final query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredPresentRecords = List.from(presentRecords);
        filteredAbsentRecords = List.from(absentRecords);
      } else {
        filteredPresentRecords = presentRecords.where((record) {
          final name = record['studentName'].toString().toLowerCase();
          final enrollment = record['enrollment'].toString().toLowerCase();
          return name.contains(query) || enrollment.contains(query);
        }).toList();

        filteredAbsentRecords = absentRecords.where((record) {
          final name = record['studentName'].toString().toLowerCase();
          final enrollment = record['enrollment'].toString().toLowerCase();
          return name.contains(query) || enrollment.contains(query);
        }).toList();
      }
    });
  }

  // ... (Export CSV, PDF methods - no change, they are fine) ...

  Future<void> _exportToCSV() async {
    if (filteredPresentRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export.')),
      );
      return;
    }
    final headers = ['Student ID', 'Enrollment', 'Name', 'Attendance Status', 'Timestamp', 'Distance'];
    final csvData = [headers];
    for (var record in filteredPresentRecords) {
      final status = record['status'] ?? 'present';
      final timestamp = record['markedAt'] != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format((record['markedAt'] as Timestamp).toDate()) : 'N/A';
      final distance = record['distance']?.toStringAsFixed(2) ?? 'N/A';
      csvData.add([
        record['userId'],
        record['enrollment'],
        record['studentName'],
        status,
        timestamp,
        distance,
      ]);
    }
    final now = DateTime.now();
    final fileName = 'attendance_${widget.subject!.code}_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsString(const ListToCsvConverter().convert(csvData));
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV file saved to $filePath')),
      );
    }
    await Share.shareXFiles([XFile(file.path)], text: 'Attendance_Report');
  }

  Future<void> _exportToPDF() async {
    if (filteredPresentRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export.')),
      );
      return;
    }
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Attendance Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.Text('Subject: ${widget.subject!.name} (${widget.subject!.code})', style: pw.TextStyle(fontSize: 16)),
            pw.Text('Date: ${DateFormat('EEEE, MMM dd, yyyy').format(selectedDate)}', style: pw.TextStyle(fontSize: 14)),
            pw.Divider(),
          ],
        ),
        build: (context) => [
          pw.Table.fromTextArray(
            headers: ['Name', 'Enrollment', 'Status', 'Time'],
            data: filteredPresentRecords.map((record) {
              final status = record['status'] ?? 'present';
              final time = record['markedAt'] != null ? DateFormat('HH:mm:ss').format((record['markedAt'] as Timestamp).toDate()) : 'N/A';
              return [record['studentName'], record['enrollment'], status, time];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            border: pw.TableBorder.all(width: 0.5),
            cellAlignment: pw.Alignment.center,
          ),
        ],
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'attendance_${widget.subject!.code}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
    );
  }

  Future<void> _deleteAttendanceRecord(String attendanceId) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final year = widget.subject!.year.toString();
      final semester = widget.subject!.semester.toString();
      final department = widget.subject!.dept;
      final attendancePath = 'attendance/$year/$semester/${department.split(',').first.trim()}/$dateStr/${widget.subject!.period}/entries';

      await FirebaseFirestore.instance
          .collection(attendancePath)
          .doc(attendanceId)
          .delete();

      _fetchAttendanceForDate(selectedDate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance record deleted successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete record: $e')),
        );
      }
    }
  }

  void _confirmDelete(Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Attendance'),
        content: Text('Are you sure you want to delete the attendance record for ${record['studentName']}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAttendanceRecord(record['userId']); // Use userId as the document ID
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;

    if (widget.subject == null) {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text("Student Attendance"),
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_outlined, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                "Please select a subject first from Class List",
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Attendance"),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Download CSV",
            onPressed: _exportToCSV,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Download PDF",
            onPressed: _exportToPDF,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubjectInfoCard(),
          _buildStatisticsRow(),
          if (showCalendar) _buildCalendarView() else _buildDateSelector(),
          if (!showCalendar) _buildSearchBar(),
          if (!showCalendar) _buildListToggleButtons(),
          if (!showCalendar) _buildAttendanceList(),
        ],
      ),
    );
  }

  Widget _buildSubjectInfoCard() {
    return Padding(
      padding: EdgeInsets.only(
        top: 8,
        bottom: 8,
        left: screenWidth * 0.02,
        right: screenWidth * 0.02,
      ),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: primaryGradient,
          ),
          child: ListTile(
            leading: const Icon(Icons.school, color: Colors.white, size: 32),
            title: Text(
              "${widget.subject!.name} (${widget.subject!.code})",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              "Year: ${widget.subject!.year} | Dept: ${widget.subject!.dept} | Sem: ${widget.subject!.semester}\nDay: ${widget.subject!.day} | Period: ${widget.subject!.period}",
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11.0),
      child: Row(
        children: [
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people, color: Colors.green, size: 24),
                        const SizedBox(width: 8,),
                        Text(
                          '$totalPresent',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),

                    Text('Present Today', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.class_, color: Colors.blue, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          '$totalEnrolledStudents',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                    Text('Total Students', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.analytics, color: Colors.orange, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          totalEnrolledStudents == 0 ? '0%' : '${((totalPresent / totalEnrolledStudents) * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ]
                    ),

                    Text('Attendance %', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Padding(
      padding: EdgeInsets.only(
        top: 8,
        bottom: 8,
        left: screenWidth * 0.02,
        right: screenWidth * 0.02,
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(Icons.calendar_today, color: primary),
          title: Text(
            'Selected Date: ${DateFormat('EEEE, MMM dd, yyyy').format(selectedDate)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: Icon(Icons.arrow_forward_ios, color: primary, size: 16),
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: primary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null && picked != selectedDate) {
              setState(() {
                selectedDate = picked;
                focusedDate = picked;
              });
              _fetchAttendanceForDate(selectedDate);
            }
          },
        ),
      ),
    );
  }

  Widget _buildCalendarView() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now(),
            focusedDay: focusedDate,
            selectedDayPredicate: (day) => isSameDay(selectedDate, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                selectedDate = selectedDay;
                focusedDate = focusedDay;
                showCalendar = false;
              });
              _fetchAttendanceForDate(selectedDay);
            },
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              selectedDecoration: BoxDecoration(
                color: primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: primary.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF765DBD),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: "Search by Name or Enrollment Number",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              searchController.clear();
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildListToggleButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => setState(() => showPresent = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: showPresent ? primary : Colors.grey.shade300,
                foregroundColor: showPresent ? Colors.white : Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Present (${filteredPresentRecords.length})'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () => setState(() => showPresent = false),
              style: ElevatedButton.styleFrom(
                backgroundColor: !showPresent ? primary : Colors.grey.shade300,
                foregroundColor: !showPresent ? Colors.white : Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Absent (${filteredAbsentRecords.length})'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    final listToShow = showPresent ? filteredPresentRecords : filteredAbsentRecords;

    return Expanded(
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : listToShow.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_dissatisfied,
                size: 80,
                color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              searchController.text.isNotEmpty
                  ? "No students found matching your search"
                  : "No ${showPresent ? 'present' : 'absent'} records found for ${DateFormat('MMM dd, yyyy').format(selectedDate)}",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: () => _fetchAttendanceForDate(selectedDate),
        child: ListView.builder(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20, // extra padding for keyboard
          ),
          itemCount: listToShow.length,
          itemBuilder: (context, index) {
            final record = listToShow[index];
            final isPresent = record['status'] == 'present';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPresent ? Colors.green : Colors.red,
                  child: Icon(
                    isPresent ? Icons.check : Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(
                  record['studentName'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isPresent ? Colors.black87 : Colors.grey[600],
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enrollment: ${record['enrollment']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (isPresent && record['markedAt'] != null)
                      Text(
                        'Time: ${DateFormat('HH:mm:ss').format((record['markedAt'] as Timestamp).toDate())}',
                        style: const TextStyle(fontSize: 11, color: Colors.green),
                      ),
                    if (isPresent && record['distance'] != null)
                      Text(
                        'Distance: ${record['distance'].toStringAsFixed(1)}m',
                        style: const TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                  ],
                ),
                trailing: isPresent
                    ? IconButton(
                  icon: const Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                    size: 32,
                  ),
                  onPressed: () => _confirmDelete(record),
                  tooltip: 'Delete Attendance',
                )
                    : Container(
                  width: 24, // keeps alignment consistent
                ),
                onTap: () => _showAttendanceDetails(record),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAttendanceDetails(Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attendance Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${record['studentName']}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Enrollment: ${record['enrollment']}'),
            const SizedBox(height: 8),
            if (record['markedAt'] != null)
              Text('Time: ${DateFormat('HH:mm:ss, MMM dd, yyyy').format((record['markedAt'] as Timestamp).toDate())}'),
            if (record['distance'] != null)
              Text('Distance from teacher: ${record['distance'].toStringAsFixed(2)} meters'),
            const SizedBox(height: 8),
            if (record['verification'] != null) ...[
              Text('Verification Method: ${record['verification']['method'] ?? 'Unknown'}'),
              Text('Face Verified: ${record['verification']['faceRecognized'] ?? false ? 'Yes' : 'No'}'),
              Text('GPS Verified: ${record['verification']['proximityVerified'] ?? false ? 'Yes' : 'No'}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}