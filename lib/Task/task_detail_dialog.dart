import 'package:flutter/material.dart';

import '../environment_config.dart';
import '../network.dart';
import 'task_models.dart';
import 'task_service.dart';

class TaskDetailDialog extends StatefulWidget {
  const TaskDetailDialog({
    super.key,
    required this.boardId,
    required this.taskId,
    required this.column,
    required this.columns,
    required this.members,
    required this.reloadMembers,
    required this.onMove,
    required this.expectedGeneration,
    this.boardDueDate,
    required this.isViewCurrent,
    required this.onChanged,
  });

  final String boardId;
  final bool Function() isViewCurrent;
  final String taskId;
  final KanbanColumn column;
  final List<KanbanColumn> columns;
  final List<TaskUser>? members;
  final Future<List<TaskUser>> Function() reloadMembers;
  final Future<bool> Function(String, String, String) onMove;
  final int expectedGeneration;
  final String? boardDueDate;
  final VoidCallback onChanged;

  @override
  State<TaskDetailDialog> createState() => _TaskDetailDialogState();
}

class _TaskDetailDialogState extends State<TaskDetailDialog> {
  late final int viewGeneration;
  late final String _viewBoardId;
  late final String _viewTaskId;
  late final String _viewColumnId;
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  TaskCard? _task;
  List<TaskUser>? _members;
  final Set<String> _selectedAssigneeIds = {};
  DateTime? _deadline;
  String? _originalDate;
  String? _error;
  String? _memberError;
  bool _loading = true;
  bool _pending = false;
  bool _savedRefreshFailed = false;
  bool _clearDeadline = false;
  bool _scopeChanged = false;
  bool _scopeRefreshRequested = false;
  int _requestId = 0;
  bool _syncingDrafts = false;
  bool _viewStale = false;

  bool get _current =>
      mounted &&
      !_viewStale &&
      EnvironmentConfig.generation == viewGeneration &&
      widget.expectedGeneration == viewGeneration &&
      widget.boardId == _viewBoardId &&
      widget.isViewCurrent() &&
      widget.taskId == _viewTaskId &&
      widget.column.publicId == _viewColumnId;

  @override
  void initState() {
    super.initState();
    viewGeneration = widget.expectedGeneration;
    _viewBoardId = widget.boardId;
    _viewTaskId = widget.taskId;
    _viewColumnId = widget.column.publicId;
    _members = widget.members;
    _loadTask();
    _title.addListener(_draftChanged);
    _description.addListener(_draftChanged);
  }

  void _markViewStale() {
    if (!mounted || _viewStale) return;
    setState(() {
      _viewStale = true;
      _task = null;
      _members = null;
      _loading = false;
      _error = 'Sesi berubah, buka ulang proyek';
      _syncingDrafts = true;
      _title.clear();
      _description.clear();
      _syncingDrafts = false;
      _deadline = null;
      _originalDate = null;
    });
  }

  void _draftChanged() {
    if (mounted && !_syncingDrafts) setState(() {});
  }

  void _setDrafts(TaskCard task) {
    _syncingDrafts = true;
    _title.text = task.title;
    _description.text = task.description;
    _syncingDrafts = false;
  }

