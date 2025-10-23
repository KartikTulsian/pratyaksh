import 'dart:math';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iem_attendance_app/models/student_model.dart';
import 'package:iem_attendance_app/models/subject_model.dart';
import 'package:iem_attendance_app/widgets/timetable_gps_service.dart';
import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:iem_attendance_app/services/face_recognition_service.dart';
import 'package:permission_handler/permission_handler.dart';

// The class declaration remains the same
class FaceAttendanceScreen extends StatefulWidget {
  final StudentModel student;
  final SubjectModel subject;
  final SubjectGPSInfo activeSubjectInfo;

  const FaceAttendanceScreen({
    super.key,
    required this.student,
    required this.subject,
    required this.activeSubjectInfo,
  });

  @override
  State<FaceAttendanceScreen> createState() => _FaceAttendanceScreenState();
}

class _FaceAttendanceScreenState extends State<FaceAttendanceScreen> {
  // New and existing state variables
  CameraController? _cameraController;
  Position? _currentPosition;
  // List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isLoading = false; // New loading state for initial checks
  String _statusMessage = "Initializing..."; // Initial status
  Color _statusColor = Colors.blue; // New status color for UI feedback
  String _debugInfo = "";

  Color primary = const Color(0xFF765DBD);
  final LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF765DBD), Color(0xFF301B5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final FaceRecognitionService _faceRecognitionService = FaceRecognitionService();
  final TimetableGPSService _gpsService = TimetableGPSService();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing...';
      _statusColor = Colors.blue;
      _debugInfo = 'Starting initialization process...';
    });

    try {
      // 1. Check permissions and get location
      await _checkPermissionsAndGetLocation();
      await _initializeCamera();
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Initialization failed: $e';
          _statusColor = Colors.red;
          _debugInfo = 'Initialization failed: $e';
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkPermissionsAndGetLocation() async {
    final permission = await Permission.location.request();
    if (permission != PermissionStatus.granted) {
      throw Exception('Location permission denied');
    }
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = position;
    });
  }

  // Future<void> _checkForActiveSubjects() async {
  //   if (_currentPosition == null) return;
  //   try {
  //     final activeSubject = await _gpsService.getActiveGPSSubject(
  //       studentLatitude: _currentPosition!.latitude,
  //       studentLongitude: _currentPosition!.longitude,
  //       courseCode: widget.subject.code,
  //       year: widget.student.year,
  //       semester: widget.student.semester,
  //       dept: widget.student.dept,
  //     );
  //     setState(() {
  //       _activeSubject = activeSubject;
  //       if (activeSubject != null) {
  //         _statusMessage = 'Found active class: ${activeSubject.subjectName}\n'
  //             'Distance: ${activeSubject.distance.toStringAsFixed(1)}m from teacher.\n'
  //             'Ready to mark attendance!';
  //         _statusColor = Colors.green;
  //       } else {
  //         _statusMessage = 'No active classes found in your proximity.';
  //         _statusColor = Colors.orange;
  //       }
  //     });
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() {
  //         _statusMessage = 'Error checking for active classes: $e';
  //         _statusColor = Colors.red;
  //       });
  //     }
  //   }
  // }

  Future<void> _initializeCamera() async {
    try {
      final permission = await Permission.camera.request();
      if (permission != PermissionStatus.granted) {
        setState(() {
          _statusMessage = "Camera permission denied";
          _debugInfo = "Camera permission not granted";
        });
        return;
      }

      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        setState(() {
          _statusMessage = "No cameras available";
          _debugInfo = "No camera devices found on this device";
        });
        return;
      }

      CameraDescription selectedCamera = cameras.first;
      for (var camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          // Set initial status message based on whether an active class was found
          _statusMessage = 'Ready to mark attendance!';
          _statusColor = Colors.green;
          _debugInfo = 'Camera initialized. Student: ${widget.student.name}\nSubject: ${widget.activeSubjectInfo.subjectName}\nDistance: ${widget.activeSubjectInfo.distance.toStringAsFixed(1)}m';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Failed to initialize camera: $e";
        _statusColor = Colors.red;
        _debugInfo = "Camera initialization error: $e";
      });
    }
  }

  Future<File?> cropLargestFace(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableTracking: false,
      enableContours: false,
      enableLandmarks: false,
    );
    final detector = FaceDetector(options: options);
    final faces = await detector.processImage(inputImage);
    await detector.close();

    if (faces.isEmpty) return null;

    // pick largest face
    faces.sort((a, b) => b.boundingBox.width.compareTo(a.boundingBox.width));
    final rect = faces.first.boundingBox;

    // load & crop
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    // expand box a bit for safety
    final pad = (rect.width * 0.2).toInt();
    final x = max(0, rect.left.toInt() - pad);
    final y = max(0, rect.top.toInt() - pad);
    final w = min(decoded.width - x, rect.width.toInt() + 2 * pad);
    final h = min(decoded.height - y, rect.height.toInt() + 2 * pad);

    final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);

    // front camera mirror fix (you already do this later; keep it consistent)
    // if you already flipped earlier, remove duplication.
    final fixed = cropped; // or img.flipHorizontal(cropped);

    final outPath = '${imageFile.path}.face.jpg';
    final outFile = File(outPath)..writeAsBytesSync(img.encodeJpg(fixed, quality: 95));
    return outFile;
  }

  // Updated _captureAndVerify()
  Future<void> _captureAndVerify() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isProcessing) {
      print('Camera not ready or already processing');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = "Starting attendance check...";
      _debugInfo = "Capturing image...";
    });

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      final File capturedImage = File(imageFile.path);

      img.Image? rawImage = img.decodeImage(await capturedImage.readAsBytes());
      if (_cameraController!.description.lensDirection == CameraLensDirection.front) {
        rawImage = img.flipHorizontal(rawImage!);
        capturedImage.writeAsBytesSync(img.encodeJpg(rawImage));
      }

      final faceFile = await cropLargestFace(capturedImage);
      if (faceFile == null) {
        _showErrorDialog(AttendanceResult(
          success: false,
          reason: 'No face detected. Please center your face in the frame.',
          errorType: AttendanceErrorType.faceNotRecognized,
        ));
        return;
      }

      setState(() { _statusMessage = "Verifying location and face..."; });

      print('=== DEBUG INFO ===');
      print('Student ID: ${widget.student.id}');
      print('Student Name: ${widget.student.name}');
      print('Subject: ${widget.activeSubjectInfo.subjectName}');
      print('Position: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
      print('==================');

      final result = await _faceRecognitionService.markAttendanceWithFaceGps(
        studentId: widget.student.id,
        faceImage: faceFile,
        studentLatitude: _currentPosition!.latitude,
        studentLongitude: _currentPosition!.longitude,
        activeSubject: widget.activeSubjectInfo,
      );

      setState(() {
        _debugInfo = result.success
            ? "Verification successful! Attendance marked."
            : "Verification failed: ${result.reason}";
      });

      if (result.success) {
        _showSuccessDialog(result);
      } else {
        _showErrorDialog(result); // Pass the entire result object
      }

      await capturedImage.delete();
      await faceFile.delete();
    } catch (e) {
      if(mounted) {
        setState(() {
          _statusMessage = "System Error: ${e.toString()}";
          _statusColor = Colors.red;
        });
        _showErrorDialog(AttendanceResult(success: false, reason: "System Error: ${e.toString()}", errorType: AttendanceErrorType.system));
      }
    } finally {
      if(mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Updated to take the new AttendanceResult object
  void _showErrorDialog(AttendanceResult result) {
    IconData errorIcon;
    Color errorColor;
    String helpText;

    switch (result.errorType) {
      case AttendanceErrorType.noActiveSubject:
        errorIcon = Icons.location_off;
        errorColor = Colors.orange;
        helpText = 'Make sure you are within 2 meters of your teacher when they have activated attendance.';
        break;
      case AttendanceErrorType.faceNotRecognized:
        errorIcon = Icons.face_retouching_off;
        errorColor = Colors.red;
        helpText = 'Ensure good lighting, remove any face coverings, and look directly at the camera.';
        break;
      case AttendanceErrorType.faceVerificationFailed:
        errorIcon = Icons.security;
        errorColor = Colors.red;
        helpText = 'The face detected does not match your registered profile. Please ensure you are using your own account.';
        break;
      case AttendanceErrorType.duplicate:
        errorIcon = Icons.done_all;
        errorColor = Colors.blue;
        helpText = 'You have already marked attendance for this class today.';
        break;
      default:
        errorIcon = Icons.error;
        errorColor = Colors.red;
        helpText = 'Please try again or contact support if the problem persists.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(errorIcon, color: errorColor, size: 32),
            const SizedBox(width: 8),
            const Text('Attendance Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.reason),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb, color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      const Text('Suggestion', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(helpText, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (result.errorType == AttendanceErrorType.noActiveSubject)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Refresh'),
            ),
          if (result.errorType != AttendanceErrorType.duplicate)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Try Again'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Updated _showSuccessDialog()
  void _showSuccessDialog(AttendanceResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 8),
            Text('Attendance Marked!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your attendance has been successfully recorded.'),
            const SizedBox(height: 12),
            if (result.subjectInfo != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Subject: ${result.subjectInfo!.subjectName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Code: ${result.subjectInfo!.subjectCode}'),
                    Text('Day: ${result.subjectInfo!.day}, Period: ${result.subjectInfo!.period}'),
                    Text('Distance: ${result.subjectInfo!.distance.toStringAsFixed(1)}m from teacher'),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismisses the dialog
              Navigator.of(context).pop(true); // Pops the screen and returns 'true'
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handlePermissionDenied() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Camera Permission Required'),
        content: Text('Please enable camera permission in settings to use face recognition.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings(); // Opens app settings
            },
            child: Text('Settings'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Verify Face - ${widget.subject.name}"),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
          children: [
            Expanded(
                flex: 3,
                child: _isCameraInitialized && _cameraController != null
                    ? Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      child: CameraPreview(_cameraController!),
                    ),

                    Center(
                      child: Container(
                        width: 250,
                        height: 300,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _isProcessing
                                ? Colors.orange
                                : Colors.white,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(150),
                        ),
                      ),
                    ),
                    if (_isProcessing)
                      Container(
                        color: Colors.black.withOpacity(0.5),
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                  ],
                )
                    : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
            ),
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _isProcessing ? Colors.orange : Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    if (_isCameraInitialized && !_isProcessing)
                      ElevatedButton(
                        onPressed: _captureAndVerify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt),
                            SizedBox(width: 8),
                            Text(
                              'Capture & Verify',
                              style: TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      ),

                    if (_isProcessing) ...[
                      const SizedBox(height: 15),
                      const Text(
                        'Position your face within the oval frame\nand tap the button to verify',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            )
          ]
      ),
    );
  }
}