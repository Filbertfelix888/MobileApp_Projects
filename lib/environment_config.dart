import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'session_manager.dart';

enum BackendEnvironment { qa, dev }
typedef EnvironmentSnapshot = ({
  String baseUrl,
  String environment,
  int generation,
  String? accessToken,
});

class EnvironmentConfig {
  static const String _preferenceKey = 'BACKEND_ENVIRONMENT';
  static const String _qaUrl = 'http://43.173.10.180:3030';
  static const String _devUrl = 'http://10.0.2.2:3030';

  static final ValueNotifier<BackendEnvironment> selected =
      ValueNotifier(BackendEnvironment.qa);
  static final ValueNotifier<bool> switching = ValueNotifier(false);
  static Future<void>? _initializing;
  static Future<void>? _queue;
  static int _generation = 0;
  static int _switchCount = 0;
  static Completer<void>? _switchCompletion;
  @visibleForTesting
  static void resetForTesting() {
    _initializing = null;
    _queue = null;
    _generation = 0;
    _switchCount = 0;
    _switchCompletion = null;
    switching.value = false;
    selected.value = BackendEnvironment.qa;
  }

  static String get baseUrl => selected.value == BackendEnvironment.qa ? _qaUrl : _devUrl;
  static int get generation => _generation;

  static Future<void> initialize() => _initializing ??= _initialize().catchError(
    (Object error, StackTrace stackTrace) {
      _initializing = null;
      Error.throwWithStackTrace(error, stackTrace);
    },
  );

  static Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_preferenceKey);
    // The academic demo is QA-only: ignore any stored DEV preference.
    selected.value = BackendEnvironment.qa;
    if (saved != BackendEnvironment.qa.name) {
      await prefs.setString(_preferenceKey, BackendEnvironment.qa.name);
    }
    await SessionManager.invalidateUntaggedOrMismatchedSession(
      BackendEnvironment.qa.name,
    );
  }

  static Future<void> select(BackendEnvironment environment) async {
    if (_switchCount++ == 0) {
      _switchCompletion = Completer<void>();
      switching.value = true;
    }
    try {
      await initialize();
      await _serialize(() async {
        if (selected.value == environment) return;
        _generation++;
        await SessionManager.clearSession();
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(_preferenceKey, environment.name)) {
          throw StateError('Could not persist backend environment');
        }
        selected.value = environment;
      });
    } finally {
      if (--_switchCount == 0) {
        switching.value = false;
        _switchCompletion?.complete();
        _switchCompletion = null;
      }
    }
  }
  static Future<EnvironmentSnapshot> snapshot({
    bool includeAuth = false,
  }) async {
    await initialize();
    while (switching.value) {
      await _switchCompletion?.future;
    }
    return _serialize(() async {
      final environment = selected.value.name;
      return (
        baseUrl: baseUrl,
        environment: environment,
        generation: _generation,
        accessToken: includeAuth
            ? await SessionManager.getTokenForEnvironment(environment)
            : null,
      );
    });
  }

  static Future<void> logout() async {
    await initialize();
    await _serialize(() async {
      _generation++;
      await SessionManager.clearSession();
    });
  }

  static Future<int?> invalidateSessionIfCurrent(
    int generation,
    String environment,
  ) async {
    await initialize();
    return _serialize(() async {
      if (_generation != generation || selected.value.name != environment) {
        return null;
      }
      _generation++;
      try {
        await SessionManager.clearSession();
      } catch (error) {
        throw SessionInvalidationFailure(
          _generation,
          'Could not clear saved session ($error). This device may restore '
          'the session after restart.',
        );
      }
      return _generation;
    });
  }

  static Future<bool> saveSessionIfCurrent(
    int generation,
    String environment,
    Map<String, dynamic> session,
  ) async {
    await initialize();
    return _serialize(() async {
      if (_generation != generation || selected.value.name != environment) {
        return false;
      }
      await SessionManager.setSession(session, environment: environment);
      if (_generation != generation || selected.value.name != environment) {
        return false;
      }
      _generation++;
      return true;
    });
  }

  static Future<T> _serialize<T>(Future<T> Function() action) {
    final result = (_queue ?? Future<void>.value()).then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace stack) {});
    return result;
  }
}
class SessionInvalidationFailure implements Exception {
  final int generation;
  final String message;

  const SessionInvalidationFailure(this.generation, this.message);

  @override
  String toString() => message;
}
