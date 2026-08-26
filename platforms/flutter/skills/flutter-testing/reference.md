# flutter-testing — Reference

Deep-dive material for `SKILL.md`. **Bad (❌) vs good (✅)** Dart code pairs per guard rule,
plus Mode-A generation examples. Decision criteria live in `SKILL.md`.

---

## Mode A — Generation examples

### Example 1: unit test with injected clock and stubbed HTTP

```dart
// lib/src/clock.dart — injectable abstraction (ponytail: thin wrapper, no dep needed)
abstract class Clock {
  DateTime now();
}

// lib/src/weather_repository.dart
class WeatherRepository {
  WeatherRepository(this._client, this._clock);
  final http.Client _client;
  final Clock _clock;

  Future<Weather> fetchWeather(String city) async {
    final res = await _client.get(
      Uri.parse('https://api.example.com/weather?city=$city'),
    );
    if (res.statusCode != 200) throw WeatherException(res.statusCode);
    return Weather.fromJson(jsonDecode(res.body) as Map<String, dynamic>)
        ..fetchedAt = _clock.now();
  }
}

// test/weather_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

class MockClock extends Mock implements Clock {}

void main() {
  late MockClock clock;
  late WeatherRepository sut;

  setUp(() {
    clock = MockClock();
    // Arrange: fixed instant — test is fully deterministic
    when(() => clock.now()).thenReturn(DateTime(2024, 1, 15, 10, 0));
  });

  group('WeatherRepository.fetchWeather', () {
    test('returns parsed weather with fetchedAt from injected clock', () async {
      // Arrange: stubbed HTTP client — no real network
      final client = MockClient((_) async => http.Response(
            '{"city":"London","temp":20}',
            200,
          ));
      sut = WeatherRepository(client, clock);

      // Act
      final result = await sut.fetchWeather('London');

      // Assert: SUT output, not the stub value
      expect(result.city, 'London');
      expect(result.temp, 20);
      expect(result.fetchedAt, DateTime(2024, 1, 15, 10, 0)); // from injected clock
    });

    test('throws WeatherException on non-200 response', () async {
      // Arrange: server error path
      final client = MockClient((_) async => http.Response('', 503));
      sut = WeatherRepository(client, clock);

      // Act + Assert: error branch covered
      expect(
        () => sut.fetchWeather('London'),
        throwsA(isA<WeatherException>().having((e) => e.statusCode, 'statusCode', 503)),
      );
    });
  });
}
```

### Example 2: widget test with fakeAsync and error-state coverage

```dart
// test/weather_page_test.dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWeatherBloc extends MockBloc<WeatherEvent, WeatherState>
    implements WeatherBloc {}

void main() {
  late MockWeatherBloc bloc;

  setUp(() => bloc = MockWeatherBloc());

  testWidgets('shows CircularProgressIndicator while loading', (tester) async {
    whenListen(bloc, Stream.value(WeatherLoading()), initialState: WeatherLoading());

    await tester.pumpWidget(BlocProvider.value(value: bloc, child: const WeatherPage()));
    await tester.pump(); // one frame — do NOT pumpAndSettle with an infinite indicator

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error widget and retry button on failure', (tester) async {
    whenListen(
      bloc,
      Stream.value(const WeatherError('No connection')),
      initialState: WeatherLoading(),
    );

    await tester.pumpWidget(BlocProvider.value(value: bloc, child: const WeatherPage()));
    await tester.pumpAndSettle();

    // Assert: error state rendered — error path covered
    expect(find.text('No connection'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
  });

  testWidgets('advances debounce timer without real sleep', (tester) async {
    fakeAsync((async) {
      // Arrange + Act: advance 500 ms of debounce without waiting
      async.elapse(const Duration(milliseconds: 500));
      tester.pump(const Duration(milliseconds: 500));

      // Assert: loading triggered after debounce
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
```

---

## Guard rule 1 — Assertion-free test

```dart
// ❌ Runs the SUT; asserts nothing — CI stays green, bugs stay hidden
test('fetchWeather completes', () async {
  final repo = WeatherRepository(MockClient((_) async => http.Response('{}', 200)), MockClock());
  await repo.fetchWeather('London'); // no expect
});

// ✅ Asserts the actual output
test('fetchWeather returns weather for valid city', () async {
  final client = MockClient((_) async => http.Response('{"city":"London","temp":20}', 200));
  final repo = WeatherRepository(client, FixedClock(DateTime(2024)));

  final result = await repo.fetchWeather('London');

  expect(result.city, 'London');
  expect(result.temp, 20);
});
```

---

## Guard rule 2 — Mock-echo / tautological assertion

