import 'package:flutter/foundation.dart';

/// Konfigurasi URL Firebase Realtime Database.
///
/// Ubah [_defaultDatabaseUrl] di file ini jika ingin mengganti project Firebase
/// atau kosongkan (`''`) untuk menjalankan mode penyimpanan lokal saja.
class FirebaseConfig {
  FirebaseConfig._();

  static const String _defaultDatabaseUrl =
      'https://mobileapp-projects-default-rtdb.asia-southeast1.firebasedatabase.app';

  static String? _overrideDatabaseUrl;

  static String get databaseUrl =>
      _normalize(_overrideDatabaseUrl ?? _defaultDatabaseUrl);

  static bool get isConfigured => databaseUrl.isNotEmpty;

  @visibleForTesting
  static void setDatabaseUrlForTesting(String? url) {
    _overrideDatabaseUrl = url == null ? null : _normalize(url);
  }

  @visibleForTesting
  static void resetForTesting() {
    _overrideDatabaseUrl = null;
  }

  static String _normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
