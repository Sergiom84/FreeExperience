import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

// Native picker (iOS/Android/desktop): uses the OS document/media picker via
// file_picker. Avoids the iOS Safari async-gesture bug of the web <input>.
Future<({Uint8List bytes, String name})?> pickFile(String accept) async {
  final (type, extensions) = _resolveType(accept);
  final result = await FilePicker.platform.pickFiles(
    type: type,
    allowedExtensions: extensions,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.first;
  final bytes = file.bytes;
  if (bytes == null) return null;
  return (bytes: bytes, name: file.name);
}

(FileType, List<String>?) _resolveType(String accept) {
  if (accept.startsWith('image/')) return (FileType.image, null);
  if (accept.startsWith('video/')) {
    return (FileType.custom, ['mp4', 'mov', 'm4v', 'webm']);
  }
  if (accept.startsWith('audio/')) {
    return (
      FileType.custom,
      ['mp3', 'm4a', 'aac', 'wav', 'aiff', 'aif', 'mp4'],
    );
  }
  return (FileType.any, null);
}

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
  bool _busy = false;

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await pickFile(widget.accept);
      if (picked != null && mounted) {
        widget.onPicked(picked.bytes, picked.name);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _busy ? null : _pick,
        child: _busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(widget.label),
      ),
    );
  }
}
