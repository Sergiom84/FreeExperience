import 'package:flutter/material.dart';

import 'design_direction.dart';

abstract final class AppTokens {
  // Atmospheric cover gradient (placeholder when no image)
  static Gradient coverGradient(DesignDirection direction) =>
      switch (direction) {
        DesignDirection.umbral => const RadialGradient(
          center: Alignment(-0.28, -0.48),
          radius: 1.25,
          colors: [Color(0xFF2F3B46), Color(0xFF16202A), Color(0xFF080B0F)],
          stops: [0.0, 0.48, 0.96],
        ),
        DesignDirection.materia => const RadialGradient(
          center: Alignment(-0.36, -0.56),
          radius: 1.20,
          colors: [Color(0xFF73492E), Color(0xFF3D2C1D), Color(0xFF1D150F)],
          stops: [0.0, 0.52, 0.94],
        ),
        DesignDirection.mineral => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDCD6CB), Color(0xFFCDC6B8), Color(0xFFBFB7A7)],
          stops: [0.0, 0.55, 1.0],
        ),
      };

  // Bottom-fade overlay for featured cover cards
  static Gradient coverOverlay(DesignDirection direction) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      switch (direction) {
        DesignDirection.umbral => const Color(0xED080B0F),
        DesignDirection.materia => const Color(0xED17130F),
        DesignDirection.mineral => const Color(0x40181A1B),
      },
    ],
    stops: const [0.40, 1.0],
  );

  // Focus/selection ring color per direction
  static Color focusRingColor(DesignDirection direction) => switch (direction) {
    DesignDirection.umbral => const Color(0x2EC6A15B),
    DesignDirection.materia => const Color(0x2EBE7C56),
    DesignDirection.mineral => const Color(0x288A6A3E),
  };

  // Deep cinematographic card shadow
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x8C14120F),
      blurRadius: 70,
      spreadRadius: -28,
      offset: Offset(0, 40),
    ),
  ];

  // Organic arc for Materia featured cover
  static const BorderRadius materiaArc = BorderRadius.only(
    topLeft: Radius.circular(120),
    topRight: Radius.circular(120),
    bottomLeft: Radius.circular(18),
    bottomRight: Radius.circular(18),
  );

  // Letter-spacing constants
  static const double labelLetterSpacing = 3.5;
  static const double metaLetterSpacing = 1.5;

  // Pill radius (chips, tags)
  static const double pillRadius = 999;
}
