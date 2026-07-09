import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:free_experience/core/util/image_prep.dart';

void main() {
  group('prepareImage', () {
    test('recorta una foto panorámica al encuadre 4:5 centrado', () {
      final wide = img.Image(width: 1000, height: 400);
      final prepared = prepareImage(
        img.encodePng(wide),
        maxDimension: 1600,
        targetAspect: 4 / 5,
      );
      expect(prepared, isNotNull);
      final out = img.decodeImage(prepared!.bytes)!;
      expect(out.width / out.height, closeTo(4 / 5, 0.02));
    });

    test('recorta una foto vertical al encuadre 4:5 centrado', () {
      final tall = img.Image(width: 400, height: 1000);
      final prepared = prepareImage(
        img.encodePng(tall),
        maxDimension: 1600,
        targetAspect: 4 / 5,
      );
      expect(prepared, isNotNull);
      final out = img.decodeImage(prepared!.bytes)!;
      expect(out.width / out.height, closeTo(4 / 5, 0.02));
    });

    test('sin targetAspect conserva la relación de aspecto original', () {
      final square = img.Image(width: 800, height: 800);
      final prepared = prepareImage(img.encodePng(square), maxDimension: 1600);
      expect(prepared, isNotNull);
      final out = img.decodeImage(prepared!.bytes)!;
      expect(out.width, out.height);
    });
  });
}
