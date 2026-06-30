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
  final String? mediaPath;
  final Duration duration;
  final bool featured;
  final int sortOrder;
  final DateTime? publishedAt;

  bool get hasPlayableMedia => mediaPath?.isNotEmpty ?? false;

  String get durationLabel => formatMinutes(duration);
}
