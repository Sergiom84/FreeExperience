import '../../../core/util/formatters.dart';

enum ContentKind {
  meditation,
  practice,
  channeling,
  video,
  recommendation,
  intro,
}

extension ContentKindLabel on ContentKind {
  String get databaseValue => name;

  String get label => switch (this) {
    ContentKind.meditation => 'Meditaciones',
    ContentKind.practice => 'Prácticas',
    ContentKind.channeling => 'Canalizaciones',
    ContentKind.video => 'Vídeos',
    ContentKind.recommendation => 'Recomendaciones',
    ContentKind.intro => 'Introducción',
  };

  // Título de la cabecera de cada sección de nav. Difiere de `label` cuando el
  // nombre mostrado no coincide con el plural del catálogo (p. ej. Duerme usa
  // el kind `practice` pero su cabecera es "Reprogramación").
  String get sectionTitle => switch (this) {
    ContentKind.meditation => 'Meditaciones',
    ContentKind.channeling => 'Canalizaciones',
    ContentKind.practice => 'Reprogramación',
    _ => label,
  };

  // Descriptor breve bajo el título en la cabecera. Completa la frase iniciada
  // por `sectionTitle`. null para los kinds sin pantalla de nav propia.
  String? get tagline => switch (this) {
    ContentKind.meditation => 'con energía crística',
    ContentKind.channeling => 'con alma',
    ContentKind.practice => 'nocturna para descansar y soltar',
    _ => null,
  };

  bool get isAudio => switch (this) {
    ContentKind.meditation ||
    ContentKind.practice ||
    ContentKind.channeling ||
    ContentKind.intro => true,
    _ => false,
  };

  static ContentKind parse(String value) => ContentKind.values.firstWhere(
    (kind) => kind.name == value,
    orElse: () => ContentKind.meditation,
  );
}

class ContentItem {
  const ContentItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.coverPath,
    required this.duration,
    required this.sortOrder,
    this.author,
    this.body,
    this.externalUrl,
    this.thumbPath,
    this.mediaPath,
    this.featured = false,
    this.publishedAt,
  });

  final String id;
  final ContentKind kind;
  final String title;
  final String? author;
  final String? body;
  final String? externalUrl;
  final String coverPath;

  /// Recorte cuadrado (1:1) para miniaturas. Si es null, la UI cae a
  /// [coverPath] recortado en cliente.
  final String? thumbPath;
  final String? mediaPath;
  final Duration duration;
  final bool featured;
  final int sortOrder;
  final DateTime? publishedAt;

  /// Ruta para la miniatura: el recorte cuadrado si existe, si no la portada.
  String get thumbOrCover =>
      thumbPath?.isNotEmpty == true ? thumbPath! : coverPath;

  bool get hasPlayableMedia => mediaPath?.isNotEmpty ?? false;

  String get durationLabel => formatMinutes(duration);
}
