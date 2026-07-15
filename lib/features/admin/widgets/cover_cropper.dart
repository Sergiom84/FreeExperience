import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/util/image_prep.dart';

/// Recortador guiado: muestra [bytes] dentro de un marco de proporción [aspect]
/// (ancho/alto) fijo; el usuario arrastra y hace pinch para encuadrar. La imagen
/// siempre cubre el marco (no deja huecos). Notifica el recorte normalizado por
/// [onChanged] en cada ajuste. No decodifica en isolate: solo lee las
/// dimensiones intrínsecas para calcular el rectángulo.
class CoverCropper extends StatefulWidget {
  const CoverCropper({
    required this.bytes,
    required this.aspect,
    required this.onChanged,
    super.key,
  });

  final Uint8List bytes;
  final double aspect;
  final ValueChanged<CropRect> onChanged;

  @override
  State<CoverCropper> createState() => _CoverCropperState();
}

class _CoverCropperState extends State<CoverCropper> {
  Size? _imageSize; // px intrínsecos
  double _scale = 1; // px pantalla por px imagen
  Offset _offset = Offset.zero; // esquina sup-izq de la imagen en el marco
  Size _viewport = Size.zero;

  // Estado del gesto.
  double _startScale = 1;
  Offset _gestureImagePoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  @override
  void didUpdateWidget(CoverCropper old) {
    super.didUpdateWidget(old);
    if (old.bytes != widget.bytes || old.aspect != widget.aspect) {
      _imageSize = null;
      _loadSize();
    }
  }

  Future<void> _loadSize() async {
    final codec = await ui.instantiateImageCodec(widget.bytes);
    final frame = await codec.getNextFrame();
    final size = Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
    frame.image.dispose();
    if (!mounted) return;
    setState(() => _imageSize = size);
  }

  double get _minScale {
    final img = _imageSize!;
    return (_viewport.width / img.width) > (_viewport.height / img.height)
        ? _viewport.width / img.width
        : _viewport.height / img.height;
  }

  void _resetToCover() {
    final img = _imageSize!;
    _scale = _minScale;
    _offset = Offset(
      (_viewport.width - img.width * _scale) / 2,
      (_viewport.height - img.height * _scale) / 2,
    );
    _emit();
  }

  Offset _clampOffset(Offset value, double scale) {
    final img = _imageSize!;
    final minX = _viewport.width - img.width * scale;
    final minY = _viewport.height - img.height * scale;
    return Offset(value.dx.clamp(minX, 0.0), value.dy.clamp(minY, 0.0));
  }

  void _emit() {
    final img = _imageSize!;
    final x0 = (-_offset.dx / _scale) / img.width;
    final y0 = (-_offset.dy / _scale) / img.height;
    final w = (_viewport.width / _scale) / img.width;
    final h = (_viewport.height / _scale) / img.height;
    widget.onChanged(
      CropRect(
        left: x0.clamp(0.0, 1.0),
        top: y0.clamp(0.0, 1.0),
        width: w.clamp(0.0, 1.0),
        height: h.clamp(0.0, 1.0),
      ),
    );
  }

  void _onScaleStart(ScaleStartDetails d) {
    _startScale = _scale;
    _gestureImagePoint = (d.localFocalPoint - _offset) / _scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final newScale = (_startScale * d.scale).clamp(_minScale, _minScale * 5);
    final newOffset = d.localFocalPoint - _gestureImagePoint * newScale;
    setState(() {
      _scale = newScale;
      _offset = _clampOffset(newOffset, newScale);
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (_imageSize == null) {
            return const ColoredBox(
              color: Color(0x11000000),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }
          if (_viewport != size) {
            _viewport = size;
            // Reencuadra a cubrir tras conocer el marco (o si cambió de tamaño).
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(_resetToCover);
            });
          }
          final img = _imageSize!;
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: GestureDetector(
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: _offset.dx,
                    top: _offset.dy,
                    width: img.width * _scale,
                    height: img.height * _scale,
                    child: Image.memory(
                      widget.bytes,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  // Rejilla de tercios para guiar el encuadre.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _ThirdsPainter()),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ThirdsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final dx = size.width * i / 3;
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(_ThirdsPainter oldDelegate) => false;
}
