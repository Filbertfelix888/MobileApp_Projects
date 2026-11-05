import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String sessionKey = 'SESSION_KEY';
  static const String _sessionEnvironmentKey = 'SESSION_ENVIRONMENT';
  static const String _sessionInvalidationKey = 'SESSION_INVALIDATED';
  static bool _sessionUncertain = false;

  static void resetForTesting() => _sessionUncertain = false;
  static Future<void> setSession(
    Map<String, dynamic> user, {
    required String environment,
  }) async {
    if (user['access_token'] is! String ||
        (user['access_token'] as String).isEmpty) {
      throw StateError('Session must contain a nonempty access token');
    }
    _sessionUncertain = true;
    final prefs = await SharedPreferences.getInstance();
    try {
      if (!await prefs.setBool(_sessionInvalidationKey, true)) {
        throw StateError('Could not persist session invalidation marker');
      }
      if (!await prefs.setString(sessionKey, jsonEncode(user))) {
        throw StateError('Could not persist session');
      }
      if (!await prefs.setString(_sessionEnvironmentKey, environment)) {
        throw StateError('Could not persist session environment');
      }
      if (!await prefs.remove(_sessionInvalidationKey)) {
        throw StateError('Could not remove session invalidation marker');
      }
      _sessionUncertain = false;
    } catch (error, stackTrace) {
      try {
        final sessionRemoved = await prefs.remove(sessionKey);
        final environmentRemoved = await prefs.remove(_sessionEnvironmentKey);
        if (!sessionRemoved || !environmentRemoved) {
          throw StateError('Could not clean up partial session');
        }
      } catch (cleanupError) {
        throw StateError(
          'Session persistence failed and cleanup is uncertain: $cleanupError',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static Future<void> invalidateUntaggedOrMismatchedSession(
    String environment,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(sessionKey)) {
      if (prefs.containsKey(_sessionEnvironmentKey) &&
          !await prefs.remove(_sessionEnvironmentKey)) {
        _sessionUncertain = true;
        throw StateError('Could not remove session environment');
      }
      return;
    }
    if (prefs.getString(_sessionEnvironmentKey) == environment) return;
    _sessionUncertain = true;
    if (!await prefs.setBool(_sessionInvalidationKey, true)) {
      throw StateError('Could not persist session invalidation marker');
    }
    final sessionRemoved = await prefs.remove(sessionKey);
    final environmentRemoved = await prefs.remove(_sessionEnvironmentKey);
    if (!sessionRemoved || !environmentRemoved) {
      throw StateError('Could not invalidate mismatched session');
    }
    _sessionUncertain = false;
  }

  static Future<Map<String, dynamic>?> getSessionForEnvironment(
    String environment,
  ) async {
    if (_sessionUncertain) return null;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_sessionInvalidationKey) ?? false) return null;
    final sessionEnvironment = prefs.getString(_sessionEnvironmentKey);
    if (sessionEnvironment == null ||
        sessionEnvironment.isEmpty ||
        sessionEnvironment != environment) {
      return null;
    }
    final userString = prefs.getString(sessionKey);
    if (userString == null) return null;
    try {
      final decoded = jsonDecode(userString);
      if (decoded is! Map<String, dynamic> ||
          decoded['access_token'] is! String ||
          (decoded['access_token'] as String).isEmpty) {
        return null;
      }
      return decoded;
    } on FormatException {
      return null;
    }
  }
  
  static Future<Map<String, dynamic>?> getSession() async {
    if (_sessionUncertain) return null;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_sessionInvalidationKey) ?? false) return null;
    final sessionEnvironment = prefs.getString(_sessionEnvironmentKey);
    if (sessionEnvironment == null || sessionEnvironment.isEmpty) return null;
    final String? userString = prefs.getString(sessionKey);
    if (userString == null) return null;
    try {
      final decoded = jsonDecode(userString);
      if (decoded is! Map<String, dynamic> ||
          decoded['access_token'] is! String ||
          (decoded['access_token'] as String).isEmpty) {
        return null;
      }
      return decoded;
    } on FormatException {
      return null;
    }
  }

  static Future<String?> getTokenForEnvironment(String environment) async {
    final session = await getSessionForEnvironment(environment);
    final token = session?['access_token'];
    return token is String && token.isNotEmpty ? token : null;
  }

  static Future<String?> getToken() async {
    final session = await getSession();
    final token = session?['access_token'];
    return token is String && token.isNotEmpty ? token : null;
  }

  static Future<void> clearSession() async {
    _sessionUncertain = true;
    final prefs = await SharedPreferences.getInstance();
    var markerWritten = false;
    var sessionRemoved = false;
    var environmentRemoved = false;
    try {
      markerWritten = await prefs.setBool(_sessionInvalidationKey, true);
    } catch (_) {}
    try {
      sessionRemoved = await prefs.remove(sessionKey);
    } catch (_) {}
    try {
      environmentRemoved = await prefs.remove(_sessionEnvironmentKey);
    } catch (_) {}
    if (!markerWritten || !sessionRemoved || !environmentRemoved) {
      throw StateError('Could not clear session');
    }
    _sessionUncertain = false;
  }
}