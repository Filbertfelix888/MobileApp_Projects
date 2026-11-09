import 'package:flutter/material.dart';

import 'create_new_task.dart';

typedef TaskMovedCallback = void Function(
  Map<String, dynamic> task,
  String fromListId,
  String toListId,
);

/// Data carried while a task card is being dragged between lists.
class TaskDragData {
  final Map<String, dynamic> task;
  final String listId;

  const TaskDragData({required this.task, required this.listId});
}

class ProjectListCard extends StatelessWidget {
  final Map<String, dynamic> list;
  final List<dynamic> tasks;
  final String projectInitials;
  final VoidCallback onDelete;
  final VoidCallback onTaskCreated;
  final TaskMovedCallback onTaskMoved;
  final double width;

  const ProjectListCard({
    super.key,
    required this.list,
    required this.tasks,
    required this.projectInitials,
    required this.onDelete,
    required this.onTaskCreated,
    required this.onTaskMoved,
    required this.width,
  });

  static const _primary = Color(0xFF1976D2);

  Widget _buildTaskTile(
    BuildContext context,
    Map<String, dynamic> task,
    Color dividerColor, {
    bool isDragging = false,
  }) {
    final taskTitle = task['title']?.toString() ?? '';
    final taskNumber = task['internal_id']?.toString() ?? '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(isDragging ? 6 : 4),
        border: Border.all(
          color: isDragging ? _primary : dividerColor,
          width: isDragging ? 1.5 : 1,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  taskTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.drag_indicator,
                size: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '$projectInitials-$taskNumber',
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragFeedback(
    BuildContext context,
    Map<String, dynamic> task,
    Color dividerColor,
  ) {
    return Material(
      color: Colors.transparent,
      child: Transform.rotate(
        angle: 0.015,
        child: SizedBox(
          width: width - 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTaskTile(context, task, dividerColor, isDragging: true),
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_with, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Geser ke daftar tujuan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragPlaceholder(
    BuildContext context,
    Map<String, dynamic> task,
    Color dividerColor,
  ) {
    final tile = _buildTaskTile(context, task, dividerColor);

    return Stack(
      children: [
        Opacity(opacity: 0.3, child: tile),
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_with, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Tugas diangkat',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDraggableTask(
    BuildContext context,
    Map<String, dynamic> task,
    String listId,
    Color dividerColor,
  ) {
    return LongPressDraggable<TaskDragData>(
      key: ValueKey('task-${task['public_id']}-$listId'),
      data: TaskDragData(task: task, listId: listId),
      feedback: _buildDragFeedback(context, task, dividerColor),
      childWhenDragging: _buildDragPlaceholder(context, task, dividerColor),
      child: _buildTaskTile(context, task, dividerColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = list['title']?.toString() ?? '';
    final publicId = list['public_id']?.toString() ?? '';
    final dividerColor = Theme.of(context).dividerColor;

    return DragTarget<TaskDragData>(
      onWillAcceptWithDetails: (details) =>
          publicId.isNotEmpty && details.data.listId != publicId,
      onAcceptWithDetails: (details) {
        onTaskMoved(details.data.task, details.data.listId, publicId);
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;

        return SizedBox(
          width: width,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: isDropTarget
                  ? _primary.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            foregroundDecoration: isDropTarget
                ? BoxDecoration(
                    border: Border.all(color: _primary, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 40,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                constraints: const BoxConstraints(minWidth: 28),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5A623),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${tasks.length}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: InkWell(
                            onTap: onDelete,
                            customBorder: const CircleBorder(),
                            child: const Center(
                              child: Icon(
                                Icons.delete,
                                size: 18,
                                color: Color(0xFFD32F2F),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, thickness: 1, color: dividerColor),
                if (tasks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Column(
                      children: [
                        for (final task in tasks)
                          if (task is Map)
                            _buildDraggableTask(
                              context,
                              Map<String, dynamic>.from(task),
                              publicId,
                              dividerColor,
                            ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: CreateNewTask(
                    listId: publicId,
                    position: tasks.length + 1,
                    onSuccess: onTaskCreated,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
