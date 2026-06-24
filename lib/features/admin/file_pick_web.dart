import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<({Uint8List bytes, String name})?> pickFile(String accept) {
  final completer = Completer<({Uint8List bytes, String name})?>();
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = accept
    ..style.cssText = 'position:fixed;top:-9999px;left:-9999px;opacity:0';

  // iOS Safari requires the input to be in the DOM for programmatic .click()
  web.document.body!.appendChild(input);

  void cleanup() => input.remove();

  input.onchange = (web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.item(0)!;
    final reader = web.FileReader();
    reader.onload = (web.Event _) {
      final buffer = reader.result as JSArrayBuffer;
      final bytes = buffer.toDart.asUint8List();
      cleanup();
      if (!completer.isCompleted) {
        completer.complete((bytes: bytes, name: file.name));
      }
    }.toJS;
    reader.onerror = (web.Event _) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    }.toJS;
    reader.readAsArrayBuffer(file);
  }.toJS;

  input.click();
  return completer.future;
}
