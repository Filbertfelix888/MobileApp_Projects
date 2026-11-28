import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_mobile_app/Home/navbar_page.dart';
import 'package:my_mobile_app/Profile/edit_profile_page.dart';
import 'package:my_mobile_app/Profile/profile_store.dart';
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

  testWidgets('EditProfilePage validates, saves role/avatar/bio locally', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: EditProfilePage()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'JK'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'jk@example.com'),
      findsOneWidget,
    );

    // Clear name to verify validation
    await tester.enterText(find.widgetWithText(TextFormField, 'JK'), '');
    await tester.ensureVisible(find.text('Simpan Perubahan'));
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(find.text('Nama lengkap wajib diisi'), findsOneWidget);

    // Choose avatar preset
    await tester.ensureVisible(find.byKey(const ValueKey('avatar-developer')));
    await tester.tap(find.byKey(const ValueKey('avatar-developer')));
    await tester.pumpAndSettle();

    // Update name, role dropdown, phone, bio
    await tester.enterText(find.byType(TextFormField).at(0), 'JK Updated');

    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mobile Developer').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(2), '08123456789');
    await tester.enterText(
      find.byType(TextFormField).at(3),
      'Mobile app contributor',
    );

    await tester.ensureVisible(find.text('Simpan Perubahan'));
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    final saved = await ProfileStore.loadProfile();
    expect(saved.name, 'JK Updated');
    expect(saved.role, 'Mobile Developer');
    expect(saved.phone, '08123456789');
    expect(saved.bio, 'Mobile app contributor');
    expect(saved.avatarPreset, ProfileAvatarPreset.developer);
    expect(saved.hasCustomAvatar, isTrue);
  });

  test('ProfileStore syncs profile and photo with Firebase when configured', () async {
    FirebaseConfig.setDatabaseUrlForTesting(
      'https://demo-default-rtdb.firebasedatabase.app',
    );

    final Map<String, dynamic> remoteStorage = {};
    final requests = <http.Request>[];
    FirebaseService.client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'PUT' &&
          request.url.path == '/profiles/user-1.json') {
        remoteStorage['user-1'] = jsonDecode(request.body);
        return http.Response(request.body, 200);
      }
      if (request.method == 'GET' &&
          request.url.path == '/profiles/user-1.json') {
        return http.Response(
          jsonEncode(remoteStorage['user-1']),
          200,
        );
      }
      return http.Response('null', 404);
    });

    final tinyPngBase64 = base64Encode([137, 80, 78, 71, 13, 10, 26, 10]);
    await ProfileStore.saveProfile(
      ProfileData(
        name: 'JK Firebase',
        email: 'jk@example.com',
        role: 'Mobile Developer',
        avatarBase64: tinyPngBase64,
        hasCustomAvatar: true,
      ),
    );

    expect(
      requests.any(
        (r) => r.method == 'PUT' && r.url.path == '/profiles/user-1.json',
      ),
      isTrue,
    );

    // Clear local cache to verify loadProfile pulls from Firebase
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('USER_PROFILE_qa_user-1');

    final loaded = await ProfileStore.loadProfile();
    expect(loaded.name, 'JK Firebase');
    expect(loaded.role, 'Mobile Developer');
    expect(loaded.avatarBase64, tinyPngBase64);
  });

  testWidgets('Navbar profile menu opens EditProfilePage and refreshes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(appBar: Navbar())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Akun dan keluar'));
    await tester.pumpAndSettle();

    expect(find.text('Edit profil'), findsOneWidget);
    await tester.tap(find.text('Edit profil'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfilePage), findsOneWidget);
  });
}
