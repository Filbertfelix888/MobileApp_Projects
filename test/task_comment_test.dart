import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_mobile_app/Task/task_comment_section.dart';
import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/services/firebase_config.dart';
import 'package:my_mobile_app/services/firebase_service.dart';
import 'package:my_mobile_app/session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      SessionManager.sessionKey: jsonEncode({
        'access_token': 'test-token',
        'user': {
          'public_id': 'user-1',
          'name': 'JK',
          'email': 'jk@example.com',
        },
      }),
      'USER_PROFILE_qa_user-1': jsonEncode({
        'name': 'JK',
        'email': 'jk@example.com',
        'role': 'Mobile Developer',
        'avatar_color': 0xFF345BC7,
        'avatar_preset': 'initials',
        'has_custom_avatar': true,
      }),
    });
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
    FirebaseConfig.setDatabaseUrlForTesting('');
    FirebaseService.client = null;
  });

  tearDown(() {
    FirebaseConfig.resetForTesting();
    FirebaseService.client = null;
  });

  testWidgets(
    'TaskCommentSection supports adding, replying, right-aligned delete',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TaskCommentSection(taskId: 'task-123'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Diskusi & Komentar'), findsOneWidget);
      expect(find.text('Belum ada komentar'), findsOneWidget);

      // Add top-level comment
      await tester.enterText(
        find.byType(TextField),
        'UI sudah dirapikan.',
      );
      await tester.tap(find.byTooltip('Kirim Komentar'));
      await tester.pumpAndSettle();

      expect(find.text('UI sudah dirapikan.'), findsOneWidget);
      expect(find.text('JK'), findsOneWidget);
      expect(find.text('Mobile Developer'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Edit comment locally
      await tester.tap(find.byTooltip('Edit komentar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'UI sudah dirapikan banget.',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(find.text('UI sudah dirapikan banget.'), findsOneWidget);
      expect(find.text('(diedit)'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && (w.message ?? '').startsWith('Diedit '),
        ),
        findsOneWidget,
      );

      // Verify delete icon is aligned near the right edge of the section
      final sectionRect = tester.getRect(find.byType(TaskCommentSection));
      final deleteRect = tester.getRect(find.byTooltip('Hapus komentar'));
      expect(sectionRect.right - deleteRect.right, lessThan(40));

      // Reply to comment
      await tester.tap(find.text('Balas').first);
      await tester.pumpAndSettle();
      expect(find.text('Membalas JK'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Lanjut testing!');
      await tester.tap(find.byTooltip('Kirim Komentar'));
      await tester.pumpAndSettle();

      expect(find.text('Membalas @JK'), findsOneWidget);
      expect(find.text('Lanjut testing!'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Reply to the reply itself (button must exist on replies too)
      expect(find.text('Balas'), findsNWidgets(2));
      await tester.tap(find.text('Balas').last);
      await tester.pumpAndSettle();
      expect(find.text('Membalas JK'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Siap lanjut!');
      await tester.tap(find.byTooltip('Kirim Komentar'));
      await tester.pumpAndSettle();

      expect(find.text('Siap lanjut!'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Delete latest reply
      await tester.tap(find.byTooltip('Hapus komentar').last);
      await tester.pumpAndSettle();

      expect(find.text('Siap lanjut!'), findsNothing);
      expect(find.text('2'), findsOneWidget);

      // Delete first reply
      await tester.tap(find.byTooltip('Hapus komentar').last);
      await tester.pumpAndSettle();

      expect(find.text('Lanjut testing!'), findsNothing);
      expect(find.text('1'), findsOneWidget);
    },
  );

  testWidgets(
    'TaskCommentSection syncs remote comments and deletes via Firebase',
    (tester) async {
      FirebaseConfig.setDatabaseUrlForTesting(
        'https://demo-default-rtdb.firebasedatabase.app',
      );

      final Map<String, dynamic> remoteProfiles = {};
      final Map<String, dynamic> remoteComments = {
        '-O1existing': {
          'task_id': 'task-123',
          'author_name': 'Jerry',
          'author_email': 'jerry@example.com',
          'author_role': 'UI/UX Designer',
          'author_color': 0xFF1F6B45,
          'author_preset': 'initials',
          'content': 'Komentar dari perangkat lain',
          'created_at': '2026-11-28T08:00:00Z',
        },
      };

      final requests = <http.Request>[];
      FirebaseService.client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/profiles.json') {
          return http.Response(jsonEncode(remoteProfiles), 200);
        }
        if (request.method == 'GET' &&
            request.url.path == '/profiles/user-1.json') {
          return http.Response('null', 200);
        }
        if (request.method == 'GET' &&
            request.url.path == '/task_comments/task-123.json') {
          return http.Response(jsonEncode(remoteComments), 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/task_comments/task-123.json') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          remoteComments['-O1newId'] = body;
          return http.Response(jsonEncode({'name': '-O1newId'}), 200);
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/task_comments/task-123/-O1newId.json') {
          final updates = jsonDecode(request.body) as Map<String, dynamic>;
          remoteComments['-O1newId'] = {
            ...remoteComments['-O1newId'] as Map<String, dynamic>,
            ...updates,
          };
          return http.Response(jsonEncode(remoteComments['-O1newId']), 200);
        }
        if (request.method == 'DELETE' &&
            request.url.path == '/task_comments/task-123/-O1newId.json') {
          remoteComments.remove('-O1newId');
          return http.Response('null', 200);
        }
        return http.Response('null', 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TaskCommentSection(taskId: 'task-123'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Remote comment from Jerry should be visible immediately
      expect(find.text('Komentar dari perangkat lain'), findsOneWidget);
      expect(find.text('Jerry'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Post new comment -> sent to Firebase
      await tester.enterText(find.byType(TextField), 'Mantap, diterima!');
      await tester.tap(find.byTooltip('Kirim Komentar'));
      await tester.pumpAndSettle();

      expect(find.text('Mantap, diterima!'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(
        requests.any(
          (r) =>
              r.method == 'POST' &&
              r.url.path == '/task_comments/task-123.json',
        ),
        isTrue,
      );

      // Edit own comment -> sends PATCH to Firebase
      await tester.tap(find.byTooltip('Edit komentar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'Mantap, sudah diedit!',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(find.text('Mantap, sudah diedit!'), findsOneWidget);
      expect(find.text('(diedit)'), findsOneWidget);
      expect(
        requests.any(
          (r) =>
              r.method == 'PATCH' &&
              r.url.path == '/task_comments/task-123/-O1newId.json',
        ),
        isTrue,
      );

      // Delete own comment -> deletes Firebase key preserving case (-O1newId)
      await tester.tap(find.byTooltip('Hapus komentar'));
      await tester.pumpAndSettle();

      expect(find.text('Mantap, diterima!'), findsNothing);
      expect(find.text('1'), findsOneWidget);
      expect(
        requests.any(
          (r) =>
              r.method == 'DELETE' &&
              r.url.path == '/task_comments/task-123/-O1newId.json',
        ),
        isTrue,
      );

      // Type a draft and start replying, then simulate a remote comment arriving
      await tester.tap(find.text('Balas'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Lagi ngetik draft...');
      await tester.pump();

      remoteComments['-O1live'] = {
        'task_id': 'task-123',
        'author_name': 'Justyn',
        'author_email': 'justyn@example.com',
        'author_role': 'Backend Developer',
        'author_color': 0xFF6B3FA0,
        'author_preset': 'initials',
        'content': 'Komentar baru masuk live!',
        'created_at': '2026-11-28T09:00:00Z',
      };

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('Komentar baru masuk live!'), findsOneWidget);
      expect(find.text('Justyn'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Membalas Jerry'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Lagi ngetik draft...',
      );

      // Update Jerry's profile in Firebase -> old comment must sync to new PFP/role/name
      remoteProfiles['user-jerry'] = {
        'name': 'Jerry Updated',
        'email': 'jerry@example.com',
        'role': 'Lead Designer',
        'avatar_color': 0xFF6B3FA0,
        'avatar_preset': 'developer',
        'has_custom_avatar': true,
      };
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('Jerry Updated'), findsOneWidget);
      expect(find.text('Lead Designer'), findsOneWidget);
      expect(find.byIcon(Icons.code), findsOneWidget);
    },
  );
}
