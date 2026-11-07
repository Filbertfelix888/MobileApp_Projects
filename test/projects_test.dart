import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mobile_app/Home/home_page.dart';
import 'package:my_mobile_app/System Login/login_page.dart';
import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/main.dart';
import 'package:my_mobile_app/network.dart';
import 'package:my_mobile_app/session_manager.dart';

const _base = 'http://43.173.10.180:3030/api/v1/boards';
const _id = '11111111-1111-1111-1111-111111111111';

http.Response _list(
  String title, {
  String desc = 'First',
  int totalPages = 1,
  bool empty = false,
}) {
  return http.Response(
    jsonEncode({
      'status': 'Success',
      'response_code': 200,
      'data': empty
          ? []
          : [
              {
                'public_id': _id,
                'title': title,
                'description': desc,
                'created_at': '2026-11-01T08:00:00Z',
              },
            ],
      'meta': {'page': 1, 'limit': 10, 'total': 1, 'total_pages': totalPages},
    }),
    200,
  );
}

void main() {
  late List<http.Request> requests;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"t"}',
    });
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
    requests = [];
  });

  tearDown(() => Network.client.close());

  Future<void> pumpHome(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler,
  ) async {
    Network.client = MockClient((request) {
      requests.add(request);
      return handler(request);
    });
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();
  }

  IconButton iconButton(WidgetTester tester, IconData icon) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));

  testWidgets('create validates fields and submits payload, then refreshes', (
    tester,
  ) async {
    await pumpHome(tester, (request) async {
      if (request.method == 'POST') {
        return http.Response(
          '{"message":"Board Created Successfully","data":{}}',
          200,
        );
      }
      return _list('Alpha');
    });
    await tester.tap(find.text('BUAT PROYEK BARU'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Nama proyek wajib diisi'), findsOneWidget);
    expect(find.text('Deskripsi wajib diisi'), findsOneWidget);
    expect(requests.where((request) => request.method == 'POST'), isEmpty);

    await tester.enterText(find.byType(TextFormField).at(0), 'Proyek baru');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Deskripsi proyek',
    );
    final displayedDate = tester
        .widget<TextFormField>(find.byType(TextFormField).at(2))
        .controller!
        .text;
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    final post = requests.singleWhere((request) => request.method == 'POST');
    expect(post.url.toString(), _base);
    expect(post.headers['authorization'], 'Bearer t');
    final payload = jsonDecode(post.body) as Map<String, dynamic>;
    expect(payload.keys.toSet(), {'title', 'description', 'due_date'});
    expect(payload['title'], 'Proyek baru');
    expect(payload['description'], 'Deskripsi proyek');
    final dueDate = payload['due_date'] as String;
    expect(
      dueDate,
      matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$')),
    );
    expect(
      DateTime.parse(dueDate).toLocal().toIso8601String().substring(0, 10),
      displayedDate,
    );
    expect(find.text('Buat proyek baru'), findsNothing);
    expect(requests.where((request) => request.method == 'GET').length, 2);
  });

  testWidgets('create error preserves input and allows retry', (tester) async {
    var attempts = 0;
    await pumpHome(tester, (request) async {
      if (request.method == 'POST') {
        attempts++;
        return attempts == 1
            ? http.Response(
                '{"message":"Failed to create board","error":"invalid"}',
                400,
              )
            : http.Response(
                '{"message":"Board Created Successfully","data":{}}',
                200,
              );
      }
      return _list('Alpha');
    });
    await tester.tap(find.text('BUAT PROYEK BARU'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Proyek baru');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Deskripsi proyek',
    );
    final date = tester
        .widget<TextFormField>(find.byType(TextFormField).at(2))
        .controller!
        .text;
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Failed to create board'), findsOneWidget);
    expect(find.text('Buat proyek baru'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller!
          .text,
      'Proyek baru',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      'Deskripsi proyek',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(2))
          .controller!
          .text,
      date,
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Buat proyek baru'), findsNothing);
    expect(requests.where((request) => request.method == 'GET').length, 2);
  });

  testWidgets('renders row from real envelope', (tester) async {
    await pumpHome(tester, (_) async => _list('Alpha'));
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    final createdDate = DateTime.parse('2026-11-01T08:00:00Z')
        .toLocal()
        .toIso8601String()
        .split('T')
        .first;
    expect(find.text(createdDate), findsOneWidget);
    expect(requests.single.url.toString(), '$_base/my?filter&limit=10&page=1');
  });

  testWidgets('empty data disables pagination', (tester) async {
    await pumpHome(tester, (_) async => _list('x', totalPages: 0, empty: true));
    expect(find.text('Data tidak tersedia'), findsOneWidget);
    expect(iconButton(tester, Icons.chevron_left).onPressed, isNull);
    expect(iconButton(tester, Icons.chevron_right).onPressed, isNull);
  });

  testWidgets('next page requests page=2', (tester) async {
    await pumpHome(tester, (_) async => _list('Alpha', totalPages: 3));
    expect(iconButton(tester, Icons.chevron_right).onPressed, isNotNull);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(requests.last.url.toString(), '$_base/my?filter&limit=10&page=2');
  });

  testWidgets('search encodes filter and resets to page 1', (tester) async {
    await pumpHome(tester, (_) async => _list('Alpha', totalPages: 3));
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a&b');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      requests.last.url.toString(),
      '$_base/my?filter=a%26b&limit=10&page=1',
    );
  });

  testWidgets('deleting last row on page 2 refetches page 1', (tester) async {
    await pumpHome(tester, (request) async {
      if (request.method == 'DELETE') {
        return http.Response('{"message":"ok"}', 200);
      }
      return _list('Alpha', totalPages: 2);
    });
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.delete));
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    final tail = requests.sublist(requests.length - 2);
    expect(tail[0].method, 'DELETE');
    expect(tail[0].url.toString(), '$_base/$_id');
    expect(tail[1].url.toString(), '$_base/my?filter&limit=10&page=1');
  });

  testWidgets('delete failure shows server message', (tester) async {
    await pumpHome(tester, (request) async {
      if (request.method == 'DELETE') {
        return http.Response('{"message":"Failed to delete board"}', 400);
      }
      return _list('Alpha');
    });
    await tester.ensureVisible(find.byIcon(Icons.delete));
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Failed to delete board'), findsOneWidget);
  });

  testWidgets('project delete explains that child tasks are removed', (
    tester,
  ) async {
    await pumpHome(tester, (request) async {
      if (request.method == 'DELETE') {
        return http.Response('{"message":"ok"}', 200);
      }
      return _list('Alpha');
    });
    await tester.ensureVisible(find.byIcon(Icons.delete));
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Menghapus proyek ini juga menghapus semua kolom dan tugas di dalamnya. Tindakan ini tidak dapat dibatalkan.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(requests.where((request) => request.method == 'DELETE'), isEmpty);
  });

  testWidgets('stale response does not overwrite newer search result', (
    tester,
  ) async {
    final first = Completer<http.Response>();
    var calls = 0;
    await tester.runAsync(() async {});
    Network.client = MockClient((request) {
      requests.add(request);
      return ++calls == 1 ? first.future : Future.value(_list('Beta'));
    });
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.enterText(find.byType(TextField), 'b');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsOneWidget);
    first.complete(_list('Alpha'));
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
  });

  group('401 handling', () {
    final unauthorized = http.Response('{"message":"Error unauthorized"}', 401);

    Future<void> pumpWithLogin(
      WidgetTester tester,
      Future<http.Response> Function(http.Request) handler, {
      bool settle = true,
    }) async {
      Network.client = MockClient((request) {
        requests.add(request);
        return handler(request);
      });
      await tester.pumpWidget(const MyApp(homePage: HomePage()));
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        for (var attempt = 0; attempt < 10 && requests.isEmpty; attempt++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
      }
    }

    Future<String?> storedToken(WidgetTester tester) async => (await tester
        .runAsync<String?>(() => SessionManager.getTokenForEnvironment('qa')));

    testWidgets('401 on list clears session and opens Login', (tester) async {
      await pumpWithLogin(tester, (_) async => unauthorized);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Sesi berakhir, silakan login kembali'), findsNothing);
      expect(await storedToken(tester), isNull);
    });

    testWidgets('401 on delete clears session and opens Login', (tester) async {
      await pumpWithLogin(tester, (request) async {
        return request.method == 'DELETE' ? unauthorized : _list('Alpha');
      });
      await tester.ensureVisible(find.byIcon(Icons.delete));
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(await storedToken(tester), isNull);
    });

    testWidgets('non-401 error keeps session and stays on page', (
      tester,
    ) async {
      await pumpWithLogin(
        tester,
        (_) async => http.Response('{"message":"boom"}', 500),
      );
      expect(find.byType(LoginPage), findsNothing);
      expect(find.text('boom'), findsOneWidget);
      expect(await storedToken(tester), 't');
    });

    testWidgets('stale 401 after logout does not navigate again', (
      tester,
    ) async {
      final first = Completer<http.Response>();
      await pumpWithLogin(tester, (_) => first.future, settle: false);
      expect(requests, hasLength(1));
      await tester.runAsync(EnvironmentConfig.logout);
      first.complete(unauthorized);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('stale 401 after environment switch keeps the new session', (
      tester,
    ) async {
      final first = Completer<http.Response>();
      await pumpWithLogin(tester, (_) => first.future, settle: false);
      expect(requests, hasLength(1));
      await tester.runAsync(() async {
        await EnvironmentConfig.select(BackendEnvironment.dev);
        await SessionManager.setSession({
          'access_token': 'dev-token',
        }, environment: 'dev');
      });
      first.complete(unauthorized);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsNothing);
      expect(
        await tester.runAsync(
          () => SessionManager.getTokenForEnvironment('dev'),
        ),
        'dev-token',
      );
    });
  });
}
