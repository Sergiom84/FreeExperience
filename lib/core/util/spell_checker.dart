import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';

/// Corrector ortográfico local para el panel de administración.
///
/// Usa un diccionario de español (es_ES expandido con hunspell) empaquetado
/// como asset comprimido. Funciona sin red y no envía el texto a ningún
/// servicio externo. Solo señala palabras desconocidas: la decisión de
/// publicar sigue siendo de la persona que edita.
class SpellChecker {
  SpellChecker._(this._words);

  final Set<String> _words;

  static SpellChecker? _instance;
  static Future<SpellChecker>? _loading;

  /// Términos del dominio y marcas que no están en el diccionario general.
  /// Añadir aquí las palabras propias del proyecto que no deben marcarse.
  static const _extraWords = <String>{
    'crística',
    'crístico',
    'crísticas',
    'crísticos',
    'reprogramación',
    'reprogramaciones',
    'canalizadora',
    'canalizador',
    'chakra',
    'chakras',
    'mantra',
    'mantras',
    'reiki',
    'kundalini',
    'mindfulness',
    'soulkey',
    'youtube',
    'instagram',
    'app',
    'email',
    'online',
    'podcast',
    'playlist',
    'wifi',
  };

  static Future<SpellChecker> load() {
    if (_instance != null) return Future.value(_instance);
    return _loading ??= _load();
  }

  static Future<SpellChecker> _load() async {
    final data = await rootBundle.load('assets/dict/es_words.txt.gz');
    final bytes = GZipDecoder().decodeBytes(data.buffer.asUint8List());
    final words = const LineSplitter().convert(utf8.decode(bytes));
    return _instance = SpellChecker._({...words, ..._extraWords});
  }

  static final _wordPattern = RegExp(r'[a-záéíóúüñA-ZÁÉÍÓÚÜÑ]+');

  bool isKnown(String word) => _words.contains(word.toLowerCase());

  /// Palabras de [text] que no aparecen en el diccionario, con su posición,
  /// para poder subrayarlas.
  List<SpellIssue> check(String text) {
    final issues = <SpellIssue>[];
    for (final match in _wordPattern.allMatches(text)) {
      final word = match.group(0)!;
      // Palabras de una o dos letras: demasiado ruido (siglas, partículas).
      if (word.length < 3) continue;
      if (isKnown(word)) continue;
      issues.add(SpellIssue(word: word, start: match.start, end: match.end));
    }
    return issues;
  }
}

class SpellIssue {
  const SpellIssue({required this.word, required this.start, required this.end});

  final String word;
  final int start;
  final int end;
}
