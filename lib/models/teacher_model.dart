import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherModel {
  final String id;
  final String name;
  final String enrollment;
  final String? password;

  TeacherModel({
    required this.id,
    required this.name,
    required this.enrollment,
    this.password,
  });

  factory TeacherModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final docId = doc.id;

    return TeacherModel(
      id: docId,
      name: data['name'],
      enrollment: data['enrollment'],
      password: data['password'],
    );
  }

  TeacherModel copyWith({bool? attended}) {
    return TeacherModel(
      name: this.name,
      enrollment: this.enrollment,
      id: this.id,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.isNotEmpty ? name : 'N/A',
      'enrollment': enrollment.isNotEmpty ? enrollment : 'N/A',
      if (password != null && password!.isNotEmpty) 'password': password,
    };
  }
}