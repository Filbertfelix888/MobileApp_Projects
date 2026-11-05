import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/session_manager.dart';
import 'package:my_mobile_app/main.dart';
import 'package:my_mobile_app/network.dart';

class _FailClearStore extends InMemorySharedPreferencesStore {
  _FailClearStore() : super.withData({
    'flutter.BACKEND_ENVIRONMENT': 'qa',
    'flutter.SESSION_ENVIRONMENT': 'qa',
    'flutter.SESSION_KEY': '{"access_token":"t"}',
  });

  @override
  Future<bool> setValue(String valueType, String key, Object value) async => false;

  @override
  Future<bool> remove(String key) async => false;
}

class _RequestHome extends StatelessWidget {
  const _RequestHome();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextButton(
      onPressed: () => Network.get('/boards').catchError((_) => null),
      child: const Text('Request'),
    ),
  );
}

void main() {
  test('failed persistence surfaces restore risk and keeps session fail-closed', () async {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"t"}',
    });
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
    final snapshot = await EnvironmentConfig.snapshot(includeAuth: true);
    SharedPreferencesStorePlatform.instance = _FailClearStore();

    await expectLater(
      EnvironmentConfig.invalidateSessionIfCurrent(
        snapshot.generation,
        snapshot.environment,
      ),
      throwsA(isA<SessionInvalidationFailure>().having(
        (error) => error.message,
        'message',
        allOf(contains('restore'), contains('restart')),
      )),
    );
    expect(EnvironmentConfig.generation, snapshot.generation + 1);
    expect(await SessionManager.getToken(), isNull);
  });

  testWidgets('401 storage failure shows a dismissible warning on login', (tester) async {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"t"}',
    });
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
    Network.client = MockClient((_) async => http.Response('{}', 401));
    addTearDown(() => Network.client.close());
    await tester.pumpWidget(const MyApp(homePage: _RequestHome()));
    await tester.pumpAndSettle();
    SharedPreferencesStorePlatform.instance = _FailClearStore();
    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.textContaining('session after restart'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('session after restart'), findsNothing);
  });

  test('successful invalidation rejects old in-flight session save', () async {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"t"}',
    });
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
    final snapshot = await EnvironmentConfig.snapshot(includeAuth: true);

    expect(
      await EnvironmentConfig.invalidateSessionIfCurrent(
        snapshot.generation,
        snapshot.environment,
      ),
      snapshot.generation + 1,
    );
    expect(
      await EnvironmentConfig.saveSessionIfCurrent(
        snapshot.generation,
        snapshot.environment,
        {'access_token': 'old'},
      ),
      isFalse,
    );
  });
}
