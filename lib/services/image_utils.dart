// lib/services/image_utils.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

Future<File> downloadImageToTempFile(String url, String filenamePrefix) async {
  final resp = await http.get(Uri.parse(url));
  if (resp.statusCode != 200) throw Exception('Image download failed: ${resp.statusCode}');
  final ext = path.extension(Uri.parse(url).path).isNotEmpty ? path.extension(Uri.parse(url).path) : '.jpg';
  final file = File('${Directory.systemTemp.path}/${filenamePrefix}_${DateTime.now().millisecondsSinceEpoch}$ext');
  await file.writeAsBytes(resp.bodyBytes);
  return file;
}
