import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:iem_attendance_app/services/face_embedding_service.dart';
import 'package:image_picker/image_picker.dart';
import '../models/student_model.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'dart:typed_data';

class FaceRegistration extends StatefulWidget {
  final StudentModel student;
  const FaceRegistration({super.key, required this.student});

  @override
  State<FaceRegistration> createState() => _FaceRegistrationState();
}

class _FaceRegistrationState extends State<FaceRegistration> {

  final ImagePicker _picker = ImagePicker();
  late FaceDetector _faceDetector;

  File? _pickedFaceImage;
  String? _uploadedProfileImageUrl;

  File? _currentFile;
  List<Face> _faces = [];
  bool _isDetecting = false;
  bool _isUploading = false;
  bool _isGeneratingEmbeddings = false;

  final List<String> _angles = ["Look Front", "Look Left", "Look Right", "Look Up", "Look Down"];
  // final String _angle = "Look Front";
  File? _faceImage;
  int _currentIndex = 0;
  Map<String, File> _faceImages = {};

  @override
  void initState() {
    super.initState();

    _uploadedProfileImageUrl = widget.student.profileImage;

    final options = FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
    );
    _faceDetector = FaceDetector(options: options);

    // Initialize the embedding service
    _initializeEmbeddingService();
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initializeEmbeddingService() async {
    bool success = await FaceEmbeddingService.initialize();

    if (!success) {
      _showMsg("❌ Embedding service initialization failed.");
    }
  }

