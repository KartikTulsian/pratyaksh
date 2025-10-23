import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iem_attendance_app/models/student_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _secureStorage = FlutterSecureStorage();
  static const _tokenKey = 'app_jwt_token';

  //Login with enrollment no and password
  Future<String?> loginWithEnrollment(String enrollmentNo, String password) async {
    try {
      final snap = await _firestore
          .collection("users")
          .where("enrollment", isEqualTo: enrollmentNo)
          .get();

      if (snap.docs.isEmpty) return "User not found";

      final doc = snap.docs[0];
      final data = doc.data();

      if (data['password'] != password) return "Password Incorrect";

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("id", doc.id);
      await prefs.setString("role", doc['role']);
      await prefs.setString("name", doc['name']);

      if (data['role'] == 'student') {
        await prefs.setString("year", doc['year'].toString());
        await prefs.setString("semester", doc['semester'].toString());
        await prefs.setString("dept", doc['dept']);
        await prefs.setString("enrollment", data['enrollment']);
      } else if (data['role'] == 'teacher') {
        await prefs.setString("enrollment", data['enrollment']);
      } else if (data['role'] == 'admin') {
        await prefs.setString("enrollment", data['enrollment']);
      }

      return null; // null means success
    } catch (e) {
      return "Login Failed: ${e.toString()}";
    }
  }

  //get role from firestore
  // Future<String?> getRole(String uid) async {
  //   try {
  //     final doc = await _firestore.collection('users').doc(uid).get();
  //     return doc.data()?['role'];
  //   } catch (e) {
  //     throw Exception('Failed to get role');
  //   }
  // }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<StudentModel?> getCurrentStudent() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString("id");
    if (id == null) return null;

    final doc = await _firestore.collection("users").doc(id).get();
    if (!doc.exists) return null;

    return StudentModel.fromFirestore(doc);
  }

  Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("role");
  }

  Future<String?> getSavedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("id");
  }

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _secureStorage.read(key: _tokenKey);
  }
}