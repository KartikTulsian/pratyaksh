class AppUser {
  final String id;
  final String name;
  final String role;
  final String? dept;
  final String? enrollment;
  final int? year;
  final int? semester;

  AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.dept,
    this.enrollment,
    this.year,
    this.semester,
  });
}
