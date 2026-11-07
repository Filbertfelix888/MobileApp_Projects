import 'dart:async';
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

const _base = 'http://43.173.10.180:3030/api/v1/boards';
const _id = '11111111-1111-1111-1111-111111111111';

http.Response _list(String title, int totalPages) => http.Response(
  jsonEncode({
    'status': 'Success',
    'response_code': 200,
    'data': [
      {
        'public_id': _id,
        'title': title,
        'description': 'Description',
        'created_at': '2026-11-01T08:00:00Z',
      },
    ],
    'meta': {'page': 1, 'limit': 10, 'total': 3, 'total_pages': totalPages},
  }),
  200,
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

  testWidgets(
    'delayed delete does not roll back after page context is refreshed',
    (tester) async {
      final deleteResponse = Completer<http.Response>();
      Network.client = MockClient((request) {
        requests.add(request);
        if (request.method == 'DELETE') return deleteResponse.future;
        final page = request.url.queryParameters['page'];
        return Future.value(_list('Page $page', 3));
      });

      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('Halaman 2 dari 3'), findsOneWidget);

      await tester.ensureVisible(find.byIcon(Icons.delete));
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('Halaman 3 dari 3'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('Halaman 2 dari 3'), findsOneWidget);

      deleteResponse.complete(http.Response('{"message":"ok"}', 200));
      await tester.pumpAndSettle();

      expect(find.text('Halaman 2 dari 3'), findsOneWidget);
      expect(requests.last.url.toString(), '$_base/my?filter&limit=10&page=2');
    },
  );

  testWidgets(
    'delayed delete on last page refetches page 1 after total pages shrink',
    (tester) async {
      final deleteResponse = Completer<http.Response>();
      var totalPages = 2;
      Network.client = MockClient((request) {
        requests.add(request);
        if (request.method == 'DELETE') return deleteResponse.future;
        final page = request.url.queryParameters['page'];
        if (page == '2' && totalPages == 1) {
          return Future.value(
            http.Response('{"data":[],"meta":{"total_pages":1}}', 200),
          );
        }
        return Future.value(_list('Page $page', totalPages));
      });

      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('Halaman 2 dari 2'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);

      await tester.ensureVisible(find.byIcon(Icons.delete));
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      totalPages = 1;
      deleteResponse.complete(http.Response('{"message":"ok"}', 200));
      await tester.pumpAndSettle();

      expect(find.text('Halaman 1 dari 1'), findsOneWidget);
      expect(find.text('Page 1'), findsOneWidget);
      expect(requests.last.url.toString(), '$_base/my?filter&limit=10&page=1');
    },
  );
}
