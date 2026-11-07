import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mobile_app/Home/home_page.dart';
import 'package:my_mobile_app/Project/project_detail_page.dart';
import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/network.dart';
import 'package:my_mobile_app/session_manager.dart';

const _id = '11111111-1111-1111-1111-111111111111';
const _createdAt = '2026-11-01T20:00:00Z';

void main() {
  final board = {
    'public_id': _id,
    'title': 'Alpha',
    'description': 'First',
    'created_at': _createdAt,
  };
  final localCreatedDate = DateTime.parse(_createdAt)
      .toLocal()
      .toIso8601String()
      .split('T')
      .first;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"t"}',
    });
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
    Network.client = MockClient((request) async {
      if (request.url.path.endsWith('/boards/my')) {
        return http.Response(
          jsonEncode({
            'status': 'Success',
            'response_code': 200,
            'data': [board],
            'meta': {'page': 1, 'limit': 10, 'total': 1, 'total_pages': 1},
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/lists')) {
        return http.Response('{"data":{"Lists":[]}}', 200);
      }
      if (request.url.path.endsWith('/members')) {
        return http.Response('{"data":[]}', 200);
      }
      if (request.url.path.endsWith('/cards')) {
        return http.Response('{"data":[]}', 200);
      }
      return http.Response(
        jsonEncode({'status': 'Success', 'response_code': 200, 'data': board}),
        200,
      );
    });
  });

  tearDown(() => Network.client.close());

  testWidgets('list and detail show created_at in device-local date', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const HomePage(),
        onGenerateRoute: (settings) {
          final name = settings.name ?? '';
          if (name.startsWith('/projects/')) {
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

    expect(find.text(localCreatedDate), findsOneWidget);

    await tester.ensureVisible(find.text('DETAIL PROYEK'));
    await tester.tap(find.text('DETAIL PROYEK'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectDetailPage), findsOneWidget);

    expect(find.text(localCreatedDate), findsOneWidget);
  });
}
