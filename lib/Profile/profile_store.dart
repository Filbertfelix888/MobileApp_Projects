import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../environment_config.dart';
import '../services/firebase_config.dart';
import '../services/firebase_service.dart';
import '../session_manager.dart';

enum ProfileAvatarPreset {
  initials('initials', 'Inisial', null),
  developer('developer', 'Dev', Icons.code),
  designer('designer', 'Desain', Icons.palette_outlined),
  leader('leader', 'Lead', Icons.star_outline),
  rocket('rocket', 'Roket', Icons.rocket_launch_outlined),
  smile('smile', 'Santai', Icons.sentiment_satisfied_alt);

  const ProfileAvatarPreset(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData? icon;

  static ProfileAvatarPreset fromId(String? id) {
    for (final preset in values) {
      if (preset.id == id) return preset;
    }
    return ProfileAvatarPreset.initials;
  }
}

class ProfileData {
  const ProfileData({
    required this.name,
    required this.email,
    this.role = '',
    this.phone = '',
    this.bio = '',
    this.avatarColorValue = 0xFF345BC7,
    this.avatarPresetId = 'initials',
    this.avatarBase64,
    this.hasCustomAvatar = false,
  });

  final String name;
  final String email;
  final String role;
  final String phone;
  final String bio;
  final int avatarColorValue;
  final String avatarPresetId;
  final String? avatarBase64;
  final bool hasCustomAvatar;

  ProfileAvatarPreset get avatarPreset =>
      ProfileAvatarPreset.fromId(avatarPresetId);

