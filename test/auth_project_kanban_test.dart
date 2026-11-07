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
import 'package:my_mobile_app/ui/Theme/theme_notifier.dart';

const _board = '11111111-1111-1111-1111-111111111111';
const _column = '22222222-2222-2222-2222-222222222222';
const _task = '33333333-3333-3333-3333-333333333333';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

void main() {
  late List<http.Request> requests;

  setUp(() {
    SharedPreferences.setMockInitialValues({'BACKEND_ENVIRONMENT': 'qa'});
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
    ThemeNotifier.themeMode.value = ThemeMode.light;
    requests = [];
    Network.client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path == '/v1/auth/login') {
        return _json({
          'data': {
            'access_token': 'test-token',
            'user': {'name': 'QA User'},
          },
        });
      }
      if (path == '/api/v1/boards/my') {
        return _json({
          'data': [
            {
              'public_id': _board,
              'title': 'QA Project',
              'description': 'Integration fixture',
              'created_at': '2026-11-01T00:00:00Z',
              'due_date': null,
            },
          ],
          'meta': {'page': 1, 'limit': 10, 'total': 1, 'total_pages': 1},
        });
      }
      if (path == '/api/v1/boards/$_board') {
        return _json({
          'data': {
            'public_id': _board,
            'title': 'QA Project',
            'description': 'Integration fixture',
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
        return _json({'data': []});
      }
      if (path == '/api/v1/lists/$_column/cards') {
        return _json({
          'data': [
            {
              'internal_id': 7,
              'public_id': _task,
              'list_internal_id': 1,
              'title': 'Task after login',
              'description': 'Protected workspace fixture',
              'position': 1,
              'created_at': '2026-11-01T00:00:00Z',
            },
          ],
        });
      }
      return _json({'message': 'Unexpected request $path'}, 404);
    });
  });

  tearDown(() => Network.client.close());

  testWidgets('login reaches project list and protected Kanban board', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Masuk'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'user+tag@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'test-password');
    await tester.tap(find.text('Masuk ke akun Anda'));
    await tester.pumpAndSettle();

    expect(find.text('Daftar Proyek'), findsOneWidget);
    expect(find.text('QA Project'), findsOneWidget);
    expect(
      requests
          .singleWhere((request) => request.url.path == '/v1/auth/login')
          .headers['authorization'],
      isNull,
    );

    await tester.ensureVisible(find.text('Detail proyek'));
    await tester.tap(find.text('Detail proyek'));
    await tester.pumpAndSettle();

    expect(find.text('QA Project'), findsWidgets);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Task after login'), findsOneWidget);

    final protectedRequests = requests.where(
      (request) => request.url.path.startsWith('/api/v1/'),
    );
    expect(protectedRequests, isNotEmpty);
    expect(
      protectedRequests.every(
        (request) => request.headers['authorization'] == 'Bearer test-token',
      ),
      isTrue,
    );
    expect(
      requests.any((request) => request.url.path.contains('/positions')),
      isFalse,
    );
  });
}
