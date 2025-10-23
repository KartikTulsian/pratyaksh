import 'package:flutter/material.dart';
import 'package:iem_attendance_app/models/teacher_model.dart';
import 'package:iem_attendance_app/services/database_service.dart';
import 'package:iem_attendance_app/widgets/create_teacher.dart';
import 'package:iem_attendance_app/widgets/update_teacher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AllTeachersScreen extends StatefulWidget {
  const AllTeachersScreen({super.key});

  @override
  State<AllTeachersScreen> createState() => _AllTeachersScreenState();
}

class _AllTeachersScreenState extends State<AllTeachersScreen> {
  String role = '';
  List<TeacherModel> teachers = [];
  List<TeacherModel> filteredTeachers = [];
  TextEditingController searchController = TextEditingController();

  Color primary = const Color(0xFF765DBD);
  final LinearGradient primaryGradient = const LinearGradient(
    colors: [Color(0xFF765DBD), Color(0xFF301B5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    loadRole();
    searchController.addListener(_applyFilters);
  }

  Future<void> loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      role = prefs.getString('role') ?? '';
    });
  }

  void _applyFilters() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredTeachers = teachers.where((teacher) {
        return query.isEmpty ||
            teacher.name.toLowerCase().contains(query) ||
            teacher.enrollment.toLowerCase().contains(query);
      }).toList();
    });
  }

  Widget _highlightMatch(String source, String query) {
    final matchIndex = source.toLowerCase().indexOf(query.toLowerCase());
    if (matchIndex == -1) return Text(source);

    final beforeMatch = source.substring(0, matchIndex);
    final match = source.substring(matchIndex, matchIndex + query.length);
    final afterMatch = source.substring(matchIndex + query.length);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: beforeMatch, style: const TextStyle(color: Colors.black)),
          TextSpan(
            text: match,
            style: TextStyle(
              color: Colors.deepPurple,
              backgroundColor: Colors.yellow.shade200,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: afterMatch, style: const TextStyle(color: Colors.black)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = searchController.text;

    return Scaffold(
      appBar: AppBar(
        title: const Text("All Teachers"),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: StreamBuilder<List<TeacherModel>>(
        stream: DatabaseService().getTeacherStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading teachers"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          teachers = snapshot.data!;
          teachers.sort((a, b) => a.name.compareTo(b.name));
          filteredTeachers = teachers.where((teacher) {
            return query.isEmpty ||
                teacher.name.toLowerCase().contains(query) ||
                teacher.enrollment.toLowerCase().contains(query);
          }).toList();

          return Column(
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(11.0),
                  child: Row(
                    children: [
                      Icon(Icons.groups, color: primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Total Teachers: ${filteredTeachers.length}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search by Name, Enrollment',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: filteredTeachers.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_off, size: 80, color: Colors.grey[400]),
                      Text("No matching results",
                          style: TextStyle(fontSize: 18, color: Colors.grey[700])),
                    ],
                  ),
                )
                    : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filteredTeachers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final teacher = filteredTeachers[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          _showTeacherDialog(teacher);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person, color: primary, size: 20),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: query.isNotEmpty
                                        ? _highlightMatch(teacher.name, query)
                                        : Text(teacher.name,
                                        style: const TextStyle(
                                            color: Colors.black, fontSize: 15)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.badge, color: primary, size: 20),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: query.isNotEmpty
                                        ? _highlightMatch(
                                        "Enrollment: ${teacher.enrollment}", query)
                                        : Text("Enrollment: ${teacher.enrollment}",
                                        style: const TextStyle(color: Colors.black54)),
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateTeacherScreen()),
          );
        },
        label: const Text("Add Teacher"),
        icon: const Icon(Icons.person_add),
      ),
    );
  }

  void _showTeacherDialog(TeacherModel teacher) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Teacher Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: "Update",
                          onPressed: () {
                            Navigator.pop(context); // close the details dialog first
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UpdateTeacherScreen(teacher: teacher),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: "Delete",
                          onPressed: () async {
                            await DatabaseService().deleteTeacher(teacher.id);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Teacher deleted")),
                            );
                          },
                        ),
                      ],
                    )
                  ],
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(teacher.name),
                  subtitle: const Text("Name"),
                ),
                ListTile(
                  leading: const Icon(Icons.badge),
                  title: Text(teacher.enrollment),
                  subtitle: const Text("Enrollment"),
                ),
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: Text("••••••"), // hide actual password
                  subtitle: const Text("Password"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUpdateDialog(TeacherModel teacher) {
    final nameController = TextEditingController(text: teacher.name);
    final enrollmentController = TextEditingController(text: teacher.enrollment);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Update Teacher"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: enrollmentController,
                decoration: const InputDecoration(labelText: "Enrollment"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final updated = TeacherModel(
                  id: teacher.id,
                  name: nameController.text.trim(),
                  enrollment: enrollmentController.text.trim(),
                  password: teacher.password,
                );
                await DatabaseService().updateTeacher(updated);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Teacher updated")),
                );
              },
              child: const Text("Save"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

}
