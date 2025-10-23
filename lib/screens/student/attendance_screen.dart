import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iem_attendance_app/models/student_model.dart';
import 'package:iem_attendance_app/models/subject_model.dart';
import 'package:iem_attendance_app/services/auth_service.dart';
import 'package:iem_attendance_app/widgets/day_selector.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iem_attendance_app/services/firestore_service.dart';
import 'package:iem_attendance_app/widgets/subject_card.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {

  double screenHeight = 0;
  double screenWidth = 0;

  Color primary = const Color(0xFF765DBD);
  final LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF765DBD), Color(0xFF301B5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  String selectedDay = '';
  List<SubjectModel> subjects = [];
  // bool isDayActive = false;
  bool isLoading = true;
  Position? currentPosition;
  bool isLoadingLocation = false;

  StudentModel? currentStudent;

  String? year, dept, semester, enrollment;

  void initState() {
    super.initState();
    // _loadStudentInfo();
    _initializw();
  }

  Future<void> _initializw() async {
    await _loadStudentInfo(); // sets selectedDay
    if (selectedDay.isNotEmpty) {
      await _fetchData(); // now safe to call
    }
    await _checkAndRequestLocationPermission();
  }

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

  Future<void> _loadStudentInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    year = prefs.getString('year');
    dept = prefs.getString('dept');
    semester = prefs.getString('semester');
    enrollment = prefs.getString('enrollment');

    selectedDay = _getTodayDayName();

    debugPrint("📦 SharedPreferences loaded:");
    debugPrint("Year: $year, Dept: $dept, Semester: $semester, ID: $enrollment");
    debugPrint("Loaded -> Year: $year, Dept: $dept, Sem: $semester, Day: $selectedDay");

    if (year != null && dept != null && semester != null && enrollment != null) {
      currentStudent = await AuthService().getCurrentStudent();
      debugPrint("✅ Current student loaded: ${currentStudent?.name}");
      await _fetchData(); // fetch data first
    } else {
      debugPrint("X: ERROR: SharedPreferences values missing.");
    }
  }

  String _getTodayDayName() {
    final now = DateTime.now();
    return (now.weekday >= 6)
        ? ''  // Saturday (6) or Sunday (7)
        : ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'][now.weekday - 1];
  }

  Future<void> _fetchData() async {
    if (selectedDay.isEmpty) {
      setState(() {
        // isDayActive = false;
        subjects = [];
      });
      debugPrint("🚫 Weekend or no day selected. Skipping fetch.");
      return;
    }

    // final dayActive = await FirestoreService().isDayActive(selectedDay);

    if (year != null && dept != null && semester != null && enrollment != null) {

      setState(() {
        isLoading = true;
      });

      final fetchedSubjects = await FirestoreService().getSubjectsForDay(
        year: year!,
        dept: dept!,
        semester: semester!,
        day: selectedDay,
        enrollment: enrollment!,
      );

      // fetchedSubjects.sort((a,b) => a.period.compareTo(b.period));

      setState(() {
        subjects = fetchedSubjects;
        // isDayActive = fetchedSubjects.isNotEmpty;
        isLoading = false;
      });
    }
  }

  void _onDaySelected(String day) {
    setState(() {
      selectedDay = day;
    });
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    screenHeight = MediaQuery
        .of(context)
        .size
        .height;
    print("🔄 Building StudentAttendanceScreen...");
    return Scaffold(
      appBar: AppBar(
        title: const Text("Time Table"),
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
            icon: Icon(Icons.refresh),
            tooltip: "Refresh Attendance",
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              _fetchData();
              //refresh attendance
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            DaySelecter(
              selectedDay: selectedDay,
              onDaySelected: _onDaySelected,
            ),
            const Divider(),

            if (selectedDay.isEmpty && subjects.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      "No classes today (Weekend)",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              )
            else if (currentStudent == null)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Builder(
                builder: (_) {
                  if (subjects.isEmpty) {
                    debugPrint("🗂️ Subjects in UI: ${subjects.length}");
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text("No Subjects scheduled.")),
                    );
                  } else {
                    debugPrint("🗂️ Subjects in UI: ${subjects.length}");
                    return Column(
                      children: subjects.map((subject) {
                        debugPrint("🧩 Subject in UI: ${subject.name}, attended: ${subject.attended}");
                        return SubjectCard(subject: subject, enrollment: enrollment!, student: currentStudent!, onRefresh: _fetchData, currentPosition: currentPosition);
                      }).toList(),
                    );
                  }
                },
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primary,
        icon: const Icon(Icons.my_location, color: Colors.white),
        label: const Text("Relocate", style: TextStyle(color: Colors.white)),
        onPressed: () async {
          await _getCurrentLocation();
        },
      ),
    );
  }
}
