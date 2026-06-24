import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String> createPreviewUrl(Uint8List bytes, String mimeType) async {
  final parts = <JSAny>[bytes.buffer.toJS].toJS;
  final blob = web.Blob(parts, web.BlobPropertyBag(type: mimeType));
  return web.URL.createObjectURL(blob);
}

void revokePreviewUrl(String url) => web.URL.revokeObjectURL(url);
