import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/main.dart';
import 'package:my_mobile_app/network.dart';
import 'package:my_mobile_app/session_manager.dart';

const _id = '11111111-1111-1111-1111-111111111111';
const _url = 'http://43.173.10.180:3030/api/v1/boards/$_id';

http.Response _board() => http.Response(
  jsonEncode({
    'status': 'Success',
    'response_code': 200,
    'data': {
      'public_id': _id,
      'title': 'Alpha',
      'description': 'First project',
      'created_at': '2026-11-01T08:00:00Z',
      'due_date': '2026-12-31T00:00:00Z',
    },
  }),
  200,
);

http.Response _empty(Object data) =>
    http.Response(jsonEncode({'data': data}), 200);

Future<http.Response> _detailResponse(http.Request request) async {
  if (request.url.path == '/api/v1/boards/$_id') return _board();
  if (request.url.path.endsWith('/lists')) {
    return _empty({'Lists': []});
  }
  if (request.url.path.endsWith('/members')) return _empty([]);
  if (request.url.path.endsWith('/cards')) return _empty([]);
  return http.Response('{"message":"Unexpected request"}', 404);
}

void main() {
  late List<http.Request> requests;

  void seed({bool session = true}) {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      if (session) 'SESSION_ENVIRONMENT': 'qa',
      if (session) 'SESSION_KEY': '{"access_token":"t"}',
    });
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
  }

  setUp(() {
    requests = [];
    seed();
  });

  tearDown(() => Network.client.close());

  Future<void> openDetail(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler, {
    bool settle = true,
  }) async {
    Network.client = MockClient((request) {
      requests.add(request);
      return handler(request);
    });
    await tester.pumpWidget(
      const MyApp(homePage: Scaffold(body: Text('home'))),
    );
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(Scaffold).first))
        .pushNamed('/projects/$_id');
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  testWidgets('shows title, description, created and due dates', (
    tester,
  ) async {
    await openDetail(tester, _detailResponse);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('First project'), findsOneWidget);
    final createdDate = DateTime.parse('2026-11-01T08:00:00Z')
        .toLocal()
        .toIso8601String()
        .split('T')
        .first;
    final dueDate = DateTime.parse('2026-12-31T00:00:00Z')
        .toLocal()
        .toIso8601String()
        .split('T')
        .first;
    await tester.tap(find.text('Detail proyek'));
    await tester.pumpAndSettle();
    expect(find.text(createdDate), findsOneWidget);
    expect(find.text(dueDate), findsOneWidget);
    final boardRequests = requests.where(
      (request) => request.url.toString() == _url,
    );
    expect(boardRequests.length, 1);
    expect(boardRequests.single.method, 'GET');
    expect(boardRequests.single.headers['authorization'], 'Bearer t');
  });

  testWidgets('missing session shows Login and sends no request', (
    tester,
  ) async {
    seed(session: false);
    await openDetail(tester, (_) async => _board());
    // Home is also guarded, so the pushed detail route is the only way to reach it.
    expect(find.text('Masuk'), findsWidgets);
    expect(find.text('Alpha'), findsNothing);
    expect(requests, isEmpty);
  });

  testWidgets('404 shows server message and retry refetches', (tester) async {
    var calls = 0;
    await openDetail(tester, (request) async {
      if (request.url.path != '/api/v1/boards/$_id') {
        return _detailResponse(request);
      }
      return ++calls == 1
          ? http.Response('{"message":"Board Not Found"}', 404)
          : _board();
    });
    expect(find.text('Board Not Found'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(
      requests.where((request) => request.url.toString() == _url).length,
      2,
    );
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Board Not Found'), findsNothing);
  });

  testWidgets('401 clears session and opens Login', (tester) async {
    await openDetail(
      tester,
      (_) async => http.Response('{"message":"Error unauthorized"}', 401),
    );
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    expect(
      await tester.runAsync(() => SessionManager.getTokenForEnvironment('qa')),
      isNull,
    );
  });

  testWidgets('stale 401 after environment switch keeps the new session', (
    tester,
  ) async {
    final first = Completer<http.Response>();
    await openDetail(tester, (_) => first.future, settle: false);
    await tester.runAsync(() async {
      await EnvironmentConfig.select(BackendEnvironment.dev);
      await SessionManager.setSession({
        'access_token': 'dev-token',
      }, environment: 'dev');
    });
    first.complete(http.Response('{"message":"Error unauthorized"}', 401));
    await tester.pump();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('Masuk'), findsNothing);
    expect(
      await tester.runAsync(() => SessionManager.getTokenForEnvironment('dev')),
      'dev-token',
    );
  });
  testWidgets(
    'stale successful metadata response stops loading and clears board',
    (tester) async {
      final first = Completer<http.Response>();
      await openDetail(tester, (_) => first.future, settle: false);
      await tester.runAsync(() async {
        await EnvironmentConfig.select(BackendEnvironment.dev);
        await SessionManager.setSession({
          'access_token': 'dev-token',
        }, environment: 'dev');
      });
      first.complete(_board());
      await tester.pump();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(find.text('Sesi berubah, buka ulang proyek'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Kembali'), findsOneWidget);
    },
  );
}
