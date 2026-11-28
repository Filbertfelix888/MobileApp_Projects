import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../Profile/profile_store.dart';
import '../environment_config.dart';
import '../services/firebase_config.dart';
import '../services/firebase_service.dart';

class TaskComment {
  const TaskComment({
    required this.id,
    required this.taskId,
    this.authorId = '',
    required this.authorName,
    required this.authorEmail,
    this.authorRole = '',
    this.authorColorValue = 0xFF345BC7,
    this.authorPresetId = 'initials',
    this.authorAvatarBase64,
    required this.content,
    this.parentId,
    this.replyToAuthor,
    required this.createdAt,
    this.editedAt,
  });

  final String id;
  final String taskId;
  final String authorId;
  final String authorName;
  final String authorEmail;
  final String authorRole;
  final int authorColorValue;
  final String authorPresetId;
  final String? authorAvatarBase64;
  final String content;
  final String? parentId;
  final String? replyToAuthor;
  final DateTime createdAt;
  final DateTime? editedAt;

  ProfileAvatarPreset get authorPreset =>
      ProfileAvatarPreset.fromId(authorPresetId);

  List<int>? get authorAvatarBytes {
    final encoded = authorAvatarBase64;
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  TaskComment copyWith({
    String? id,
    String? content,
    DateTime? editedAt,
  }) {
    return TaskComment(
      id: id ?? this.id,
      taskId: taskId,
      authorId: authorId,
      authorName: authorName,
      authorEmail: authorEmail,
      authorRole: authorRole,
      authorColorValue: authorColorValue,
      authorPresetId: authorPresetId,
      authorAvatarBase64: authorAvatarBase64,
      content: content ?? this.content,
      parentId: parentId,
      replyToAuthor: replyToAuthor,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
    );
  }

  factory TaskComment.fromJson(
    Map<String, dynamic> json, {
    String fallbackTaskId = '',
  }) {
    final rawCreatedAt = json['created_at']?.toString();
    final parsedDate = rawCreatedAt != null
        ? DateTime.tryParse(rawCreatedAt) ?? DateTime.now()
        : DateTime.now();
    final rawEditedAt = json['edited_at']?.toString();
    final parsedEditedAt =
        rawEditedAt != null ? DateTime.tryParse(rawEditedAt) : null;
    final rawAvatar = json['author_avatar_base64']?.toString().trim();

    return TaskComment(
      id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
      taskId: (json['task_id'] ?? fallbackTaskId).toString(),
      authorId: (json['author_id'] ?? '').toString(),
      authorName: (json['author_name'] ?? 'User').toString(),
      authorEmail: (json['author_email'] ?? '').toString(),
      authorRole: (json['author_role'] ?? '').toString(),
      authorColorValue: json['author_color'] is int
          ? json['author_color'] as int
          : 0xFF345BC7,
      authorPresetId: (json['author_preset'] ?? 'initials').toString(),
      authorAvatarBase64:
          rawAvatar != null && rawAvatar.isNotEmpty ? rawAvatar : null,
      content: (json['content'] ?? '').toString(),
      parentId: json['parent_id']?.toString(),
      replyToAuthor: json['reply_to_author']?.toString(),
      createdAt: parsedDate,
      editedAt: parsedEditedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      if (authorId.isNotEmpty) 'author_id': authorId,
      'author_name': authorName,
      'author_email': authorEmail,
      'author_role': authorRole,
      'author_color': authorColorValue,
      'author_preset': authorPresetId,
      'author_avatar_base64': ?authorAvatarBase64,
      'content': content,
      'parent_id': ?parentId,
      'reply_to_author': ?replyToAuthor,
      'created_at': createdAt.toIso8601String(),
      if (editedAt != null) 'edited_at': editedAt!.toIso8601String(),
    };
  }
}

/// Persists task comments and discussion threads locally and syncs to
/// Firebase Realtime Database when configured.
class TaskCommentStore {
  static const String _storagePrefix = 'TASK_COMMENTS_';

  static Future<String> _storageKey(String taskId) async {
    final environment = await EnvironmentConfig.snapshot();
    return '$_storagePrefix${environment.environment}_$taskId';
  }

