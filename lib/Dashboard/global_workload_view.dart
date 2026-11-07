import 'package:flutter/material.dart';

import 'dashboard_service.dart';

class GlobalWorkloadView extends StatelessWidget {
  const GlobalWorkloadView({
    super.key,
    required this.workload,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<AssigneeTaskCount> workload;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assignments = workload.fold<int>(
      0,
      (total, row) => total + row.taskCount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Beban tugas', style: theme.textTheme.titleLarge),
            ),
            if (!loading && error == null)
              IconButton(
                tooltip: 'Muat ulang beban tugas',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Agregat semua penugasan backend; tidak dipisah per proyek atau pengguna. Nama anggota yang sama digabung.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        if (loading)
          Semantics(
            label: 'Memuat beban tugas',
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: List.generate(
                  3,
                  (_) => Container(
                    height: 48,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          )
        else if (error != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(error!, style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
          )
        else if (workload.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Belum ada tugas yang memiliki penanggung jawab.'),
          )
        else ...[
          Text(
            'Jumlah penugasan: $assignments',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final row in workload) ...[
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              title: Text(row.assignee.isEmpty ? 'Tanpa nama' : row.assignee),
              subtitle: const Text('Penugasan pada seluruh proyek'),
              trailing: Text('${row.taskCount}'),
            ),
            const Divider(height: 1),
          ],
        ],
      ],
    );
  }
}
