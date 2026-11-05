import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:my_mobile_app/session_manager.dart';

class _FailingSessionRemovalStore extends InMemorySharedPreferencesStore {
  _FailingSessionRemovalStore(super.data) : super.withData();

  @override
  Future<bool> remove(String key) async {
    if (key.endsWith(SessionManager.sessionKey)) return false;
    return super.remove(key);
  }
}

class _ClearSessionStore extends InMemorySharedPreferencesStore {
  _ClearSessionStore(
    super.data, {
    this.markerResult = true,
    this.sessionResult = true,
    this.environmentResult = true,
    this.throwOnSessionRemoval = false,
  }) : super.withData();

  final bool markerResult;
  final bool sessionResult;
  final bool environmentResult;
  final bool throwOnSessionRemoval;
  final attempted = <String>[];

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith('SESSION_INVALIDATED')) {
      attempted.add('marker');
      if (!markerResult) return false;
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (key.endsWith(SessionManager.sessionKey)) {
      attempted.add('session');
      if (throwOnSessionRemoval) throw StateError('session removal failed');
      if (!sessionResult) return false;
    } else if (key.endsWith('SESSION_ENVIRONMENT')) {
      attempted.add('environment');
      if (!environmentResult) return false;
    }
    return super.remove(key);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      SessionManager.sessionKey: '{"access_token":"old-token"}',
      'SESSION_ENVIRONMENT': 'qa',
      'unrelated': 'keep',
    });
    SessionManager.resetForTesting();
  });

  test('failed marker still removes session and environment', () async {
    final store = _ClearSessionStore({
      'flutter.${SessionManager.sessionKey}':
          '{"access_token":"old-token"}',
      'flutter.SESSION_ENVIRONMENT': 'qa',
    }, markerResult: false);
    SharedPreferencesStorePlatform.instance = store;

    await expectLater(SessionManager.clearSession(), throwsStateError);

    expect(store.attempted, ['marker', 'session', 'environment']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SessionManager.sessionKey), isNull);
    expect(prefs.getString('SESSION_ENVIRONMENT'), isNull);
    expect(await SessionManager.getSessionForEnvironment('qa'), isNull);
  });

  test('session removal throw does not skip environment removal', () async {
    final store = _ClearSessionStore({
      'flutter.${SessionManager.sessionKey}':
          '{"access_token":"old-token"}',
      'flutter.SESSION_ENVIRONMENT': 'qa',
    }, throwOnSessionRemoval: true);
    SharedPreferencesStorePlatform.instance = store;

    await expectLater(SessionManager.clearSession(), throwsStateError);

    expect(store.attempted, ['marker', 'session', 'environment']);
    expect(await SessionManager.getSessionForEnvironment('qa'), isNull);
  });

  test('durable clear failures do not claim restart invalidation', () async {
    final store = _ClearSessionStore({
      'flutter.${SessionManager.sessionKey}':
          '{"access_token":"old-token"}',
      'flutter.SESSION_ENVIRONMENT': 'qa',
    }, markerResult: false, sessionResult: false, environmentResult: false);
    SharedPreferencesStorePlatform.instance = store;

    await expectLater(SessionManager.clearSession(), throwsStateError);
    expect(store.attempted, ['marker', 'session', 'environment']);
    expect(await SessionManager.getSessionForEnvironment('qa'), isNull);

    await (await SharedPreferences.getInstance()).reload();
    SessionManager.resetForTesting();
    expect(await SessionManager.getSessionForEnvironment('qa'), {
      'access_token': 'old-token',
    });
  });

  test('startup rejects invalidated and incomplete sessions', () async {
    SharedPreferences.setMockInitialValues({
      SessionManager.sessionKey: '{"access_token":"old-token"}',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_INVALIDATED': true,
    });
    expect(await SessionManager.getSessionForEnvironment('qa'), isNull);
    expect(await SessionManager.getSession(), isNull);

    SharedPreferences.setMockInitialValues({
      SessionManager.sessionKey: '{"access_token":"old-token"}',
    });
    SessionManager.resetForTesting();
    expect(await SessionManager.getSession(), isNull);
  });

  test('failed removal stays invalid after simulated restart', () async {
    final store = _FailingSessionRemovalStore({
      'flutter.${SessionManager.sessionKey}':
          '{"access_token":"old-token"}',
      'flutter.SESSION_ENVIRONMENT': 'qa',
      'flutter.unrelated': 'keep',
    });
    SharedPreferencesStorePlatform.instance = store;

    await expectLater(SessionManager.clearSession(), throwsStateError);

    SessionManager.resetForTesting();
    expect(await SessionManager.getSessionForEnvironment('qa'), isNull);
    expect((await SharedPreferences.getInstance()).getString('unrelated'), 'keep');
  });

  test('successful session renewal removes invalidation marker', () async {
    await SessionManager.clearSession();
    expect(await SessionManager.getSessionForEnvironment('qa'), isNull);

    await SessionManager.setSession(
      {'access_token': 'new-token'},
      environment: 'qa',
    );

    expect(
      await SessionManager.getTokenForEnvironment('qa'),
      'new-token',
    );
    expect((await SharedPreferences.getInstance()).getString('unrelated'), 'keep');
  });
}
