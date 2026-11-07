import 'package:flutter/material.dart';

import '../network.dart';
import '../environment_config.dart';
import 'task_column.dart';
import 'task_form_dialog.dart';
import 'task_models.dart';
import 'task_service.dart';
import 'task_detail_dialog.dart';
import 'board_members_dialog.dart';
import 'task_summary.dart';

class KanbanBoard extends StatefulWidget {
  const KanbanBoard({
    super.key,
    required this.boardId,
    required this.boardTitle,
    required this.expectedGeneration,
    this.boardDueDate,
  });

  final String boardId;
  final String boardTitle;
  final int expectedGeneration;
  final String? boardDueDate;

  @override
  State<KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> {
  late final int _viewGeneration;
  final Map<String, List<TaskCard>> _tasksByColumn = {};
  final Map<String, bool> _taskLoading = {};
  final Map<String, String?> _taskErrors = {};
  final Map<String, int> _taskEpochs = {};
  List<KanbanColumn> _columns = const [];
  bool _columnsLoading = true;
  String? _columnsError;
  bool _missingColumnOrder = false;
  List<TaskUser>? _members;
  String? _membersError;
  TaskSummary? _summary;
  bool _summaryLoading = false;
  String? _summaryError;
  int _summaryEpoch = 0;
  int _columnEpoch = 0;
  int _memberEpoch = 0;
  int _workspaceEpoch = 0;
  bool _workspaceLocked = false;
  bool _refreshNeeded = false;
  bool _sessionStale = false;
  int _selectedTab = 0;

  bool get _isCurrent =>
      mounted &&
      !_sessionStale &&
      EnvironmentConfig.generation == _viewGeneration;

  @override
  void initState() {
    super.initState();
    _viewGeneration = widget.expectedGeneration;
    EnvironmentConfig.selected.addListener(_markStaleIfNeeded);
    _loadColumns();
    _loadMembers();
  }

  @override
  void dispose() {
    EnvironmentConfig.selected.removeListener(_markStaleIfNeeded);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant KanbanBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expectedGeneration != oldWidget.expectedGeneration) {
      _markStale();
      return;
    }
    if (widget.boardId == oldWidget.boardId) return;
    _workspaceEpoch++;
    _columnEpoch++;
    _memberEpoch++;
    _taskEpochs.clear();
    _tasksByColumn.clear();
    _taskLoading.clear();
    _taskErrors.clear();
    _columns = const [];
    _members = null;
    _summaryEpoch++;
    _summary = null;
    _summaryLoading = false;
    _summaryError = null;
    _loadColumns();
    _loadMembers();
  }

  void _markStale() {
    if (!mounted || _sessionStale) return;
    setState(() {
      _sessionStale = true;
      _columns = const [];
      _tasksByColumn.clear();
      _members = null;
      _columnsError = 'Sesi berubah, buka ulang proyek';
      _summary = null;
      _summaryError = null;
      _summaryLoading = false;
    });
  }

  bool _accept(
    int epoch,
    int currentEpoch,
    int workspaceEpoch,
    String boardId,
  ) {
    if (!_isCurrent) {
      _markStale();
      return false;
    }
    return epoch == currentEpoch &&
        workspaceEpoch == _workspaceEpoch &&
        boardId == widget.boardId;
  }

  Future<void> _loadColumns() async {
    if (!_isCurrent) {
      _markStale();
      return;
    }
    final boardId = widget.boardId;
    final epoch = ++_columnEpoch;
    final workspaceEpoch = _workspaceEpoch;
    setState(() {
      _columnsLoading = true;
      _columnsError = null;
      _missingColumnOrder = false;
    });
    try {
      final received = await TaskService.getColumns(
        boardId,
        expectedGeneration: _viewGeneration,
      );
      if (!_accept(epoch, _columnEpoch, workspaceEpoch, boardId)) return;
      for (final column in received) {
        if (column.boardPublicId != boardId) {
          throw const FormatException('Kolom tidak cocok dengan proyek ini');
        }
      }
      final seen = <String>{};
      final unique = received
          .where((column) => seen.add(column.publicId))
          .toList();
      setState(() {
        _columns = List.unmodifiable(unique);
        _columnsLoading = false;
      });
      await Future.wait(unique.map((column) => _loadTasks(column)));
      if (_selectedTab == 1) _maybeLoadSummary();
    } on NetworkHttpException catch (error) {
      if (!_accept(epoch, _columnEpoch, workspaceEpoch, boardId)) return;
      final missing =
          error.statusCode == 404 &&
          error.serverError == 'list position not found';
      setState(() {
        _columnsLoading = false;
        _columnsError = error.message;
        _missingColumnOrder = missing;
      });
      if (_selectedTab == 1) _maybeLoadSummary();
    } catch (error) {
      if (!_accept(epoch, _columnEpoch, workspaceEpoch, boardId)) return;
      setState(() {
        _columnsLoading = false;
        _columnsError = error is UnauthorizedException
            ? null
            : error.toString().replaceFirst('Exception: ', '');
      });
      if (_selectedTab == 1) _maybeLoadSummary();
    }
  }

