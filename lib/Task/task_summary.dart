import 'package:flutter/material.dart';

import 'task_models.dart';

/// Count and floor percentage for one column, in server-provided board order.
class TaskColumnSummary {
  const TaskColumnSummary({
    required this.column,
    required this.count,
    required this.percentage,
  });

  final KanbanColumn column;
  final int count;
  final int percentage;
}

/// Hydrated assignment workload for one public user identity.
class TaskWorkloadRow {
  const TaskWorkloadRow({required this.user, required this.taskCount});

  final TaskUser user;
  final int taskCount;

  String get publicId => user.publicId;
  String get name => user.displayName;
  String get email => user.displayEmail;
}

/// A dated task paired with its containing board column and UTC due calendar day.
class TaskSummaryTaskEntry {
  const TaskSummaryTaskEntry({
    required this.task,
    required this.column,
    required this.dueDay,
  });

  final TaskCard task;
  final KanbanColumn column;
  final DateTime dueDay;
}

/// Immutable board-local task metrics derived from hydrated card data.
class TaskSummary {
  const TaskSummary({
    required this.totalTasks,
    required this.columns,
    required this.workloads,
    required this.unassignedCount,
    required this.overdueOrToday,
    required this.dueSoon,
  });

  final int totalTasks;
  final List<TaskColumnSummary> columns;
  final List<TaskWorkloadRow> workloads;
  final int unassignedCount;
  final List<TaskSummaryTaskEntry> overdueOrToday;
  final List<TaskSummaryTaskEntry> dueSoon;

  /// Workload counts keyed by public UUID; duplicate display names stay distinct.
  Map<String, int> get workloadByPublicId => Map.unmodifiable({
    for (final row in workloads) row.publicId: row.taskCount,
  });
}

/// Computes board metrics without state, I/O, or dependence on column names.
TaskSummary computeTaskSummary({
  required List<KanbanColumn> columns,
  required Map<String, List<TaskCard>> tasksByColumn,
  required DateTime today,
}) {
  final total = columns.fold<int>(
    0,
    (sum, column) => sum + (tasksByColumn[column.publicId]?.length ?? 0),
  );
  final columnSummaries = <TaskColumnSummary>[];
  final userById = <String, TaskUser>{};
  final workloadCounts = <String, int>{};
  final dated = <TaskSummaryTaskEntry>[];
  var unassigned = 0;

  for (final column in columns) {
    final tasks = tasksByColumn[column.publicId] ?? const <TaskCard>[];
    columnSummaries.add(
      TaskColumnSummary(
        column: column,
        count: tasks.length,
        percentage: total == 0 ? 0 : (tasks.length * 100 ~/ total),
      ),
    );
    for (final task in tasks) {
      final uniqueAssignees = <String, TaskUser>{};
      for (final assignee in task.assignees) {
        uniqueAssignees.putIfAbsent(
          assignee.user.publicId,
          () => assignee.user,
        );
      }
      if (uniqueAssignees.isEmpty) {
        unassigned++;
      } else {
        for (final entry in uniqueAssignees.entries) {
          userById.putIfAbsent(entry.key, () => entry.value);
          workloadCounts.update(
            entry.key,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }

      final dueDay = _utcCalendarDay(task.dueDate);
      if (dueDay != null) {
        dated.add(
          TaskSummaryTaskEntry(task: task, column: column, dueDay: dueDay),
        );
      }
    }
  }

  final todayDay = DateTime.utc(today.year, today.month, today.day);
  final overdueOrToday = <TaskSummaryTaskEntry>[];
  final dueSoon = <TaskSummaryTaskEntry>[];
  for (final entry in dated) {
    final difference = entry.dueDay.difference(todayDay).inDays;
    if (difference <= 0) {
      overdueOrToday.add(entry);
    } else if (difference <= 3) {
      dueSoon.add(entry);
    }
  }
  int compareEntries(TaskSummaryTaskEntry a, TaskSummaryTaskEntry b) {
    final dateOrder = a.dueDay.compareTo(b.dueDay);
    if (dateOrder != 0) return dateOrder;
    final titleOrder = a.task.title.toLowerCase().compareTo(
      b.task.title.toLowerCase(),
    );
    return titleOrder != 0
        ? titleOrder
        : a.task.publicId.compareTo(b.task.publicId);
  }

  overdueOrToday.sort(compareEntries);
  dueSoon.sort(compareEntries);

  final workloadRows =
      [
        for (final entry in workloadCounts.entries)
          TaskWorkloadRow(user: userById[entry.key]!, taskCount: entry.value),
      ]..sort((a, b) {
        final countOrder = b.taskCount.compareTo(a.taskCount);
        if (countOrder != 0) return countOrder;
        final nameOrder = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return nameOrder != 0 ? nameOrder : a.publicId.compareTo(b.publicId);
      });

  return TaskSummary(
    totalTasks: total,
    columns: List.unmodifiable(columnSummaries),
    workloads: List.unmodifiable(workloadRows),
    unassignedCount: unassigned,
    overdueOrToday: List.unmodifiable(overdueOrToday),
    dueSoon: List.unmodifiable(dueSoon),
  );
}

DateTime? _utcCalendarDay(String? raw) {
  if (raw == null || raw.isEmpty || raw.startsWith('0001-01-01')) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final utc = parsed.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day);
}

/// Text-first board summary. Incomplete hydration remains visible and retryable.
class TaskSummaryView extends StatelessWidget {
  const TaskSummaryView({
    super.key,
    required this.summary,
    required this.complete,
    this.error,
    this.loading = false,
    this.onRetry,
    required this.onTaskOpen,
  });

  final TaskSummary summary;
  final bool complete;
  final String? error;
  final bool loading;
  final VoidCallback? onRetry;
  final ValueChanged<TaskSummaryTaskEntry> onTaskOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!complete) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Ringkasan tugas', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            loading ? 'Memuat detail tugas; ringkasan belum lengkap.' : 'Ringkasan belum lengkap karena sebagian detail tugas gagal dimuat.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (!loading && onRetry != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Ringkasan tugas', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Total tugas: ${summary.totalTasks}',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        Text('Tugas per kolom', style: theme.textTheme.titleMedium),
        for (final item in summary.columns)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.column.displayTitle}: ${item.count} (${item.percentage}%)',
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: item.percentage / 100),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Text('Beban tugas', style: theme.textTheme.titleMedium),
        if (summary.workloads.isEmpty && summary.unassignedCount == 0)
          const Text('Belum ada tugas yang ditugaskan.'),
        for (final row in summary.workloads)
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: EdgeInsets.zero,
            title: Text(row.name),
            subtitle: Text(row.email),
            trailing: Text('${row.taskCount}'),
          ),
        if (summary.unassignedCount > 0)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
            title: const Text('Belum ditugaskan'),
            trailing: Text('${summary.unassignedCount}'),
          ),
        const SizedBox(height: 16),
        _taskSection(
          context,
          'Terlambat atau jatuh tempo hari ini',
          summary.overdueOrToday,
        ),
        const SizedBox(height: 12),
        _taskSection(context, 'Jatuh tempo 1–3 hari lagi', summary.dueSoon),
      ],
    );
  }

  Widget _taskSection(
    BuildContext context,
    String title,
    List<TaskSummaryTaskEntry> entries,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (entries.isEmpty) const Text('Tidak ada tugas.'),
        for (final entry in entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.task.displayTitle),
            subtitle: Text(
              '${entry.column.displayTitle} • ${_formatDay(entry.dueDay)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onTaskOpen(entry),
          ),
      ],
    );
  }
}

String _formatDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
