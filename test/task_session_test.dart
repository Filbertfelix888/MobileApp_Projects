import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mobile_app/System Login/login_page.dart';
import 'package:my_mobile_app/Task/board_members_dialog.dart';
import 'package:my_mobile_app/Task/kanban_board.dart';
import 'package:my_mobile_app/Task/task_detail_dialog.dart';
import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/main.dart';
import 'package:my_mobile_app/network.dart';
import 'package:my_mobile_app/session_manager.dart';

const _board = '11111111-1111-1111-1111-111111111111';
const _first = '22222222-2222-2222-2222-222222222222';
const _task = '55555555-5555-5555-5555-555555555555';
const _user = '66666666-6666-6666-6666-666666666666';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Map<String, dynamic> _column() => {
  'internal_id': 1,
  'public_id': _first,
  'board_public_id': _board,
  'title': 'Todo',
  'position': 1,
  'created_at': '2026-11-01T00:00:00Z',
};

Map<String, dynamic> _card() => {
  'internal_id': 7,
  'public_id': _task,
  'list_internal_id': 1,
  'title': 'Task A',
  'description': 'Description',
  'position': 1,
  'created_at': '2026-11-01T00:00:00Z',
};

Future<http.Response> _fixture(http.Request request) async {
  final path = request.url.path;
  if (path == '/api/v1/boards/$_board') {
    return _json({
      'data': {
        'public_id': _board,
        'title': 'Board',
        'description': 'Description',
        'created_at': '2026-11-01T00:00:00Z',
      },
    });
  }
  if (path.endsWith('/lists') && request.method == 'GET') {
    return _json({
      'data': {
        'Lists': [_column()],
      },
    });
  }
  if (path.endsWith('/members') && request.method == 'GET') {
    return _json({
      'data': [
        {'public_id': _user, 'name': 'Alex', 'email': 'alex@example.test'},
      ],
    });
  }
  if (path.endsWith('/cards') && request.method == 'GET') {
    return _json({
      'data': [_card()],
    });
  }
  if (path == '/api/v1/cards/$_task' && request.method == 'GET') {
    return _json({'data': _card()});
  }
  if (path == '/api/v1/users/page') {
    return _json({
      'data': [
        {
          'public_id': '77777777-7777-7777-7777-777777777777',
          'name': 'Blake',
          'email': 'blake@example.test',
        },
      ],
      'meta': {'page': 1, 'limit': 10, 'total': 1, 'total_pages': 1},
    });
  }
  return _json({'message': 'unexpected ${request.method} $path'}, 404);
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

  Future<void> openProject(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Network.client = MockClient((request) {
      requests.add(request);
      return handler(request);
    });
    await tester.pumpWidget(
      const MyApp(homePage: Scaffold(body: Text('home'))),
    );
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('home')))
        .pushNamed('/projects/$_board');
    await tester.pumpAndSettle();
  }

  Future<void> expectLoggedOut(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(TaskDetailDialog), findsNothing);
    expect(find.byType(BoardMembersDialog), findsNothing);
    expect(
      await tester.runAsync(() => SessionManager.getTokenForEnvironment('qa')),
      isNull,
    );
  }

  testWidgets('column mutation 401 closes dialogs and returns to Login', (
    tester,
  ) async {
    await openProject(tester, (request) async {
      if (request.method == 'POST' && request.url.path == '/api/v1/lists') {
        return _json({'message': 'expired'}, 401);
      }
      return _fixture(request);
    });
    await tester.tap(find.text('Tambah kolom').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Doing');
    await tester.tap(find.text('Simpan'));
    await expectLoggedOut(tester);
  });

  testWidgets('task update 401 closes detail and returns to Login', (
    tester,
  ) async {
    await openProject(tester, (request) async {
      if (request.method == 'PUT' &&
          request.url.path == '/api/v1/cards/$_task') {
        return _json({'message': 'expired'}, 401);
      }
      return _fixture(request);
    });
    await tester.tap(find.text('Task A'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Changed');
    await tester.pump();
    await tester.tap(find.text('Simpan perubahan'));
    await expectLoggedOut(tester);
  });

  testWidgets('assignee mutation 401 closes detail and returns to Login', (
    tester,
  ) async {
    await openProject(tester, (request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/assignees')) {
        return _json({'message': 'expired'}, 401);
      }
      return _fixture(request);
    });
    await tester.tap(find.text('Task A'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Tugaskan (1)'));
    await expectLoggedOut(tester);
  });

  testWidgets('board member mutation 401 closes member dialog', (tester) async {
    await openProject(tester, (request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/members')) {
        return _json({'message': 'expired'}, 401);
      }
      return _fixture(request);
    });
    await tester.tap(find.text('Anggota'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'alex');
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Tambah (1)'));
    await expectLoggedOut(tester);
  });

  testWidgets(
    'stale detail GET after environment switch never dispatches follow-up',
    (tester) async {
      final detail = Completer<http.Response>();
      await openProject(tester, (request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/cards/$_task') {
          return detail.future;
        }
        return _fixture(request);
      });
      await tester.tap(find.text('Task A'));
      await tester.pump();
      final before = requests.length;
      await tester.runAsync(() async {
        await EnvironmentConfig.select(BackendEnvironment.dev);
        await SessionManager.setSession({
          'access_token': 'dev-token',
        }, environment: 'dev');
      });
      detail.complete(_json({'data': _card()}));
      await tester.pumpAndSettle();
      expect(requests.length, before);
      expect(find.textContaining('Sesi berubah'), findsWidgets);
      expect(find.text('Task A'), findsNothing);
      expect(
        await tester.runAsync(
          () => SessionManager.getTokenForEnvironment('dev'),
        ),
        'dev-token',
      );
    },
  );

  testWidgets(
    'kanban board marks itself stale after pinned generation changes',
    (tester) async {
      Network.client = MockClient(_fixture);
      final generation = EnvironmentConfig.generation;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KanbanBoard(
              boardId: _board,
              boardTitle: 'Board',
              expectedGeneration: generation,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await EnvironmentConfig.select(BackendEnvironment.dev);
        await SessionManager.setSession({
          'access_token': 'dev-token',
        }, environment: 'dev');
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KanbanBoard(
              boardId: _board,
              boardTitle: 'Board',
              expectedGeneration: generation,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sesi berubah, buka ulang proyek'), findsWidgets);
      expect(find.text('Todo'), findsNothing);
    },
  );
}