  Future<void> _loadTask() async {
    if (!_current) {
      if (mounted) setState(() => _error = 'Sesi berubah, muat ulang data');
      return;
    }
    final request = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _savedRefreshFailed = false;
    });
    try {
      final task = await TaskService.getTask(
        _viewTaskId,
        expectedGeneration: viewGeneration,
      );
      if (!mounted || request != _requestId) return;
      if (!_current) {
        _markViewStale();
        return;
      }
      final scopeChanged = task.listInternalId != widget.column.internalId;
      setState(() {
        _task = task;
        _loading = false;
        _scopeChanged = scopeChanged;
        _setDrafts(task);
        _deadline = _utcCalendarDate(task.dueDate);
        _originalDate = task.dueDate;
        _clearDeadline = false;
      });
      if (scopeChanged && !_scopeRefreshRequested) {
        _scopeRefreshRequested = true;
        widget.onChanged();
      }
    } catch (error) {
      if (!mounted || request != _requestId) return;
      if (!_current) {
        _markViewStale();
        return;
      }
      setState(() {
        _loading = false;
        _error = error is UnauthorizedException
            ? null
            : error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  DateTime? _utcCalendarDate(String? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    final utc = parsed.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  String _dateLabel(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? get _projectDeadline {
    final raw = widget.boardDueDate;
    if (raw == null || raw.isEmpty || raw.startsWith('0001-01-01')) return null;
    final parsed = DateTime.tryParse(raw)?.toLocal();
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  Future<void> _chooseDeadline() async {
    if (_pending) return;
    final cap = _projectDeadline;
    if (cap != null && cap.isBefore(_today)) {
      setState(
        () =>
            _error = 'Tanggal proyek sudah lewat; tenggat baru tidak tersedia',
      );
      return;
    }
    final existing = _deadline == null
        ? null
        : DateTime(_deadline!.year, _deadline!.month, _deadline!.day);
    final lastDate = cap ?? DateTime(_today.year + 100, 12, 31);
    var initial = existing == null || existing.isBefore(_today)
        ? _today
        : existing;
    if (initial.isAfter(lastDate)) initial = lastDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _today,
      lastDate: lastDate,
      helpText: 'Pilih tenggat tugas',
    );
    if (picked != null && mounted) {
      setState(() {
        _deadline = DateTime.utc(picked.year, picked.month, picked.day);
        _clearDeadline = false;
      });
    }
  }

  bool get _dirty {
    final task = _task;
    if (task == null) return false;
    return _title.text.trim() != task.title ||
        _description.text != task.description ||
        _dateForUpdate != _originalDate;
  }

  String? get _dateForUpdate {
    if (_clearDeadline) return null;
    if (_deadline == null) return _originalDate;
    final original = _utcCalendarDate(_originalDate);
    if (original != null &&
        original.year == _deadline!.year &&
        original.month == _deadline!.month &&
        original.day == _deadline!.day) {
      return _originalDate;
    }
    return '${_dateLabel(_deadline!)}T00:00:00Z';
  }

  String get _dateText {
    if (_deadline != null) return _dateLabel(_deadline!);
    if (_clearDeadline) return 'Tidak ada tenggat';
    if (_originalDate != null) return 'Tanggal tidak tersedia';
    return 'Tidak ada tenggat';
  }

  String? _validateTitle(String? value) {
    final title = value?.trim() ?? '';
    if (title.isEmpty) return 'Judul wajib diisi';
    if (title.runes.length > 255) return 'Judul maksimal 255 karakter';
    return null;
  }

  Future<void> _save() async {
    final task = _task;
    if (_pending ||
        task == null ||
        _scopeChanged ||
        !_current ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final payload = task.updatePayload(
        listId: widget.column.publicId,
        title: _title.text.trim(),
        description: _description.text,
        dueDate: _dateForUpdate,
        clearDueDate: _clearDeadline || _dateForUpdate == null,
      );
      await TaskService.updateTask(
        task.publicId,
        payload,
        expectedGeneration: viewGeneration,
      );
      if (!mounted) return;
      widget.onChanged();
      await _reloadAfterSave();
    } catch (error) {
      if (mounted && error is! UnauthorizedException) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _reloadAfterSave() async {
    if (!_current) {
      setState(() {
        _savedRefreshFailed = true;
        _error = 'Sesi berubah, muat ulang data';
      });
      return;
    }
    final request = ++_requestId;
    try {
      final task = await TaskService.getTask(
        _viewTaskId,
        expectedGeneration: viewGeneration,
      );
      if (!mounted || request != _requestId) return;
      if (!_current) throw StateError('Sesi berubah, muat ulang data');
      setState(() {
        _task = task;
        _scopeChanged = task.listInternalId != widget.column.internalId;
        _setDrafts(task);
        _deadline = _utcCalendarDate(task.dueDate);
        _originalDate = task.dueDate;
        _clearDeadline = false;
        _savedRefreshFailed = false;
        _error = _scopeChanged
            ? 'Tugas berubah kolom. Muat ulang papan.'
            : null;
      });
    } catch (error) {
      if (mounted && request == _requestId) {
        setState(() {
          _savedRefreshFailed = true;
          _error = 'Tersimpan, gagal memuat ulang';
        });
      }
    }
  }

  Future<void> _delete() async {
    final task = _task;
    if (_pending || task == null || _scopeChanged || !_current) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Hapus tugas?'),
        content: Text('Tugas “${task.displayTitle}” akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_current) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await TaskService.deleteTask(
        task.publicId,
        expectedGeneration: viewGeneration,
      );
      _requestId++;
      if (!mounted) return;
      widget.onChanged();
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted && error is! UnauthorizedException) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _move(KanbanColumn destination) async {
    final task = _task;
    if (_pending ||
        _savedRefreshFailed ||
        task == null ||
        _scopeChanged ||
        !_current ||
        _dirty ||
        destination.publicId == widget.column.publicId) {
      return;
    }
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final moved = await widget.onMove(
        task.publicId,
        widget.column.publicId,
        destination.publicId,
      );
      if (moved && mounted && _current) Navigator.of(context).pop();
      if (!moved && mounted) {
        setState(() => _error = 'Tugas tidak dapat dipindahkan');
      }
    } catch (error) {
      if (mounted && error is! UnauthorizedException) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  KanbanColumn? _columnForId(String id) {
    for (final column in widget.columns) {
      if (column.publicId == id) return column;
    }
    return null;
  }

  Future<void> _loadMembers() async {
    if (!_current) {
      _markViewStale();
      return;
    }
    setState(() {
      _pending = true;
      _memberError = null;
    });
    try {
      final members = await widget.reloadMembers();
      if (mounted && _current) {
        setState(() {
          _members = members;
          _memberError = null;
        });
      }
    } catch (error) {
      if (mounted && error is! UnauthorizedException) {
        setState(
          () => _memberError = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _addSelectedAssignees() async {
    final task = _task;
    final members = _members;
    if (task == null || members == null) return;
    final users = members
        .where(
          (user) =>
              _selectedAssigneeIds.contains(user.publicId) &&
              !task.assignees.any(
                (assignee) => assignee.user.publicId == user.publicId,
              ),
        )
        .toList();
    if (users.isEmpty) return;
    await _changeAssignees(users, add: true);
  }

  Future<void> _removeAssignee(TaskUser user) =>
      _changeAssignees([user], add: false);

  Future<void> _changeAssignees(
    List<TaskUser> users, {
    required bool add,
  }) async {
    final task = _task;
    if (_pending ||
        _savedRefreshFailed ||
        users.isEmpty ||
        task == null ||
        _scopeChanged ||
        !_current) {
      return;
    }
    final userIds = users.map((user) => user.publicId).toList();
    var committed = false;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      if (add) {
        await TaskService.addAssignees(
          task.publicId,
          userIds,
          expectedGeneration: viewGeneration,
        );
      } else {
        final user = users.single;
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Hapus penanggung jawab?'),
            content: Text(
              '${user.displayName} (${user.displayEmail}) tidak lagi ditugaskan pada tugas ini.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted || !_current) return;
        await TaskService.removeAssignees(
          task.publicId,
          userIds,
          expectedGeneration: viewGeneration,
        );
      }
      committed = true;
      if (!mounted || !_current) return;
      _selectedAssigneeIds.clear();
      widget.onChanged();
      final updated = await TaskService.getTask(
        _viewTaskId,
        expectedGeneration: viewGeneration,
      );
      if (!mounted) return;
      if (!_current) throw StateError('Sesi berubah, muat ulang data');
      final confirmedIds = updated.assignees
          .map((assignee) => assignee.user.publicId)
          .toSet();
      setState(() {
        _task = updated;
        _scopeChanged = updated.listInternalId != widget.column.internalId;
        _savedRefreshFailed = false;
        _error = add && !userIds.every(confirmedIds.contains)
            ? 'Assignee tidak diterapkan oleh server'
            : null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          if (committed) {
            _savedRefreshFailed = true;
            _error = 'Tersimpan, gagal memuat ulang';
          } else if (error is! UnauthorizedException) {
            _error = error.toString().replaceFirst('Exception: ', '');
          }
        });
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  void dispose() {
    _title.removeListener(_draftChanged);
    _description.removeListener(_draftChanged);
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_current && !_viewStale) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markViewStale();
      });
    }
    final task = _task;
    final readOnly =
        _pending || _scopeChanged || _savedRefreshFailed || !_current;
    final screenSize = MediaQuery.sizeOf(context);
    final isCompact = screenSize.width < 600;
    final dialogContent = SafeArea(
      child: Column(
        children: [
          AppBar(
            title: const Text('Detail tugas'),
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              tooltip: 'Tutup detail tugas',
              onPressed: _pending ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && task == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _loadTask,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    ),
                  )
                : task == null
                ? const SizedBox.shrink()
                : Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_scopeChanged) ...[
                            const Text(
                              'Tugas berpindah kolom. Tutup detail dan muat ulang papan sebelum mengubah tugas.',
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_savedRefreshFailed)
                            Card(
                              child: ListTile(
                                title: const Text(
                                  'Tersimpan, gagal memuat ulang',
                                ),
                                trailing: IconButton(
                                  tooltip: 'Muat ulang detail',
                                  onPressed: _pending ? null : _reloadAfterSave,
                                  icon: const Icon(Icons.refresh),
                                ),
                              ),
                            ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          TextFormField(
                            controller: _title,
                            enabled: !readOnly,
                            maxLength: 255,
                            validator: _validateTitle,
                            decoration: const InputDecoration(
                              labelText: 'Judul tugas',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _description,
                            enabled: !readOnly,
                            minLines: 3,
                            maxLines: 8,
                            decoration: const InputDecoration(
                              labelText: 'Deskripsi',
                            ),
                          ),
                          const SizedBox(height: 12),
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Tenggat',
                            ),
                            child: Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(_dateText),
                                TextButton.icon(
                                  onPressed: readOnly ? null : _chooseDeadline,
                                  icon: const Icon(Icons.calendar_today),
                                  label: const Text('Pilih tanggal'),
                                ),
                                if (_deadline != null || _originalDate != null)
                                  TextButton(
                                    onPressed: readOnly
                                        ? null
                                        : () => setState(() {
                                            _deadline = null;
                                            _clearDeadline = true;
                                          }),
                                    child: const Text('Hapus tenggat'),
                                  ),
                              ],
                            ),
                          ),
                          if ((_projectDeadline?.isBefore(_today) ?? false))
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Tanggal proyek sudah lewat; tenggat baru tidak tersedia. Tenggat tersimpan tetap dapat dipertahankan atau dihapus.',
                              ),
                            ),
                          const SizedBox(height: 20),
                          Text(
                            'Penanggung jawab',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (task.assignees.isEmpty)
                            const Text('Belum ada penanggung jawab.'),
                          for (final assignee in task.assignees)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(assignee.user.displayName),
                              subtitle: Text(assignee.user.displayEmail),
                              trailing: IconButton(
                                tooltip:
                                    'Hapus ${assignee.user.displayName} sebagai penanggung jawab',
                                onPressed: readOnly
                                    ? null
                                    : () => _removeAssignee(assignee.user),
                                icon: const Icon(Icons.person_remove),
                              ),
                            ),
                          if (_members == null)
                            OutlinedButton.icon(
                              onPressed: _pending ? null : _loadMembers,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                _memberError == null
                                    ? 'Muat anggota papan'
                                    : 'Coba lagi memuat anggota',
                              ),
                            )
                          else ...[
                            if (_memberError != null)
                              Text(
                                _memberError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            if (_members!.isEmpty)
                              const Text(
                                'Tidak ada anggota papan yang dapat ditugaskan.',
                              ),
                            for (final member in _members!.where(
                              (member) => !task.assignees.any(
                                (assignee) =>
                                    assignee.user.publicId == member.publicId,
                              ),
                            ))
                              CheckboxListTile(
                                value: _selectedAssigneeIds.contains(
                                  member.publicId,
                                ),
                                onChanged: readOnly
                                    ? null
                                    : (selected) => setState(() {
                                        if (selected == true) {
                                          _selectedAssigneeIds.add(
                                            member.publicId,
                                          );
                                        } else {
                                          _selectedAssigneeIds.remove(
                                            member.publicId,
                                          );
                                        }
                                      }),
                                title: Text(member.displayName),
                                subtitle: Text(member.displayEmail),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                            FilledButton.icon(
                              onPressed:
                                  readOnly || _selectedAssigneeIds.isEmpty
                                  ? null
                                  : _addSelectedAssignees,
                              icon: const Icon(Icons.person_add_alt_1),
                              label: Text(
                                'Tugaskan (${_selectedAssigneeIds.length})',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
          if (task != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: screenSize.height * .4),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_dirty)
                      FilledButton.icon(
                        onPressed: readOnly ? null : _save,
                        icon: const Icon(Icons.save),
                        label: const Text('Simpan perubahan'),
                      ),
                    if (_dirty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Simpan atau batalkan perubahan sebelum memindahkan tugas.',
                        ),
                      ),
                    if (widget.columns
                        .where(
                          (column) => column.publicId != widget.column.publicId,
                        )
                        .isNotEmpty)
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          '${task.publicId}:${widget.column.publicId}',
                        ),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Pindahkan tugas',
                          helperText:
                              'Tugas akan ditambahkan di akhir kolom tujuan.',
                        ),
                        items: widget.columns
                            .where(
                              (column) =>
                                  column.publicId != widget.column.publicId,
                            )
                            .map(
                              (column) => DropdownMenuItem(
                                value: column.publicId,
                                child: Text(column.title),
                              ),
                            )
                            .toList(),
                        onChanged: readOnly || _dirty
                            ? null
                            : (id) {
                                if (id == null) return;
                                final destination = _columnForId(id);
                                if (destination != null) {
                                  _move(destination);
                                }
                              },
                      ),
                    const Divider(height: 24),
                    Text(
                      'Bahaya',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: readOnly ? null : _delete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Hapus tugas'),
                    ),
                  ],
                ),
              ),
            ),
          if (_pending) const LinearProgressIndicator(),
        ],
      ),
    );
    return PopScope(
      canPop: !_pending,
      child: isCompact
          ? Dialog.fullscreen(child: dialogContent)
          : Dialog(
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 640,
                  maxHeight: screenSize.height * .9,
                ),
                child: dialogContent,
              ),
            ),
    );
  }
}
