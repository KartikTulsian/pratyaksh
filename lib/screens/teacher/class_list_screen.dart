import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iem_attendance_app/models/subject_model.dart';
import 'package:iem_attendance_app/models/teacher_model.dart';
import 'package:iem_attendance_app/widgets/timetable_gps_service.dart';
import 'package:permission_handler/permission_handler.dart';

class ClassListScreen extends StatefulWidget {
  final void Function(SubjectModel subject)? onSubjectSelected;
  final TeacherModel teacher;


  const ClassListScreen({super.key, this.onSubjectSelected, required this.teacher});

  @override
  State<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> with AutomaticKeepAliveClientMixin{

  @override
  bool get wantKeepAlive => true;

  double screenHeight = 0;
  double screenWidth = 0;

  Color primary = const Color(0xFF765DBD);
  final LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF765DBD), Color(0xFF301B5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final TimetableGPSService _gpsService = TimetableGPSService();

  List<int> yearList = [1, 2, 3, 4];
  List<int> semList = [1, 2, 3, 4, 5, 6, 7, 8];
  List<String> deptList = ["CSE", "IT", "IOT", "IOTCSBT", "CSE(AIML)", "CSE(AI)", "CSBS", "ECE", "EEE", "ME", "CE"];
  List<String> dayList = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];

  int? selectedYear;
  int? selectedSemester;
  String? selectedDept;
  String? selectedDay;

  List<SubjectModel> subjects = [];
  bool isLoading = false;
  Position? currentPosition;
  bool isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _checkAndRequestLocationPermission();
  }

  Future<void> _checkAndRequestLocationPermission() async {
    if (isLoadingLocation) return;
    setState(() {
      isLoadingLocation = true;
      currentPosition = null;
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

  Future<void> _fetchSubjects() async {
    if (selectedYear == null || selectedSemester == null || selectedDept == null || selectedDay == null) return;

    setState(() {
      isLoading = true;
      subjects = [];
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection("timetable")
          .where("year", isEqualTo: selectedYear)
          .where("semester", isEqualTo: selectedSemester)
          .where("day", isEqualTo: selectedDay)
          .get();

      print("📚 Fetched ${snap.docs.length} timetable documents");

      final now = DateTime.now();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      for (var doc in snap.docs) {
        final data = doc.data();
        if (data.containsKey("lastTemporaryUpdate")) {
          final lastUpdate = DateTime.tryParse(data["lastTemporaryUpdate"]);
          final isTemporary = (data["name"] as String).contains("(Arranged)") || (data["name"] as String).contains("(Combined)");

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

      print("✅ Filtered subjects: ${fetchedSubjects.length}");

      setState(() {
        subjects = fetchedSubjects;
        isLoading = false;
      });
    } catch (e) {
      print("❌ Error fetching subjects: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateSubjectActivation(String id, bool isActive) async {
    print("🔄 Updating subject activation: $id, active: $isActive");

    try {
      if (isActive) {
        // Activating GPS attendance
        if (currentPosition == null) {
          await _getCurrentLocation();
          if (currentPosition == null) {
            throw Exception('Location is not available. Please refresh your location first.');
          }
        }

        print("📍 Using position: ${currentPosition!.latitude}, ${currentPosition!.longitude}");
        print("👨‍🏫 Teacher ID: ${widget.teacher.id}");

        final success = await _gpsService.activateGPSAttendance(
          subjectId: id,
          teacherId: widget.teacher.id,
          latitude: currentPosition!.latitude,
          longitude: currentPosition!.longitude,
        );

        if (success) {
          print("✅ GPS attendance activated successfully");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("✅ GPS attendance activated successfully!"),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          throw Exception('Failed to activate GPS attendance via service.');
        }

      } else {
        // Deactivating GPS attendance
        print("🔄 Deactivating GPS attendance...");
        final success = await _gpsService.deactivateGPSAttendance(id);

        if (success) {
          print("✅ GPS attendance deactivated successfully");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("📍 GPS attendance deactivated"),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          throw Exception('Failed to deactivate GPS attendance via service.');
        }
      }

      // Update local state after successful Firestore operation
      if(mounted) {
        setState(() {
          subjects = subjects.map((s) {
            if (s.id == id) return s.copyWith(isActive: isActive);
            return s;
          }).toList();
        });
      }
    } catch (e) {
      print("❌ Error updating subject activation: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed to ${isActive ? 'activate' : 'deactivate'} GPS attendance: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
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
            icon: Icon(currentPosition != null ? Icons.location_on : Icons.location_off),
            onPressed: _getCurrentLocation,
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentPosition != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(8),
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Location ready for GPS attendance',
                      style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(8),
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_off, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Location required for GPS attendance. Tap refresh.',
                        style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

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
              onPressed: _fetchSubjects,
              icon: const Icon(
                Icons.search,
                color: Colors.white,
              ),
              label: const Text("Fetch Subjects"),
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
                      : ListView.builder(
                  itemCount: subjects.length,
                  itemBuilder: (context, index) {
                    final subject = subjects[index];

                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: GestureDetector(
                        onTap: () {
                          if (widget.onSubjectSelected != null) {
                            widget.onSubjectSelected!(subject);
                          }
                        },
                        child: Card(
                          child: ListTile(
                            title: Text(
                              "${subject.name} (${subject.code})",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text("Period: ${subject.period}, Day: ${subject.day}"),
                            trailing: Switch(
                              value: subject.isActive,
                              activeColor: Colors.green[400],
                              onChanged: (value) {
                                _updateSubjectActivation(subject.id, value);
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                )
            )
          ],
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
}
