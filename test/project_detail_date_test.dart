import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/network.dart';
import 'package:my_mobile_app/Project/project_detail_page.dart';
import 'package:my_mobile_app/session_manager.dart';

void main() {
  const id = '11111111-1111-1111-1111-111111111111';
  late String created;
  late String due;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"t"}',
    });
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
    created = DateTime.parse('2026-11-01T01:00:00+07:00')
        .toLocal()
        .toIso8601String()
        .split('T')
        .first;
    due = DateTime.parse('2026-11-04T17:00:00Z')
        .toLocal()
        .toIso8601String()
        .split('T')
        .first;
    Network.client = MockClient((_) async => http.Response(
          jsonEncode({
            'status': 'Success',
            'response_code': 200,
            'data': {
              'public_id': id,
              'title': 'Alpha',
              'description': 'Date test',
              'created_at': '2026-11-01T01:00:00+07:00',
              'due_date': '2026-11-04T17:00:00Z',
            },
          }),
          200,
        ));
  });

  tearDown(() => Network.client.close());

  testWidgets('converts timestamps to local calendar dates', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ProjectDetailPage(boardId: id),
    ));
    await tester.pumpAndSettle();

    expect(find.text(created), findsOneWidget);
    expect(find.text(due), findsOneWidget);
  });
}
