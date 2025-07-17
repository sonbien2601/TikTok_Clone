import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:path/path.dart' as p;

class UploadController {
  static Future<Response> uploadImageHandler(Request request) async {
    try {
      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.startsWith('multipart/form-data')) {
        return Response(400, body: jsonEncode({'error': 'Content-Type must be multipart/form-data.'}));
      }
      String? userId;
      List<int>? imageBytes;
      String? originalFileName;
      String? imageMimeType;
      final multipartRequest = request.multipart();
      if (multipartRequest == null) {
        return Response(400, body: jsonEncode({'error': 'Failed to parse multipart data'}));
      }
      await for (final part in multipartRequest.parts) {
        final contentDisposition = part.headers['content-disposition'];
        final contentTypeHeader = part.headers['content-type'];
        if (contentDisposition != null) {
          final params = _parseContentDisposition(contentDisposition);
          final partName = params['name'];
          final filename = params['filename'];
          if (partName == 'userId') {
            final bytes = await _readAllBytes(part);
            userId = utf8.decode(bytes);
          } else if (partName == 'imageFile') {
            originalFileName = filename;
            imageMimeType = contentTypeHeader;
            imageBytes = await _readAllBytes(part);
          } else {
            await _readAllBytes(part);
          }
        } else {
          await _readAllBytes(part);
        }
      }
      if (imageBytes == null || imageBytes.isEmpty) {
        return Response(400, body: jsonEncode({'error': 'Image file is required.'}));
      }
      // Tạo thư mục uploads nếu chưa tồn tại
      final uploadDir = Directory('uploads');
      if (!await uploadDir.exists()) {
        await uploadDir.create(recursive: true);
      }
      // Xác định extension
      String fileExtension = '.png';
      if (originalFileName != null && originalFileName.contains('.')) {
        fileExtension = p.extension(originalFileName).toLowerCase();
      } else if (imageMimeType != null) {
        if (imageMimeType.contains('jpeg')) fileExtension = '.jpg';
        else if (imageMimeType.contains('png')) fileExtension = '.png';
        else if (imageMimeType.contains('gif')) fileExtension = '.gif';
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '${userId ?? 'img'}_${timestamp}$fileExtension';
      final imagePath = p.join(uploadDir.path, uniqueFileName);
      final file = File(imagePath);
      await file.writeAsBytes(imageBytes);
      final imageUrl = '/uploads/$uniqueFileName';
      return Response.ok(jsonEncode({'imageUrl': imageUrl}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }
}

Map<String, String> _parseContentDisposition(String contentDisposition) {
  final params = <String, String>{};
  final parts = contentDisposition.split(';');
  for (var part in parts) {
    final sub = part.trim().split('=');
    if (sub.length == 2) {
      params[sub[0]] = sub[1].replaceAll('"', '');
    }
  }
  return params;
}

Future<List<int>> _readAllBytes(Stream<List<int>> stream) async {
  final bytes = <int>[];
  await for (final chunk in stream) {
    bytes.addAll(chunk);
  }
  return bytes;
} 