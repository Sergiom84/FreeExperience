import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la interfaz no contiene emojis ni textos tutoriales', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final forbiddenCopy = RegExp(
      r'aqu[ií] (?:es donde|encontrar[aá]s)|en esta secci[oó]n',
      caseSensitive: false,
    );
    final emoji = RegExp(
      r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
      unicode: true,
    );

    for (final file in files) {
      final source = file.readAsStringSync();
      expect(forbiddenCopy.hasMatch(source), isFalse, reason: file.path);
      expect(emoji.hasMatch(source), isFalse, reason: file.path);
    }
  });
}
