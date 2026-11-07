import '../network.dart';
import 'task_models.dart';

class TaskService {
  static Future<List<KanbanColumn>> getColumns(
    String boardId, {
    required int expectedGeneration,
  }) async {
    final response = await Network.get(
      '/api/v1/boards/${Uri.encodeComponent(boardId)}/lists',
      expectedGeneration: expectedGeneration,
    );
    final data = _dataObject(response);
    if (!data.containsKey('Lists')) {
      throw const FormatException('Missing Lists collection');
    }
    final rawLists = data['Lists'];
    if (rawLists == null) return const <KanbanColumn>[];
    if (rawLists is! List) {
      throw const FormatException('Invalid Lists collection');
    }
    return List.unmodifiable(
      rawLists.map((value) {
        if (value is! Map) throw const FormatException('Invalid list item');
        return KanbanColumn.fromJson(_stringMap(value));
      }),
    );
  }

  static Future<KanbanColumn> createColumn(
    String boardId,
    String title, {
    required int expectedGeneration,
  }) async {
    final response = await Network.post('/api/v1/lists', {
      'board_public_id': boardId,
      'title': title,
    }, expectedGeneration: expectedGeneration);
    return KanbanColumn.fromJson(_dataObject(response));
  }

  static Future<KanbanColumn> renameColumn(
    String columnId,
    String title, {
    required int expectedGeneration,
  }) async {
    final response = await Network.put(
      '/api/v1/lists/${Uri.encodeComponent(columnId)}',
      {'title': title},
      expectedGeneration: expectedGeneration,
    );
    return KanbanColumn.fromJson(_dataObject(response));
  }

  static Future<void> deleteColumn(
    String columnId, {
    required int expectedGeneration,
  }) async {
    await Network.delete(
      '/api/v1/lists/${Uri.encodeComponent(columnId)}',
      expectedGeneration: expectedGeneration,
    );
  }

  static Future<List<TaskCard>> getTasks(
    String columnId, {
    required int expectedGeneration,
  }) async {
    final response = await Network.get(
      '/api/v1/lists/${Uri.encodeComponent(columnId)}/cards',
      expectedGeneration: expectedGeneration,
    );
    final data = _dataValue(response);
    if (data == null) return const <TaskCard>[];
    if (data is! List) throw const FormatException('Invalid cards collection');
    return List.unmodifiable(
      data.map((value) {
        if (value is! Map) throw const FormatException('Invalid card item');
        return TaskCard.fromJson(_stringMap(value));
      }),
    );
  }

  static Future<TaskCard> getTask(
    String taskId, {
    required int expectedGeneration,
  }) async {
    final response = await Network.get(
      '/api/v1/cards/${Uri.encodeComponent(taskId)}',
      expectedGeneration: expectedGeneration,
    );
    return TaskCard.fromJson(_dataObject(response));
  }

  static Future<void> createTask(
    String columnId, {
    required String title,
    String description = '',
    String? dueDate,
    required int position,
    required int expectedGeneration,
  }) async {
    final payload = <String, dynamic>{
      'list_id': columnId,
      'title': title,
      'description': description,
      'position': position,
    };
    if (dueDate != null) payload['due_date'] = dueDate;
    await Network.post(
      '/api/v1/cards',
      payload,
      expectedGeneration: expectedGeneration,
    );
  }

  static Future<void> updateTask(
    String taskId,
    Map<String, dynamic> payload, {
    required int expectedGeneration,
  }) async {
    await Network.put(
      '/api/v1/cards/${Uri.encodeComponent(taskId)}',
      payload,
      expectedGeneration: expectedGeneration,
    );
  }

  static Future<void> deleteTask(
    String taskId, {
    required int expectedGeneration,
  }) async {
    await Network.delete(
      '/api/v1/cards/${Uri.encodeComponent(taskId)}',
      expectedGeneration: expectedGeneration,
    );
  }

  static Future<void> addAssignees(
    String taskId,
    List<String> userIds, {
    required int expectedGeneration,
  }) async {
    if (userIds.isEmpty) {
      throw ArgumentError.value(userIds, 'userIds', 'Must not be empty');
    }
    await Network.post(
      '/api/v1/cards/${Uri.encodeComponent(taskId)}/assignees',
      {'user_id': userIds},
      expectedGeneration: expectedGeneration,
    );
  }

  static Future<void> removeAssignees(
    String taskId,
    List<String> userIds, {
    required int expectedGeneration,
  }) async {
    if (userIds.isEmpty) {
      throw ArgumentError.value(userIds, 'userIds', 'Must not be empty');
    }
    await Network.delete(
      '/api/v1/cards/${Uri.encodeComponent(taskId)}/assignees',
      payload: {'user_id': userIds},
      expectedGeneration: expectedGeneration,
    );
  }

  static Future<TaskUserPage> searchUsers({
    required String search,
    int page = 1,
    required int expectedGeneration,
  }) async {
    if (page < 1) throw ArgumentError.value(page, 'page', 'Must be positive');
    final path = Uri(
      path: '/api/v1/users/page',
      queryParameters: {
        'filter': search,
        'page': '$page',
        'limit': '10',
        'sort': 'name',
      },
    ).toString();
    try {
      final response = await Network.get(
        path,
        expectedGeneration: expectedGeneration,
      );
      return TaskUserPage.fromJson(_envelope(response));
    } on NetworkHttpException catch (error) {
      if (error.statusCode == 404 && error.meta?['total'] == 0) {
        return TaskUserPage(users: const [], page: page, totalPages: 1);
      }
      rethrow;
    }
  }
}

Map<String, dynamic> _envelope(dynamic response) {
  if (response is! Map) {
    throw const FormatException('Invalid response envelope');
  }
  return _stringMap(response);
}

Map<String, dynamic> _dataObject(dynamic response) {
  final data = _envelope(response)['data'];
  if (data is! Map) throw const FormatException('Invalid data object');
  return _stringMap(data);
}

dynamic _dataValue(dynamic response) {
  final envelope = _envelope(response);
  if (!envelope.containsKey('data')) {
    throw const FormatException('Missing data collection');
  }
  return envelope['data'];
}

Map<String, dynamic> _stringMap(Map value) {
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw const FormatException('Invalid object key');
    result[entry.key as String] = entry.value;
  }
  return result;
}
