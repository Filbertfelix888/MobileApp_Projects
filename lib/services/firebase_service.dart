import 'dart:convert';

import 'package:http/http.dart' as http;

import 'firebase_config.dart';

/// Client REST ringan untuk Firebase Realtime Database.
/// Menggunakan package `http` sehingga bekerja di Android, iOS, Web, dan Desktop
/// tanpa plugin native tambahan atau perubahan database PostgreSQL backend.
class FirebaseService {
  FirebaseService._();

  static http.Client? _clientOverride;
  static final http.Client _defaultClient = http.Client();

  static http.Client get client => _clientOverride ?? _defaultClient;

  static set client(http.Client? value) {
    _clientOverride = value;
  }

  static Uri _buildUri(String path) {
    final base = FirebaseConfig.databaseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$cleanPath.json');
  }

  /// Sanitizes user/task keys for Firebase RTDB paths (lowercased).
  static String sanitizeKey(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return 'default';
    return normalized.replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
  }

  /// Sanitizes Firebase push IDs while preserving case and '-' prefix.
  static String sanitizeNodeId(String raw) {
    return raw.trim().replaceAll(RegExp(r'[.#$\[\]/\s]'), '_');
  }

  static Future<Map<String, dynamic>?> getProfile(String userKey) async {
    if (!FirebaseConfig.isConfigured) return null;
    final safeKey = sanitizeKey(userKey);
    final response = await client.get(_buildUri('/profiles/$safeKey'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Gagal memuat profil dari Firebase (${response.statusCode})',
      );
    }
    final trimmed = response.body.trim();
    if (trimmed.isEmpty || trimmed == 'null') return null;
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  static Future<void> saveProfile(
    String userKey,
    Map<String, dynamic> profileJson,
  ) async {
    if (!FirebaseConfig.isConfigured) return;
    final safeKey = sanitizeKey(userKey);
    final response = await client.put(
      _buildUri('/profiles/$safeKey'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(profileJson),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Gagal menyimpan profil ke Firebase (${response.statusCode})',
      );
    }
  }

  static Future<Map<String, Map<String, dynamic>>> getAllProfiles() async {
    if (!FirebaseConfig.isConfigured) return const {};
    final response = await client.get(_buildUri('/profiles'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Gagal memuat daftar profil dari Firebase (${response.statusCode})',
      );
    }
    final trimmed = response.body.trim();
    if (trimmed.isEmpty || trimmed == 'null') return const {};
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) return const {};

    final profiles = <String, Map<String, dynamic>>{};
    decoded.forEach((key, value) {
      if (value is Map) {
        profiles[key.toString()] = Map<String, dynamic>.from(value);
      }
    });
    return profiles;
  }

  static Future<List<Map<String, dynamic>>> getTaskComments(
    String taskId,
  ) async {
    if (!FirebaseConfig.isConfigured || taskId.isEmpty) return const [];
    final safeTaskId = sanitizeKey(taskId);
    final response = await client.get(_buildUri('/task_comments/$safeTaskId'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Gagal memuat komentar dari Firebase (${response.statusCode})',
      );
    }
    final trimmed = response.body.trim();
    if (trimmed.isEmpty || trimmed == 'null') return const [];
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) return const [];

    final comments = <Map<String, dynamic>>[];
    decoded.forEach((key, value) {
      if (value is Map) {
        comments.add({
          ...Map<String, dynamic>.from(value),
          'id': key.toString(),
        });
      }
    });
    comments.sort((a, b) {
      final left = (a['created_at'] ?? '').toString();
      final right = (b['created_at'] ?? '').toString();
      return left.compareTo(right);
    });
    return comments;
  }

  static Future<String?> addTaskComment(
    String taskId,
    Map<String, dynamic> commentJson,
  ) async {
    if (!FirebaseConfig.isConfigured || taskId.isEmpty) return null;
    final safeTaskId = sanitizeKey(taskId);
    final response = await client.post(
      _buildUri('/task_comments/$safeTaskId'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(commentJson),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Gagal mengirim komentar ke Firebase (${response.statusCode})',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['name'] != null) {
      return decoded['name'].toString();
    }
    return null;
  }

  static Future<void> updateTaskComment(
    String taskId,
    String commentId,
    Map<String, dynamic> updates,
  ) async {
    if (!FirebaseConfig.isConfigured || taskId.isEmpty || commentId.isEmpty) {
      return;
    }
    final safeTaskId = sanitizeKey(taskId);
    final safeCommentId = sanitizeNodeId(commentId);
    final response = await client.patch(
      _buildUri('/task_comments/$safeTaskId/$safeCommentId'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(updates),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Gagal memperbarui komentar di Firebase (${response.statusCode})',
      );
    }
  }

  static Future<void> deleteTaskComment(
    String taskId,
    String commentId,
  ) async {
    if (!FirebaseConfig.isConfigured || taskId.isEmpty || commentId.isEmpty) {
      return;
    }
    final safeTaskId = sanitizeKey(taskId);
    final safeCommentId = sanitizeNodeId(commentId);
    final response = await client.delete(
      _buildUri('/task_comments/$safeTaskId/$safeCommentId'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Gagal menghapus komentar di Firebase (${response.statusCode})',
      );
    }
  }
}
