import 'package:flutter_test/flutter_test.dart';
import 'package:free_experience/features/profile/intro_seen_store.dart';
import 'package:free_experience/features/profile/profile_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockProfileRepository profile;
  late IntroSeenStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    profile = _MockProfileRepository();
    store = IntroSeenStore(profile);
  });

  test('sin remoto ni flag local la introducción no está vista', () async {
    when(profile.introSeen).thenAnswer((_) async => null);
    expect(await store.isSeen(), isFalse);
  });

  test('el remoto manda y actualiza el respaldo local', () async {
    when(profile.introSeen).thenAnswer((_) async => true);
    expect(await store.isSeen(), isTrue);

    // Sin red se conserva el flag local sincronizado antes.
    when(profile.introSeen).thenThrow(Exception('sin red'));
    expect(await store.isSeen(), isTrue);
  });

  test('markSeen persiste en local y en el perfil remoto', () async {
    when(profile.setIntroSeen).thenAnswer((_) async {});
    when(profile.introSeen).thenThrow(Exception('sin red'));

    await store.markSeen();

    verify(profile.setIntroSeen).called(1);
    expect(await store.isSeen(), isTrue);
  });
}
