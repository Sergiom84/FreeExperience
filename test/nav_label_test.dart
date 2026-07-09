import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:free_experience/core/design/app_theme.dart';
import 'package:free_experience/core/design/design_direction.dart';

/// Etiquetas reales del bottom bar (formas cortas). Deben caber en una sola
/// línea en la pantalla más estrecha soportada (375 pt) para las tres
/// direcciones visuales.
const _labels = ['Meditar', 'Prácticas', 'Canales', 'Inspirar'];

void main() {
  for (final direction in DesignDirection.values) {
    testWidgets(
      'las etiquetas del nav caben en una línea a 375 pt (${direction.name})',
      (tester) async {
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.forDirection(direction),
            home: Scaffold(
              bottomNavigationBar: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.0,
                child: NavigationBar(
                  selectedIndex: 0,
                  destinations: [
                    for (final l in _labels)
                      NavigationDestination(
                        icon: const Icon(Icons.circle_outlined),
                        label: l,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

        for (final label in _labels) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          final lineTops = paragraph
              .getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: label.length),
              )
              .map((b) => b.top.round())
              .toSet();
          expect(
            lineTops.length,
            1,
            reason: '"$label" debe caber en una sola línea (${direction.name})',
          );
        }
      },
    );
  }
}
