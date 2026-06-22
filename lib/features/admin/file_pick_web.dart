import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<({Uint8List bytes, String name})?> pickFile(String accept) {
  final completer = Completer<({Uint8List bytes, String name})?>();
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = accept;

  input.onchange = (web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.item(0)!;
    final reader = web.FileReader();
    reader.onload = (web.Event _) {
      final buffer = reader.result as JSArrayBuffer;
      final bytes = buffer.toDart.asUint8List();
      if (!completer.isCompleted) {
        completer.complete((bytes: bytes, name: file.name));
      }
    }.toJS;
    reader.onerror = (web.Event _) {
      if (!completer.isCompleted) completer.complete(null);
    }.toJS;
    reader.readAsArrayBuffer(file);
  }.toJS;

  input.click();
  return completer.future;
}
