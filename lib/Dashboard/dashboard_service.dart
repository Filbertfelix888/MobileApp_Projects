import '../network.dart';

class AssigneeTaskCount {
  const AssigneeTaskCount({required this.assignee, required this.taskCount});

  final String assignee;
  final int taskCount;

  factory AssigneeTaskCount.fromJson(Map<String, dynamic> json) {
    final assignee = json['assignee'];
    final taskCount = json['taskCount'];
    if (assignee is! String) {
      throw const FormatException('Invalid workload assignee');
    }
    if (taskCount is! int || taskCount < 0) {
      throw const FormatException('Invalid workload taskCount');
    }
    return AssigneeTaskCount(assignee: assignee, taskCount: taskCount);
  }
}

class DashboardService {
  static Future<List<AssigneeTaskCount>> getWorkload({
    required int expectedGeneration,
  }) async {
    final response = await Network.get(
      '/api/v1/dashboard/workload',
      expectedGeneration: expectedGeneration,
    );
    if (response == null) return const [];
    if (response is! List) {
      throw const FormatException('Invalid dashboard workload collection');
    }
    final workload = <AssigneeTaskCount>[];
    for (final item in response) {
      if (item is! Map) {
        throw const FormatException('Invalid dashboard workload item');
      }
      final json = <String, dynamic>{};
      for (final entry in item.entries) {
        if (entry.key is! String) {
          throw const FormatException('Invalid dashboard workload key');
        }
        json[entry.key as String] = entry.value;
      }
      workload.add(AssigneeTaskCount.fromJson(json));
    }
    return List.unmodifiable(workload);
  }
}