  Future<void> _loadTasks(KanbanColumn column) async {
    if (!_isCurrent) {
      _markStale();
      return;
    }
    final boardId = widget.boardId;
    final id = column.publicId;
    final epoch = (_taskEpochs[id] ?? 0) + 1;
    final workspaceEpoch = _workspaceEpoch;
    _taskEpochs[id] = epoch;
    setState(() {
      _taskLoading[id] = true;
      _taskErrors[id] = null;
    });
    try {
      final received = await TaskService.getTasks(
        id,
        expectedGeneration: _viewGeneration,
      );
      if (!_isCurrent ||
          boardId != widget.boardId ||
          workspaceEpoch != _workspaceEpoch ||
          _taskEpochs[id] != epoch) {
        _markStaleIfNeeded();
        return;
      }
      final seen = <String>{};
      final unique = <TaskCard>[];
      for (final task in received) {
        if (task.listInternalId != column.internalId) {
          throw const FormatException('Tugas tidak cocok dengan kolom ini');
        }
        if (seen.add(task.publicId)) unique.add(task);
      }
      setState(() {
        _tasksByColumn[id] = List.unmodifiable(unique);
        _taskLoading[id] = false;
        _taskErrors[id] = null;
      });
      _maybeLoadSummary();
    } catch (error) {
      if (!_isCurrent ||
          boardId != widget.boardId ||
          workspaceEpoch != _workspaceEpoch ||
          _taskEpochs[id] != epoch) {
        _markStaleIfNeeded();
        return;
      }
      setState(() {
        _taskLoading[id] = false;
        _taskErrors[id] = error is UnauthorizedException
            ? null
            : error.toString().replaceFirst('Exception: ', '');
      });
      _maybeLoadSummary();
    }
  }

  void _markStaleIfNeeded() {
    if (mounted && EnvironmentConfig.generation != _viewGeneration) {
      _markStale();
    }
  }

