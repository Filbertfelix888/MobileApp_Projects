import 'dart:math' as math;

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
        const SizedBox(height: 12),
        _TaskDistributionChart(
          columns: summary.columns,
          totalTasks: summary.totalTasks,
        ),
        const SizedBox(height: 16),
        Text('Beban tugas', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _WorkloadChart(summary: summary),
        const SizedBox(height: 16),
        _taskSection(
          context,
          'Terlambat atau jatuh tempo hari ini (${summary.overdueOrToday.length})',
          summary.overdueOrToday,
        ),
        const SizedBox(height: 12),
        _taskSection(
          context,
          'Jatuh tempo 1–3 hari lagi (${summary.dueSoon.length})',
          summary.dueSoon,
        ),
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

class _TaskDistributionChart extends StatelessWidget {
  const _TaskDistributionChart({
    required this.columns,
    required this.totalTasks,
  });

  final List<TaskColumnSummary> columns;
  final int totalTasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = List.generate(
      columns.length,
      (index) =>
          _categoryColor(theme.colorScheme.primary, theme.brightness, index),
    );
    final chartLabel = columns
        .map(
          (item) =>
              '${item.column.displayTitle}: ${item.count} tugas, ${item.percentage}%',
        )
        .join('. ');

    return Column(
      children: [
        Semantics(
          container: true,
          label: columns.isEmpty
              ? 'Sebaran tugas per kolom. Belum ada kolom.'
              : 'Sebaran tugas per kolom. Total $totalTasks tugas. $chartLabel',
          child: ExcludeSemantics(
            child: SizedBox(
              width: 184,
              height: 184,
              child: CustomPaint(
                painter: _TaskDistributionPainter(
                  counts: columns.map((item) => item.count).toList(),
                  colors: colors,
                  totalTasks: totalTasks,
                  trackColor: theme.colorScheme.surfaceContainerHigh,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$totalTasks', style: theme.textTheme.titleLarge),
                      Text('tugas', style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (columns.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Belum ada kolom tugas.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        for (var i = 0; i < columns.length; i++)
          Semantics(
            container: true,
            label:
                '${columns[i].column.displayTitle}: ${columns[i].count} tugas, ${columns[i].percentage}%',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors[i],
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        columns[i].column.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${columns[i].count} (${columns[i].percentage}%)',
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WorkloadChart extends StatelessWidget {
  const _WorkloadChart({required this.summary});

  final TaskSummary summary;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final row in summary.workloads)
        _WorkloadEntry(
          name: row.name,
          email: row.email,
          taskCount: row.taskCount,
        ),
      if (summary.unassignedCount > 0)
        _WorkloadEntry(
          name: 'Belum ditugaskan',
          taskCount: summary.unassignedCount,
        ),
    ];
    if (rows.isEmpty) {
      return const Text('Belum ada tugas yang ditugaskan.');
    }

    var maxCount = 0;
    for (final row in rows) {
      if (row.taskCount > maxCount) maxCount = row.taskCount;
    }

    return Column(
      children: [
        for (final row in rows) _WorkloadBar(row: row, maxCount: maxCount),
      ],
    );
  }
}

class _WorkloadEntry {
  const _WorkloadEntry({
    required this.name,
    this.email,
    required this.taskCount,
  });

  final String name;
  final String? email;
  final int taskCount;
}

class _WorkloadBar extends StatelessWidget {
  const _WorkloadBar({required this.row, required this.maxCount});

  final _WorkloadEntry row;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = row.email;
    return Semantics(
      container: true,
      label:
          '${row.name}${email == null || email.isEmpty ? '' : ', $email'}: ${row.taskCount} tugas',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (email != null && email.isNotEmpty)
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${row.taskCount}'),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: row.taskCount / maxCount,
                  minHeight: 8,
                  color: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskDistributionPainter extends CustomPainter {
  const _TaskDistributionPainter({
    required this.counts,
    required this.colors,
    required this.totalTasks,
    required this.trackColor,
  });

  final List<int> counts;
  final List<Color> colors;
  final int totalTasks;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 24.0;
    final radius = math
        .max(0.0, math.min(size.width, size.height) / 2 - strokeWidth / 2)
        .toDouble();
    if (radius == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, track);
    if (totalTasks <= 0) return;

    var startAngle = -math.pi / 2;
    for (var i = 0; i < counts.length; i++) {
      final sweep = math.pi * 2 * counts[i] / totalTasks;
      final gap = counts[i] > 0 && counts[i] < totalTasks && sweep > 0.04
          ? 0.04
          : 0.0;
      final segment = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawArc(rect, startAngle + gap / 2, sweep - gap, false, segment);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _TaskDistributionPainter oldDelegate) {
    if (totalTasks != oldDelegate.totalTasks ||
        trackColor != oldDelegate.trackColor ||
        counts.length != oldDelegate.counts.length ||
        colors.length != oldDelegate.colors.length) {
      return true;
    }
    for (var i = 0; i < counts.length; i++) {
      if (counts[i] != oldDelegate.counts[i] ||
          colors[i] != oldDelegate.colors[i]) {
        return true;
      }
    }
    return false;
  }
}

Color _categoryColor(Color seed, Brightness brightness, int index) {
  if (index == 0) return seed;
  final base = HSLColor.fromColor(seed);
  return base
      .withHue((base.hue + index * 137.5) % 360)
      .withSaturation(0.52)
      .withLightness(brightness == Brightness.dark ? 0.68 : 0.48)
      .toColor();
}
