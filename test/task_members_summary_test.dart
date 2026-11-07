import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mobile_app/Task/board_members_dialog.dart';
import 'package:my_mobile_app/Task/task_models.dart';
import 'package:my_mobile_app/Task/task_summary.dart';
import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/network.dart';
import 'package:my_mobile_app/session_manager.dart';

const _board = '11111111-1111-1111-1111-111111111111';
const _a = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const _b = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const _c = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Map<String, dynamic> _user(String id, String name, String email) => {
  'public_id': id,
  'name': name,
  'email': email,
  'password': 'must-never-be-retained',
  'internal_id': 99,
};

KanbanColumn _column(String id, int internalId, String title) => KanbanColumn(
  internalId: internalId,
  publicId: id,
  boardPublicId: _board,
  title: title,
  position: internalId,
  createdAt: '2026-11-01T00:00:00Z',
);

TaskCard _card(
  String id,
  int listId, {
  String title = 'Task',
  String? dueDate,
  List<TaskAssignee> assignees = const [],
}) => TaskCard(
  internalId: 1,
  publicId: id,
  listInternalId: listId,
  title: title,
  description: '',
  position: 1,
  createdAt: '2026-11-01T00:00:00Z',
  dueDate: dueDate,
  assignees: assignees,
);

TaskAssignee _assignee(String id, String name) => TaskAssignee(
  user: TaskUser(publicId: id, name: name, email: '$id@x.test'),
);

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

  group('summary', () {
    test('computes board-local counts, workload, and date buckets', () {
      final first = _column('first', 1, 'Backlog');
      final second = _column('second', 2, 'Doing');
      final today = DateTime(2026, 11, 10);
      final summary = computeTaskSummary(
        columns: [first, second],
        tasksByColumn: {
          'first': [
            _card(
              't1',
              1,
              title: 'Overdue',
              dueDate: '2026-11-09T00:00:00Z',
              assignees: [_assignee(_a, 'Sam'), _assignee(_b, 'Sam')],
            ),
            _card('t2', 1, title: 'Zero', dueDate: null),
          ],
          'second': [
            _card(
              't3',
              2,
              title: 'Today',
              dueDate: '2026-11-10T00:00:00Z',
              assignees: [_assignee(_a, 'Sam')],
            ),
          ],
        },
        today: today,
      );
      expect(summary.totalTasks, 3);
      expect(summary.columns.map((item) => item.percentage), [66, 33]);
      expect(summary.workloads.map((row) => row.publicId), [_a, _b]);
      expect(summary.workloads.map((row) => row.taskCount), [2, 1]);
      expect(summary.unassignedCount, 1);
      expect(summary.overdueOrToday.map((entry) => entry.task.title), [
        'Overdue',
        'Today',
      ]);
    });

    testWidgets('renders the numeric unassigned task count', (tester) async {
      final column = _column('first', 1, 'Backlog');
      final summary = computeTaskSummary(
        columns: [column],
        tasksByColumn: {
          'first': [_card('unassigned-1', 1), _card('unassigned-2', 1)],
        },
        today: DateTime(2026, 11, 10),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskSummaryView(
              summary: summary,
              complete: true,
              onTaskOpen: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Belum ditugaskan'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.textContaining('Instance of'), findsNothing);
    });

    test('uses inclusive one-to-three day due-soon window only', () {
      final column = _column('first', 1, 'Any');
      final summary = computeTaskSummary(
        columns: [column],
        tasksByColumn: {
          'first': [
            _card('p1', 1, title: '+1', dueDate: '2026-11-11T00:00:00Z'),
            _card('p3', 1, title: '+3', dueDate: '2026-11-13T00:00:00Z'),
            _card('p4', 1, title: '+4', dueDate: '2026-11-14T00:00:00Z'),
            _card('zero', 1, title: 'zero', dueDate: '0001-01-01T00:00:00Z'),
          ],
        },
        today: DateTime(2026, 11, 10),
      );
      expect(summary.dueSoon.map((entry) => entry.task.title), ['+1', '+3']);
      expect(summary.overdueOrToday, isEmpty);
    });
  });

  group('members', () {
    Future<void> openMembers(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => BoardMembersDialog(
                    boardId: _board,
                    expectedGeneration: EnvironmentConfig.generation,
                    isViewCurrent: () => true,
                    onChanged: () {},
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('parses member envelope without exposing raw fields', (
      tester,
    ) async {
      Network.client = MockClient((request) async {
        requests.add(request);
        return _json({
          'data': [_user(_a, 'Ada', 'ada@x.test')],
        });
      });
      await openMembers(tester);
      await tester.pumpAndSettle();
      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('ada@x.test'), findsOneWidget);
      expect(find.textContaining('must-never-be-retained'), findsNothing);
      expect(requests.single.url.path, '/api/v1/boards/$_board/members');
    });

    testWidgets('empty member names and emails remain readable', (
      tester,
    ) async {
      Network.client = MockClient((request) async {
        requests.add(request);
        return _json({
          'data': [_user(_a, '', '')],
        });
      });
      await openMembers(tester);
      await tester.pumpAndSettle();
      expect(find.text('Tanpa nama'), findsOneWidget);
      expect(find.text('Email tidak tersedia'), findsOneWidget);
    });

    testWidgets('search page selection sends raw UUID array and refetches', (
      tester,
    ) async {
      var memberCalls = 0;
      Network.client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/members') && request.method == 'GET') {
          memberCalls++;
          return _json({
            'data': memberCalls == 1 ? [] : [_user(_b, 'Bea', 'bea@x.test')],
          });
        }
        if (request.url.path == '/api/v1/users/page') {
          return _json({
            'data': [
              {'public_id': _b, 'name': 'Bea', 'email': 'bea@x.test'},
            ],
            'meta': {'page': 1, 'limit': 10, 'total': 11, 'total_pages': 2},
          });
        }
        if (request.method == 'POST') return _json({'status': 'Success'});
        return _json({'message': 'unexpected'}, 404);
      });
      await openMembers(tester);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'be');
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
      expect(find.text('Halaman 1 dari 2'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Tambah (1)'));
      await tester.pumpAndSettle();
      final post = requests.singleWhere((request) => request.method == 'POST');
      expect(jsonDecode(post.body), [_b]);
      expect(
        requests
            .where((request) => request.url.path == '/api/v1/users/page')
            .first
            .url
            .queryParameters,
        {'filter': 'be', 'page': '1', 'limit': '10', 'sort': 'name'},
      );
      expect(find.text('Bea'), findsWidgets);
    });

    testWidgets('next page requests page 2 with the same search', (
      tester,
    ) async {
      Network.client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/members')) return _json({'data': []});
        if (request.url.path == '/api/v1/users/page') {
          final page = request.url.queryParameters['page'];
          return _json({
            'data': [
              {
                'public_id': page == '1' ? _b : _c,
                'name': page == '1' ? 'Page One' : 'Page Two',
                'email': 'p$page@x.test',
              },
            ],
            'meta': {'page': 1, 'limit': 10, 'total': 11, 'total_pages': 2},
          });
        }
        return _json({'message': 'unexpected'}, 404);
      });
      await openMembers(tester);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'pa');
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
      expect(find.text('Page One'), findsOneWidget);
      await tester.tap(find.byTooltip('Halaman berikutnya'));
      await tester.pumpAndSettle();
      expect(find.text('Page Two'), findsOneWidget);
      final pageRequests = requests
          .where((request) => request.url.path == '/api/v1/users/page')
          .toList();
      expect(pageRequests.last.url.queryParameters['page'], '2');
      expect(pageRequests.last.url.queryParameters['filter'], 'pa');
    });

    testWidgets(
      'session change during delayed search clears sensitive results',
      (tester) async {
        final delayed = Completer<http.Response>();
        Network.client = MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/members')) return _json({'data': []});
          if (request.url.path == '/api/v1/users/page') return delayed.future;
          return _json({'message': 'unexpected'}, 404);
        });
        await openMembers(tester);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'old');
        await tester.pump(const Duration(milliseconds: 1100));
        await tester.runAsync(() async {
          await EnvironmentConfig.select(BackendEnvironment.dev);
          await SessionManager.setSession({
            'access_token': 'dev',
          }, environment: 'dev');
        });
        delayed.complete(
          _json({
            'data': [
              {'public_id': _c, 'name': 'Old Result', 'email': 'old@x.test'},
            ],
            'meta': {'page': 1, 'limit': 10, 'total': 1, 'total_pages': 1},
          }),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('Old Result'), findsNothing);
        expect(find.textContaining('Sesi berubah'), findsWidgets);
      },
    );
  });
}
