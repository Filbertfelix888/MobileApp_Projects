import 'package:flutter/material.dart';

import '../network.dart';
import '../environment_config.dart';
import 'task_models.dart';
import 'task_service.dart';

class TaskFormDialog extends StatefulWidget {
  const TaskFormDialog({
    super.key,
    required this.boardId,
    required this.column,
    required this.nextPosition,
    required this.expectedGeneration,
    this.boardDueDate,
    required this.isBoardCurrent,
  });

  final String boardId;
  final bool Function() isBoardCurrent;
  final KanbanColumn column;
  final int nextPosition;
  final int expectedGeneration;
  final String? boardDueDate;

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  DateTime? _deadline;
  bool _pending = false;
  String? _error;
  late final int _viewGeneration;
  late final String _columnId;
  late final String _boardId;

  @override
  void initState() {
    super.initState();
    _viewGeneration = widget.expectedGeneration;
    _columnId = widget.column.publicId;
    _boardId = widget.boardId;
  }

  bool get _isCurrent =>
      EnvironmentConfig.generation == _viewGeneration &&
      widget.expectedGeneration == _viewGeneration &&
      widget.boardId == _boardId &&
      widget.column.publicId == _columnId &&
      widget.column.boardPublicId == _boardId &&
      widget.isBoardCurrent();

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? get _projectDeadline {
    final raw = widget.boardDueDate;
    if (raw == null || raw.isEmpty || raw.startsWith('0001-01-01')) {
      return null;
    }
    final parsed = DateTime.tryParse(raw)?.toLocal();
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  Future<void> _chooseDeadline() async {
    if (!_isCurrent) {
      setState(() => _error = 'Sesi berubah, buka ulang proyek');
      return;
    }
    final cap = _projectDeadline;
    if (cap != null && cap.isBefore(_today)) {
      setState(
        () =>
            _error = 'Tanggal proyek sudah lewat; tenggat baru tidak tersedia',
      );
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? _today,
      firstDate: _today,
      lastDate: cap ?? DateTime(_today.year + 100, 12, 31),
    );
    if (picked != null && mounted && _isCurrent) {
      setState(() {
        _deadline = DateTime.utc(picked.year, picked.month, picked.day);
        _error = null;
      });
    } else if (picked != null && mounted) {
      setState(() => _error = 'Sesi berubah, buka ulang proyek');
    }
  }

  String _dateLabel(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_pending) return;
    if (!_isCurrent) {
      setState(() => _error = 'Sesi berubah, buka ulang proyek');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await TaskService.createTask(
        _columnId,
        title: _title.text.trim(),
        description: _description.text,
        dueDate: _deadline == null
            ? null
            : '${_dateLabel(_deadline!)}T00:00:00Z',
        position: widget.nextPosition,
        expectedGeneration: _viewGeneration,
      );
      if (mounted && _isCurrent) {
        Navigator.of(context).pop(true);
      } else if (mounted) {
        setState(() => _error = 'Sesi berubah, buka ulang proyek');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          if (!_isCurrent) {
            _error = 'Sesi berubah, buka ulang proyek';
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
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_pending,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tugas baru · ${widget.column.displayTitle}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _title,
                    autofocus: true,
                    maxLength: 255,
                    enabled: !_pending && _isCurrent,
                    decoration: const InputDecoration(labelText: 'Judul tugas'),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Judul wajib diisi';
                      }
                      if (value!.trim().runes.length > 255) {
                        return 'Maksimal 255 karakter';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _description,
                    enabled: !_pending && _isCurrent,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Deskripsi'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pending || !_isCurrent ? null : _chooseDeadline,
                    icon: const Icon(Icons.event),
                    label: Text(
                      _deadline == null
                          ? 'Pilih tenggat (opsional)'
                          : 'Tenggat: ${_dateLabel(_deadline!)}',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _pending
                            ? null
                            : () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                      FilledButton(
                        onPressed: _pending || !_isCurrent ? null : _submit,
                        child: _pending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Buat tugas'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
