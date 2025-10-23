import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iem_attendance_app/models/subject_model.dart';
import 'package:iem_attendance_app/services/database_service.dart';
import 'package:iem_attendance_app/widgets/create_period.dart';
import 'package:iem_attendance_app/widgets/update_period.dart';
import 'package:permission_handler/permission_handler.dart';

class AllClasslistScreen extends StatefulWidget {
  final void Function(SubjectModel subject)? onSubjectSelected;

  const AllClasslistScreen({super.key, this.onSubjectSelected});

  @override
  State<AllClasslistScreen> createState() => _AllClasslistScreenState();
}

class _AllClasslistScreenState extends State<AllClasslistScreen> with AutomaticKeepAliveClientMixin{

  @override
  bool get wantKeepAlive => true;

  double screenHeight = 0;
  double screenWidth = 0;

  String? longPressedSubjectId;

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

  int? selectedYear;
  int? selectedSemester;
  String? selectedDept;
  String? selectedDay;

  // Map<String, bool> dayActivation = {};
  // String? expandedDay;

  List<SubjectModel> subjects = [];
  bool isLoading = false;
  bool isLoadingLocation = false;
  Position? currentPosition;

  // Future<void> _fetchAvailableDays() async {
  //   if (selectedYear == null || selectedSemester == null || selectedDept == null) return;
  //
  //   setState(() {
  //     isLoading = true;
  //     dayActivation.clear();
  //     expandedDay = null;
  //     subjects.clear();
  //   });
  //
  //   final snap = await FirebaseFirestore.instance
  //       .collection("timetable")
  //       .where("year", isEqualTo: selectedYear)
  //       .where("semester", isEqualTo: selectedSemester)
  //       .where("dept", isEqualTo: selectedDept)
  //       .get();
  //
  //   final docs = snap.docs;
  //
  //   // Get unique days
  //   final uniqueDays = <String>{};
  //   for (var doc in docs) {
  //     uniqueDays.add(doc['day']);
  //   }
  //
  //   // Prepare activation state
  //   for (var day in uniqueDays) {
  //     final anyActive = docs.any((d) => d['day'] == day && d['isActive'] == true);
  //     dayActivation[day] = anyActive;
  //   }
  //
  //   setState(() {
  //     isLoading = false;
  //   });
  // }

