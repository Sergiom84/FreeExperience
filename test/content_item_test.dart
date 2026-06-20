import 'package:flutter_test/flutter_test.dart';
import 'package:free_experience/features/content/domain/content_item.dart';

void main() {
  group('ContentKind', () {
    test('clasifica únicamente el contenido sonoro como audio', () {
      expect(ContentKind.meditation.isAudio, isTrue);
      expect(ContentKind.practice.isAudio, isTrue);
      expect(ContentKind.channeling.isAudio, isTrue);
      expect(ContentKind.video.isAudio, isFalse);
      expect(ContentKind.recommendation.isAudio, isFalse);
    });

    test('tolera un tipo remoto desconocido', () {
      expect(ContentKindLabel.parse('desconocido'), ContentKind.meditation);
    });
  });

  test('la duración se expresa en minutos', () {
    const item = ContentItem(
      id: 'uno',
      kind: ContentKind.meditation,
      title: 'Presencia',
      coverPath: 'assets/images/cover_umbral.svg',
      duration: Duration(minutes: 18),
      sortOrder: 0,
    );

    expect(item.durationLabel, '18 min');
  });
}
