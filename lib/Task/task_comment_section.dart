import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../Profile/profile_store.dart';
import '../services/firebase_config.dart';
import '../services/firebase_service.dart';
import 'task_comment_store.dart';

class TaskCommentSection extends StatefulWidget {
  const TaskCommentSection({
    super.key,
    required this.taskId,
    this.readOnly = false,
    this.onCountChanged,
  });

  final String taskId;
  final bool readOnly;
  final ValueChanged<int>? onCountChanged;

  @override
  State<TaskCommentSection> createState() => _TaskCommentSectionState();
}

class _TaskCommentSectionState extends State<TaskCommentSection> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _loading = true;
  bool _submitting = false;
  bool _silentSyncing = false;
  List<TaskComment> _comments = [];
  Map<String, ProfileData> _profilesById = const {};
  Map<String, ProfileData> _profilesByEmail = const {};
  TaskComment? _replyingTo;
  String _currentUserEmail = '';
  Timer? _autoRefreshTimer;

  static const Duration _autoRefreshInterval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _loadComments();
    _startAutoRefresh();
  }

  @override
  void didUpdateWidget(covariant TaskCommentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) {
      _replyingTo = null;
      _loadComments();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    if (!FirebaseConfig.isConfigured) return;
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      _silentRefresh();
    });
  }

  bool _hasCommentsChanged(List<TaskComment> current, List<TaskComment> next) {
    if (current.length != next.length) return true;
    for (var i = 0; i < current.length; i++) {
      if (current[i].id != next[i].id ||
          current[i].content != next[i].content ||
          current[i].editedAt != next[i].editedAt ||
          current[i].authorName != next[i].authorName) {
        return true;
      }
    }
    return false;
  }

  bool _hasProfilesChanged(
    Map<String, ProfileData> current,
    Map<String, ProfileData> next,
  ) {
    if (current.length != next.length) return true;
    for (final entry in next.entries) {
      final prev = current[entry.key];
      if (prev == null) return true;
      final curr = entry.value;
      if (prev.name != curr.name ||
          prev.role != curr.role ||
          prev.avatarColorValue != curr.avatarColorValue ||
          prev.avatarPresetId != curr.avatarPresetId ||
          prev.avatarBase64 != curr.avatarBase64) {
        return true;
      }
    }
    return false;
  }

  Future<void> _silentRefresh() async {
    if (!mounted ||
        _loading ||
        _submitting ||
        _silentSyncing ||
        !FirebaseConfig.isConfigured) {
      return;
    }
    _silentSyncing = true;
    try {
      final latest = await TaskCommentStore.getComments(widget.taskId);
      final profiles = await ProfileStore.loadProfilesIndex();
      if (!mounted || _submitting) return;
      final commentsChanged = _hasCommentsChanged(_comments, latest);
      final profilesChanged =
          _hasProfilesChanged(_profilesById, profiles.byId) ||
          _hasProfilesChanged(_profilesByEmail, profiles.byEmail);
      if (commentsChanged || profilesChanged) {
        setState(() {
          _comments = latest;
          _profilesById = profiles.byId;
          _profilesByEmail = profiles.byEmail;
        });
        if (commentsChanged) {
          widget.onCountChanged?.call(latest.length);
        }
      }
    } catch (_) {
      // Ignore transient network errors during background sync.
    } finally {
      _silentSyncing = false;
    }
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final profile = await ProfileStore.loadProfile();
      final comments = await TaskCommentStore.getComments(widget.taskId);
      final profiles = await ProfileStore.loadProfilesIndex();
      if (!mounted) return;
      setState(() {
        _currentUserEmail = profile.email;
        _comments = comments;
        _profilesById = profiles.byId;
        _profilesByEmail = profiles.byEmail;
        _loading = false;
      });
      widget.onCountChanged?.call(comments.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting || widget.readOnly) return;

    setState(() => _submitting = true);
    try {
      final parent = _replyingTo;
      final threadParentId =
          (parent?.parentId != null && parent!.parentId!.isNotEmpty)
          ? parent.parentId
          : parent?.id;
      final added = await TaskCommentStore.addComment(
        taskId: widget.taskId,
        content: text,
        parentId: threadParentId,
        replyToAuthor: parent?.authorName,
      );
      if (!mounted) return;
      _controller.clear();
      final updated = [..._comments, added];
      setState(() {
        _comments = updated;
        _replyingTo = null;
      });
      widget.onCountChanged?.call(updated.length);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceAll('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _editComment(TaskComment comment) async {
    if (widget.readOnly) return;
    final newContent = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _EditCommentDialog(initialContent: comment.content),
    );

    if (newContent == null ||
        newContent.isEmpty ||
        newContent == comment.content ||
        !mounted) {
      return;
    }

    try {
      final updatedComment = await TaskCommentStore.editComment(
        taskId: widget.taskId,
        commentId: comment.id,
        newContent: newContent,
      );
      if (!mounted) return;
      setState(() {
        _comments = _comments
            .map((c) => c.id == comment.id ? updatedComment : c)
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceAll('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _deleteComment(TaskComment comment) async {
    if (widget.readOnly) return;
    try {
      await TaskCommentStore.deleteComment(
        taskId: widget.taskId,
        commentId: comment.id,
      );
      if (!mounted) return;
      final updated = _comments
          .where((c) => c.id != comment.id && c.parentId != comment.id)
          .toList();
      setState(() {
        _comments = updated;
        if (_replyingTo?.id == comment.id) {
          _replyingTo = null;
        }
      });
      widget.onCountChanged?.call(updated.length);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceAll('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  bool _canDelete(TaskComment comment) {
    if (_currentUserEmail.isEmpty || comment.authorEmail.isEmpty) return true;
    return comment.authorEmail == _currentUserEmail;
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _formatTimestamp(DateTime dateTime) {
    final local = dateTime.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    return _formatExactTimestamp(local);
  }

  String _formatExactTimestamp(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  ProfileData? _resolveLiveProfile(TaskComment comment) {
    if (comment.authorId.isNotEmpty) {
      final byId = _profilesById[FirebaseService.sanitizeKey(comment.authorId)];
      if (byId != null) return byId;
    }
    final emailKey = comment.authorEmail.trim().toLowerCase();
    if (emailKey.isNotEmpty) {
      return _profilesByEmail[emailKey];
    }
    return null;
  }

  Widget _buildAvatar(
    TaskComment comment, {
    required bool isReply,
    ProfileData? liveProfile,
  }) {
    final radius = isReply ? 13.0 : 16.0;
    final colorValue = liveProfile?.avatarColorValue ?? comment.authorColorValue;
    final photoBytes = liveProfile != null
        ? liveProfile.avatarBytes
        : comment.authorAvatarBytes;
    if (photoBytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Color(colorValue),
        backgroundImage: MemoryImage(Uint8List.fromList(photoBytes)),
      );
    }

    final presetIcon =
        (liveProfile?.avatarPreset ?? comment.authorPreset).icon;
    final displayName = liveProfile?.name ?? comment.authorName;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Color(colorValue),
      child: presetIcon != null
          ? Icon(presetIcon, size: radius + 1, color: Colors.white)
          : Text(
              _initials(displayName),
              style: TextStyle(
                fontSize: isReply ? 10 : 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
    );
  }

  Widget _buildCommentCard(TaskComment comment, {required bool isReply}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final liveProfile = _resolveLiveProfile(comment);
    final authorName = liveProfile?.name ?? comment.authorName;
    final authorRole = liveProfile?.role ?? comment.authorRole;

    return Container(
      margin: EdgeInsets.only(left: isReply ? 28 : 0, bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: isReply
            ? colors.surfaceContainerLow
            : colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _buildAvatar(
              comment,
              isReply: isReply,
              liveProfile: liveProfile,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            authorName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (authorRole.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                authorRole,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onPrimaryContainer,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          Text(
                            _formatTimestamp(comment.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          if (comment.editedAt != null)
                            Tooltip(
                              message:
                                  'Diedit ${_formatExactTimestamp(comment.editedAt!)}',
                              triggerMode: TooltipTriggerMode.tap,
                              child: Text(
                                '(diedit)',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_canDelete(comment)) ...[
                      IconButton(
                        tooltip: 'Edit komentar',
                        onPressed: widget.readOnly
                            ? null
                            : () => _editComment(comment),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 17,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Hapus komentar',
                        onPressed: widget.readOnly
                            ? null
                            : () => _deleteComment(comment),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                if (comment.replyToAuthor != null &&
                    comment.replyToAuthor!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Membalas @${comment.replyToAuthor}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(comment.content, style: theme.textTheme.bodyMedium),
                if (!widget.readOnly) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () {
                      setState(() => _replyingTo = comment);
                      _focusNode.requestFocus();
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      child: Text(
                        'Balas',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final topLevel = _comments
        .where((c) => c.parentId == null || c.parentId!.isEmpty)
        .toList();
    final repliesByParent = <String, List<TaskComment>>{};
    for (final comment in _comments) {
      final parentId = comment.parentId;
      if (parentId != null && parentId.isNotEmpty) {
        repliesByParent.putIfAbsent(parentId, () => []).add(comment);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
          child: Row(
            children: [
              Icon(Icons.forum_outlined, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Diskusi & Komentar',
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_comments.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (FirebaseConfig.isConfigured)
                IconButton(
                  tooltip: 'Muat ulang komentar',
                  onPressed: _loading ? null : _loadComments,
                  icon: const Icon(Icons.refresh, size: 18),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _comments.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 36,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Belum ada komentar',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mulai diskusi dengan tim mengenai tugas ini.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  children: [
                    for (final comment in topLevel) ...[
                      _buildCommentCard(comment, isReply: false),
                      for (final reply
                          in repliesByParent[comment.id] ??
                              const <TaskComment>[])
                        _buildCommentCard(reply, isReply: true),
                    ],
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_replyingTo != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.reply,
                        size: 16,
                        color: colors.onPrimaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Membalas ${_replyingTo!.authorName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _replyingTo = null),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: !widget.readOnly && !_submitting,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitComment(),
                      decoration: InputDecoration(
                        hintText: _replyingTo != null
                            ? 'Tulis balasan...'
                            : 'Tulis komentar atau diskusi...',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Kirim Komentar',
                    onPressed: widget.readOnly || _submitting
                        ? null
                        : _submitComment,
                    icon: _submitting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditCommentDialog extends StatefulWidget {
  const _EditCommentDialog({required this.initialContent});

  final String initialContent;

  @override
  State<_EditCommentDialog> createState() => _EditCommentDialogState();
}

class _EditCommentDialogState extends State<_EditCommentDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialContent,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit komentar'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: 4,
        decoration: const InputDecoration(hintText: 'Tulis komentar...'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final trimmed = _controller.text.trim();
            if (trimmed.isEmpty) return;
            Navigator.pop(context, trimmed);
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