  static Future<List<TaskComment>> getComments(String taskId) async {
    if (taskId.isEmpty) return const [];

    if (FirebaseConfig.isConfigured) {
      try {
        final remoteMaps = await FirebaseService.getTaskComments(taskId);
        final remoteComments = remoteMaps
            .map(
              (item) => TaskComment.fromJson(item, fallbackTaskId: taskId),
            )
            .toList();
        await _saveLocalComments(taskId, remoteComments);
        return remoteComments;
      } catch (_) {
        // Fallback to cached local comments when offline.
      }
    }

    return _loadLocalComments(taskId);
  }

  static Future<TaskComment> addComment({
    required String taskId,
    required String content,
    String? parentId,
    String? replyToAuthor,
  }) async {
    final profile = await ProfileStore.loadProfile();
    final authorId = await ProfileStore.currentUserId();
    var comment = TaskComment(
      id: 'cmt-${DateTime.now().microsecondsSinceEpoch}',
      taskId: taskId,
      authorId: authorId == 'default' ? '' : authorId,
      authorName: profile.name,
      authorEmail: profile.email,
      authorRole: profile.role,
      authorColorValue: profile.avatarColorValue,
      authorPresetId: profile.avatarPresetId,
      authorAvatarBase64: profile.avatarBase64,
      content: content.trim(),
      parentId: parentId,
      replyToAuthor: replyToAuthor,
      createdAt: DateTime.now(),
    );

    if (FirebaseConfig.isConfigured) {
      final remoteId = await FirebaseService.addTaskComment(
        taskId,
        comment.toJson(),
      );
      if (remoteId != null && remoteId.isNotEmpty) {
        comment = comment.copyWith(id: remoteId);
      }
    }

    final existing = List<TaskComment>.from(await _loadLocalComments(taskId));
    existing.add(comment);
    await _saveLocalComments(taskId, existing);
    return comment;
  }

  static Future<TaskComment> editComment({
    required String taskId,
    required String commentId,
    required String newContent,
  }) async {
    final trimmed = newContent.trim();
    final editedAt = DateTime.now();

    if (FirebaseConfig.isConfigured) {
      await FirebaseService.updateTaskComment(taskId, commentId, {
        'content': trimmed,
        'edited_at': editedAt.toIso8601String(),
      });
    }

    final existing = List<TaskComment>.from(await _loadLocalComments(taskId));
    TaskComment? updatedComment;
    for (var i = 0; i < existing.length; i++) {
      if (existing[i].id == commentId) {
        updatedComment = existing[i].copyWith(
          content: trimmed,
          editedAt: editedAt,
        );
        existing[i] = updatedComment;
        break;
      }
    }
    await _saveLocalComments(taskId, existing);
    return updatedComment ??
        TaskComment(
          id: commentId,
          taskId: taskId,
          authorName: 'User',
          authorEmail: '',
          content: trimmed,
          createdAt: editedAt,
          editedAt: editedAt,
        );
  }

  static Future<void> deleteComment({
    required String taskId,
    required String commentId,
  }) async {
    final existing = List<TaskComment>.from(await _loadLocalComments(taskId));
    final idsToDelete = <String>{commentId};
    for (final comment in existing) {
      if (comment.parentId == commentId) {
        idsToDelete.add(comment.id);
      }
    }

    if (FirebaseConfig.isConfigured) {
      for (final id in idsToDelete) {
        await FirebaseService.deleteTaskComment(taskId, id);
      }
    }

    existing.removeWhere((comment) => idsToDelete.contains(comment.id));
    await _saveLocalComments(taskId, existing);
  }

  static Future<List<TaskComment>> _loadLocalComments(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(await _storageKey(taskId));
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => TaskComment.fromJson(
              Map<String, dynamic>.from(item),
              fallbackTaskId: taskId,
            ),
          )
          .toList();
    } on FormatException {
      return const [];
    }
  }

  static Future<void> _saveLocalComments(
    String taskId,
    List<TaskComment> comments,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(comments.map((c) => c.toJson()).toList());
    await prefs.setString(await _storageKey(taskId), encoded);
  }
}