```dart
// ❌ Asserts the stub value — verifies nothing the SUT did
test('getUser returns user', () async {
  const fakeUser = User(id: 1, name: 'Alice');
  final repo = MockUserRepository();
  when(() => repo.getUser(1)).thenReturn(fakeUser);
  final sut = UserService(repo);

  final result = await sut.getUser(1);

  expect(result, fakeUser); // tautological: SUT could be replaced with `return repo.getUser(id)`
});

// ✅ Assert something the SUT transforms or enriches
test('getUser returns display-formatted name', () async {
  final repo = MockUserRepository();
  when(() => repo.getUser(1)).thenReturn(const User(id: 1, name: 'alice'));
  final sut = UserService(repo); // SUT capitalizes the name

  final result = await sut.getUser(1);

  expect(result.displayName, 'Alice'); // SUT's transformation, not the stub value
});
```

---

## Guard rule 3 — Over-mocking / mocking the SUT

```dart
// ❌ MockWeatherBloc is the SUT — the real implementation is never exercised
test('WeatherBloc emits loaded state', () async {
  final bloc = MockWeatherBloc(); // mocking the class under test
  whenListen(bloc, Stream.value(WeatherLoaded(Weather(temp: 20))));

  await expectLater(bloc.stream, emits(isA<WeatherLoaded>()));
  // This tests mocktail, not WeatherBloc
});

// ✅ Use the real SUT; mock only its dependencies
test('WeatherBloc emits WeatherLoaded after successful fetch', () async {
  final repo = MockWeatherRepository();
  when(() => repo.fetchWeather('London'))
      .thenAnswer((_) async => Weather(temp: 20));

  final bloc = WeatherBloc(repo); // real implementation
  bloc.add(const FetchWeatherEvent('London'));

  await expectLater(
    bloc.stream,
    emitsInOrder([isA<WeatherLoading>(), isA<WeatherLoaded>()]),
  );
});
```

---

## Guard rule 4 — Implementation-detail coupling

```dart
// ❌ Asserts on a private helper — breaks on any refactor, even a no-op one
test('parse calls _normalizeCity', () {
  final sut = WeatherParser();
  // ignore: invalid_use_of_protected_member
  verify(() => sut._normalizeCity('London')).called(1); // private internals
});

// ✅ Assert on the observable output; internal refactors don't break the test
test('parse trims and lowercases city name', () {
  final sut = WeatherParser();
  final result = sut.parse('  LONDON  ');
  expect(result.city, 'london'); // public output, not how it got there
});
```

---

## Guard rule 5 — Non-determinism / flakiness

```dart
// ❌ Real delay in a widget test — flaky in slow CI, slow everywhere
testWidgets('loader disappears after fetch', (tester) async {
  await tester.pumpWidget(const WeatherPage());
  await Future.delayed(const Duration(milliseconds: 300)); // real wall-clock wait
  await tester.pump();
  expect(find.byType(CircularProgressIndicator), findsNothing);
});

// ✅ Inject clock; control time with fakeAsync — deterministic and instant
testWidgets('loader disappears when bloc emits loaded', (tester) async {
  final bloc = MockWeatherBloc();
  whenListen(
    bloc,
    Stream.fromIterable([WeatherLoading(), WeatherLoaded(Weather(temp: 20))]),
    initialState: WeatherLoading(),
  );

  await tester.pumpWidget(BlocProvider.value(value: bloc, child: const WeatherPage()));
  await tester.pumpAndSettle(); // safe — stream is finite, no infinite animation

  expect(find.byType(CircularProgressIndicator), findsNothing);
  expect(find.text('20°'), findsOneWidget);
});

// ❌ DateTime.now() in Arrange — test result depends on when it runs
test('token is not expired', () {
  final token = Token(expiresAt: DateTime.now().add(const Duration(hours: 1)));
  expect(token.isValid, isTrue); // flaky near midnight, in a different timezone, etc.
});

// ✅ Fixed instant via injected Clock
test('token is valid when expiry is in the future', () {
  final now = DateTime(2024, 6, 1, 12, 0);
  final token = Token(expiresAt: now.add(const Duration(hours: 1)));
  expect(token.isValidAt(now), isTrue);
});
```

---

## Guard rule 6 — Happy-path only

```dart
// ❌ Only the success case — the error/empty branches are unverified
test('fetchWeather returns weather', () async {
  final client = MockClient((_) async => http.Response('{"city":"London","temp":20}', 200));
  final result = await WeatherRepository(client, FixedClock()).fetchWeather('London');
  expect(result.city, 'London');
});

// ✅ Success + error + empty/boundary all covered
group('WeatherRepository.fetchWeather', () {
  test('returns parsed weather on 200', () async {
    final client = MockClient((_) async => http.Response('{"city":"London","temp":20}', 200));
    final result = await WeatherRepository(client, FixedClock()).fetchWeather('London');
    expect(result.city, 'London');
  });

  test('throws WeatherException on 503', () {
    final client = MockClient((_) async => http.Response('', 503));
    expect(
      () => WeatherRepository(client, FixedClock()).fetchWeather('London'),
      throwsA(isA<WeatherException>()),
    );
  });

  test('throws FormatException on malformed JSON', () {
    final client = MockClient((_) async => http.Response('not-json', 200));
    expect(
      () => WeatherRepository(client, FixedClock()).fetchWeather('London'),
      throwsA(isA<FormatException>()),
    );
  });
});
```

