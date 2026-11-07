import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mobile_app/Dashboard/dashboard_service.dart';
import 'package:my_mobile_app/Home/home_page.dart';
import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/network.dart';
import 'package:my_mobile_app/session_manager.dart';
import 'package:my_mobile_app/System Login/login_page.dart';
import 'package:my_mobile_app/System Login/register_page.dart';
import 'package:my_mobile_app/ui/Theme/theme_notifier.dart';
import 'package:my_mobile_app/ui/Theme/theme_tonggle.dart';

const _base = 'http://43.173.10.180:3030';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

http.Response _boards() => _json({
  'status': 'Success',
  'response_code': 200,
  'data': [
    {
      'public_id': '11111111-1111-1111-1111-111111111111',
      'title': 'Alpha',
      'description': 'First',
      'created_at': '2026-11-01T00:00:00Z',
    },
  ],
  'meta': {'page': 1, 'limit': 10, 'total': 1, 'total_pages': 1},
});

void main() {
  late List<http.Request> requests;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"token"}',
    });
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
    ThemeNotifier.themeMode.value = ThemeMode.light;
    requests = [];
  });

  tearDown(() => Network.client.close());

  testWidgets('theme toggle exposes 48dp target and updates its label', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ThemeToggle()));
    final enableDark = find.byTooltip('Aktifkan tema gelap');
    expect(enableDark, findsOneWidget);
    final targetSize = tester.getSize(enableDark);
    expect(targetSize.width, greaterThanOrEqualTo(48));
    expect(targetSize.height, greaterThanOrEqualTo(48));
    await tester.tap(enableDark);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Aktifkan tema terang'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('APP_THEME_MODE'), 'dark');
  });

  test('theme initialization restores saved mode', () async {
    SharedPreferences.setMockInitialValues({'APP_THEME_MODE': 'dark'});
    await ThemeNotifier.initialize();
    expect(ThemeNotifier.themeMode.value, ThemeMode.dark);
  });
  test('dashboard service parses raw workload array only', () async {
    Network.client = MockClient((request) async {
      requests.add(request);
      return _json([
        {'assignee': 'Ada', 'taskCount': 5},
        {'assignee': 'Lin', 'taskCount': 2},
        {'assignee': '', 'taskCount': 1},
      ]);
    });
    final workload = await DashboardService.getWorkload(
      expectedGeneration: EnvironmentConfig.generation,
    );
    expect(workload.map((row) => row.assignee), ['Ada', 'Lin', '']);
    expect(workload.map((row) => row.taskCount), [5, 2, 1]);
    expect(requests.single.method, 'GET');
    expect(requests.single.url.toString(), '$_base/api/v1/dashboard/workload');
    expect(requests.single.headers['authorization'], 'Bearer token');
  });

  test('dashboard service treats a null raw workload as empty', () async {
    Network.client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        'null',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final workload = await DashboardService.getWorkload(
      expectedGeneration: EnvironmentConfig.generation,
    );

    expect(workload, isEmpty);
    expect(requests.single.method, 'GET');
    expect(requests.single.url.toString(), '$_base/api/v1/dashboard/workload');
  });

  test('dashboard service rejects envelope instead of raw array', () async {
    Network.client = MockClient((_) async => _json({'data': []}));
    await expectLater(
      DashboardService.getWorkload(
        expectedGeneration: EnvironmentConfig.generation,
      ),
      throwsFormatException,
    );
  });

  testWidgets('Home dashboard displays global workload with API scope', (
    tester,
  ) async {
    Network.client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/boards/my')) return _boards();
      if (request.url.path == '/api/v1/dashboard/workload') {
        return _json([
          {'assignee': 'Alex', 'taskCount': 3},
          {'assignee': 'Sam', 'taskCount': 1},
          {'assignee': '', 'taskCount': 1},
        ]);
      }
      return _json({'message': 'unexpected'}, 404);
    });
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analitik global'));
    await tester.pumpAndSettle();
    expect(find.text('Beban tugas'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Tanpa nama'), findsOneWidget);
    expect(
      find.textContaining('Nama anggota yang sama digabung'),
      findsOneWidget,
    );
    expect(find.text('persentase'), findsNothing);
  });

  testWidgets('re-entering analytics reloads changed assignment counts', (
    tester,
  ) async {
    var taskCount = 1;
    var workloadRequests = 0;
    Network.client = MockClient((request) async {
      if (request.url.path.endsWith('/boards/my')) return _boards();
      if (request.url.path == '/api/v1/dashboard/workload') {
        workloadRequests++;
        return _json([
          {'assignee': 'Alex', 'taskCount': taskCount},
        ]);
      }
      return _json({'message': 'unexpected'}, 404);
    });
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analitik global'));
    await tester.pumpAndSettle();
    expect(find.text('Jumlah penugasan: 1'), findsOneWidget);

    await tester.tap(find.text('Proyek'));
    await tester.pumpAndSettle();
    taskCount = 2;
    await tester.tap(find.text('Analitik global'));
    await tester.pumpAndSettle();
    expect(find.text('Jumlah penugasan: 2'), findsOneWidget);
    expect(workloadRequests, 2);

    taskCount = 3;
    await tester.tap(find.byTooltip('Muat ulang beban tugas'));
    await tester.pumpAndSettle();
    expect(find.text('Jumlah penugasan: 3'), findsOneWidget);
    expect(workloadRequests, 3);
  });

  testWidgets(
    'Home project GET failure has inline retry and preserves recovery',
    (tester) async {
      var attempts = 0;
      Network.client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/boards/my')) {
          attempts++;
          return attempts == 1
              ? _json({'message': 'Projects unavailable'}, 500)
              : _boards();
        }
        return _json({'message': 'unexpected'}, 404);
      });
      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      await tester.pumpAndSettle();
      expect(find.text('Gagal memuat proyek'), findsOneWidget);
      expect(find.text('Projects unavailable'), findsOneWidget);
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Gagal memuat proyek'), findsNothing);
      expect(attempts, 2);
    },
  );

  testWidgets('Home controls fit at 360px with large text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Network.client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/boards/my')) return _boards();
      return _json([
        {'assignee': 'Alex', 'taskCount': 1},
      ]);
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const HomePage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('BUAT PROYEK BARU'), findsOneWidget);
    await tester.tap(find.text('Analitik global'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Beban tugas'), findsOneWidget);
  });
  testWidgets('auth forms remain usable at large text in dark theme', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        routes: {'/signup': (_) => const RegisterPage()},
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const LoginPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Daftar baru'));
    await tester.tap(find.text('Daftar baru'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Daftar Baru'), findsOneWidget);
    expect(find.text('Buat Akun Baru'), findsOneWidget);
  });

  testWidgets('project creation dialog fits narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Network.client = MockClient((request) async {
      requests.add(request);
      return _boards();
    });
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BUAT PROYEK BARU'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Buat proyek baru'), findsOneWidget);
    final dialogRect = tester.getRect(find.byType(Dialog));
    expect(dialogRect.left, greaterThanOrEqualTo(0));
    expect(dialogRect.right, lessThanOrEqualTo(360));
  });
}
