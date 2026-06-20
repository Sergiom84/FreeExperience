import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_experience/features/ui/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('presenta las tres direcciones visuales', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ProfileScreen())),
    );
    await tester.pump();

    expect(find.text('Umbral nocturno'), findsOneWidget);
    expect(find.text('Materia quieta'), findsOneWidget);
    expect(find.text('Silencio mineral'), findsOneWidget);
    expect(find.text('Modo local'), findsOneWidget);
  });
}
