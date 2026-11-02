import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_manager.dart';

class Network {
  static const String baseUrl = 'http://10.0.2.2:3030';

  static Future<dynamic> post(String endpoint, Map<String, dynamic> payload) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final token = await SessionManager.getToken();
    
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'Gagal menghubungi server');
    }
  }
}

class AuthService {
  static Future<dynamic> login(Map<String, dynamic> payload) {
    return Network.post('/v1/auth/login', payload);
  }

  static Future<dynamic> signUp(Map<String, dynamic> payload) {
    return Network.post('/v1/auth/register', payload);
  }
}