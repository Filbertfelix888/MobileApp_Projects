import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mobile_app/Home/home_page.dart';
import 'package:my_mobile_app/Modal/modal_add_new_project.dart';
import 'package:my_mobile_app/Project/project_detail_page.dart';
import 'package:my_mobile_app/System Login/login_page.dart';
import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/main.dart';
import 'package:my_mobile_app/network.dart';
import 'package:my_mobile_app/session_manager.dart';

const _id = '11111111-1111-1111-1111-111111111111';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"t"}',
    });
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
  });

  tearDown(() => Network.client.close());

  testWidgets('current authenticated 401 clears session and opens Login', (
    tester,
  ) async {
    Network.client = MockClient((_) async => http.Response('{}', 401));

    await tester.pumpWidget(const MyApp(homePage: HomePage()));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(
      await tester.runAsync(() => SessionManager.getTokenForEnvironment('qa')),
      isNull,
    );
  });

  testWidgets('create 401 navigates through app-level login handler', (
    tester,
  ) async {
    Network.client = MockClient((_) async => http.Response('{}', 401));

    await tester.pumpWidget(const MyApp(homePage: _CreateHome()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open create'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Board');
    await tester.enterText(find.byType(TextFormField).at(1), 'Description');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(ModalAddNewProject), findsNothing);
    expect(
      await tester.runAsync(() => SessionManager.getTokenForEnvironment('qa')),
      isNull,
    );
  });

  testWidgets('detail 401 navigates after detail widget is disposed', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    http.Request? request;
    Network.client = MockClient((incoming) {
      request = incoming;
      return response.future;
    });

    await tester.pumpWidget(
      const MyApp(homePage: Scaffold(body: Text('home'))),
    );
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('home'))).pushNamed('/projects/$_id');
    await tester.pump();
    await tester.pump();
    expect(find.byType(ProjectDetailPage), findsOneWidget);
    expect(request?.method, 'GET');

    Navigator.of(tester.element(find.byType(ProjectDetailPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(ProjectDetailPage), findsNothing);

    response.complete(http.Response('{}', 401));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('stale 401 cannot invalidate a newer same-environment session', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    http.Request? request;
    Network.client = MockClient((incoming) {
      request = incoming;
      return response.future;
    });
    final generation = EnvironmentConfig.generation;

    await tester.pumpWidget(
      const MyApp(homePage: Scaffold(body: Text('home'))),
    );
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('home'))).pushNamed('/projects/$_id');
    await tester.pump();
    await tester.pump();
    expect(request?.headers['authorization'], 'Bearer t');

    final saved = await tester.runAsync(
      () => EnvironmentConfig.saveSessionIfCurrent(
        generation,
        'qa',
        {'access_token': 'new-token'},
      ),
    );
    expect(saved, isTrue);

    response.complete(http.Response('{}', 401));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(ProjectDetailPage), findsOneWidget);
    expect(
      await tester.runAsync(
        () => SessionManager.getTokenForEnvironment('qa'),
      ),
      'new-token',
    );
  });
}

class _CreateHome extends StatelessWidget {
  const _CreateHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => ModalAddNewProject(onSuccess: () {}),
          ),
          child: const Text('Open create'),
        ),
      ),
    );
  }
}
