import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectModel {
  final String id;
  final String name;
  final String code;
  final int year;
  final String dept;
  final int semester;
  final int period;
  final bool isActive;
  final String day;
  final bool attended;

  SubjectModel ( {
    required this.id,
    required this.name,
    required this.code,
    required this.year,
    required this.dept,
    required this.semester,
    required this.period,
    this.isActive = false,
    required this.day,
    this.attended = false,
  });

  factory SubjectModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final docId = doc.id;
    return SubjectModel(
      id: docId,
      name: data['name'],
      code: data['code'],
      year: data['year'],
      dept: data['dept'],
      semester: data['semester'],
      period: data['period'],
      isActive: data['isActive'] ?? true,
      day: data['day'],
    );
  }

  SubjectModel copyWith({bool? attended, bool? isActive}) {
    return SubjectModel(
      name: this.name,
      code: this.code,
      period: this.period,
      dept: this.dept,
      year: this.year,
      semester: this.semester,
      id: this.id,
      day: this.day,
      isActive: isActive ?? this.isActive,
      attended: attended ?? this.attended,
    );
  }
}