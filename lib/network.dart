import 'dart:convert';
import 'package:http/http.dart' as http;
import 'environment_config.dart';
import 'session_manager.dart';

typedef NetworkEnvironment = ({
  String baseUrl,
  String environment,
  int generation,
});

class Network {
  static http.Client client = http.Client();

  static String get baseUrl => EnvironmentConfig.baseUrl;

  static Future<Map<String, String>> _getHeaders(
    NetworkEnvironment environment, {
    bool includeAuth = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (includeAuth) {
      final token = await SessionManager.getTokenForEnvironment(
        environment.environment,
      );
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<dynamic> get(String endpoint) async {
    final environment = await EnvironmentConfig.snapshot();
    final url = Uri.parse('${environment.baseUrl}$endpoint');
    final headers = await _getHeaders(environment);
    final response = await client.get(url, headers: headers);
    final responseData = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseData;
    }
    throw Exception(responseData['message'] ?? 'Gagal mengambil data dari server');
  }

  static Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> payload, {
    NetworkEnvironment? environmentSnapshot,
    bool includeAuth = true,
  }) async {
    final environment = environmentSnapshot ?? await EnvironmentConfig.snapshot();
    final url = Uri.parse('${environment.baseUrl}$endpoint');
    final headers = await _getHeaders(environment, includeAuth: includeAuth);
    final response = await client.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );
    final responseData = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseData;
    }
    throw Exception(responseData['message'] ?? 'Gagal mengirim data ke server');
  }

  static Future<dynamic> delete(String endpoint) async {
    final environment = await EnvironmentConfig.snapshot();
    final url = Uri.parse('${environment.baseUrl}$endpoint');
    final headers = await _getHeaders(environment);
    final response = await client.delete(url, headers: headers);
    final responseData = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseData;
    }
    throw Exception(responseData['message'] ?? 'Gagal menghapus data dari server');
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
    return Network.post(
      '/v1/auth/register',
      payload,
      includeAuth: false,
    );
  }
}

class BoardService {
  // GET /v1/boards/my-boards?filter=...&limit=10&page=1
  static Future<dynamic> getMyBoards({String search = '', int page = 1, int limit = 10}) async {
    final queryParams = '?filter=$search&limit=$limit&page=$page';
    return Network.get('/v1/boards/my-boards$queryParams');
  }

  // DELETE /v1/boards/:id
  static Future<dynamic> deleteBoard(String boardId) async {
    return Network.delete('/v1/boards/$boardId');
  }

  // POST /v1/boards
  static Future<dynamic> createBoard(Map<String, dynamic> payload) async {
    return Network.post('/v1/boards', payload);
  }
}