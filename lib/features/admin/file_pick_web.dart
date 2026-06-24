import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

// Programmatic pick — works on desktop, blocked by iOS Safari async gesture chain.
Future<({Uint8List bytes, String name})?> pickFile(String accept) {
  final completer = Completer<({Uint8List bytes, String name})?>();
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = accept
    ..style.cssText = 'position:fixed;top:-9999px;left:-9999px;opacity:0';

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

// iOS-safe: user taps real <input type="file"> directly — no programmatic click.
int _viewCounter = 0;

class FilePickerButton extends StatefulWidget {
  const FilePickerButton({
    required this.accept,
    required this.label,
    required this.onPicked,
    super.key,
  });

  final String accept;
  final String label;
  final void Function(Uint8List bytes, String name) onPicked;

  @override
  State<FilePickerButton> createState() => _FilePickerButtonState();
}

class _FilePickerButtonState extends State<FilePickerButton> {
  late final String _viewType = 'fe-fp-${_viewCounter++}';
  web.HTMLInputElement? _el;

  @override
  void initState() {
    super.initState();
    ui.platformViewRegistry.registerViewFactory(_viewType, (_) {
      final input = web.document.createElement('input') as web.HTMLInputElement
        ..type = 'file'
        ..accept = widget.accept
        ..style.cssText =
            'position:absolute;inset:0;width:100%;height:100%;'
            'opacity:0;cursor:pointer;';
      _el = input;

      input.addEventListener(
        'change',
        (web.Event _) {
          final files = input.files;
          if (files == null || files.length == 0) return;
          final file = files.item(0)!;
          final reader = web.FileReader();
          reader.onload = (web.Event _) {
            final buffer = reader.result as JSArrayBuffer;
            final bytes = buffer.toDart.asUint8List();
            if (mounted) widget.onPicked(bytes, file.name);
            input.value = '';
          }.toJS;
          reader.onerror = (web.Event _) {}.toJS;
          reader.readAsArrayBuffer(file);
        }.toJS,
      );

      return input;
    });
  }

  @override
  void didUpdateWidget(FilePickerButton old) {
    super.didUpdateWidget(old);
    _el?.accept = widget.accept;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {},
            child: Text(widget.label),
          ),
        ),
        Positioned.fill(
          child: HtmlElementView(viewType: _viewType),
        ),
      ],
    );
  }
}