---

## Guard rule 7 — Snapshot / golden abuse

```dart
// ❌ Golden regenerated without review — the assertion just becomes whatever renders now
testWidgets('WeatherCard golden', (tester) async {
  await tester.pumpWidget(const WeatherCard(temp: 20));
  // run with --update-goldens on every PR to "fix" failures — meaningless baseline
  await expectLater(find.byType(WeatherCard), matchesGoldenFile('weather_card.png'));
});

// ✅ Golden used for intentional visual regression only; combined with behavior assertions
testWidgets('WeatherCard renders temp and icon correctly', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: WeatherCard(temp: 20, icon: Icons.wb_sunny)));
  await tester.pumpAndSettle();

  // Behavior assertions first — these catch logic bugs regardless of pixel changes
  expect(find.text('20°'), findsOneWidget);
  expect(find.byIcon(Icons.wb_sunny), findsOneWidget);

  // Golden for visual regression — only update after deliberate review
  await expectLater(
    find.byType(WeatherCard),
    matchesGoldenFile('goldens/weather_card_sunny_20.png'),
  );
  // ponytail: update goldens only with: flutter test --update-goldens + PR review of .png diff
});
```

---

## Guard rule 8 — Smuggled skip / disable

```dart
// ❌ Silent skip — this broken test will never run again
test('fetchWeather handles timeout', () async {
  // ... test body
}, skip: 'TODO');

// ❌ skip: true with no reason
testWidgets('WeatherPage renders on Android', (tester) async {
  // ...
}, skip: true);

// ✅ Skip with reason + ticket — tracked and time-boxed
test(
  'fetchWeather handles timeout',
  () async {
    // ...
  },
  // skip: tracking https://github.com/org/repo/issues/4321
  //        MockClient does not yet support request timeout simulation;
  //        remove skip once package:http/testing.dart adds timeout support.
  skip: 'Blocked on package:http/testing.dart timeout support — see #4321',
);
```

---

## Guard rule 9 — Copy-paste clone

```dart
// ❌ Identical assertions, different names — neither adds unique coverage
test('fetchWeather with city London returns weather', () async {
  final result = await repo.fetchWeather('London');
  expect(result.city, 'London');
  expect(result.temp, 20);
});

test('fetchWeather with city Paris returns weather', () async {
  // copy-pasted — still returns London/20 from the same stub
  final result = await repo.fetchWeather('Paris');
  expect(result.city, 'London'); // wrong assertion — went unnoticed in copy-paste
  expect(result.temp, 20);
});

// ✅ Parameterize differing inputs — each case is distinct and correct
const cases = [
  ('London', '{"city":"London","temp":20}', 20),
  ('Paris', '{"city":"Paris","temp":15}', 15),
  ('Tokyo', '{"city":"Tokyo","temp":28}', 28),
];

for (final (city, body, expectedTemp) in cases) {
  test('fetchWeather returns correct temp for $city', () async {
    final client = MockClient((_) async => http.Response(body, 200));
    final result = await WeatherRepository(client, FixedClock()).fetchWeather(city);
    expect(result.city, city);
    expect(result.temp, expectedTemp);
  });
}
```

---

## Guard rule 10 — Coverage theater

```dart
// ❌ Calls every method; asserts nothing; line coverage is 100%, value is 0%
test('WeatherService smoke test', () {
  final svc = WeatherService(MockWeatherRepository());
  expect(() => svc.refresh(), returnsNormally); // only checks "it didn't throw"
  expect(() => svc.clear(), returnsNormally);
  expect(() => svc.lastCity, returnsNormally);
  // mutation score: 0 — any return value can be changed and this test still passes
});

// ✅ Assert on actual output and state transitions — mutations fail
group('WeatherService', () {
  test('refresh updates lastCity', () async {
    final repo = MockWeatherRepository();
    when(() => repo.fetchWeather('Berlin'))
        .thenAnswer((_) async => Weather(city: 'Berlin', temp: 18));
    final svc = WeatherService(repo);

    await svc.refresh('Berlin');

    expect(svc.lastCity, 'Berlin'); // a mutant returning null would fail this
  });

  test('clear resets lastCity to null', () async {
    final svc = WeatherService(MockWeatherRepository())..lastCity = 'Berlin';
    svc.clear();
    expect(svc.lastCity, isNull); // asserts the state mutation
  });
});
```

---

## Official references

- flutter_test API: https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html
- mocktail: https://pub.dev/packages/mocktail
- fake_async: https://pub.dev/packages/fake_async
- package:http/testing.dart (MockClient): https://pub.dev/packages/http
- integration_test: https://docs.flutter.dev/testing/integration-tests
- Flutter golden tests: https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html
- Flutter testing overview: https://docs.flutter.dev/testing
- Team baseline: [../../guidance.md](../../guidance.md)
