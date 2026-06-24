import 'dart:typed_data';

import 'package:flutter/material.dart';

Future<({Uint8List bytes, String name})?> pickFile(String accept) async {
  throw UnsupportedError(
    'La selección de archivos solo está disponible en web',
  );
}

class FilePickerButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => throw UnsupportedError('web only'),
        child: Text(label),
      ),
    );
  }
}