  // String get currentAngle => _angles[_currentIndex];

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80);

    if (picked == null) return;

    setState(() {
      // _pickedFaceImage = File(picked.path);
      _currentFile = File(picked.path);
    });

    await _detectFace();
  }

  Future<void> _detectFace() async {
    if (_currentFile == null) return;

    setState(() => _isDetecting = true);

    final inputImage = InputImage.fromFile(_currentFile!);
    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      _showMsg("❌ No face detected. Try again.");
      setState(() => _isDetecting = false);
      return;
    }

    final face = faces.reduce((a,b) =>
        a.boundingBox.width * a.boundingBox.height >
        b.boundingBox.width * b.boundingBox.height
        ? a
        : b
    );

    double? yaw = face.headEulerAngleY; // Left (-) / Right (+)
    double? pitch = face.headEulerAngleX; // Up (+) / Down (-)
    String expected = _angles[_currentIndex];
    bool isValid = false;

    if (yaw != null && pitch != null) {
      switch (expected) {
        case "Look Front":
          isValid = yaw.abs() < 10 && pitch.abs() < 10;
          break;
        case "Look Left":
          isValid = yaw < -15;
          break;
        case "Look Right":
          isValid = yaw > 15;
          break;
        case "Look Down":
          isValid = pitch < -10;
          break;
        case "Look Up":
          isValid = pitch > 10;
          break;
      }
    }

    if (!isValid) {
      _showMsg("❌ Please redo. Angle not matching: $expected");

      setState(() {
        _isDetecting = false;
        _currentFile = null;
      });

      return;
    }

    final bytes = await _currentFile!.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      _showMsg("❌ Failed to decode image.");
      setState(() => _isDetecting = false);
      return;
    }

    final faceRect = face.boundingBox;

    final cropped = img.copyCrop(
      decoded,
      x: faceRect.left.toInt().clamp(0, decoded.width - 1),
      y: faceRect.top.toInt().clamp(0, decoded.height - 1),
      width: faceRect.width.toInt().clamp(1, decoded.width),
      height: faceRect.height.toInt().clamp(1, decoded.height),
    );
    
    final croppedFile =
        await File ("${_currentFile!.parent.path}/${_angles[_currentIndex]}.jpg")
            .writeAsBytes(img.encodeJpg(cropped));

    // final croppedFile = await File(
    //     "${_currentFile!.parent.path}/$_angle.jpg")
    //     .writeAsBytes(img.encodeJpg(cropped));
    
    // setState(() {
    //   _faceImages[currentAngle] = croppedFile;
    //   _currentFile = null;
    //
    //   if (_faceImages.length < _angles.length) {
    //     _currentIndex = _angles.indexWhere((a) => !_faceImages.containsKey(a));
    //   }
    // });
    //
    // _showMsg("✅ Face captured for $currentAngle");

    setState(() {
      _faceImages[_angles[_currentIndex]] = croppedFile;
      _currentFile = null;
      _isDetecting = false;

      if (_currentIndex < _angles.length - 1) {
        _currentIndex++;
      }
    });

    _showMsg("✅ Face captured for ${_angles[_currentIndex]}");
  }

  Future<File> _downloadImageToTempFile(String url, String filenamePrefix) async {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) throw Exception('Image download failed: ${response.statusCode}');

    final tempDir = Directory.systemTemp;
    // final ext = path.extension(Uri.parse(url).path).isNotEmpty ? path.extension(Uri.parse(url).path) : '.jpg';
    final file = File('${tempDir.path}/${filenamePrefix}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }
  
  Future<void> _generateAndStoreEmbeddings(String userId, Map<String, String> faceUrls) async {
    setState(() => _isGeneratingEmbeddings = true);
    
    try {
      _showMsg("🔄 Generating face embeddings...");

      Map<String, List<double>> embeddingsMap = {};
      List<File> tempFiles = [];

      for (final entry in faceUrls.entries) {
        final angle = entry.key;
        final url = entry.value;

        try {
          final tempFile = await _downloadImageToTempFile(url, '${userId}_$angle');
          tempFiles.add(tempFile);

          List<double>? embedding = await FaceEmbeddingService.extractEmbedding(tempFile);

          if (embedding != null) {
            embeddingsMap[angle] = embedding;
            print("Generated embedding for $angle; ${embedding.length} dimensions");
          } else {
            print("Failed to generate embedding for $angle");
          }
        } catch (e) {
          print('Error processing $angle for $userId: $e');
        }
      }

      if (embeddingsMap.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'faceEmbeddings': embeddingsMap,
          'embeddingsGeneratedAt': FieldValue.serverTimestamp(),
          'embeddingCount': embeddingsMap.length,
        });

        _showMsg("🎉 Face embeddings generated and stored successfully!");
        print('Stored ${embeddingsMap.length} embeddings for user $userId');
      } else {
        _showMsg("❌ No embeddings generated.");
      }

      for (final tempFile in tempFiles) {
        try {
          await tempFile.delete();
        } catch (e) {
          print('Error deleting temp file: $e');
        }
      }

    } catch (e) {
      _showMsg("❌ Failed to generate embeddings: $e");
      print('Error in _generateAndStoreEmbeddings: $e');
    } finally {
      setState(() => _isGeneratingEmbeddings = false);
    }
  }

  Future<void> _uploadFaces() async {
    if (_faceImages.length < _angles.length) {
      _showMsg("⚠ Please capture all face angles first.");
      return;
    }

    // if (_faceImage == null) {
    //   _showMsg("⚠ Please capture the face first.");
    //   return;
    // }

    debugPrint("Uploading file: ${_pickedFaceImage?.path ?? _faceImage?.path}");

    setState(() => _isUploading = true);

    try {

      Map<String, String> urls = {};

      // final ref = FirebaseStorage.instance
      //     .ref()
      //     .child("faces/${widget.student.id}_$_angle.jpg");
      //
      // final metadata = SettableMetadata(contentType: "image/jpeg");
      //
      // UploadTask uploadTask = ref.putFile(_pickedFaceImage ?? _faceImage!, metadata);
      //
      // TaskSnapshot snapshot = await uploadTask.whenComplete(() {});
      // final url = await snapshot.ref.getDownloadURL();
      
      for (final angle in _angles) {
        final faceFile = _faceImages[angle];
        if (faceFile == null) continue;


        final ref = FirebaseStorage.instance
            .ref()
            .child("faces/${widget.student.id}_$angle.jpg");

        final metadata = SettableMetadata(contentType: "image/jpeg");

        // UploadTask uploadTask = ref.putFile(faceFile, metadata);
        // TaskSnapshot snapshot = await uploadTask.whenComplete(() {});
        final snapshot = await ref.putFile(faceFile, metadata);
        urls[angle] = await snapshot.ref.getDownloadURL();
      }

      //
      // await FirebaseFirestore.instance
      //     .collection("users")
      //     .doc(widget.student.id)
      //     .set({
      //   "faceData": {_angle: url},
      //   "profileImage": url,
      // }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.student.id)
          .set({
        // "faceData": urls, // store map of all angles
        // "profileImage": urls["Look Front"], // default dp

        "faceData": urls, // only one angle
        "profileImage": urls["Look Front"] ?? "",
        "faceRegisteredAt": FieldValue.serverTimestamp(),

      }, SetOptions(merge: true));

      setState(() {
        _uploadedProfileImageUrl = urls["Look Front"]; // Update preview
        // _pickedFaceImage = null;
        _faceImages.clear();
        _currentIndex = 0;
      });

      _showMsg("🎉 Face Registration Completed!");

      await _generateAndStoreEmbeddings(widget.student.id, urls);

      // Navigator.pop(context, urls["Look Front"]);
      Navigator.pop(context, _uploadedProfileImageUrl);

    } catch (e) {
      _showMsg("❌ Upload failed: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Face Registration"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Step ${_faceImages.length + 1}/${_angles.length}: ${_angles[_currentIndex]}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            // const Text("Step 1/1: Look Front",
            //     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            Container(
              height: 220,
              width: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
              ),
              child: _currentFile != null
                  ? ClipOval(child: Image.file(_currentFile!, fit: BoxFit.cover))
                  : _faceImages[_angles[_currentIndex]] != null
                    ? ClipOval(child: Image.file(_faceImages[_angles[_currentIndex]]!, fit: BoxFit.cover))
                    : _uploadedProfileImageUrl != null && _uploadedProfileImageUrl!.isNotEmpty
                      ? ClipOval(child: Image.network(_uploadedProfileImageUrl!, fit: BoxFit.cover))
                      : const Icon(Icons.person, size: 120, color: Colors.black54),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _currentIndex > 0 ? () => setState(() => _currentIndex--) : null,
                  child: const Text("Previous"),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _currentIndex < _angles.length - 1 ? () => setState(() => _currentIndex++) : null,
                  child: const Text("Next"),
                ),
              ],
            ),

            if (_isDetecting) const Padding(
              padding: EdgeInsets.only(top: 16),
              child: CircularProgressIndicator(),
            ),

            const SizedBox(height: 20),

            // Pick buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Camera"),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Gallery"),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),

            const SizedBox(height: 30),

            Wrap(
              spacing: 10,
              children: _faceImages.entries.map((e) {
                return Column(
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 13)),
                    Image.file(e.value, width: 60, height: 60, fit: BoxFit.cover),
                  ],
                );
              }).toList(),
            ),

            // if (_faceImage != null)
            //   Column(
            //     children: [
            //       Text(_angle, style: const TextStyle(fontSize: 13)),
            //       Image.file(_faceImage!, width: 80, height: 80,
            //           fit: BoxFit.cover),
            //     ],
            //   ),

            const SizedBox(height: 40),

            // Upload button
            // _isUploading
            //     ? const CircularProgressIndicator()
            //     : ElevatedButton.icon(
            //   icon: const Icon(Icons.cloud_upload),
            //   label: const Text("Submit Face Data"),
            //   onPressed: _uploadFaces,
            // ),

            if (_isUploading || _isGeneratingEmbeddings)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  Text(
                    _isUploading ? "Uploading..." : "Generating embeddings...",
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload),
                onPressed: _uploadFaces,
                label: const Text("Submit Face Data"),
              )
          ],
        ),
      ),
    );
  }
}
