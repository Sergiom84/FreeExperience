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
/// Si se indica [targetAspect] (ancho/alto) recorta la imagen centrada a ese
/// encuadre antes de redimensionar, de modo que todas las vistas la muestren
/// con el mismo marco. Devuelve null para formatos que el decodificador no
/// entiende (p. ej. HEIC), dejando la decisión de respaldo en manos de quien
/// llama. Compartido por las portadas del panel de administración y el avatar
/// del perfil.
PreparedImage? prepareImage(
  Uint8List bytes, {
  required int maxDimension,
  double? targetAspect,
}) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final framed = targetAspect == null
        ? decoded
        : _centerCropToAspect(decoded, targetAspect);
    final fits = framed.width <= maxDimension && framed.height <= maxDimension;
    final resized = fits
        ? framed
        : (framed.width >= framed.height
              ? img.copyResize(framed, width: maxDimension)
              : img.copyResize(framed, height: maxDimension));
    return PreparedImage(img.encodeJpg(resized, quality: 82));
  } on Object catch (error, stackTrace) {
    reportError(error, stackTrace, context: 'prepareImage');
    return null;
  }
}

/// Recorta [src] centrado al [aspect] (ancho/alto) indicado. Descarta los
/// bordes del lado que sobra; nunca añade relleno.
img.Image _centerCropToAspect(img.Image src, double aspect) {
  final current = src.width / src.height;
  if ((current - aspect).abs() < 0.001) return src;
  if (current > aspect) {
    // Demasiado ancha: recorta a los lados.
    final cropW = (src.height * aspect).round();
    final x = ((src.width - cropW) / 2).round();
    return img.copyCrop(src, x: x, y: 0, width: cropW, height: src.height);
  }
  // Demasiado alta: recorta arriba y abajo.
  final cropH = (src.width / aspect).round();
  final y = ((src.height - cropH) / 2).round();
  return img.copyCrop(src, x: 0, y: y, width: src.width, height: cropH);
}
