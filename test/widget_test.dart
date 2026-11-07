import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// The platform store allows simulating a failed preferences write.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:my_mobile_app/Home/navbar_page.dart';
import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/main.dart';
import 'package:my_mobile_app/session_manager.dart';
import 'package:my_mobile_app/network.dart';
import 'package:my_mobile_app/System Login/login_page.dart';

Widget _testHome() => const Scaffold(appBar: Navbar());

class _FailingEnvironmentStore extends InMemorySharedPreferencesStore {
  _FailingEnvironmentStore(super.data) : super.withData();

  bool failEnvironmentWrite = false;
  bool failSessionEnvironmentWrite = false;
  bool failSessionRemoval = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (failEnvironmentWrite && key.endsWith('BACKEND_ENVIRONMENT')) {
      return Future.value(false);
    }
    if (failSessionEnvironmentWrite && key.endsWith('SESSION_ENVIRONMENT')) {
      return Future.value(false);
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) {
    if (failSessionRemoval &&
        (key.endsWith('SESSION_KEY') || key.endsWith('SESSION_ENVIRONMENT'))) {
      return Future.value(false);
    }
    return super.remove(key);
  }
}

void main() {
  setUp(() {
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
    SharedPreferences.setMockInitialValues({'BACKEND_ENVIRONMENT': 'qa'});
  });

  testWidgets('startup shows login when session is missing', (tester) async {
    await tester.pumpWidget(MyApp(homePage: _testHome()));
    await tester.pumpAndSettle();

    expect(find.text('Masuk'), findsOneWidget);
    expect(find.byIcon(Icons.account_circle), findsNothing);
  });

  testWidgets('startup opens home for a nonempty access token', (tester) async {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"test-token"}',
    });

    await tester.pumpWidget(MyApp(homePage: _testHome()));
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.account_circle), findsOneWidget);
    expect(find.text('Masuk'), findsNothing);
  });

  testWidgets('direct protected route rejects malformed token', (tester) async {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":42}',
    });

    await tester.pumpWidget(MyApp(homePage: _testHome()));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Masuk'));
    Navigator.of(context).pushNamed('/');
    await tester.pumpAndSettle();

    expect(find.text('Masuk'), findsOneWidget);
    expect(find.byIcon(Icons.account_circle), findsNothing);
  });

  testWidgets('malformed stored session fails closed without deleting it', (
    tester,
  ) async {
    const malformedSession = '{not-json';
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': malformedSession,
    });

    await tester.pumpWidget(MyApp(homePage: _testHome()));
    await tester.pumpAndSettle();

    expect(find.text('Masuk'), findsOneWidget);
    expect(
      await SharedPreferences.getInstance().then(
        (prefs) => prefs.getString('SESSION_KEY'),
      ),
      malformedSession,
    );
  });

  testWidgets('home stays hidden while session restoration is pending', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"test-token"}',
    });

    await tester.pumpWidget(MyApp(homePage: _testHome()));

    expect(find.byIcon(Icons.account_circle), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('switching environments removes authenticated routes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"test-token"}',
    });
    await tester.pumpWidget(
      MyApp(
        homePage: _testHome(),
        loginPage: const LoginPage(showEnvironmentSelector: true),
      ),
    );
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byIcon(Icons.account_circle)))
        .pushNamed('/login');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<BackendEnvironment>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DEV').last);
    await tester.pumpAndSettle();
    expect(EnvironmentConfig.selected.value, BackendEnvironment.dev);
    expect(Navigator.of(tester.element(find.text('Masuk'))).canPop(), isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.account_circle), findsNothing);
  });

  testWidgets(
    'failed environment persistence keeps switched session logged out on Back',
    (tester) async {
      final initialValues = {
        'BACKEND_ENVIRONMENT': 'qa',
        'SESSION_ENVIRONMENT': 'qa',
        'SESSION_KEY': '{"access_token":"test-token"}',
      };
      SharedPreferences.setMockInitialValues(initialValues);
      final store = _FailingEnvironmentStore({
        for (final entry in initialValues.entries)
          'flutter.${entry.key}': entry.value,
      });
      SharedPreferencesStorePlatform.instance = store;

      await tester.pumpWidget(
        MyApp(
          homePage: _testHome(),
          loginPage: const LoginPage(showEnvironmentSelector: true),
        ),
      );
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byIcon(Icons.account_circle)))
          .pushNamed('/login');
      await tester.pumpAndSettle();
      final previousGeneration = EnvironmentConfig.generation;
      store.failEnvironmentWrite = true;
      await tester.tap(
        find.byType(DropdownButtonFormField<BackendEnvironment>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('DEV').last);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(EnvironmentConfig.selected.value, BackendEnvironment.qa);
      expect(EnvironmentConfig.generation, greaterThan(previousGeneration));
      expect((await store.getAll())['flutter.BACKEND_ENVIRONMENT'], 'qa');
      expect(prefs.getString('SESSION_KEY'), isNull);
      expect(find.text('QA'), findsOneWidget);
      expect(find.text('DEV'), findsNothing);
      expect(
        Navigator.of(tester.element(find.text('Masuk'))).canPop(),
        isFalse,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.account_circle), findsNothing);
    },
  );

  testWidgets('logout clears session and opens login route', (tester) async {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"test-token"}',
    });

    await tester.pumpWidget(MyApp(homePage: _testHome()));
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.account_circle), findsOneWidget);

    Navigator.of(tester.element(find.byIcon(Icons.account_circle)))
        .pushNamed('/');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Masuk'), findsOneWidget);
    expect(find.byIcon(Icons.account_circle), findsNothing);
    expect(Navigator.of(tester.element(find.text('Masuk'))).canPop(), isFalse);
    expect(
      await SharedPreferences.getInstance().then(
        (prefs) => prefs.getString('SESSION_KEY'),
      ),
      isNull,
    );
  });

  test(
    'partial session write fails closed and removes any written token',
    () async {
      final store = _FailingEnvironmentStore({
        'flutter.BACKEND_ENVIRONMENT': 'qa',
      })..failSessionEnvironmentWrite = true;
      SharedPreferencesStorePlatform.instance = store;

      await expectLater(
        SessionManager.setSession({
          'access_token': 'partial-token',
        }, environment: 'qa'),
        throwsStateError,
      );

      expect(await SessionManager.getSessionForEnvironment('qa'), isNull);
      expect(
        (await store.getAll()).containsKey('flutter.SESSION_KEY'),
        isFalse,
      );
    },
  );

  testWidgets('failed logout fails closed, reports error, and blocks Back', (
    tester,
  ) async {
    final initialValues = {
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"test-token"}',
    };
    SharedPreferences.setMockInitialValues(initialValues);
    final store = _FailingEnvironmentStore({
      for (final entry in initialValues.entries)
        'flutter.${entry.key}': entry.value,
    })..failSessionRemoval = true;
    SharedPreferencesStorePlatform.instance = store;

    await tester.pumpWidget(MyApp(homePage: _testHome()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Masuk'), findsOneWidget);
    expect(find.textContaining('Could not clear session'), findsOneWidget);
    expect(Navigator.of(tester.element(find.text('Masuk'))).canPop(), isFalse);
    expect(await SessionManager.getSessionForEnvironment('qa'), isNull);
    Navigator.of(tester.element(find.text('Masuk'))).pushNamed('/');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.account_circle), findsNothing);
    expect(
      (await store.getAll())['flutter.SESSION_KEY'],
      contains('test-token'),
    );
    expect((await store.getAll())['flutter.SESSION_ENVIRONMENT'], 'qa');
  });
  testWidgets('failed login persistence removes old Home route', (
    tester,
  ) async {
    final initialValues = {
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"old-token"}',
    };
    SharedPreferences.setMockInitialValues(initialValues);
    final store = _FailingEnvironmentStore({
      for (final entry in initialValues.entries)
        'flutter.${entry.key}': entry.value,
    })..failSessionEnvironmentWrite = true;
    SharedPreferencesStorePlatform.instance = store;
    Network.client = MockClient(
      (_) async => http.Response('{"data":{"access_token":"new-token"}}', 200),
    );

    await tester.pumpWidget(MyApp(homePage: _testHome()));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.account_circle), findsOneWidget);
    Navigator.of(tester.element(find.byIcon(Icons.account_circle)))
        .pushNamed('/login');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('Masuk ke akun Anda'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not persist session environment'),
      findsOneWidget,
    );
    expect(find.text('Login Berhasil!'), findsNothing);
    expect(find.byIcon(Icons.account_circle), findsNothing);
    expect(Navigator.of(tester.element(find.text('Masuk'))).canPop(), isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.account_circle), findsNothing);
    expect(await SessionManager.getSessionForEnvironment('qa'), isNull);
  });

  testWidgets('missing and blank login tokens do not authenticate', (
    tester,
  ) async {
    for (final body in ['{}', '{"data":{"access_token":""}}']) {
      EnvironmentConfig.resetForTesting();
      SessionManager.resetForTesting();
      SharedPreferences.setMockInitialValues({'BACKEND_ENVIRONMENT': 'qa'});
      await EnvironmentConfig.initialize();
      Network.client = MockClient((_) async => http.Response(body, 200));
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password');

      await tester.tap(find.text('Masuk ke akun Anda'));
      await tester.pumpAndSettle();

      expect(find.textContaining('valid access token'), findsOneWidget);
      expect(await SessionManager.getSessionForEnvironment('qa'), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
