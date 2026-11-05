import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';


import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/network.dart';
import 'package:my_mobile_app/session_manager.dart';
import 'package:my_mobile_app/System Login/login_page.dart';
import 'package:my_mobile_app/main.dart';

Widget _loginApp() => MaterialApp(
  initialRoute: '/login',
  routes: {
    '/login': (_) => const LoginPage(),
    '/': (_) => const Scaffold(body: Text('home')),
  },
);
Future<void> _enterCredentials(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'user@example.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'password');
}
class _BlockingEnvironmentStore extends InMemorySharedPreferencesStore {
  _BlockingEnvironmentStore(
    super.data, {
    this.blockEnvironmentRead = false,
  }) : super.withData();

  final bool blockEnvironmentRead;
  final environmentRead = Completer<void>();
  final environmentWrite = Completer<void>();

  @override
  Future<Map<String, Object>> getAll() async {
    if (blockEnvironmentRead) await environmentRead.future;
    return super.getAll();
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith('BACKEND_ENVIRONMENT') && value == 'dev') {
      await environmentWrite.future;
    }
    return super.setValue(valueType, key, value);
  }
}



void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
    Network.client = MockClient((_) async => http.Response('{}', 200));
  });

  tearDown(() => Network.client.close());

  testWidgets('login selector displays and switches persisted environment', (tester) async {
    await EnvironmentConfig.initialize();
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.text('Environment'), findsOneWidget);
    expect(find.text('QA'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<BackendEnvironment>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DEV').last);
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(EnvironmentConfig.selected.value, BackendEnvironment.dev);
    expect(prefs.getString('BACKEND_ENVIRONMENT'), 'dev');
    expect(find.text('DEV'), findsOneWidget);
  });

  test('fresh install selects QA and removes only untagged legacy session', () async {
    SharedPreferences.setMockInitialValues({
      SessionManager.sessionKey: '{"access_token":"legacy-secret"}',
      'unrelated': 'keep',
    });
    await EnvironmentConfig.initialize();

    final prefs = await SharedPreferences.getInstance();
    expect(EnvironmentConfig.selected.value, BackendEnvironment.qa);
    expect(EnvironmentConfig.baseUrl, 'http://43.173.10.180:3030');
    expect(prefs.getString(SessionManager.sessionKey), isNull);
    expect(prefs.getString('unrelated'), 'keep');
  });

  test('restores persisted DEV selection', () async {
    SharedPreferences.setMockInitialValues({'BACKEND_ENVIRONMENT': 'dev'});
    await EnvironmentConfig.initialize();

    expect(EnvironmentConfig.selected.value, BackendEnvironment.dev);
    expect(EnvironmentConfig.baseUrl, 'http://10.0.2.2:3030');
  });

  test('switch persists environment and clears only session data', () async {
    await EnvironmentConfig.initialize();
    await SessionManager.setSession(
      {'access_token': 'qa-secret'},
      environment: 'qa',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unrelated', 'keep');

    await EnvironmentConfig.select(BackendEnvironment.dev);

    expect(prefs.getString('BACKEND_ENVIRONMENT'), 'dev');
    expect(prefs.getString(SessionManager.sessionKey), isNull);
    expect(prefs.getString('unrelated'), 'keep');
  });

  test('GET POST DELETE and auth use selected URL and retain paths and headers', () async {
    await EnvironmentConfig.select(BackendEnvironment.dev);
    await SessionManager.setSession(
      {'access_token': 'dev-token'},
      environment: 'dev',
    );
    final requests = <http.Request>[];
    Network.client = MockClient((request) async {
      requests.add(request);
      return http.Response('{"ok":true}', 200);
    });

    await Network.get('/v1/boards');
    await Network.post('/v1/boards', {'name': 'test'});
    await Network.delete('/v1/boards/7');
    await AuthService.login({'email': 'qa@example.com'});
    await AuthService.signUp({'email': 'qa@example.com'});

    expect(requests.map((request) => request.url.toString()), [
      'http://10.0.2.2:3030/v1/boards',
      'http://10.0.2.2:3030/v1/boards',
      'http://10.0.2.2:3030/v1/boards/7',
      'http://10.0.2.2:3030/v1/auth/login',
      'http://10.0.2.2:3030/v1/auth/register',
    ]);
    expect(requests.map((request) => request.method), ['GET', 'POST', 'DELETE', 'POST', 'POST']);
    expect(requests.every((request) => request.headers['accept'] == 'application/json'), isTrue);
    expect(
      requests.map((request) => request.headers['authorization']),
      ['Bearer dev-token', 'Bearer dev-token', 'Bearer dev-token', null, null],
    );
    expect(requests[1].headers['content-type'], 'application/json');
    expect(jsonDecode(requests[1].body), {'name': 'test'});
  });
  test('malformed stored session does not block login or registration', () async {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      SessionManager.sessionKey: '{not-json',
    });
    final requests = <http.Request>[];
    Network.client = MockClient((request) async {
      requests.add(request);
      return http.Response('{}', 200);
    });

    await AuthService.login({'email': 'user@example.com'});
    await AuthService.signUp({'email': 'user@example.com'});

    expect(requests, hasLength(2));
    expect(
      requests.map((request) => request.headers['authorization']),
      [null, null],
    );
    expect(
      (await SharedPreferences.getInstance()).getString(SessionManager.sessionKey),
      '{not-json',
    );
  });


  test('network sends tokens only to their matching environment', () async {
    await EnvironmentConfig.initialize();
    final requests = <http.Request>[];
    Network.client = MockClient((request) async {
      requests.add(request);
      return http.Response('{}', 200);
    });

    await SessionManager.setSession(
      {'access_token': 'dev-token'},
      environment: 'dev',
    );
    await Network.get('/v1/boards');
    await SessionManager.setSession(
      {'access_token': 'qa-token'},
      environment: 'qa',
    );
    await Network.get('/v1/boards');
    await EnvironmentConfig.select(BackendEnvironment.dev);
    await SessionManager.setSession(
      {'access_token': 'qa-token'},
      environment: 'qa',
    );
    await Network.get('/v1/boards');
    await SessionManager.setSession(
      {'access_token': 'dev-token'},
      environment: 'dev',
    );
    await Network.get('/v1/boards');

    expect(requests.map((request) => request.url.toString()), [
      'http://43.173.10.180:3030/v1/boards',
      'http://43.173.10.180:3030/v1/boards',
      'http://10.0.2.2:3030/v1/boards',
      'http://10.0.2.2:3030/v1/boards',
    ]);
    expect(
      requests.map((request) => request.headers['authorization']),
      [null, 'Bearer qa-token', null, 'Bearer dev-token'],
    );
  });

  testWidgets('login shows backend connection errors in a snackbar', (tester) async {
    await EnvironmentConfig.initialize();
    Network.client = MockClient((_) async {
      throw const SocketException('Connection refused');
    });
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.enterText(find.byType(TextFormField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');

    await tester.tap(find.text('Masuk ke akun Anda'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Connection refused'), findsOneWidget);
  });
  testWidgets('switch unblocks login and stale success cannot affect new request', (tester) async {
    await EnvironmentConfig.initialize();
    final responses = [Completer<http.Response>(), Completer<http.Response>()];
    var requestCount = 0;
    Network.client = MockClient((_) => responses[requestCount++].future);
    await tester.pumpWidget(_loginApp());
    await _enterCredentials(tester);
    await tester.tap(find.text('Masuk ke akun Anda'));
    await tester.pump();
    expect(requestCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton).first).onPressed,
      isNull,
    );

    await tester.tap(find.byType(DropdownButtonFormField<BackendEnvironment>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('DEV').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton).first).onPressed,
      isNotNull,
    );
    await _enterCredentials(tester);

    await tester.tap(find.text('Masuk ke akun Anda'));
    await tester.pump();
    await tester.pump();
    expect(requestCount, 2);
    responses[0].complete(http.Response('{"data":{"access_token":"old"}}', 200));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    responses[1].complete(http.Response('{"data":{"access_token":"new"}}', 200));
    await tester.pumpAndSettle();
    expect(
      await SessionManager.getTokenForEnvironment('dev'),
      'new',
    );
  });

  testWidgets('stale login error cannot interfere with new request', (tester) async {
    await EnvironmentConfig.initialize();
    final responses = [Completer<http.Response>(), Completer<http.Response>()];
    var requestCount = 0;
    Network.client = MockClient((_) => responses[requestCount++].future);
    await tester.pumpWidget(_loginApp());
    await _enterCredentials(tester);
    await tester.tap(find.text('Masuk ke akun Anda'));
    await tester.pump();
    expect(requestCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton).first).onPressed,
      isNull,
    );

    await tester.tap(find.byType(DropdownButtonFormField<BackendEnvironment>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('DEV').last);
    await tester.pumpAndSettle();
    await _enterCredentials(tester);
    await tester.tap(find.text('Masuk ke akun Anda'));
    await tester.pump();
    await tester.pump();
    expect(requestCount, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton).first).onPressed,
      isNull,
    );

    responses[0].completeError(const SocketException('stale error'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    responses[1].complete(http.Response('{"data":{"access_token":"new"}}', 200));
    await tester.pumpAndSettle();
    expect(await SessionManager.getTokenForEnvironment('dev'), 'new');
  });


  test('in-flight login stays on its original URL and cannot save after switch', () async {
    await EnvironmentConfig.initialize();
    final snapshot = await EnvironmentConfig.snapshot();
    final responseCompleter = Completer<http.Response>();
    Uri? requestUrl;
    Network.client = MockClient((request) {
      requestUrl = request.url;
      return responseCompleter.future;
    });

    final login = AuthService.login(
      {'email': 'qa@example.com'},
      environmentSnapshot: snapshot,
    );
    await Future<void>.delayed(Duration.zero);
    await EnvironmentConfig.select(BackendEnvironment.dev);
    responseCompleter.complete(http.Response(
      '{"data":{"access_token":"qa-secret"}}',
      200,
    ));
    final result = await login;
    final saved = await EnvironmentConfig.saveSessionIfCurrent(
      snapshot.generation,
      snapshot.environment,
      result['data'] as Map<String, dynamic>,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(requestUrl.toString(), 'http://43.173.10.180:3030/v1/auth/login');
    expect(saved, isFalse);
    expect(prefs.getString(SessionManager.sessionKey), isNull);
  });

  testWidgets('environment switch disables signup until persistence finishes', (tester) async {
    SharedPreferences.setMockInitialValues({'BACKEND_ENVIRONMENT': 'qa'});
    final store = _BlockingEnvironmentStore({
      'flutter.BACKEND_ENVIRONMENT': 'qa',
    });
    SharedPreferencesStorePlatform.instance = store;
    await EnvironmentConfig.initialize();
    await tester.pumpWidget(_loginApp());
    final signup = find.byType(TextButton).last;
    expect(tester.widget<TextButton>(signup).onPressed, isNotNull);

    await tester.tap(find.byType(DropdownButtonFormField<BackendEnvironment>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('DEV').last);
    await tester.pump();

    expect(EnvironmentConfig.switching.value, isTrue);
    expect(tester.widget<TextButton>(signup).onPressed, isNull);

    store.environmentWrite.complete();
    await tester.pumpAndSettle();

    expect(EnvironmentConfig.switching.value, isFalse);
    expect(tester.widget<TextButton>(signup).onPressed, isNotNull);
  });

  testWidgets('cold-start login re-enables signup after environment switch', (tester) async {
    SharedPreferences.setMockInitialValues({'BACKEND_ENVIRONMENT': 'qa'});
    final store = _BlockingEnvironmentStore({
      'flutter.BACKEND_ENVIRONMENT': 'qa',
    });
    SharedPreferencesStorePlatform.instance = store;
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    final signup = find.widgetWithText(TextButton, 'Daftar baru');
    expect(find.text('Masuk'), findsOneWidget);
    expect(tester.widget<TextButton>(signup).onPressed, isNotNull);

    await tester.tap(find.byType(DropdownButtonFormField<BackendEnvironment>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('DEV').last);
    await tester.pump();

    expect(EnvironmentConfig.switching.value, isTrue);
    expect(tester.widget<TextButton>(signup).onPressed, isNull);

    store.environmentWrite.complete();
    await tester.pumpAndSettle();

    expect(EnvironmentConfig.switching.value, isFalse);
    expect(find.text('Masuk'), findsOneWidget);
    expect(tester.widget<TextButton>(signup).onPressed, isNotNull);
  });

  testWidgets('environment switch blocks login and snapshots until persistence finishes', (tester) async {
    SharedPreferences.setMockInitialValues({'BACKEND_ENVIRONMENT': 'qa'});
    final store = _BlockingEnvironmentStore({
      'flutter.BACKEND_ENVIRONMENT': 'qa',
    });
    SharedPreferencesStorePlatform.instance = store;
    await EnvironmentConfig.initialize();
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.tap(find.byType(DropdownButtonFormField<BackendEnvironment>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('DEV').last);
    await tester.pump();

    expect(EnvironmentConfig.switching.value, isTrue);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton).first).onPressed,
      isNull,
    );
    var snapshotCompleted = false;
    final snapshotFuture = EnvironmentConfig.snapshot().then((snapshot) {
      snapshotCompleted = true;
      return snapshot;
    });
    await tester.pump();
    expect(snapshotCompleted, isFalse);

    store.environmentWrite.complete();
    await tester.pumpAndSettle();
    final snapshot = await snapshotFuture;
    expect(snapshot.environment, 'dev');
    expect(EnvironmentConfig.switching.value, isFalse);
  });
  testWidgets('environment switch invalidates login while initialization is pending', (tester) async {
    SharedPreferences.setMockInitialValues({'BACKEND_ENVIRONMENT': 'qa'});
    final store = _BlockingEnvironmentStore(
      {'flutter.BACKEND_ENVIRONMENT': 'qa'},
      blockEnvironmentRead: true,
    );
    SharedPreferencesStorePlatform.instance = store;
    var requestCount = 0;
    Network.client = MockClient((_) async {
      requestCount++;
      return http.Response('{}', 200);
    });
    await tester.pumpWidget(_loginApp());
    await _enterCredentials(tester);
    await tester.tap(find.text('Masuk ke akun Anda'));
    await tester.pump();
    expect(requestCount, 0);

    await tester.tap(find.byType(DropdownButtonFormField<BackendEnvironment>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('DEV').last);
    await tester.pump();
    expect(EnvironmentConfig.switching.value, isTrue);

    store.environmentRead.complete();
    await tester.pump();
    expect(requestCount, 0);
    store.environmentWrite.complete();
    await tester.pumpAndSettle();

    expect(EnvironmentConfig.selected.value, BackendEnvironment.dev);
    expect(requestCount, 0);
  });
}
