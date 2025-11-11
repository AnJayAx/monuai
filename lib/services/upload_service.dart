import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;

class UploadResult {
  final bool ok;
  final int statusCode;
  final String? body;

  const UploadResult({required this.ok, required this.statusCode, this.body});
}

class UploadService {
  /// Uploads an image file to the given [uploadUrl] using multipart/form-data.
  ///
  /// Fields sent:
  /// - landmark: String
  /// - capturedAt: ISO-8601 UTC string
  /// - filename: original filename (best-effort)
  static Future<UploadResult> uploadImage({
    required Uri uploadUrl,
    required File file,
    required String landmark,
    required DateTime capturedAt,
  }) async {
    final request = http.MultipartRequest('POST', uploadUrl)
      ..fields['landmark'] = landmark
      ..fields['capturedAt'] = capturedAt.toUtc().toIso8601String()
      ..fields['filename'] = file.path.split(Platform.pathSeparator).last;

    final mimeType = _guessMimeType(file.path);
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        file.path,
        contentType: mimeType == null
            ? null
            : http_parser.MediaType.parse(mimeType),
      ),
    );

    try {
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      return UploadResult(
        ok: resp.statusCode >= 200 && resp.statusCode < 300,
        statusCode: resp.statusCode,
        body: resp.body,
      );
    } on SocketException catch (e) {
      return UploadResult(
        ok: false,
        statusCode: -1,
        body: 'Network error: ${e.message}',
      );
    } catch (e) {
      return UploadResult(ok: false, statusCode: -1, body: e.toString());
    }
  }

  static String? _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return null; // let server infer
  }
}
