import 'dart:io';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:iem_attendance_app/models/student_model.dart';
import 'package:iem_attendance_app/screens/student/profile_screen.dart';
import 'package:iem_attendance_app/services/database_service.dart';
import 'package:iem_attendance_app/widgets/create_student.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;

class AllStudentsScreen extends StatefulWidget {
  const AllStudentsScreen({super.key});

  @override
  State<AllStudentsScreen> createState() => _AllStudentsScreenState();
}

class _AllStudentsScreenState extends State<AllStudentsScreen> {

  int totalCount = 0;
  TextEditingController searchController = TextEditingController();
  List<StudentModel> students = [];
  List<StudentModel> filteredStudents = [];

  Color primary = const Color(0xFF765DBD);
  final LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF765DBD), Color(0xFF301B5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  List<int> yearList = [1, 2, 3, 4];
  List<int> semList = [1, 2, 3, 4, 5, 6, 7, 8];
  List<String> deptList = ["CSE", "IT", "IOT", "IOTCSBT", "CSE(AIML)", "CSE(AI)", "CSBS", "ECE", "EEE", "ME", "CE"];
  List<String> dayList = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];

  // List<>

  int? selectedYear;
  int? selectedSemester;
  String? selectedDept;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    searchController.addListener(() {
      _applyFilters();
    });
  }

  void _applyFilters() {
    final query = searchController.text.toLowerCase();

    setState(() {
      filteredStudents = students.where((student) {

        final matchesYear = selectedYear == null || student.year == selectedYear;
        final matchesDept = selectedDept == null || student.dept == selectedDept;
        final matchesSem = selectedSemester == null || student.semester == selectedSemester;

        final matchesSearch = query.isEmpty ||
          student.name.toLowerCase().contains(query) ||
          student.enrollment.toLowerCase().contains(query) ||
          student.dept.toLowerCase().contains(query) ||
          student.year.toString().contains(query);

        return matchesYear && matchesDept && matchesSem && matchesSearch;

      }).toList();
    });
  }

  Widget _highlightMatch(String source, String query) {
    final matchIndex = source.toLowerCase().indexOf(query.toLowerCase());

    if (matchIndex == -1) return Text(source);

    final beforeMatch = source.substring(0, matchIndex);
    final match = source.substring(matchIndex, matchIndex + query.length);
    final afterMatch = source.substring(matchIndex + query.length);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: beforeMatch,
            style: TextStyle(color: Colors.black),
          ),
          TextSpan(
            text: match,
            style: TextStyle(
              color: Colors.deepPurple,
              backgroundColor: Colors.yellow.shade200,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: afterMatch,
            style: TextStyle(color: Colors.black),
          ),
        ],
      ),
    );
  }

  // Future<void> _fetchStudents() async {
  //   if (
  //     selectedYear == null ||
  //     selectedSemester == null ||
  //     selectedDept == null
  //   ) {
  //     return;
  //   }
  //
  //   setState(() {
  //     isLoading = true;
  //     filteredStudents = [];
  //   });
  //
  //   final snap = await FirebaseFirestore.instance
  //       .collection("users")
  //       .where("role", isEqualTo: "student")
  //       .where("year", isEqualTo: selectedYear)
  //       .where("semester", isEqualTo: selectedSemester)
  //       .where("dept", isEqualTo: selectedDept)
  //       .get();
  //
  //   final fetchedStudents = snap.docs.map((doc) => StudentModel.fromFirestore(doc)).toList();
  //
  //   setState(() {
  //     students = fetchedStudents;
  //     isLoading = false;
  //   });
  // }

  Future<void> _exportToCSV() async {
    List<List<String>> csvData = [
      ['Student ID', 'Name', 'Department', 'Year']
    ];

    for (var student in filteredStudents) {
      csvData.add([
        student.enrollment,
        student.name,
        student.dept,
        student.year.toString()
      ]);
    }
    
    final now = DateTime.now();
    final year = students[0].year;
    final dept = students[0].dept;
    final fileName = 'student_data_${dept}_${year}_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    
    await file.writeAsString(const ListToCsvConverter().convert(csvData));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV file saved to $filePath')),
    );
    
    await Share.shareXFiles([XFile(file.path)], text: 'Student_Data_${dept}_${year}_CSV');
  }
  
  Future<void> _exportToPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Student List_${students[0].dept}_${students[0].year}_${DateFormat('yyyy-MM-dd HH:mm a').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Student ID', 'Name', 'Department', 'Year'],
            data: filteredStudents.map((student) {
              return [
              student.enrollment,
              student.name,
              student.dept,
              student.year.toString()];
              }).toList(),
          )
        ],
      )
    );
    
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'student_list_${students[0].dept}_${students[0].year}_${DateFormat('yyyy-MM-dd HH:mm a').format(DateTime.now())}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Students"),
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
      body: StreamBuilder<List<StudentModel>>(
        stream: DatabaseService().getStudentStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint("🔥 Firestore Stream Error: ${snapshot.error}");
            return Center(child: Text("Error Loading in Data"));
          }
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          students = snapshot.data!;

          students.sort((a, b) {
            return a.enrollment.compareTo(b.enrollment);
          });

          totalCount = students.length;

          // Always apply filters when stream updates
          filteredStudents = students.where((student) {
            final query = searchController.text.toLowerCase();

            final matchesYear = selectedYear == null || student.year == selectedYear;
            final matchesDept = selectedDept == null || student.dept == selectedDept;
            final matchesSem = selectedSemester == null || student.semester == selectedSemester;

            final matchesSearch = query.isEmpty ||
                student.name.toLowerCase().contains(query) ||
                student.enrollment.toLowerCase().contains(query) ||
                student.dept.toLowerCase().contains(query) ||
                student.year.toString().contains(query);

            return matchesYear && matchesDept && matchesSem && matchesSearch;
          }).toList();

          return Column(
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Padding(
                  padding: EdgeInsets.all(11.0),
                  child: Row(
                    children: [
                      Icon(Icons.groups, color: Colors.deepPurple),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _buildStudentCountTitle(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                child: Row(
                  // crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          labelText: 'Search by Name, Enroll No.',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _showFilterDropdownDialog,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                          child: Row(
                            children: [
                              Icon(Icons.filter_alt_outlined, color: primary, size: 30),
                              // const SizedBox(width: 5),
                              // Text("Filter", style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
                            ],
                          )
                        ),
                      )
                    )
                  ],
                ),
              ),
              Expanded(
                child: filteredStudents.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_off, size: 80, color: Colors.grey[400]),
                      Text("No matching results",
                        style: TextStyle(fontSize: 18, color: Colors.grey[700])),
                    ],
                  ),
                )
                    : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filteredStudents.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    final query = searchController.text;

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StudentProfileScreen(student: student),
                            ),
                          );

                          if (result == true) {
                            setState(() {
                              filteredStudents.removeWhere((s) => s.id == student.id);
                              students.removeWhere((s) => s.id == student.id);
                            });
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person, color: primary, size: 20),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: query.isNotEmpty
                                        ? _highlightMatch(student.name, query)
                                        : Text(student.name, style: TextStyle(color: Colors.black, fontSize: 15)),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.fingerprint, color: primary, size: 20),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: query.isNotEmpty
                                        ? _highlightMatch("Enrollment No.: ${student.enrollment}", query)
                                        : Text("Enrollment No.: ${student.enrollment}", style: TextStyle(color: Colors.black87)),
                                  )
                                ],
                              ),
                              SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.school, color: primary, size: 20),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: query.isNotEmpty
                                        ? _highlightMatch("Department: ${student.dept}", query)
                                        : Text("Department: ${student.dept}", style: TextStyle(color: Colors.black54)),
                                  )
                                ],
                              ),
                              SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.school, color: primary, size: 20),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: query.isNotEmpty
                                        ? _highlightMatch("Year: ${student.year}", query)
                                        : Text("Year: ${student.year}", style: TextStyle(color: Colors.black54)),
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),

      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateStudentScreen()),
              );
            },
            label: Text("Add Student"),
            icon: Icon(Icons.person_add),
            heroTag: "addStudent",
          ),
          SizedBox(height: 10),
          // FloatingActionButton.extended(
          //   onPressed: _updateAllWomanIds,
          //   label: Text("Update womanId"),
          //   icon: Icon(Icons.update),
          //   backgroundColor: Colors.deepPurpleAccent,
          //   heroTag: "updateWomanId",
          // ),
          // TEMPORARY: For adding 500 dummy women
          // FloatingActionButton.extended(
          //   onPressed: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => const AddDummyWomenScreen()),
          //     );
          //   },
          //   label: Text("Add Dummy"),
          //   icon: Icon(Icons.auto_fix_high),
          //   backgroundColor: Colors.orangeAccent,
          //   heroTag: "addDummy",
          // ),
        ]
      ),
    );
  }

  void _showFilterDropdownDialog() {

    final RenderBox box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    int? tempSelectedYear = selectedYear;
    int? tempSelectedSemester = selectedSemester;
    String? tempSelectedDept = selectedDept;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return Stack(
          children: [
            Positioned(
              left: 20,
              right: 20,
              top: offset.dy + 220,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        offset: Offset(0, 4),
                        blurRadius: 12,
                      )
                    ],
                  ),
                  child: StatefulBuilder(
                    builder: (ctx, setModalState) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDropdowns<int>("Year", yearList, tempSelectedYear, (value) {
                            setState(() {
                              setModalState(() => tempSelectedYear = value);
                              // _applyFilters();
                            });
                          }),
                          SizedBox(height: 12),
                          _buildDropdowns<int>("Semester", semList, tempSelectedSemester, (value) {
                            setState(() {
                              setModalState(() => tempSelectedSemester = value);
                              // _applyFilters();
                            });
                          }),
                          SizedBox(height: 12),
                          _buildDropdowns<String>("Department", deptList, tempSelectedDept, (value) {
                            setState(() {
                              setModalState(() => tempSelectedDept = value);
                              // _applyFilters();
                            });
                          }),
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    selectedYear = null;
                                    selectedSemester = null;
                                    selectedDept = null;
                                    filteredStudents = students;
                                  });
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[50],
                                  foregroundColor: primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),

                                child: Text("Reset"),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    selectedYear = tempSelectedYear;
                                    selectedSemester = tempSelectedSemester;
                                    selectedDept = tempSelectedDept;
                                  });
                                  _applyFilters();
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text("Apply"),
                              )
                            ],
                          )
                        ],
                      );
                    },
                  ),
                )
              ),
            )
          ],
        );
      }
    );
  }

  Widget _buildDropdowns<T>(String title, List<T> list, T? selectedValue, void Function(T?) onChanged) {
    return Row(
      children: [
        Text(
          "$title:",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CustomDropdown(
            hintText: "Select $title",
            items: list,
            onChanged: onChanged,
            initialItem: selectedValue,
          ),
        )
      ],
    );
  }

  String _buildStudentCountTitle() {
    if (selectedYear == null && selectedSemester == null && selectedDept == null) {
      return "Total Students: ${filteredStudents.length}";
    }

    String deptStr = selectedDept != null ? " $selectedDept" : "";
    String yearStr = selectedYear != null ? " ${_getYearText(selectedYear!)}" : "";
    String semStr = selectedSemester != null ? "Sem-${selectedSemester!} " : "";

    return "Total Students of $deptStr$yearStr$semStr: ${filteredStudents.length}";

  }

  String _getYearText(int year) {
    switch (year) {
      case 1:
        return "First Year";
      case 2:
        return "Second Year";
      case 3:
        return "Third Year";
      case 4:
        return "Fourth Year";
      default:
        return "$year Year";
    }
  }
}
