import 'dart:typed_data';

Future<({Uint8List bytes, String name})?> pickFile(String accept) async {
  throw UnsupportedError(
    'La selección de archivos solo está disponible en web',
  );
}
