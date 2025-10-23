import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String id;
  final String name;
  final String enrollment;
  final String dept;
  final int year ;
  final int semester;
  final String? password;
  final String? profileImage;

  StudentModel({
    required this.id,
    required this.name,
    required this.enrollment,
    required this.dept,
    required this.year,
    required this.semester,
    this.password,
    this.profileImage,
  });

  factory StudentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final docId = doc.id;

    return StudentModel(
      id: docId,
      name: data['name'],
      enrollment: data['enrollment'],
      dept: data['dept'],
      year: data['year'],
      semester: data['semester'],
      password: data['password'],
      profileImage: data.containsKey('profileImage') ? data['profileImage'] : '',
    );
  }

  StudentModel copyWith({bool? attended}) {
    return StudentModel(
      name: this.name,
      enrollment: this.enrollment,
      dept: this.dept,
      year: this.year,
      id: this.id,
      semester: this.semester,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.isNotEmpty ? name : 'N/A',
      'enrollment': enrollment.isNotEmpty ? enrollment : 'N/A',
      'dept': dept.isNotEmpty ? dept : 'N/A',
      'year': year,
      'semester': semester,
      if (password != null && password!.isNotEmpty) 'password': password,
      if (profileImage != null && profileImage!.isNotEmpty) 'profileImage': profileImage,
    };
  }
}