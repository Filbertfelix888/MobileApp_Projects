import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mobile_app/Home/home_page.dart';
import 'package:my_mobile_app/System Login/login_page.dart';
import 'package:my_mobile_app/Project/project_detail_page.dart';
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
  String createdAt = '2026-11-01T08:00:00Z',
  String? dueDate,
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
                'created_at': createdAt,
                'due_date': dueDate,
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
    await tester.tap(find.widgetWithText(FilledButton, 'Buat proyek baru'));
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
    expect(find.byType(Dialog), findsNothing);
    expect(requests.where((request) => request.method == 'GET').length, 2);
  });
  testWidgets('selected deadline survives create, refresh, and reopen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    final selectedDeadline = DateTime(now.year + 1, 1, 30);
    final expectedDeadline = selectedDeadline
        .toIso8601String()
        .split('T')
        .first;
    final monthsToAdvance =
        (selectedDeadline.year - now.year) * 12 +
        selectedDeadline.month -
        now.month;
    final createdAt = DateTime(
      now.year,
      now.month,
      1,
      8,
    ).toUtc().toIso8601String();
    String? persistedDueDate;

    Network.client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST' && request.url.path == '/api/v1/boards') {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        persistedDueDate = payload['due_date'] as String?;
        return http.Response(
          jsonEncode({
            'message': 'Board Created Successfully',
            'data': {
              'public_id': _id,
              'title': 'Deadline probe',
              'description': 'Date persistence test',
              'created_at': createdAt,
              'due_date': persistedDueDate,
            },
          }),
          200,
        );
      }
      if (request.method == 'GET' && request.url.path == '/api/v1/boards/my') {
        return _list(
          'Deadline probe',
          createdAt: createdAt,
          dueDate: persistedDueDate,
          empty: persistedDueDate == null,
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/boards/$_id') {
        return http.Response(
          jsonEncode({
            'status': 'Success',
            'response_code': 200,
            'data': {
              'public_id': _id,
              'title': 'Deadline probe',
              'description': 'Date persistence test',
              'created_at': createdAt,
              'due_date': persistedDueDate,
            },
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/lists')) {
        return http.Response('{"data":{"Lists":[]}}', 200);
      }
      if (request.url.path.endsWith('/members') ||
          request.url.path.endsWith('/cards')) {
        return http.Response('{"data":[]}', 200);
      }
      return http.Response('{"message":"Unexpected request"}', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: const HomePage(),
        onGenerateRoute: (settings) {
          if (settings.name == '/projects/$_id') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const ProjectDetailPage(boardId: _id),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Buat proyek baru'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Deadline probe');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Date persistence test',
    );
    await tester.tap(find.byType(TextFormField).at(2));
    await tester.pumpAndSettle();
    for (var month = 0; month < monthsToAdvance; month++) {
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('30').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(2))
          .controller!
          .text,
      expectedDeadline,
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    final post = requests.singleWhere(
      (request) =>
          request.method == 'POST' && request.url.path == '/api/v1/boards',
    );
    expect(
      DateTime.parse(persistedDueDate!)
          .toLocal()
          .toIso8601String()
          .substring(0, 10),
      expectedDeadline,
    );
    final localCreatedDate = DateTime.parse(createdAt)
        .toLocal()
        .toIso8601String()
        .split('T')
        .first;
    expect(find.text('Dibuat $localCreatedDate'), findsOneWidget);
    expect(find.text('Tenggat $expectedDeadline'), findsOneWidget);

    await tester.tap(find.text('Detail proyek'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Detail proyek'));
    await tester.pumpAndSettle();
    expect(find.text(expectedDeadline), findsOneWidget);
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Detail proyek'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Detail proyek'));
    await tester.pumpAndSettle();
    expect(find.text(expectedDeadline), findsOneWidget);
    expect(
      requests.where(
        (request) =>
            request.method == 'GET' &&
            request.url.path == '/api/v1/boards/$_id',
      ),
      hasLength(2),
    );
    expect(post.headers['authorization'], 'Bearer t');
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
    await tester.tap(find.widgetWithText(FilledButton, 'Buat proyek baru'));
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
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Buat proyek baru'),
      ),
      findsOneWidget,
    );
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
    expect(find.byType(Dialog), findsNothing);
    expect(requests.where((request) => request.method == 'GET').length, 2);
  });

  testWidgets('renders created and deadline dates from real envelope', (
    tester,
  ) async {
    const dueAt = '2026-11-30T00:00:00Z';
    await pumpHome(tester, (_) async => _list('Alpha', dueDate: dueAt));
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    final createdDate = DateTime.parse('2026-11-01T08:00:00Z')
        .toLocal()
        .toIso8601String()
        .split('T')
        .first;
    final dueDate = DateTime.parse(dueAt)
        .toLocal()
        .toIso8601String()
        .split('T')
        .first;
    expect(find.text(createdDate), findsOneWidget);
    expect(find.text(dueDate), findsOneWidget);
    expect(requests.single.url.toString(), '$_base/my?filter&limit=10&page=1');
  });
  testWidgets('mobile project list exposes detail and safe delete controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Network.client = MockClient((request) async {
      requests.add(request);
      return _list('Alpha', dueDate: '2026-11-30T00:00:00Z');
    });
    await tester.pumpWidget(
      MaterialApp(
        home: const HomePage(),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text(settings.name ?? 'detail')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DataTable), findsNothing);
    expect(find.text('First'), findsOneWidget);
    final dueDate = DateTime.parse('2026-11-30T00:00:00Z')
        .toLocal()
        .toIso8601String()
        .split('T')
        .first;
    expect(find.text('Tenggat $dueDate'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Detail proyek'),
      findsOneWidget,
    );
    expect(find.byTooltip('Hapus proyek Alpha'), findsOneWidget);

    await tester.tap(find.text('Detail proyek'));
    await tester.pumpAndSettle();
    expect(find.text('/projects/$_id'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hapus proyek Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(requests.where((request) => request.method == 'DELETE'), isEmpty);
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
    await tester.ensureVisible(find.byIcon(Icons.delete_outline));
    await tester.tap(find.byIcon(Icons.delete_outline));
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
    await tester.ensureVisible(find.byIcon(Icons.delete_outline));
    await tester.tap(find.byIcon(Icons.delete_outline));
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
    await tester.ensureVisible(find.byIcon(Icons.delete_outline));
    await tester.tap(find.byIcon(Icons.delete_outline));
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
      await tester.ensureVisible(find.byIcon(Icons.delete_outline));
      await tester.tap(find.byIcon(Icons.delete_outline));
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
