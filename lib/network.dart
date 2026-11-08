import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_manager.dart';

class Network {
  // Ganti IP sesuai perangkat yang Anda gunakan:
  // - Android Emulator: http://10.0.2.2:3030
  // - iOS Simulator / Web / Windows: http://127.0.0.1:3030
  // - HP Fisik: http://192.168.x.x:3030 (IP Laptop Anda)
  static const String baseUrl = 'http://10.0.2.2:3030';

  // Helper private untuk mengambil header standar + Authorization Token
  static Future<Map<String, String>> _getHeaders() async {
    final token = await SessionManager.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

// --- 1. METHOD GET ---
  static Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    final response = await http.get(url, headers: headers);
    final responseData = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'Gagal mengambil data dari server');
    }
  }

  // --- 2. METHOD POST ---
  static Future<dynamic> post(String endpoint, Map<String, dynamic> payload) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'Gagal mengirim data ke server');
    }
  }

  // --- 3. METHOD DELETE ---
  static Future<dynamic> delete(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    final response = await http.delete(url, headers: headers);
    final responseData = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'Gagal menghapus data dari server');
    }
  }
}

// -----------------------------------------------------------------------------
// SERVICES
// -----------------------------------------------------------------------------

class AuthService {
  static Future<dynamic> login(Map<String, dynamic> payload) {
    return Network.post('/v1/auth/login', payload);
  }

  static Future<dynamic> signUp(Map<String, dynamic> payload) {
    return Network.post('/v1/auth/register', payload);
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

  static Future<dynamic> getBoardDetail(String boardId) async {
    return Network.get('/v1/boards/$boardId');
  }

  // GET /v1/boards/:id/lists
  static Future<dynamic> getBoardLists(String boardId) async {
    return Network.get('/v1/boards/$boardId/lists');
  }

  // POST /v1/boards
  static Future<dynamic> createBoard(Map<String, dynamic> payload) async {
    return Network.post('/v1/boards', payload);
  }
}
class ListService {
  // POST /v1/lists
  static Future<dynamic> createList(Map<String, dynamic> payload) async {
    return Network.post('/v1/lists', payload);
  }
}