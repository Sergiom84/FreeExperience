import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'app_log.dart';

/// Imagen ya lista para subir: bytes re-codificados como JPEG.
class PreparedImage {
  const PreparedImage(this.bytes);

  final Uint8List bytes;

  String get ext => 'jpg';
  String get mime => 'image/jpeg';
}

/// Decodifica, limita el lado mayor a [maxDimension] y re-codifica como JPEG.
/// Devuelve null para formatos que el decodificador no entiende (p. ej. HEIC),
/// dejando la decisión de respaldo en manos de quien llama. Compartido por las
/// portadas del panel de administración y el avatar del perfil.
PreparedImage? prepareImage(Uint8List bytes, {required int maxDimension}) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final fits =
        decoded.width <= maxDimension && decoded.height <= maxDimension;
    final resized = fits
        ? decoded
        : (decoded.width >= decoded.height
              ? img.copyResize(decoded, width: maxDimension)
              : img.copyResize(decoded, height: maxDimension));
    return PreparedImage(img.encodeJpg(resized, quality: 82));
  } on Object catch (error, stackTrace) {
    reportError(error, stackTrace, context: 'prepareImage');
    return null;
  }
}