  List<int>? get avatarBytes {
    final encoded = avatarBase64;
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory ProfileData.fromJson(
    Map<String, dynamic> json, {
    String fallbackName = 'User',
    String fallbackEmail = '',
  }) {
    final rawName = (json['name'] ?? '').toString().trim();
    final rawEmail = (json['email'] ?? '').toString().trim();
    final colorValue = json['avatar_color'] is int
        ? json['avatar_color'] as int
        : ProfileStore.avatarColors.first;
    final rawBase64 = json['avatar_base64']?.toString().trim();
    final hasPhoto = rawBase64 != null && rawBase64.isNotEmpty;

    return ProfileData(
      name: rawName.isNotEmpty ? rawName : fallbackName,
      email: fallbackEmail.isNotEmpty ? fallbackEmail : rawEmail,
      role: (json['role'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      bio: (json['bio'] ?? '').toString(),
      avatarColorValue: colorValue,
      avatarPresetId: (json['avatar_preset'] ?? 'initials').toString(),
      avatarBase64: hasPhoto ? rawBase64 : null,
      hasCustomAvatar: json['has_custom_avatar'] == true || hasPhoto,
    );
  }

  ProfileData copyWith({
    String? name,
    String? email,
    String? role,
    String? phone,
    String? bio,
    int? avatarColorValue,
    String? avatarPresetId,
    String? avatarBase64,
    bool clearAvatarBase64 = false,
    bool? hasCustomAvatar,
  }) {
    return ProfileData(
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      avatarColorValue: avatarColorValue ?? this.avatarColorValue,
      avatarPresetId: avatarPresetId ?? this.avatarPresetId,
      avatarBase64: clearAvatarBase64
          ? null
          : (avatarBase64 ?? this.avatarBase64),
      hasCustomAvatar: hasCustomAvatar ?? this.hasCustomAvatar,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'bio': bio,
      'avatar_color': avatarColorValue,
      'avatar_preset': avatarPresetId,
      'avatar_base64': ?avatarBase64,
      'has_custom_avatar': hasCustomAvatar,
    };
  }
}

class ProfileStore {
  static const String _storagePrefix = 'USER_PROFILE_';
  static const int maxAvatarBytes = 200 * 1024;

  static const List<int> avatarColors = [
    0xFF345BC7, // Ocean Blue
    0xFF1F6B45, // Forest Green
    0xFF6B3FA0, // Violet
    0xFFA8431A, // Sunset
    0xFFA63D63, // Soft Pink
    0xFF3F4756, // Graphite
  ];

  static const List<String> roleOptions = [
    'Project Manager',
    'Mobile Developer',
    'Frontend Developer',
    'Backend Developer',
    'UI/UX Designer',
    'QA / Tester',
    'Lainnya',
  ];

  static String _userIdentifier(Map<String, dynamic>? user) {
    return user?['public_id']?.toString() ??
        user?['id']?.toString() ??
        user?['email']?.toString() ??
        'default';
  }

  static String _storageKey(String environment, Map<String, dynamic>? user) {
    return '$_storagePrefix${environment}_${_userIdentifier(user)}';
  }

  static Future<String> currentUserId() async {
    final environment = await EnvironmentConfig.snapshot();
    final session = await SessionManager.getSessionForEnvironment(
      environment.environment,
    );
    final rawUser = session?['user'];
    final userMap = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : <String, dynamic>{};
    return _userIdentifier(userMap);
  }

  static Future<({Map<String, ProfileData> byId, Map<String, ProfileData> byEmail})>
  loadProfilesIndex() async {
    final byId = <String, ProfileData>{};
    final byEmail = <String, ProfileData>{};

    if (FirebaseConfig.isConfigured) {
      try {
        final rawProfiles = await FirebaseService.getAllProfiles();
        rawProfiles.forEach((key, json) {
          final parsed = ProfileData.fromJson(json);
          byId[FirebaseService.sanitizeKey(key)] = parsed;
          final emailKey = parsed.email.trim().toLowerCase();
          if (emailKey.isNotEmpty) {
            byEmail[emailKey] = parsed;
          }
        });
      } catch (_) {
        // Fallback to local current user profile when Firebase is unreachable.
      }
    }

    final currentId = await currentUserId();
    final currentProfile = await loadProfile();
    if (currentId != 'default') {
      byId.putIfAbsent(
        FirebaseService.sanitizeKey(currentId),
        () => currentProfile,
      );
    }
    final currentEmail = currentProfile.email.trim().toLowerCase();
    if (currentEmail.isNotEmpty) {
      byEmail.putIfAbsent(currentEmail, () => currentProfile);
    }

    return (byId: byId, byEmail: byEmail);
  }

  static Future<ProfileData> loadProfile() async {
    final environment = await EnvironmentConfig.snapshot();
    final session = await SessionManager.getSessionForEnvironment(
      environment.environment,
    );
    final rawUser = session?['user'];
    final userMap = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : <String, dynamic>{};

    final baseName = (userMap['name'] ?? 'User').toString();
    final baseEmail = (userMap['email'] ?? '').toString();
    final userId = _userIdentifier(userMap);

    final prefs = await SharedPreferences.getInstance();
    final localKey = _storageKey(environment.environment, userMap);

    if (FirebaseConfig.isConfigured && userId != 'default') {
      try {
        final remoteJson = await FirebaseService.getProfile(userId);
        if (remoteJson != null) {
          final remoteProfile = ProfileData.fromJson(
            remoteJson,
            fallbackName: baseName,
            fallbackEmail: baseEmail,
          );
          await prefs.setString(localKey, jsonEncode(remoteProfile.toJson()));
          return remoteProfile;
        }
      } catch (_) {
        // Fallback to local cached profile when Firebase is unreachable.
      }
    }

    final savedRaw = prefs.getString(localKey);
    if (savedRaw == null || savedRaw.isEmpty) {
      return ProfileData(name: baseName, email: baseEmail);
    }

    try {
      final decoded = jsonDecode(savedRaw);
      if (decoded is! Map) {
        return ProfileData(name: baseName, email: baseEmail);
      }
      return ProfileData.fromJson(
        Map<String, dynamic>.from(decoded),
        fallbackName: baseName,
        fallbackEmail: baseEmail,
      );
    } on FormatException {
      return ProfileData(name: baseName, email: baseEmail);
    }
  }

  static Future<ProfileData> saveProfile(ProfileData profile) async {
    final environment = await EnvironmentConfig.snapshot();
    final session = await SessionManager.getSessionForEnvironment(
      environment.environment,
    );
    final rawUser = session?['user'];
    final userMap = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : <String, dynamic>{'email': profile.email};

    final prefs = await SharedPreferences.getInstance();
    final localKey = _storageKey(environment.environment, userMap);
    await prefs.setString(localKey, jsonEncode(profile.toJson()));

    final userId = _userIdentifier(userMap);
    if (FirebaseConfig.isConfigured && userId != 'default') {
      await FirebaseService.saveProfile(userId, profile.toJson());
    }

    return profile;
  }
}
