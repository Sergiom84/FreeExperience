import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'app_log.dart';

/// Calidad JPEG de las portadas. 72 pesa ~30% menos que 82 sin pérdida
/// perceptible, para que carguen antes desde Supabase Storage.
const int _jpegQuality = 72;

/// Encuadre normalizado (0..1) sobre la imagen origen: origen y tamaño
/// relativos. Compartido por el recortador de UI y el repositorio de subida.
class CropRect {
  const CropRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  static const full = CropRect(left: 0, top: 0, width: 1, height: 1);
}

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
    return PreparedImage(img.encodeJpg(resized, quality: _jpegQuality));
  } on Object catch (error, stackTrace) {
    reportError(error, stackTrace, context: 'prepareImage');
    return null;
  }
}

/// Recorta [bytes] a un rectángulo normalizado (0..1 en coordenadas de la
/// imagen origen: left, top, width, height) elegido por el usuario, y re-codifica
/// como JPEG limitando el lado mayor a [maxDimension]. Devuelve null si el
/// formato no se puede decodificar. Lo usa el recortador guiado del panel de
/// administración para generar el thumb (1:1) y la portada (4:5) por separado.
PreparedImage? cropImageToNormalizedRect(
  Uint8List bytes, {
  required double left,
  required double top,
  required double width,
  required double height,
  required int maxDimension,
}) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final x = (left * decoded.width).round().clamp(0, decoded.width - 1);
    final y = (top * decoded.height).round().clamp(0, decoded.height - 1);
    final w = (width * decoded.width).round().clamp(1, decoded.width - x);
    final h = (height * decoded.height).round().clamp(1, decoded.height - y);
    final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
    final fits =
        cropped.width <= maxDimension && cropped.height <= maxDimension;
    final resized = fits
        ? cropped
        : (cropped.width >= cropped.height
              ? img.copyResize(cropped, width: maxDimension)
              : img.copyResize(cropped, height: maxDimension));
    return PreparedImage(img.encodeJpg(resized, quality: _jpegQuality));
  } on Object catch (error, stackTrace) {
    reportError(error, stackTrace, context: 'cropImageToNormalizedRect');
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
