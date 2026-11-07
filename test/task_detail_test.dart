import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mobile_app/Task/task_form_dialog.dart';
import 'package:my_mobile_app/Task/task_models.dart';
import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/network.dart';
import 'package:my_mobile_app/session_manager.dart';

const _columnId = '22222222-2222-2222-2222-222222222222';

void main() {
  late List<http.Request> requests;
  late Future<bool?> dialogResult;
  late Future<void> Function(WidgetTester tester) showForm;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"t"}',
    });
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
    requests = [];
    Network.client = MockClient((request) async {
      requests.add(request);
      return http.Response('{"data":{}}', 200);
    });
    showForm = (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  dialogResult = showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => TaskFormDialog(
                      boardId: '11111111-1111-1111-1111-111111111111',
                      isBoardCurrent: () => true,
                      column: const KanbanColumn(
                        internalId: 3,
                        publicId: _columnId,
                        boardPublicId: '11111111-1111-1111-1111-111111111111',
                        title: 'Ready',
                        position: 1,
                        createdAt: '2026-11-01T00:00:00Z',
                      ),
                      nextPosition: 4,
                      expectedGeneration: EnvironmentConfig.generation,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    };
  });

  tearDown(() => Network.client.close());

  testWidgets('rejects blank title without sending request', (tester) async {
    await showForm(tester);
    await tester.tap(find.text('Buat tugas'));
    await tester.pumpAndSettle();
    expect(find.text('Judul wajib diisi'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('creates trimmed title and omits absent deadline', (
    tester,
  ) async {
    await showForm(tester);
    await tester.enterText(
      find.byType(TextFormField).first,
      '  Ship feature  ',
    );
    await tester.enterText(find.byType(TextFormField).last, 'Description');
    await tester.tap(find.text('Buat tugas'));
    await tester.pumpAndSettle();
    expect(await dialogResult, isTrue);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/v1/cards');
    expect(jsonDecode(requests.single.body), {
      'list_id': _columnId,
      'title': 'Ship feature',
      'description': 'Description',
      'position': 4,
    });
  });

  testWidgets('accepts Unicode titles within the backend character limit', (
    tester,
  ) async {
    final title = List.filled(128, '😀').join();
    await showForm(tester);
    await tester.enterText(find.byType(TextFormField).first, title);
    await tester.tap(find.text('Buat tugas'));
    await tester.pumpAndSettle();
    expect(await dialogResult, isTrue);
    final payload = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(payload['title'], title);
  });
  testWidgets('duplicate task submits dispatch one POST', (tester) async {
    final originalClient = Network.client;
    final response = Completer<http.Response>();
    Network.client = MockClient((request) async {
      requests.add(request);
      return response.future;
    });
    originalClient.close();

    await showForm(tester);
    await tester.enterText(find.byType(TextFormField).first, 'One request');
    await tester.tap(find.text('Buat tugas'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pump();
    expect(requests, hasLength(1));
    response.complete(http.Response('{"data":{}}', 200));
    await tester.pumpAndSettle();
    expect(await dialogResult, isTrue);
    expect(requests, hasLength(1));
  });
}
