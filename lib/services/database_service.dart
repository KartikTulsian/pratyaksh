import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iem_attendance_app/models/student_model.dart';
import 'package:iem_attendance_app/models/subject_model.dart';
import 'package:iem_attendance_app/models/teacher_model.dart';

class DatabaseService {
  final CollectionReference _usersCollection =
  FirebaseFirestore.instance.collection('users');

  final CollectionReference _timetableCollection =
  FirebaseFirestore.instance.collection('timetable');

  // ---------------------- STUDENTS ----------------------

  /// Get realtime stream of all students
  Stream<List<StudentModel>> getStudentStream() {
    return _usersCollection
        .where('role', isEqualTo: 'student')
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => StudentModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Add a new student
  Future<void> addStudent(StudentModel student) {
    return _usersCollection.add(student.toMap());
  }

  /// Update an existing student
  Future<void> updateStudent(StudentModel student) {
    return _usersCollection.doc(student.id).update(student.toMap());
  }

  /// Delete a student
  Future<void> deleteStudent(String id) {
    return _usersCollection.doc(id).delete();
  }

  /// Update student password
  Future<void> updateStudentPassword(
      StudentModel student, String newPassword) async {
    await _usersCollection.doc(student.id).update({'password': newPassword});
  }

  /// Update student face recognition data
  Future<void> updateStudentFaceData(
      String studentId, Map<String, String> faceUrls) async {
    print("Updating Firestore for student $studentId");
    print("Data being saved: faceData=$faceUrls, profileImage=${faceUrls['Look Front']}");

    await _usersCollection.doc(studentId).update({
      'faceData': faceUrls,
      'profileImage': faceUrls['Look Front'],
    });
  }

  // ---------------------- TEACHERS ----------------------

  /// Get realtime stream of all teachers
  Stream<List<TeacherModel>> getTeacherStream() {
    return _usersCollection
        .where('role', isEqualTo: 'teacher')
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => TeacherModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Add a new teacher
  Future<void> addTeacher(TeacherModel teacher) {
    return _usersCollection.add(teacher.toMap());
  }

  /// Update an existing teacher
  Future<void> updateTeacher(TeacherModel teacher) {
    return _usersCollection.doc(teacher.id).update(teacher.toMap());
  }

  /// Delete a teacher
  Future<void> deleteTeacher(String id) {
    return _usersCollection.doc(id).delete();
  }

  /// Update teacher password
  Future<void> updateTeacherPassword(
      TeacherModel teacher, String newPassword) async {
    await _usersCollection.doc(teacher.id).update({'password': newPassword});
  }

  // ---------------------- SUBJECTS ----------------------

  /// Get realtime stream of subjects by dept, year, semester, and day
  Stream<List<SubjectModel>> getSubjectsStream(
      {required String dept,
        required int year,
        required int semester,
        required String day}) {
    return _timetableCollection
        .where('dept', isEqualTo: dept)
        .where('year', isEqualTo: year)
        .where('semester', isEqualTo: semester)
        .where('day', isEqualTo: day)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) => SubjectModel.fromFirestore(doc)).toList();
    });
  }

  /// Add a new subject/period to timetable
  Future<void> addSubject(SubjectModel subject) {
    return _timetableCollection.doc(subject.id).set({
      'name': subject.name,
      'code': subject.code,
      'year': subject.year,
      'dept': subject.dept,
      'semester': subject.semester,
      'period': subject.period,
      'isActive': subject.isActive,
      'day': subject.day,
    });
  }

  /// Update an existing subject/period
  Future<void> updateSubject(SubjectModel subject) {
    return _timetableCollection.doc(subject.id).update({
      'name': subject.name,
      'code': subject.code,
      'year': subject.year,
      'dept': subject.dept,
      'semester': subject.semester,
      'period': subject.period,
      'isActive': subject.isActive,
      'day': subject.day,
    });
  }

  /// Delete a subject/period
  Future<void> deleteSubject(String id) {
    return _timetableCollection.doc(id).delete();
  }

  /// Toggle subject active/inactive
  Future<void> toggleSubjectActive(String id, bool isActive) {
    return _timetableCollection.doc(id).update({'isActive': isActive});
  }
}