  Future<void> _loadMembers() async {
    if (!_isCurrent) {
      _markStale();
      return;
    }
    final boardId = widget.boardId;
    final epoch = ++_memberEpoch;
    final workspaceEpoch = _workspaceEpoch;
    setState(() {
      _membersError = null;
    });
    try {
      final response = await BoardService.getMembers(
        boardId,
        expectedGeneration: _viewGeneration,
      );
      if (!_accept(epoch, _memberEpoch, workspaceEpoch, boardId)) return;
      if (response is! Map || !response.containsKey('data')) {
        throw const FormatException('Data anggota tidak valid');
      }
      final data = response['data'];
      if (data == null) {
        setState(() {
          _members = const [];
        });
        return;
      }
      if (data is! List) {
        throw const FormatException('Data anggota tidak valid');
      }
      final users = <TaskUser>[];
      for (final item in data) {
        if (item is! Map) throw const FormatException('Anggota tidak valid');
        users.add(TaskUser.fromJson(Map<String, dynamic>.from(item)));
      }
      setState(() {
        _members = List.unmodifiable(users);
      });
    } catch (error) {
      if (!_accept(epoch, _memberEpoch, workspaceEpoch, boardId)) return;
      setState(() {
        _members = null;
        _membersError = error is UnauthorizedException
            ? null
            : error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _refreshWorkspace({bool showSavedFailure = false}) async {
    if (!_isCurrent) {
      _markStale();
      return;
    }
    ++_workspaceEpoch;
    _summaryEpoch++;
    _summary = null;
    _summaryError = null;
    _summaryLoading = false;
    _tasksByColumn.clear();
    _taskLoading.clear();
    _taskErrors.clear();
    _taskEpochs.clear();
    await Future.wait([_loadColumns(), _loadMembers()]);
    if (_selectedTab == 1) await _loadSummary();
    final refreshFailed =
        _columnsError != null ||
        _membersError != null ||
        _taskErrors.values.any((error) => error != null) ||
        _summaryError != null;
    if (showSavedFailure && refreshFailed && mounted) {
      _showError('Tersimpan, gagal memuat ulang');
    }
  }

  Future<void> _withWorkspaceLock(Future<void> Function() action) async {
    if (_workspaceLocked || !_isCurrent) return;
    setState(() => _workspaceLocked = true);
    _refreshNeeded = false;
    try {
      await action();
    } finally {
      if (mounted) {
        final shouldRefresh = _refreshNeeded && _isCurrent;
        setState(() => _workspaceLocked = false);
        _refreshNeeded = false;
        if (shouldRefresh) {
          await _refreshWorkspace(showSavedFailure: true);
        }
      }
    }
  }

  void _markChanged() {
    if (!_isCurrent) {
      _markStale();
      return;
    }
    _workspaceEpoch++;
    _columnEpoch++;
    _memberEpoch++;
    for (final id in _taskEpochs.keys.toList()) {
      _taskEpochs[id] = (_taskEpochs[id] ?? 0) + 1;
    }
    _refreshNeeded = true;
    _summaryEpoch++;
    _summary = null;
    _summaryError = null;
    _summaryLoading = false;
  }

  void _markChangedFor(String boardId) {
    if (boardId != widget.boardId) return;
    _markChanged();
  }

  Future<String?> _textDialog({required String title, String initial = ''}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          _ColumnTextDialog(title: title, initial: initial),
    );
  }

  Future<void> _createColumn() {
    final boardId = widget.boardId;
    return _withWorkspaceLock(() async {
      final title = await _textDialog(title: 'Tambah kolom');
      if (title == null || !_isCurrent || boardId != widget.boardId) return;
      try {
        await TaskService.createColumn(
          boardId,
          title.trim(),
          expectedGeneration: _viewGeneration,
        );
        if (boardId == widget.boardId) _markChanged();
      } catch (error) {
        if (mounted && error is! UnauthorizedException) _showError(error);
      }
    });
  }

  Future<void> _openMembers() async {
    final boardId = widget.boardId;
    await _withWorkspaceLock(() async {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => BoardMembersDialog(
          boardId: boardId,
          expectedGeneration: _viewGeneration,
          isViewCurrent: () =>
              mounted && boardId == widget.boardId && _isCurrent,
          onChanged: () => _markChangedFor(boardId),
        ),
      );
    });
  }

  Future<void> _renameColumn(KanbanColumn column) {
    final boardId = widget.boardId;
    return _withWorkspaceLock(() async {
      final title = await _textDialog(
        title: 'Ganti nama kolom',
        initial: column.title,
      );
      if (title == null || !_isCurrent || boardId != widget.boardId) return;
      try {
        await TaskService.renameColumn(
          column.publicId,
          title.trim(),
          expectedGeneration: _viewGeneration,
        );
        if (boardId == widget.boardId) _markChanged();
      } catch (error) {
        if (mounted && error is! UnauthorizedException) _showError(error);
      }
    });
  }

  Future<void> _deleteColumn(KanbanColumn column) {
    final boardId = widget.boardId;
    return _withWorkspaceLock(() async {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Hapus kolom?'),
          content: Text(
            'Menghapus "${column.displayTitle}" juga menghapus semua tugas di kolom ini.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus kolom'),
            ),
          ],
        ),
      );
      if (confirmed != true || !_isCurrent || boardId != widget.boardId) {
        return;
      }
      try {
        await TaskService.deleteColumn(
          column.publicId,
          expectedGeneration: _viewGeneration,
        );
        if (boardId == widget.boardId) _markChanged();
      } catch (error) {
        if (mounted && error is! UnauthorizedException) _showError(error);
      }
    });
  }

  Future<void> _createTask(KanbanColumn column) async {
    final boardId = widget.boardId;
    if ((_tasksByColumn[column.publicId] == null) ||
        _taskErrors[column.publicId] != null) {
      return;
    }
    await _withWorkspaceLock(() async {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => TaskFormDialog(
          boardId: boardId,
          isBoardCurrent: () =>
              mounted && boardId == widget.boardId && _isCurrent,
          column: column,
          nextPosition: (_tasksByColumn[column.publicId]?.length ?? 0) + 1,
          expectedGeneration: _viewGeneration,
          boardDueDate: widget.boardDueDate,
        ),
      );
      if (created == true && _isCurrent && boardId == widget.boardId) {
        _markChanged();
      }
    });
  }

  void _openTask(TaskCard task) {
    final boardId = widget.boardId;
    final sourceId = _findTaskColumn(task.publicId);
    final source = _columnForPublicId(sourceId);
    if (source == null) return;
    _withWorkspaceLock(() async {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => TaskDetailDialog(
          boardId: boardId,
          isViewCurrent: () =>
              mounted && boardId == widget.boardId && _isCurrent,
          taskId: task.publicId,
          column: source,
          columns: _columns,
          members: _members,
          reloadMembers: () => _reloadMembersForDialog(boardId),
          onMove: (taskId, from, to) => _moveTask(
            taskId,
            from,
            to,
            lockAlreadyHeld: true,
            expectedBoardId: boardId,
          ),
          expectedGeneration: _viewGeneration,
          boardDueDate: widget.boardDueDate,
          onChanged: () => _markChangedFor(boardId),
        ),
      );
    });
  }

  Future<List<TaskUser>> _reloadMembersForDialog(String boardId) async {
    if (!_isCurrent || boardId != widget.boardId) {
      throw StateError('Sesi berubah, muat ulang data');
    }
    final epoch = ++_memberEpoch;
    final workspaceEpoch = _workspaceEpoch;
    final response = await BoardService.getMembers(
      boardId,
      expectedGeneration: _viewGeneration,
    );
    if (!_isCurrent ||
        boardId != widget.boardId ||
        epoch != _memberEpoch ||
        workspaceEpoch != _workspaceEpoch) {
      throw StateError('Sesi berubah, muat ulang data');
    }
    if (response is! Map || !response.containsKey('data')) {
      throw const FormatException('Data anggota tidak valid');
    }
    final data = response['data'];
    if (data == null) return const [];
    if (data is! List) throw const FormatException('Data anggota tidak valid');
    final users = <TaskUser>[];
    for (final item in data) {
      if (item is! Map) throw const FormatException('Anggota tidak valid');
      users.add(TaskUser.fromJson(Map<String, dynamic>.from(item)));
    }
    setState(() {
      _members = List.unmodifiable(users);
      _membersError = null;
    });
    return users;
  }

  Future<bool> _moveTask(
    String taskId,
    String sourceColumnId,
    String destinationId, {
    bool lockAlreadyHeld = false,
    String? expectedBoardId,
  }) async {
    final boardId = widget.boardId;
    if (sourceColumnId == destinationId ||
        !_isCurrent ||
        (expectedBoardId != null && expectedBoardId != boardId)) {
      return false;
    }
    if (!lockAlreadyHeld && _workspaceLocked) return false;
    if (!lockAlreadyHeld) setState(() => _workspaceLocked = true);
    var committed = false;
    try {
      final latest = await TaskService.getTask(
        taskId,
        expectedGeneration: _viewGeneration,
      );
      if (boardId != widget.boardId) return false;
      if (!_isCurrent) {
        _markStale();
        return false;
      }
      final source = _columnForPublicId(sourceColumnId);
      final destination = _columnForPublicId(destinationId);
      if (source == null ||
          destination == null ||
          latest.listInternalId != source.internalId) {
        _showError(StateError('Tugas berubah kolom. Muat ulang papan.'));
        return false;
      }
      await TaskService.updateTask(
        taskId,
        latest.updatePayload(listId: destination.publicId),
        expectedGeneration: _viewGeneration,
      );
      committed = true;
      if (boardId != widget.boardId) return false;
      _markChanged();
      return true;
    } catch (error) {
      if (mounted && error is! UnauthorizedException) _showError(error);
      return false;
    } finally {
      if (!lockAlreadyHeld && mounted) {
        final refresh = committed && boardId == widget.boardId && _isCurrent;
        setState(() => _workspaceLocked = false);
        _refreshNeeded = false;
        if (refresh) await _refreshWorkspace();
      }
    }
  }

  KanbanColumn? _columnForPublicId(String id) {
    for (final column in _columns) {
      if (column.publicId == id) return column;
    }
    return null;
  }

  void _showError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _projectTab() {
    if (_columnsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_columnsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _missingColumnOrder
                    ? 'Urutan kolom belum tersedia'
                    : _columnsError!,
                textAlign: TextAlign.center,
              ),
              if (_missingColumnOrder) ...[
                const SizedBox(height: 6),
                Text(_columnsError!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _workspaceLocked ? null : _loadColumns,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba lagi'),
                  ),
                  if (_missingColumnOrder)
                    FilledButton.icon(
                      onPressed: _workspaceLocked ? null : _createColumn,
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah kolom'),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    if (_columns.isEmpty) {
      return const Center(child: Text('Belum ada kolom'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = (constraints.maxWidth - 64)
            .clamp(0.0, 320.0)
            .toDouble();
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: _columns.length,
          itemBuilder: (context, index) {
            final column = _columns[index];
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: panelWidth,
                child: TaskColumn(
                  column: column,
                  tasks: _tasksByColumn[column.publicId] ?? const [],
                  isLoading: _taskLoading[column.publicId] ?? true,
                  error: _taskErrors[column.publicId],
                  busy: _workspaceLocked,
                  canCreate:
                      _tasksByColumn.containsKey(column.publicId) &&
                      _taskErrors[column.publicId] == null,
                  onRetry: () => _loadTasks(column),
                  onOpen: _openTask,
                  onCreate: () => _createTask(column),
                  onRename: () => _renameColumn(column),
                  onDelete: () => _deleteColumn(column),
                  canAcceptDrop: (task) =>
                      !_workspaceLocked &&
                      _tasksByColumn.containsKey(column.publicId) &&
                      _taskErrors[column.publicId] == null &&
                      _columns.any(
                        (item) =>
                            item.publicId != column.publicId &&
                            _tasksByColumn[item.publicId]?.any(
                                  (known) => known.publicId == task.publicId,
                                ) ==
                                true,
                      ),
                  onDrop: (task, destinationId) async {
                    await _moveTask(
                      task.publicId,
                      _findTaskColumn(task.publicId),
                      destinationId,
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _findTaskColumn(String taskId) {
    for (final entry in _tasksByColumn.entries) {
      if (entry.value.any((task) => task.publicId == taskId)) return entry.key;
    }
    return '';
  }

  bool get _taskListsSettled {
    if (_columnsLoading) return false;
    if (_columnsError != null) return true;
    return _columns.every(
      (column) =>
          _taskLoading[column.publicId] == false ||
          _tasksByColumn.containsKey(column.publicId) ||
          _taskErrors[column.publicId] != null,
    );
  }

  void _maybeLoadSummary() {
    if (_selectedTab != 1 ||
        _summaryLoading ||
        _summary != null ||
        _summaryError != null ||
        !_taskListsSettled) {
      return;
    }
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    if (!_isCurrent) {
      _markStale();
      return;
    }
    if (_columnsLoading ||
        _columns.any(
          (column) =>
              _taskLoading[column.publicId] == true ||
              (!_tasksByColumn.containsKey(column.publicId) &&
                  _taskErrors[column.publicId] == null),
        )) {
      setState(() {
        _summaryLoading = false;
        _summaryError = null;
      });
      return;
    }
    final taskErrors = _taskErrors.values.whereType<String>();
    final listError =
        _columnsError ?? (taskErrors.isEmpty ? null : taskErrors.first);
    if (listError != null) {
      setState(() {
        _summaryLoading = false;
        _summaryError = listError;
      });
      return;
    }

    final boardId = widget.boardId;
    final workspaceEpoch = _workspaceEpoch;
    final epoch = ++_summaryEpoch;
    setState(() {
      _summary = null;
      _summaryLoading = true;
      _summaryError = null;
    });

    final references = <MapEntry<KanbanColumn, TaskCard>>[];
    for (final column in _columns) {
      for (final task in _tasksByColumn[column.publicId] ?? const []) {
        references.add(MapEntry(column, task));
      }
    }
    final details = List<TaskCard?>.filled(references.length, null);
    final errors = List<Object?>.filled(references.length, null);
    await Future.wait(
      List<Future<void>>.generate(references.length, (index) async {
        try {
          final reference = references[index];
          final detail = await TaskService.getTask(
            reference.value.publicId,
            expectedGeneration: _viewGeneration,
          );
          if (detail.listInternalId != reference.key.internalId) {
            throw const FormatException(
              'Tugas berubah kolom. Muat ulang papan.',
            );
          }
          details[index] = detail;
        } catch (error) {
          errors[index] = error;
        }
      }),
    );
    if (boardId != widget.boardId ||
        workspaceEpoch != _workspaceEpoch ||
        epoch != _summaryEpoch) {
      return;
    }
    if (!_isCurrent) {
      _markStale();
      return;
    }
    final failedIndex = errors.indexWhere((error) => error != null);
    if (failedIndex >= 0) {
      setState(() {
        _summaryLoading = false;
        _summaryError = _summaryErrorText(errors[failedIndex]!);
      });
      return;
    }
    final hydrated = <String, List<TaskCard>>{
      for (final column in _columns) column.publicId: <TaskCard>[],
    };
    for (var index = 0; index < references.length; index++) {
      hydrated[references[index].key.publicId]!.add(details[index]!);
    }
    setState(() {
      _summary = computeTaskSummary(
        columns: _columns,
        tasksByColumn: hydrated,
        today: DateTime.now(),
      );
      _summaryLoading = false;
      _summaryError = null;
    });
  }

  String _summaryErrorText(Object error) {
    if (error is NetworkHttpException) return error.message;
    if (error is FormatException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _retrySummary() async {
    if (_columnsError != null ||
        _taskErrors.values.any((error) => error != null)) {
      await _refreshWorkspace();
      return;
    }
    await _loadSummary();
  }

  Widget _dashboardTab() {
    final summary =
        _summary ??
        computeTaskSummary(
          columns: _columns,
          tasksByColumn: const {},
          today: DateTime.now(),
        );
    return TaskSummaryView(
      summary: summary,
      complete: _summary != null && _summaryError == null,
      loading: _summaryLoading,
      error: _summaryError,
      onRetry: _retrySummary,
      onTaskOpen: (entry) => _openTask(entry.task),
    );
  }

  void _selectTab(int tab) {
    if (_selectedTab == tab) return;
    setState(() => _selectedTab = tab);
    if (tab == 1) _maybeLoadSummary();
  }

  @override
  Widget build(BuildContext context) {
    if (EnvironmentConfig.generation != _viewGeneration && !_sessionStale) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markStale();
      });
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Proyek')),
                  ButtonSegment(value: 1, label: Text('Ringkasan')),
                ],
                selected: {_selectedTab},
                onSelectionChanged: (selection) => _selectTab(selection.first),
              ),
              if (_selectedTab == 0) ...[
                OutlinedButton.icon(
                  onPressed: _workspaceLocked || _sessionStale
                      ? null
                      : _openMembers,
                  icon: const Icon(Icons.group_outlined),
                  label: const Text('Anggota'),
                ),
                FilledButton.tonalIcon(
                  onPressed:
                      _workspaceLocked ||
                          _sessionStale ||
                          (_columnsError != null && !_missingColumnOrder)
                      ? null
                      : _createColumn,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah kolom'),
                ),
              ],
            ],
          ),
        ),
        if (_sessionStale)
          const Expanded(
            child: Center(child: Text('Sesi berubah, buka ulang proyek')),
          )
        else
          Expanded(child: _selectedTab == 0 ? _projectTab() : _dashboardTab()),
      ],
    );
  }
}

class _ColumnTextDialog extends StatefulWidget {
  const _ColumnTextDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_ColumnTextDialog> createState() => _ColumnTextDialogState();
}

class _ColumnTextDialogState extends State<_ColumnTextDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 255,
      decoration: InputDecoration(labelText: 'Nama kolom', errorText: _error),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Simpan')),
    ],
  );

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Nama kolom wajib diisi');
      return;
    }
    Navigator.pop(context, value);
  }
}
