import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mobile_app/Task/task_models.dart';
import 'package:my_mobile_app/Task/task_service.dart';
import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/network.dart';
import 'package:my_mobile_app/session_manager.dart';

const _base = 'http://43.173.10.180:3030';
const _board = '11111111-1111-1111-1111-111111111111';
const _column = '22222222-2222-2222-2222-222222222222';
const _task = '33333333-3333-3333-3333-333333333333';
const _user = '44444444-4444-4444-4444-444444444444';
const _stamp = '2026-11-05T12:00:00Z';

Map<String, dynamic> _columnJson({
  String id = _column,
  String title = 'Doing',
  int pos = 1,
}) => {
  'internal_id': pos,
  'public_id': id,
  'board_public_id': _board,
  'title': title,
  'position': pos,
  'created_at': _stamp,
};

Map<String, dynamic> _cardJson({
  String id = _task,
  int listInternalId = 1,
  String title = 'Task',
  String description = 'Details',
  String? dueDate = '2026-11-07T00:00:00Z',
}) => {
  'internal_id': 9,
  'public_id': id,
  'list_internal_id': listInternalId,
  'title': title,
  'description': description,
  'position': 3,
  'created_at': _stamp,
  'due_date': ?dueDate,
};

void main() {
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) responder;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"t"}',
    });
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
    requests = [];
    responder = (_) async => http.Response('{"data":[]}', 200);
    Network.client = MockClient((request) async {
      requests.add(request);
      return responder(request);
    });
  });

  tearDown(() => Network.client.close());

  test('columns parse data.Lists in server order', () async {
    responder = (_) async => http.Response(
      jsonEncode({
        'data': {
          'Lists': [
            _columnJson(id: _column, title: 'Second', pos: 2),
            _columnJson(id: _task, title: 'First', pos: 1),
          ],
        },
      }),
      200,
    );
    final columns = await TaskService.getColumns(_board, expectedGeneration: 0);
    expect(columns.map((c) => c.title), ['Second', 'First']);
    expect(
      requests.single.url.toString(),
      '$_base/api/v1/boards/$_board/lists',
    );
  });

  test('known null collection slots become empty collections', () async {
    responder = (_) async => http.Response('{"data":{"Lists":null}}', 200);
    expect(
      await TaskService.getColumns(_board, expectedGeneration: 0),
      isEmpty,
    );
    responder = (_) async => http.Response('{"data":null}', 200);
    expect(await TaskService.getTasks(_column, expectedGeneration: 0), isEmpty);
  });

  test('cards retain response order and null due date', () async {
    responder = (_) async => http.Response(
      jsonEncode({
        'data': [
          _cardJson(title: 'Later'),
          _cardJson(id: _user, title: 'Earlier', dueDate: null),
        ],
      }),
      200,
    );
    final cards = await TaskService.getTasks(_column, expectedGeneration: 0);
    expect(cards.map((card) => card.title), ['Later', 'Earlier']);
    expect(cards.last.dueDate, isNull);
    expect(
      requests.single.url.toString(),
      '$_base/api/v1/lists/$_column/cards',
    );
  });
  test('missing or malformed collection envelopes fail closed', () async {
    responder = (_) async => http.Response('{"data":{}}', 200);
    await expectLater(
      TaskService.getColumns(_board, expectedGeneration: 0),
      throwsFormatException,
    );
    responder = (_) async => http.Response('{"status":"Success"}', 200);
    await expectLater(
      TaskService.getTasks(_column, expectedGeneration: 0),
      throwsFormatException,
    );
  });

  test(
    'updatePayload preserves saved fields and only clears due date explicitly',
    () {
      final card = TaskCard.fromJson(_cardJson());
      expect(card.updatePayload(listId: _column), {
        'list_id': _column,
        'title': 'Task',
        'description': 'Details',
        'due_date': '2026-11-07T00:00:00Z',
        'position': 3,
      });
      expect(
        card.updatePayload(listId: _column, description: 'Changed')['title'],
        'Task',
      );
      expect(
        card.updatePayload(listId: _column, clearDueDate: true)['due_date'],
        isNull,
      );
    },
  );

  test('zero date normalizes to no deadline', () {
    expect(
      TaskCard.fromJson(_cardJson(dueDate: '0001-01-01T00:00:00Z')).dueDate,
      isNull,
    );
  });

  test(
    'member mutations send raw arrays; assignee DELETE sends JSON object body',
    () async {
      await BoardService.addMembers(_board, [_user], expectedGeneration: 0);
      await BoardService.removeMembers(_board, [_user], expectedGeneration: 0);
      await TaskService.addAssignees(_task, [_user], expectedGeneration: 0);
      await TaskService.removeAssignees(_task, [_user], expectedGeneration: 0);
      expect(requests.map((r) => r.method), [
        'POST',
        'DELETE',
        'POST',
        'DELETE',
      ]);
      expect(jsonDecode(requests[0].body), [_user]);
      expect(jsonDecode(requests[1].body), [_user]);
      expect(jsonDecode(requests[2].body), {
        'user_id': [_user],
      });
      expect(jsonDecode(requests[3].body), {
        'user_id': [_user],
      });
      expect(
        requests[1].url.toString(),
        '$_base/api/v1/boards/$_board/members',
      );
      expect(
        requests[3].url.toString(),
        '$_base/api/v1/cards/$_task/assignees',
      );
    },
  );

  test('search encodes query and maps exact empty 404 to empty page', () async {
    responder = (_) async =>
        http.Response('{"message":"not found","meta":{"total":0}}', 404);
    final page = await TaskService.searchUsers(
      search: 'a& b',
      page: 2,
      expectedGeneration: 0,
    );
    expect(page.users, isEmpty);
    expect(page.totalPages, 1);
    expect(requests.single.url.queryParameters['filter'], 'a& b');
    expect(requests.single.url.queryParameters['page'], '2');
    expect(requests.single.url.queryParameters['limit'], '10');
    expect(requests.single.url.queryParameters['sort'], 'name');
  });

  test('search rethrows 404 unless meta.total is exactly zero', () async {
    responder = (_) async =>
        http.Response('{"message":"Missing" ,"meta":{"total":1}}', 404);
    await expectLater(
      TaskService.searchUsers(search: 'x', expectedGeneration: 0),
      throwsA(isA<NetworkHttpException>()),
    );
  });

  test('malformed required entity fields throw FormatException', () {
    expect(
      () => KanbanColumn.fromJson({'public_id': _column}),
      throwsFormatException,
    );
    expect(
      () => TaskCard.fromJson({'public_id': _task}),
      throwsFormatException,
    );
  });

  test('empty display strings remain valid backend entities', () async {
    responder = (_) async => http.Response(
      jsonEncode({
        'data': {
          'Lists': [_columnJson(title: '')],
        },
      }),
      200,
    );
    final columns = await TaskService.getColumns(_board, expectedGeneration: 0);
    expect(columns.single.title, '');
    expect(columns.single.displayTitle, 'Tanpa judul');

    responder = (_) async => http.Response(
      jsonEncode({
        'data': [_cardJson(title: '')],
      }),
      200,
    );
    final cards = await TaskService.getTasks(_column, expectedGeneration: 0);
    expect(cards.single.title, '');
    expect(cards.single.displayTitle, 'Tanpa judul');

    final user = TaskUser.fromJson({
      'public_id': _user,
      'name': '',
      'email': '',
    });
    expect(user.displayName, 'Tanpa nama');
    expect(user.displayEmail, 'Email tidak tersedia');
  });

  test('stale generation blocks GET POST PUT and DELETE dispatch', () async {
    final calls = <Future<dynamic> Function()>[
      () => Network.get('/stale', expectedGeneration: -1),
      () => Network.post('/stale', [_user], expectedGeneration: -1),
      () => Network.put('/stale', {}, expectedGeneration: -1),
      () => Network.delete('/stale', payload: [_user], expectedGeneration: -1),
    ];
    for (final call in calls) {
      await expectLater(call(), throwsA(isA<StateError>()));
    }
    expect(requests, isEmpty);
  });

  test(
    'stale PUT and DELETE-body 401 preserve newer same-environment session',
    () async {
      final cases = <Future<void> Function(int)>[
        (generation) => TaskService.updateTask(_task, {
          'list_id': _column,
          'title': 'Task',
          'description': '',
          'due_date': null,
          'position': 1,
        }, expectedGeneration: generation),
        (generation) => TaskService.removeAssignees(_task, [
          _user,
        ], expectedGeneration: generation),
      ];

      for (final send in cases) {
        await SessionManager.setSession({
          'access_token': 'old',
        }, environment: 'qa');
        final generation = EnvironmentConfig.generation;
        final dispatched = Completer<void>();
        final response = Completer<http.Response>();
        Network.client = MockClient((request) {
          if (!dispatched.isCompleted) dispatched.complete();
          return response.future;
        });
        final pending = send(generation);
        await dispatched.future;
        expect(
          await EnvironmentConfig.saveSessionIfCurrent(generation, 'qa', {
            'access_token': 'new',
          }),
          isTrue,
        );
        response.complete(http.Response('{"message":"expired"}', 401));
        await expectLater(pending, throwsA(isA<UnauthorizedException>()));
        expect(
          (await SessionManager.getSessionForEnvironment(
            'qa',
          ))?['access_token'],
          'new',
        );
      }
    },
  );
}
