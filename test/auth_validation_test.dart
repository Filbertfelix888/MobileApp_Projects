import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mobile_app/System Login/login_page.dart';
import 'package:my_mobile_app/System Login/register_page.dart';
import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/network.dart';
import 'package:my_mobile_app/session_manager.dart';

void main() {
  const acceptedAddresses = ['user+tag@example.com', 'user@example.technology'];

  setUp(() {
    SharedPreferences.setMockInitialValues({'BACKEND_ENVIRONMENT': 'qa'});
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
  });

  tearDown(() => Network.client.close());

  for (final address in acceptedAddresses) {
    testWidgets('login submits $address to the backend', (tester) async {
      final requests = <http.Request>[];
      Network.client = MockClient((request) async {
        requests.add(request);
        return http.Response('{"message":"Test credential rejected"}', 400);
      });

      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, address);
      await tester.enterText(find.byType(TextFormField).last, 'test-password');
      await tester.tap(find.text('Masuk ke akun Anda'));
      await tester.pumpAndSettle();

      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/v1/auth/login');
      expect(
        (jsonDecode(requests.single.body) as Map<String, dynamic>)['email'],
        address,
      );
      expect(find.text('Format email tidak valid'), findsNothing);
    });

    testWidgets('registration submits $address to the backend', (tester) async {
      final requests = <http.Request>[];
      Network.client = MockClient((request) async {
        requests.add(request);
        return http.Response('{"message":"Test registration rejected"}', 400);
      });

      await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), address);
      await tester.enterText(find.byType(TextFormField).at(2), 'test-password');
      await tester.enterText(find.byType(TextFormField).at(3), 'test-password');
      await tester.tap(find.text('Buat Akun Baru'));
      await tester.pumpAndSettle();

      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/v1/auth/register');
      expect(
        (jsonDecode(requests.single.body) as Map<String, dynamic>)['email'],
        address,
      );
      expect(find.text('Format email tidak valid'), findsNothing);
    });
  }
}
