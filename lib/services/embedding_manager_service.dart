// import 'dart:io';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:http/http.dart' as http;
// import 'package:iem_attendance_app/services/face_embedding_service.dart';
//
// class EmbeddingManagerService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   /// Download image from URL to temporary file
//   Future<File> _downloadImageToTempFile(String url, String filenamePrefix) async {
//     final response = await http.get(Uri.parse(url));
//     if (response.statusCode != 200) {
//       throw Exception('Failed to download image: ${response.statusCode}');
//     }
//
//     final tempDir = Directory.systemTemp;
//     final file = File('${tempDir.path}/${filenamePrefix}_${DateTime.now().millisecondsSinceEpoch}.jpg');
//     await file.writeAsBytes(response.bodyBytes);
//     return file;
//   }
//
//   /// Generate embeddings for a specific user from their stored face URLs
//   Future<Map<String, List<double>>?> generateEmbeddingsForUser(String userId) async {
//     try {
//       // Get user document
//       final docSnap = await _firestore.collection('users').doc(userId).get();
//       if (!docSnap.exists) {
//         throw Exception('User not found');
//       }
//
//       final data = docSnap.data()!;
//       final faceData = (data['faceData'] ?? {}) as Map<String, dynamic>;
//
//       if (faceData.isEmpty) {
//         throw Exception('No face data found for user');
//       }
//
//       Map<String, List<double>> embeddingsMap = {};
//       List<File> tempFiles = [];
//
//       // Process each face angle
//       for (final entry in faceData.entries) {
//         final angle = entry.key;
//         final url = entry.value as String?;
//
//         if (url == null || url.isEmpty) continue;
//
//         try {
//           // Download image to temporary file
//           final tempFile = await _downloadImageToTempFile(url, '${userId}_$angle');
//           tempFiles.add(tempFile);
//
//           // Extract embedding
//           List<double>? embedding = await FaceEmbeddingService.extractEmbedding(tempFile);
//
//           if (embedding != null) {
//             embeddingsMap[angle] = embedding;
//             print('Generated embedding for $angle: ${embedding.length} dimensions');
//           }
//
//         } catch (e) {
//           print('Error processing $angle for user $userId: $e');
//         }
//       }
//
//       // Cleanup temporary files
//       for (final tempFile in tempFiles) {
//         try {
//           await tempFile.delete();
//         } catch (e) {
//           print('Error deleting temp file: $e');
//         }
//       }
//
//       return embeddingsMap.isNotEmpty ? embeddingsMap : null;
//
//     } catch (e) {
//       print('Error generating embeddings for user $userId: $e');
//       return null;
//     }
//   }
//
//   /// Store embeddings in Firestore for a user
//   Future<bool> storeEmbeddingsForUser(String userId, Map<String, List<double>> embeddings) async {
//     try {
//       await _firestore.collection('users').doc(userId).update({
//         'faceEmbeddings': embeddings,
//         'embeddingsGeneratedAt': FieldValue.serverTimestamp(),
//         'embeddingCount': embeddings.length,
//       });
//
//       print('Stored ${embeddings.length} embeddings for user $userId');
//       return true;
//     } catch (e) {
//       print('Error storing embeddings for user $userId: $e');
//       return false;
//     }
//   }
//
//   /// Generate and store embeddings for a specific user
//   Future<bool> generateAndStoreEmbeddingsForUser(String userId) async {
//     final embeddings = await generateEmbeddingsForUser(userId);
//     if (embeddings == null) return false;
//
//     return await storeEmbeddingsForUser(userId, embeddings);
//   }
//
//   /// Batch process: Generate embeddings for all users who have faceData but no embeddings
//   Future<void> generateEmbeddingsForAllUsers({String? role}) async {
//     try {
//       Query query = _firestore.collection('users');
//
//       if (role != null) {
//         query = query.where('role', isEqualTo: role);
//       }
//
//       // Get users who have faceData but no embeddings
//       final snapshot = await query
//           .where('faceData', isNotEqualTo: null)
//           .get();
//
//       int processedCount = 0;
//       int successCount = 0;
//
//       for (final doc in snapshot.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//
//         // Skip if embeddings already exist and are recent
//         if (data['faceEmbeddings'] != null && data['embeddingsGeneratedAt'] != null) {
//           print('Embeddings already exist for user ${doc.id}, skipping');
//           continue;
//         }
//
//         processedCount++;
//         print('Processing embeddings for user ${doc.id} (${data['name'] ?? 'Unknown'})');
//
//         bool success = await generateAndStoreEmbeddingsForUser(doc.id);
//         if (success) {
//           successCount++;
//         }
//
//         // Add a small delay to avoid overwhelming the system
//         await Future.delayed(const Duration(milliseconds: 500));
//       }
//
//       print('Batch processing complete: $successCount/$processedCount users processed successfully');
//     } catch (e) {
//       print('Error in batch processing: $e');
//     }
//   }
//
//   /// Load all embeddings for recognition (computes average embedding per user)
//   Future<Map<String, List<double>>> loadAllEmbeddingsForRecognition() async {
//     try {
//       final snapshot = await _firestore
//           .collection('users')
//           .where('faceEmbeddings', isNotEqualTo: null)
//           .get();
//
//       Map<String, List<double>> avgEmbeddings = {};
//
//       for (final doc in snapshot.docs) {
//         final data = doc.data();
//         final embeddingsData = data['faceEmbeddings'] as Map<String, dynamic>?;
//
//         if (embeddingsData != null && embeddingsData.isNotEmpty) {
//           // Convert to List<List<double>>
//           List<List<double>> userEmbeddings = [];
//
//           embeddingsData.forEach((angle, embeddingData) {
//             if (embeddingData is List) {
//               List<double> embedding = List<double>.from(embeddingData);
//               userEmbeddings.add(embedding);
//             }
//           });
//
//           if (userEmbeddings.isNotEmpty) {
//             // Compute average embedding
//             List<double> avgEmbedding = _computeAverageEmbedding(userEmbeddings);
//             avgEmbeddings[doc.id] = avgEmbedding;
//           }
//         }
//       }
//
//       return avgEmbeddings;
//     } catch (e) {
//       print('Error loading embeddings for recognition: $e');
//       return {};
//     }
//   }
//
//   /// Compute average embedding from multiple embeddings
//   List<double> _computeAverageEmbedding(List<List<double>> embeddings) {
//     if (embeddings.isEmpty) return [];
//
//     int embeddingSize = embeddings[0].length;
//     List<double> avgEmbedding = List.filled(embeddingSize, 0.0);
//
//     // Sum all embeddings
//     for (List<double> embedding in embeddings) {
//       for (int i = 0; i < embeddingSize; i++) {
//         avgEmbedding[i] += embedding[i];
//       }
//     }
//
//     // Divide by count to get average
//     for (int i = 0; i < embeddingSize; i++) {
//       avgEmbedding[i] /= embeddings.length;
//     }
//
//     // L2 normalize the average
//     return FaceEmbeddingService._l2Normalize(avgEmbedding);
//   }
//
//   /// Check if a user has embeddings
//   Future<bool> userHasEmbeddings(String userId) async {
//     try {
//       final docSnap = await _firestore.collection('users').doc(userId).get();
//       if (!docSnap.exists) return false;
//
//       final data = docSnap.data()!;
//       return data['faceEmbeddings'] != null;
//     } catch (e) {
//       return false;
//     }
//   }
//
//   /// Get embedding statistics
//   Future<Map<String, dynamic>> getEmbeddingStats() async {
//     try {
//       // Total users
//       final totalUsersSnap = await _firestore.collection('users').count().get();
//       final totalUsers = totalUsersSnap.count;
//
//       // Users with face data
//       final withFaceDataSnap = await _firestore
//           .collection('users')
//           .where('faceData', isNotEqualTo: null)
//           .count()
//           .get();
//       final withFaceData = withFaceDataSnap.count;
//
//       // Users with embeddings
//       final withEmbeddingsSnap = await _firestore
//           .collection('users')
//           .where('faceEmbeddings', isNotEqualTo: null)
//           .count()
//           .get();
//       final withEmbeddings = withEmbeddingsSnap.count;
//
//       return {
//         'totalUsers': totalUsers,
//         'usersWithFaceData': withFaceData,
//         'usersWithEmbeddings': withEmbeddings,
//         'pendingEmbeddings': withFaceData - withEmbeddings,
//       };
//     } catch (e) {
//       return {'error': e.toString()};
//     }
//   }
// }