  Future<void> _checkAndRequestLocationPermission() async {
    setState(() {
      isLoadingLocation = true;
    });

    try {
      print("🔍 Checking location permission status...");
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        return;
      }

      // Check current permission status
      PermissionStatus permission = await Permission.location.status;
      print("📋 Current permission status: $permission");

      if (permission.isDenied) {
        print("❓ Permission denied, requesting...");
        permission = await Permission.location.request();
        print("📋 New permission status after request: $permission");
      }

      if (permission.isGranted) {
        print("✅ Location permission granted, getting position...");
        await _getCurrentLocation();
      } else if (permission.isDenied) {
        print("❌ Location permission denied by user");
        _showLocationPermissionDialog();
      } else if (permission.isPermanentlyDenied) {
        print("❌ Location permission permanently denied");
        _showLocationSettingsDialog();
      }
    } catch (e) {
      print("❌ Error checking location permission: $e");
    } finally {
      setState(() {
        isLoadingLocation = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if(mounted) {
        setState(() {
          currentPosition = position;
        });
        print("📍 Current location obtained: ${currentPosition?.latitude}, ${currentPosition?.longitude}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Location updated successfully!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if(mounted) {
        print("❌ Error getting location: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to get location: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location Permission Required'),
        content: Text('This app needs location permission to activate GPS-based attendance. Please grant location permission to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkAndRequestLocationPermission();
            },
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showLocationSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location Permission Permanently Denied'),
        content: Text('Location permission has been permanently denied. Please enable it in app settings to use GPS-based attendance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location Services Disabled'),
        content: Text('Location services are turned off. Please enable location services in your device settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchSubjectsForDay() async {
    if (selectedYear == null || selectedSemester == null || selectedDept == null || selectedDay == null) return;

    setState(() {
      isLoading = true;
      subjects = [];
    });

    final snap = await FirebaseFirestore.instance
        .collection("timetable")
        .where("year", isEqualTo: selectedYear)
        .where("semester", isEqualTo: selectedSemester)
        .where("day", isEqualTo: selectedDay)
        .get();

    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    for (var doc in snap.docs) {
      final data = doc.data();
      if (data.containsKey("lastTemporaryUpdate")) {
        final lastUpdate = DateTime.tryParse(data["lastTemporaryUpdate"]);
        final isTemporary = (data["name"] as String).contains("(Arranged)") || (data["name"] as String).contains("(Combined)");

        // If time is past 11:59 PM and it is a temporary update
        if (lastUpdate != null && now.isAfter(endOfDay) && isTemporary) {
          await FirebaseFirestore.instance.collection("timetable").doc(doc.id).update({
            "name": data["originalName"] ?? data["name"],
            "dept": data["originalDept"] ?? data["dept"],
            "originalName": FieldValue.delete(),
            "originalDept": FieldValue.delete(),
            "lastTemporaryUpdate": FieldValue.delete(),
          });
        }
      }
    }

    final fetchedSubjects = snap.docs
        .map((doc) => SubjectModel.fromFirestore(doc))
        .where((subject) => subject.dept.split(',').map((d) => d.trim()).contains(selectedDept))
        .toList()
      ..sort((a, b) => a.period.compareTo(b.period));

    setState(() {
      subjects = fetchedSubjects;
      isLoading = false;
    });
  }


  // Future<void> _updateDayActivation(String day, bool isActive) async {
  //   final snap = await FirebaseFirestore.instance
  //       .collection("timetable")
  //       .where("year", isEqualTo: selectedYear)
  //       .where("semester", isEqualTo: selectedSemester)
  //       .where("dept", isEqualTo: selectedDept)
  //       .where("day", isEqualTo: day)
  //       .get();
  //
  //   final batch = FirebaseFirestore.instance.batch();
  //
  //   for (var doc in snap.docs) {
  //     batch.update(doc.reference, {"isActive": isActive});
  //   }
  //
  //   await batch.commit();
  //
  //   setState(() {
  //     dayActivation[day] = isActive;
  //     if (!isActive) expandedDay = null;
  //   });
  //
  //   if (isActive) {
  //     _fetchSubjectsForDay(day);
  //   }
  // }


  Future<void> _updateSubjectActivation(String id, bool isActive) async {
    await FirebaseFirestore.instance
        .collection("timetable")
        .doc(id)
        .update({"isActive": isActive});

    setState(() {
      subjects = subjects.map((s) {
        if (s.id == id) return s.copyWith(attended: s.attended, isActive: isActive);
        return s;
      }).toList();
    });
  }

  Future<void> _deleteSubject(String id) async {
    try {
      await DatabaseService().deleteSubject(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Subject deleted successfully")),
      );
      _fetchSubjectsForDay();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting subject: $e")),
      );
    }
  }

  void _confirmDelete(BuildContext context, String subjectId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          "Delete Subject",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure you want to delete this subject? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // cancel
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog first
              await _deleteSubject(subjectId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }


  void _dismissLongPressOverlay() {
    if (mounted) {
      setState(() {
        longPressedSubjectId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    screenHeight = MediaQuery
        .of(context)
        .size
        .height;

    return Scaffold(
        appBar: AppBar(
          title: const Text("Manage Classes"),
          centerTitle: true,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchSubjectsForDay,
            ),
            IconButton(
                onPressed: () { // close the details dialog first
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreatePeriod(),
                    ),
                  );
                },
                icon: const Icon(Icons.add))
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (longPressedSubjectId != null) {
              setState(() {
                longPressedSubjectId = null;
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                _buildDropdowns<int>("Year", yearList, selectedYear, (val) {
                  setState(() => selectedYear = val);
                }),
                const SizedBox(height: 8),
                _buildDropdowns<int>("Semester", semList, selectedSemester, (val) {
                  setState(() => selectedSemester = val);
                }),
                const SizedBox(height: 8),
                _buildDropdowns<String>("Department", deptList, selectedDept, (val) {
                  setState(() => selectedDept = val);
                }),
                const SizedBox(height: 8),
                _buildDropdowns<String>("Day", dayList, selectedDay, (val) {
                  setState(() => selectedDay = val);
                }),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _fetchSubjectsForDay,
                  icon: const Icon(
                    Icons.search,
                    color: Colors.white,
                  ),
                  label: const Text("Fetch TimeTable"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : subjects.isEmpty
                      ? const Center(child: Text("No subjects found"))
                      : ListView(
                    children: subjects.map((subject) {
                      final isLongPressed = longPressedSubjectId == subject.id;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (widget.onSubjectSelected != null) {
                                widget.onSubjectSelected!(subject);
                              }
                            },
                            onLongPress: () {
                              setState(() {
                                longPressedSubjectId = subject.id;
                              });
                            },
                            child: Card(
                              elevation: 4,
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                title: Text(
                                  "${subject.name} (${subject.code})",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text("Period: ${subject.period}, Day: ${subject.day}"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      onPressed: () async {
                                        final updated =
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => UpdatePeriod(subject: subject),
                                          ),
                                        );
                                        if (updated != null) {
                                          _fetchSubjectsForDay();
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        _confirmDelete(context, subject.id);
                                      },
                                    ),
                                  ]
                                )
                              ),
                            ),
                          ),

                          if (isLongPressed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0, left: 12, right: 12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.deepPurple.shade100),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)],
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                child: Column(
                                  children: [
                                    _buildActionBtn("Arrangement", Icons.schedule, () {
                                      _showSubjectEditDialog(subject, isPermanent: false, isCombined: false);
                                      _dismissLongPressOverlay();
                                    }),
                                    const SizedBox(height: 8),
                                    _buildActionBtn("Permanent", Icons.update, () {
                                      _showSubjectEditDialog(subject, isPermanent: true, isCombined: false);
                                      _dismissLongPressOverlay();
                                    }),
                                    const SizedBox(height: 8),
                                    _buildActionBtn("Combine Class", Icons.group, () {
                                      _showSubjectEditDialog(subject, isPermanent: false, isCombined: true);
                                      _dismissLongPressOverlay();
                                    }),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  )
                )
              ],
            ),
          ),
        )
    );
  }

  Widget _buildDropdowns<T>(String title, List<T> list, T? selectedValue, void Function(T?) onChanged) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              "$title",
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
                // onChanged: (value) {
                //   debugPrint("Selected Year: $value");
                //   setState(() {
                //     selectedValue = value!;
                //   });
                // },
                onChanged: onChanged,
                initialItem: selectedValue,
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildActionBtn(String title, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: Colors.white),
      label: Text(title, style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      )
    );
  }

  void _showSubjectEditDialog(SubjectModel subject, {required bool isPermanent, required bool isCombined}) {
    final nameController = TextEditingController(text: subject.name);
    final codeController = TextEditingController(text: subject.code);
    final deptController = TextEditingController(text: subject.dept);

    String displayName = subject.name;
    if (subject.name.contains("(Combined)")) {
      displayName += " (Combined)";
    } else if (subject.name.contains("(Arranged)")) {
      displayName += " (Arranged)";
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          "$displayName (${subject.code})",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: "Subject Name")),
            TextField(controller: codeController, decoration: InputDecoration(labelText: "Subject Code")),
            TextField(controller: deptController, decoration: InputDecoration(labelText: "Department(s)")),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text;
              final newCode = codeController.text;
              final newDept = deptController.text;

              // Avoid duplicating department
              final currentDepts = subject.dept.split(',').map((d) => d.trim()).toSet();
              currentDepts.addAll(newDept.split(',').map((d) => d.trim()));
              final combinedDept = currentDepts.join(', ');

              if (isPermanent) {
                await FirebaseFirestore.instance
                    .collection("timetable")
                    .doc(subject.id)
                    .update({
                  "name": newName,
                  "code": newCode,
                  "dept": combinedDept,
                });
              } else {
                await FirebaseFirestore.instance
                    .collection("timetable")
                    .doc(subject.id)
                    .update({
                  "name": "$newName${isCombined ? " (Combined)" : " (Arranged)"}",
                  "code": newCode,
                  "dept": isCombined ? combinedDept : newDept,
                  "lastTemporaryUpdate": DateTime.now().toIso8601String(),
                  "originalName": subject.name,
                  "originalDept": subject.dept,
                });
              }

              Navigator.pop(context);
              _fetchSubjectsForDay();
            },
            child: const Text("Update"),
          )
        ],
      )
    );
  }

  void _scheduleAutoDeactivation(String subjectId) async {
    await Future.delayed(Duration(minutes: 50));
    final doc = await FirebaseFirestore.instance.collection("timetable").doc(subjectId).get();

    // Only deactivate if still active
    if (doc.exists && doc['isActive'] == true) {
      FirebaseFirestore.instance.collection("timetable").doc(subjectId).update({"isActive": false});
      if (mounted) {
        _fetchSubjectsForDay();
      }
    }
  }
}
