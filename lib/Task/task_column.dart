import 'package:flutter/material.dart';

import 'task_models.dart';

/// One server-ordered board column. Parent owns destructive confirmations.
class TaskColumn extends StatelessWidget {
  const TaskColumn({
    super.key,
    required this.column,
    required this.tasks,
    required this.isLoading,
    required this.error,
    required this.busy,
    required this.canCreate,
    required this.onRetry,
    required this.onOpen,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
    required this.canAcceptDrop,
    required this.onDrop,
    this.onQuickComplete,
    this.canQuickComplete,
  });

  final KanbanColumn column;
  final List<TaskCard> tasks;
  final bool isLoading;
  final String? error;
  final bool busy;
  final bool canCreate;
  final VoidCallback onRetry;
  final ValueChanged<TaskCard> onOpen;
  final VoidCallback onCreate;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final bool Function(TaskCard task) canAcceptDrop;
  final Future<void> Function(TaskCard task, String destinationColumnId) onDrop;
  final void Function(TaskCard task)? onQuickComplete;
  final bool Function(TaskCard task)? canQuickComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<TaskCard>(
      onWillAcceptWithDetails: (details) =>
          !busy && canAcceptDrop(details.data),
      onAcceptWithDetails: (details) => onDrop(details.data, column.publicId),
      builder: (context, candidates, rejected) {
        final isTarget = candidates.isNotEmpty;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isTarget
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isTarget
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              if (isTarget)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Lepas untuk menambahkan tugas ke kolom ini',
                    style: theme.textTheme.labelMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(child: _buildTasks(context)),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Semantics(
                  label: 'Tambah tugas ke ${column.displayTitle}',
                  button: true,
                  child: OutlinedButton.icon(
                    onPressed: canCreate && !busy ? onCreate : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah tugas'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              column.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Semantics(
            label: '${tasks.length} tugas di ${column.displayTitle}',
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${tasks.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Aksi kolom ${column.displayTitle}',
            enabled: !busy,
            onSelected: (action) {
              if (action == 'rename') onRename();
              if (action == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'rename',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Ganti nama kolom'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline),
                  title: Text('Hapus kolom'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTasks(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Memuat tugas'),
      );
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: busy ? null : onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }
    if (tasks.isEmpty) {
      return const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('Belum ada tugas'),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      itemCount: tasks.length,
      itemBuilder: (context, index) => _TaskCardTile(
        task: tasks[index],
        enabled: !busy,
        onTap: () => onOpen(tasks[index]),
        canQuickComplete: canQuickComplete?.call(tasks[index]) ?? false,
        onQuickComplete: onQuickComplete,
      ),
    );
  }
}

class _TaskCardTile extends StatefulWidget {
  const _TaskCardTile({
    required this.task,
    required this.enabled,
    required this.onTap,
    this.canQuickComplete = false,
    this.onQuickComplete,
  });

  final TaskCard task;
  final bool enabled;
  final VoidCallback onTap;
  final bool canQuickComplete;
  final void Function(TaskCard task)? onQuickComplete;

  @override
  State<_TaskCardTile> createState() => _TaskCardTileState();
}

class _TaskCardTileState extends State<_TaskCardTile> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<TaskCard>(
      data: widget.task,
      maxSimultaneousDrags: widget.enabled ? 1 : 0,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 280, child: _card(context, dragging: true)),
      ),
      childWhenDragging: Opacity(opacity: 0.45, child: _card(context)),
      child: _card(context),
    );
  }

  Widget _card(BuildContext context, {bool dragging = false}) {
    final theme = Theme.of(context);
    final preview = widget.task.description.trim();
    final dueDate = _calendarDate(widget.task.dueDate);
    final canAct = widget.enabled && !dragging;
    final activeGreen = canAct && (_isHovering || _isPressed);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: canAct ? widget.onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Semantics(
          button: true,
          label: 'Tugas ${widget.task.displayTitle}',
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.task.displayTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (widget.canQuickComplete && widget.onQuickComplete != null)
                      Tooltip(
                        message: 'Tandai selesai',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          onHover: (hovering) {
                            if (!canAct) return;
                            if (_isHovering != hovering) {
                              setState(() => _isHovering = hovering);
                            }
                          },
                          onHighlightChanged: (pressed) {
                            if (!canAct) return;
                            if (_isPressed != pressed) {
                              setState(() => _isPressed = pressed);
                            }
                          },
                          onTap: canAct
                              ? () => widget.onQuickComplete!(widget.task)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              activeGreen
                                  ? Icons.check_circle
                                  : Icons.check_circle_outline,
                              size: 20,
                              color: activeGreen
                                  ? Colors.green
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (dueDate != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.event_outlined, size: 16),
                      Text(
                        'Tenggat: $dueDate',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _calendarDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return 'Tanggal tidak tersedia';
    final utc = parsed.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }
}