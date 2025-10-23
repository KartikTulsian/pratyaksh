import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iem_attendance_app/services/attendance_service.dart';
import 'package:iem_attendance_app/services/face_embedding_service.dart';
import 'package:iem_attendance_app/widgets/timetable_gps_service.dart';

class FaceRecognitionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TimetableGPSService _gpsService = TimetableGPSService();
  final AttendanceService _attendanceService = AttendanceService();

  static const double FACE_SIMILARITY_THRESHOLD = 0.5;

  Future<AttendanceResult> markAttendanceWithFaceGps({
    required String studentId,
    required File faceImage,
    required double studentLatitude,
    required double studentLongitude,
    required SubjectGPSInfo activeSubject,
  }) async {
    try {
      print('=== Starting GPS + Face Recognition Attendance ===');
      print('Student ID: $studentId');
      print('Student Location: ($studentLatitude, $studentLongitude)');
      print('Using pre-validated active subject: ${activeSubject.subjectName}');

      // 1. Check if student already marked attendance for this subject
      if (await _attendanceService.isAttendanceMarked(userId: studentId, period: activeSubject.period)) {
        return AttendanceResult(
          success: false,
          reason: 'You have already marked attendance for ${activeSubject.subjectName}',
          errorType: AttendanceErrorType.duplicate,
        );
      }

      // 2. Face Recognition - Recognize the person
      // String? recognizedStudentId = await _recognizeFace(faceImage);
      print('Extracting face embedding from captured image...');

      final capturedEmbedding = await FaceEmbeddingService.extractEmbedding(faceImage);
      if (capturedEmbedding == null) {
        await _logAttendanceAttempt(
          studentId: studentId,
          subjectId: activeSubject.subjectId,
          success: false,
          reason: 'No face detected in the image',
          distance: activeSubject.distance,
        );

        return AttendanceResult(
          success: false,
          reason: 'Face not recognized. Please ensure good lighting and look directly at the camera.',
          errorType: AttendanceErrorType.faceNotRecognized,
        );
      }

      // 3. Verify the recognized face matches the claimed student

      print('Performing face recognition to identify the person...');
      String? recognizedStudentId = await _recognizeFace(capturedEmbedding);

      if (recognizedStudentId == null) {
        await _logAttendanceAttempt(
          studentId: studentId,
          subjectId: activeSubject.subjectId,
          success: false,
          reason: 'Face mismatch: claimed $studentId, recognized $recognizedStudentId',
          distance: activeSubject.distance,
        );

        return AttendanceResult(
          success: false,
          reason: 'Face verification failed. You are not authorized to mark attendance for this account.',
          errorType: AttendanceErrorType.faceVerificationFailed,
        );
      }

      // 4. CRITICAL: Verify the recognized face matches the claimed student
      if (recognizedStudentId != studentId) {
        await _logAttendanceAttempt(
          studentId: studentId,
          subjectId: activeSubject.subjectId,
          success: false,
          reason: 'Face verification failed: claimed $studentId, recognized $recognizedStudentId',
          distance: activeSubject.distance,
        );

        return AttendanceResult(
          success: false,
          reason: 'Face verification failed. You are not authorized to mark attendance for this account.',
          errorType: AttendanceErrorType.faceVerificationFailed,
        );
      }

      print('Face verification successful: recognized student matches claimed student');

      // final ok = await _verifyAgainstStudentEmbeddings(studentId, capturedEmbedding);
      // if (!ok) {
      //   return AttendanceResult(
      //     success: false,
      //     reason: 'Face verification failed. Please try again.',
      //     errorType: AttendanceErrorType.faceVerificationFailed,
      //   );
      // }

      // 5. Get student details for logging
      final studentDoc = await _firestore.collection('users').doc(studentId).get();
      final studentName = studentDoc.exists ? (studentDoc.data()?['name'] ?? 'Unknown') : 'Unknown';

      // 6. Record successful attendance
      print('Recording attendance using AttendanceService...');
      final attendanceSuccess = await _attendanceService.markAttendance(
        userId: studentId,
        subjectId: activeSubject.subjectId,
        period: activeSubject.period,
        status: 'present',
      );

      if (!attendanceSuccess) {
        return AttendanceResult(
          success: false,
          reason: 'Failed to record attendance in database. Please try again.',
          errorType: AttendanceErrorType.system,
        );
      }

      // 7. Update subject with student attendance
      await _gpsService.markStudentPresent(
        subjectId: activeSubject.subjectId,
        studentId: studentId,
      );

      // 8. Record additional GPS and face verification details
      await _recordVerificationDetails(
        studentId: studentId,
        studentName: studentName,
        activeSubject: activeSubject,
        studentLatitude: studentLatitude,
        studentLongitude: studentLongitude,
        similarity: _lastSimilarityScore, // Store the similarity score
      );

      // 9. Log successful attempt
      await _logAttendanceAttempt(
        studentId: studentId,
        subjectId: activeSubject.subjectId,
        success: true,
        reason: 'Face recognized and GPS verified',
        distance: activeSubject.distance,
      );

      print('Attendance marked successfully!');

      return AttendanceResult(
        success: true,
        reason: 'Attendance marked successfully for ${activeSubject.subjectName}',
        attendanceId: '${studentId}_${activeSubject.period}',
        subjectInfo: activeSubject,
      );

    } catch (e) {
      print('ERROR in GPS + Face attendance: $e');
      return AttendanceResult(
        success: false,
        reason: 'System error occurred. Please try again.',
        errorType: AttendanceErrorType.system,
      );
    }
  }

  Future<bool> _verifyAgainstStudentEmbeddings(String studentId, List<double> captured) async {
    final doc = await _firestore.collection('users').doc(studentId).get();
    if (!doc.exists) return false;

    final data = doc.data()!;
    final map = data['faceEmbeddings'] as Map<String, dynamic>?;
    if (map == null || map.isEmpty) return false;

    // collect all vectors
    final vectors = <List<double>>[];
    map.forEach((k, v) {
      if (v is List) {
        try {
          final vec = List<double>.from(v.map((e) => (e as num).toDouble()));
          if (vec.isNotEmpty) vectors.add(vec);
        } catch (_) {}
      }
    });
    if (vectors.isEmpty) return false;

    // average then normalize (you already have a helper)
    final enrolledAvg = FaceEmbeddingService.computeAverageEmbedding(vectors);

    // ensure captured is normalized already (it is in your pipeline)
    final sim = _cosineSimilarity(captured, enrolledAvg);
    print('cosine(sim) with enrolled avg = ${sim.toStringAsFixed(4)}');

    // pick a reasonable threshold; start with 0.45–0.55 and tune with your data
    const double COSINE_ACCEPT = 0.50;
    return sim >= COSINE_ACCEPT;
  }

  double? _lastSimilarityScore;

  /// Face Recognition - Returns the ID of the recognized person
  Future<String?> _recognizeFace(List<double> capturedEmbedding) async {
    try {
      print('=== Face Recognition Process ===');
      print('Searching for best matching user...');

      // Get all users with face embeddings
      final usersSnapshot = await _firestore.collection('users')
          .where('faceEmbeddings', isNotEqualTo: null)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        print('No users with face embeddings found');
        return null;
      }

      print('Found ${usersSnapshot.docs.length} users with face embeddings');

      String? bestMatchUserId;
      double highestSimilarity = 0.0;

      for (final userDoc in usersSnapshot.docs) {
        try {
          final userData = userDoc.data();
          final embeddingsData = userData['faceEmbeddings'] as Map<String, dynamic>?;

          if (embeddingsData == null || embeddingsData.isEmpty) {
            continue;
          }

          // Extract all valid embeddings for this user
          List<List<double>> validEmbeddings = [];

          embeddingsData.forEach((angle, embeddingData) {
            if (embeddingData is List) {
              try {
                List<double> storedEmbedding = List<double>.from(embeddingData.map((e) => (e as num).toDouble()));
                if (storedEmbedding.length == capturedEmbedding.length) {
                  validEmbeddings.add(storedEmbedding);
                }
              } catch (e) {
                print('Skipping invalid embedding for user ${userDoc.id}, angle $angle');
              }
            }
          });

          if (validEmbeddings.isEmpty) {
            print('No valid embeddings found for user ${userDoc.id}');
            continue;
          }

          // Compute average embedding for this user
          List<double> averageEmbedding = FaceEmbeddingService.computeAverageEmbedding(validEmbeddings);

          // Calculate cosine similarity with captured embedding
          double similarity = _cosineSimilarity(capturedEmbedding, averageEmbedding);

          print('User ${userDoc.id} (${userData['name'] ?? 'Unknown'}): similarity = ${similarity.toStringAsFixed(4)} (${validEmbeddings.length} embeddings averaged)');

          if (similarity > highestSimilarity) {
            highestSimilarity = similarity;
            bestMatchUserId = userDoc.id;
          }

        } catch (e) {
          print('ERROR processing user ${userDoc.id}: $e');
          continue;
        }
      }

      _lastSimilarityScore = highestSimilarity; // Store for logging

      print('=== Face Recognition Results ===');
      print('Highest similarity: ${highestSimilarity.toStringAsFixed(4)}');
      print('Similarity threshold: $FACE_SIMILARITY_THRESHOLD');
      print('Best match user ID: $bestMatchUserId');

      if (highestSimilarity >= FACE_SIMILARITY_THRESHOLD) {
        print('FACE RECOGNIZED: User $bestMatchUserId with similarity ${highestSimilarity.toStringAsFixed(4)}');
        return bestMatchUserId;
      } else {
        print('NO FACE RECOGNIZED: Highest similarity ${highestSimilarity.toStringAsFixed(4)} below threshold $FACE_SIMILARITY_THRESHOLD');
        return null;
      }

    } catch (e) {
      print('ERROR finding best matching user: $e');
      return null;
    }
  }

  Future<String?> _findBestMatchingUser(List<double> capturedEmbedding) async {
    try {
      print('=== Searching for Best Match ===');

      // Get all users with face embeddings
      final usersSnapshot = await _firestore.collection('users')
          .where('faceEmbeddings', isNotEqualTo: null)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        print('No users with face embeddings found');
        return null;
      }

      print('Found ${usersSnapshot.docs.length} users with face embeddings');

      String? bestMatchUserId;
      double highestSimilarity = 0.0;

      for (final userDoc in usersSnapshot.docs) {
        try {
          final userData = userDoc.data();
          final embeddingsData = userData['faceEmbeddings'] as Map<String, dynamic>?;

          if (embeddingsData == null || embeddingsData.isEmpty) {
            continue;
          }

          // Extract all valid embeddings for this user
          List<List<double>> validEmbeddings = [];

          embeddingsData.forEach((angle, embeddingData) {
            if (embeddingData is List) {
              try {
                List<double> storedEmbedding = List<double>.from(embeddingData);
                if (storedEmbedding.length == capturedEmbedding.length) {
                  validEmbeddings.add(storedEmbedding);
                }
              } catch (e) {
                // Skip invalid embeddings
                print('Skipping invalid embedding for user ${userDoc.id}, angle $angle');
              }
            }
          });

          if (validEmbeddings.isEmpty) {
            print('No valid embeddings found for user ${userDoc.id}');
            continue;
          }

          // Compute average embedding for this user
          List<double> averageEmbedding = FaceEmbeddingService.computeAverageEmbedding(validEmbeddings);

          // Calculate similarity with captured embedding
          double similarity = _cosineSimilarity(capturedEmbedding, averageEmbedding);

          print('User ${userDoc.id} (${userData['name'] ?? 'Unknown'}): similarity = ${similarity.toStringAsFixed(4)} (${validEmbeddings.length} embeddings averaged)');

          if (similarity > highestSimilarity) {
            highestSimilarity = similarity;
            bestMatchUserId = userDoc.id;
          }

        } catch (e) {
          print('ERROR processing user ${userDoc.id}: $e');
          continue;
        }
      }

      print('=== Face Recognition Results ===');
      print('Highest similarity: ${highestSimilarity.toStringAsFixed(4)}');
      print('Similarity threshold: $FACE_SIMILARITY_THRESHOLD');
      print('Best match user ID: $bestMatchUserId');

      if (highestSimilarity >= FACE_SIMILARITY_THRESHOLD) {
        print('FACE RECOGNIZED: User $bestMatchUserId');
        return bestMatchUserId;
      } else {
        print('NO FACE RECOGNIZED: Highest similarity ${highestSimilarity.toStringAsFixed(4)} below threshold $FACE_SIMILARITY_THRESHOLD');
        return null;
      }

    } catch (e) {
      print('ERROR finding best matching user: $e');
      return null;
    }
  }

  /// Record successful attendance in database
  Future<void> _recordVerificationDetails({
    required String studentId,
    required String studentName,
    required SubjectGPSInfo activeSubject,
    required double studentLatitude,
    required double studentLongitude,
    required double? similarity,
  }) async {
    try {
      final verificationData = {
        'studentId': studentId,
        'studentName': studentName,
        'subjectId': activeSubject.subjectId,
        'subjectName': activeSubject.subjectName,
        'subjectCode': activeSubject.subjectCode,
        'teacherId': activeSubject.teacherId,
        'year': activeSubject.year,
        'semester': activeSubject.semester,
        'dept': activeSubject.dept,
        'day': activeSubject.day,
        'period': activeSubject.period,
        'timestamp': FieldValue.serverTimestamp(),
        'studentLocation': {
          'latitude': studentLatitude,
          'longitude': studentLongitude,
        },
        'teacherLocation': {
          'latitude': activeSubject.teacherLatitude,
          'longitude': activeSubject.teacherLongitude,
        },
        'distance': activeSubject.distance,
        'verification': {
          'method': 'face_gps_combined',
          'faceRecognized': true,
          'proximityVerified': true,
          'similarityScore': similarity,
          'threshold': FACE_SIMILARITY_THRESHOLD,
        },
        'metadata': {
          'appVersion': '1.0.0',
          'platform': 'mobile',
        }
      };

      await _firestore.collection('verification_logs').add(verificationData);
      print('Verification details logged successfully');
    } catch (e) {
      print('ERROR logging verification details: $e');
    }
  }

  /// Log all attendance attempts (success and failure)
  Future<void> _logAttendanceAttempt({
    required String studentId,
    required String subjectId,
    required bool success,
    required String reason,
    required double distance,
  }) async {
    try {
      await _firestore.collection('attendance_attempts').add({
        'studentId': studentId,
        'subjectId': subjectId,
        'success': success,
        'reason': reason,
        'distance': distance,
        'timestamp': FieldValue.serverTimestamp(),
        'threshold': FACE_SIMILARITY_THRESHOLD,
      });
    } catch (e) {
      print('ERROR logging attendance attempt: $e');
    }
  }

  double _cosineSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      print('ERROR: Embedding length mismatch in cosine similarity');
      print('Embedding1 length: ${embedding1.length}');
      print('Embedding2 length: ${embedding2.length}');
      throw ArgumentError('Embeddings must have the same length');
    }

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }

    norm1 = sqrt(norm1);
    norm2 = sqrt(norm2);

    if (norm1 == 0.0 || norm2 == 0.0) {
      print('WARNING: Zero norm in cosine similarity calculation');
      return 0.0;
    }

    double similarity = dotProduct / (norm1 * norm2);
    return similarity;
  }
}

class AttendanceResult {
  final bool success;
  final String reason;
  final AttendanceErrorType? errorType;
  final String? attendanceId;
  final SubjectGPSInfo? subjectInfo;

  AttendanceResult({
    required this.success,
    required this.reason,
    this.errorType,
    this.attendanceId,
    this.subjectInfo,
  });
}

/// Enhanced Error types
enum AttendanceErrorType {
  noActiveSubject, // No active subject in proximity
  faceNotRecognized, // Face not recognized at all
  faceVerificationFailed, // Face recognized but doesn't match claimed student
  duplicate, // Already marked attendance
  system, // System error
}