import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> createPreviewUrl(Uint8List bytes, String mimeType) async {
  final dir = await getTemporaryDirectory();
  final ext = _ext(mimeType);
  final file = File('${dir.path}/admin_preview.$ext');
  await file.writeAsBytes(bytes);
  return file.uri.toString();
}

void revokePreviewUrl(String url) {
  try {
    File.fromUri(Uri.parse(url)).deleteSync();
  } on Object {
    // ignore cleanup errors
  }
}

String _ext(String mime) => switch (mime) {
  'video/mp4' || 'audio/mp4' => 'mp4',
  'video/quicktime' => 'mov',
  'video/webm' => 'webm',
  'audio/x-m4a' => 'm4a',
  'audio/aac' => 'aac',
  _ => 'mp3',
};
