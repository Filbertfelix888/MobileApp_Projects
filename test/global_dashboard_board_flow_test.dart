import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mobile_app/Home/home_page.dart';
import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/network.dart';
import 'package:my_mobile_app/session_manager.dart';
import 'package:my_mobile_app/main.dart';

const _board = '11111111-1111-1111-1111-111111111111';
const _column = '22222222-2222-2222-2222-222222222222';
const _task = '33333333-3333-3333-3333-333333333333';
const _user = '44444444-4444-4444-4444-444444444444';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

void main() {
  late List<http.Request> requests;
  late bool assigned;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"flow-token"}',
    });
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
    requests = [];
    assigned = false;
    Network.client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path == '/api/v1/boards/my') {
        return _json({
          'data': [
            {
              'public_id': _board,
              'title': 'Flow board',
              'description': 'Mutation analytics fixture',
              'created_at': '2026-11-01T00:00:00Z',
              'due_date': null,
            },
          ],
          'meta': {'page': 1, 'limit': 10, 'total': 1, 'total_pages': 1},
        });
      }
      if (path == '/api/v1/dashboard/workload') {
        return _json(
          assigned
              ? [
                  {'assignee': 'Ari', 'taskCount': 1},
                ]
              : [],
        );
      }
      if (path == '/api/v1/boards/$_board') {
        return _json({
          'data': {
            'public_id': _board,
            'title': 'Flow board',
            'description': 'Mutation analytics fixture',
            'created_at': '2026-11-01T00:00:00Z',
            'due_date': null,
          },
        });
      }
      if (path == '/api/v1/boards/$_board/lists') {
        return _json({
          'data': {
            'Lists': [
              {
                'internal_id': 1,
                'public_id': _column,
                'board_public_id': _board,
                'title': 'Ready',
                'position': 1,
                'created_at': '2026-11-01T00:00:00Z',
              },
            ],
          },
        });
      }
      if (path == '/api/v1/boards/$_board/members') {
        return _json({
          'data': [
            {
              'public_id': _user,
              'name': 'Ari',
              'email': 'ari@example.test',
              'password': 'fixture-secret-must-not-render',
            },
          ],
        });
      }
      if (path == '/api/v1/lists/$_column/cards') {
        return _json({
          'data': [
            {
              'internal_id': 7,
              'public_id': _task,
              'list_internal_id': 1,
              'title': 'Assign me',
              'description': 'Changing assignment changes global workload',
              'position': 1,
              'created_at': '2026-11-01T00:00:00Z',
            },
          ],
        });
      }
      if (path == '/api/v1/cards/$_task/assignees' &&
          request.method == 'POST') {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['user_id'], [_user]);
        assigned = true;
        return _json({'status': 'Success'});
      }
      if (path == '/api/v1/cards/$_task') {
        return _json({
          'data': {
            'internal_id': 7,
            'public_id': _task,
            'list_internal_id': 1,
            'title': 'Assign me',
            'description': 'Changing assignment changes global workload',
            'position': 1,
            'created_at': '2026-11-01T00:00:00Z',
            if (assigned)
              'assignees': [
                {
                  'user': {
                    'public_id': _user,
                    'name': 'Ari',
                    'email': 'ari@example.test',
                  },
                },
              ],
          },
        });
      }
      return _json({'message': 'Unexpected $path'}, 404);
    });
  });

  tearDown(() => Network.client.close());

  testWidgets(
    'assignee mutation in project refreshes global workload after return',
    (tester) async {
      await tester.pumpWidget(const MyApp(homePage: HomePage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Analitik global'));
      await tester.pumpAndSettle();
      expect(
        find.text('Belum ada tugas yang memiliki penanggung jawab.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Proyek'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('DETAIL PROYEK'));
      await tester.tap(find.text('DETAIL PROYEK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assign me'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ari@example.test'));
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();
      await tester.tap(find.text('Tugaskan (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Ari'), findsOneWidget);
      expect(find.text('fixture-secret-must-not-render'), findsNothing);
      expect(
        requests.where(
          (request) =>
              request.method == 'POST' &&
              request.url.path == '/api/v1/cards/$_task/assignees',
        ),
        hasLength(1),
      );

      await tester.tap(find.byTooltip('Tutup detail tugas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analitik global'));
      await tester.pumpAndSettle();

      expect(find.text('Jumlah penugasan: 1'), findsOneWidget);
      expect(find.text('Ari'), findsOneWidget);
      expect(
        requests.where(
          (request) => request.url.path == '/api/v1/dashboard/workload',
        ),
        hasLength(2),
      );
      expect(
        requests
            .where(
              (request) => request.url.path == '/api/v1/dashboard/workload',
            )
            .every(
              (request) =>
                  request.headers['authorization'] == 'Bearer flow-token',
            ),
        isTrue,
      );
      expect(
        requests.any((request) => request.url.path.contains('/positions')),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
