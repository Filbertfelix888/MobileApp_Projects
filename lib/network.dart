import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_navigation.dart';
import 'environment_config.dart';

typedef NetworkEnvironment = EnvironmentSnapshot;

class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException(this.message);

  @override
  String toString() => message;
}

class SessionInvalidationWarningException extends UnauthorizedException {
  const SessionInvalidationWarningException(super.message);
}

class NetworkHttpException implements Exception {
  const NetworkHttpException({
    required this.statusCode,
    required this.message,
    this.serverError,
    this.meta,
  });

  final int statusCode;
  final String message;
  final String? serverError;
  final Map<String, dynamic>? meta;

  @override
  String toString() => 'Exception: $message';
}

class Network {
  static http.Client client = http.Client();

  static String get baseUrl => EnvironmentConfig.baseUrl;

  static Map<String, String> _getHeaders(
    NetworkEnvironment environment, {
    bool includeAuth = true,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (includeAuth) {
      final token = environment.accessToken;
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<dynamic> _decode(
    http.Response response,
    String fallback,
    NetworkEnvironment environment, {
    bool authenticated = true,
  }) async {
    dynamic data;
    var validJson = true;
    try {
      data = jsonDecode(response.body);
    } on FormatException {
      data = null;
      validJson = false;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (!validJson) {
        throw Exception('$fallback (respons bukan JSON)');
      }
      return data;
    }
    if (authenticated && response.statusCode == 401) {
      try {
        final invalidatedGeneration =
            await EnvironmentConfig.invalidateSessionIfCurrent(
              environment.generation,
              environment.environment,
            );
        if (invalidatedGeneration != null) {
          AppNavigation.navigateToLoginIfCurrent(invalidatedGeneration);
        }
      } on SessionInvalidationFailure catch (error) {
        AppNavigation.navigateToLoginIfCurrent(
          error.generation,
          warning: error.message,
        );
        throw SessionInvalidationWarningException(error.message);
      }
      throw const UnauthorizedException('Sesi berakhir, silakan login kembali');
    }
    final body = data is Map ? data : null;
    final message = body?['message'];
    throw NetworkHttpException(
      statusCode: response.statusCode,
      message: message is String
          ? message
          : '$fallback (HTTP ${response.statusCode})',
      serverError: body?['error'] is String ? body!['error'] as String : null,
      meta: body?['meta'] is Map
          ? Map<String, dynamic>.from(body!['meta'] as Map)
          : null,
    );
  }

  static void _checkGeneration(
    NetworkEnvironment environment,
    int? expectedGeneration,
  ) {
    if (expectedGeneration != null &&
        (environment.generation != expectedGeneration ||
            EnvironmentConfig.generation != expectedGeneration)) {
      throw StateError('Sesi berubah, muat ulang data');
    }
  }

  static Future<dynamic> get(String endpoint, {int? expectedGeneration}) async {
    final environment = await EnvironmentConfig.snapshot(includeAuth: true);
    final url = Uri.parse('${environment.baseUrl}$endpoint');
    final headers = _getHeaders(environment);
    _checkGeneration(environment, expectedGeneration);
    final response = await client.get(url, headers: headers);
    return _decode(response, 'Gagal mengambil data dari server', environment);
  }

  static Future<dynamic> post(
    String endpoint,
    Object? payload, {
    NetworkEnvironment? environmentSnapshot,
    bool includeAuth = true,
    int? expectedGeneration,
  }) async {
    final environment =
        environmentSnapshot ??
        await EnvironmentConfig.snapshot(includeAuth: includeAuth);
    final url = Uri.parse('${environment.baseUrl}$endpoint');
    final headers = _getHeaders(environment, includeAuth: includeAuth);
    _checkGeneration(environment, expectedGeneration);
    final response = await client.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );
    return _decode(
      response,
      'Gagal mengirim data ke server',
      environment,
      authenticated: includeAuth,
    );
  }

  static Future<dynamic> put(
    String endpoint,
    Map<String, dynamic> payload, {
    int? expectedGeneration,
  }) async {
    final environment = await EnvironmentConfig.snapshot(includeAuth: true);
    final url = Uri.parse('${environment.baseUrl}$endpoint');
    final headers = _getHeaders(environment);
    _checkGeneration(environment, expectedGeneration);
    final response = await client.put(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );
    return _decode(response, 'Gagal memperbarui data di server', environment);
  }

  static Future<dynamic> delete(
    String endpoint, {
    Object? payload,
    int? expectedGeneration,
  }) async {
    final environment = await EnvironmentConfig.snapshot(includeAuth: true);
    final url = Uri.parse('${environment.baseUrl}$endpoint');
    final headers = _getHeaders(environment);
    _checkGeneration(environment, expectedGeneration);
    final response = await client.delete(
      url,
      headers: headers,
      body: payload == null ? null : jsonEncode(payload),
    );
    return _decode(response, 'Gagal menghapus data dari server', environment);
  }
}

class BoardService {
  // GET /api/v1/boards/:id (public_id)
  static Future<dynamic> getBoard(
    String boardId, {
    int? expectedGeneration,
  }) async {
    return Network.get(
      '/api/v1/boards/${Uri.encodeComponent(boardId)}',
      expectedGeneration: expectedGeneration,
    );
  }

  static Future<dynamic> getMembers(
    String boardId, {
    required int expectedGeneration,
  }) {
    return Network.get(
      '/api/v1/boards/${Uri.encodeComponent(boardId)}/members',
      expectedGeneration: expectedGeneration,
    );
  }

  static Future<dynamic> addMembers(
    String boardId,
    List<String> userIds, {
    required int expectedGeneration,
  }) {
    return Network.post(
      '/api/v1/boards/${Uri.encodeComponent(boardId)}/members',
      userIds,
      expectedGeneration: expectedGeneration,
    );
  }

  static Future<dynamic> removeMembers(
    String boardId,
    List<String> userIds, {
    required int expectedGeneration,
  }) {
    return Network.delete(
      '/api/v1/boards/${Uri.encodeComponent(boardId)}/members',
      payload: userIds,
      expectedGeneration: expectedGeneration,
    );
  }

  // GET /api/v1/boards/my?filter=...&limit=10&page=1
  static Future<dynamic> getMyBoards({
    String search = '',
    int page = 1,
    int limit = 10,
  }) async {
    final path = Uri(
      path: '/api/v1/boards/my',
      queryParameters: {'filter': search, 'limit': '$limit', 'page': '$page'},
    ).toString();
    return Network.get(path);
  }

  // DELETE /api/v1/boards/:id
  static Future<dynamic> deleteBoard(String boardId) async {
    return Network.delete('/api/v1/boards/$boardId');
  }

  // POST /api/v1/boards
  static Future<dynamic> createBoard(Map<String, dynamic> payload) async {
    return Network.post('/api/v1/boards', payload);
  }
}

class AuthService {
  static Future<dynamic> login(
    Map<String, dynamic> payload, {
    NetworkEnvironment? environmentSnapshot,
  }) {
    return Network.post(
      '/v1/auth/login',
      payload,
      environmentSnapshot: environmentSnapshot,
      includeAuth: false,
    );
  }

  static Future<dynamic> signUp(Map<String, dynamic> payload) {
    return Network.post('/v1/auth/register', payload, includeAuth: false);
  }
}
