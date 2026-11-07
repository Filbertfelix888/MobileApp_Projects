class KanbanColumn {
  const KanbanColumn({
    required this.internalId,
    required this.publicId,
    required this.boardPublicId,
    required this.title,
    required this.position,
    required this.createdAt,
  });

  final int internalId;
  final String publicId;
  final String boardPublicId;
  final String title;
  final int position;
  final String createdAt;
  String get displayTitle => title.isEmpty ? 'Tanpa judul' : title;

  factory KanbanColumn.fromJson(Map<String, dynamic> json) => KanbanColumn(
    internalId: _requiredInt(json, 'internal_id'),
    publicId: _requiredString(json, 'public_id'),
    boardPublicId: _requiredString(json, 'board_public_id'),
    title: _stringValue(json, 'title'),
    position: _requiredInt(json, 'position'),
    createdAt: _requiredString(json, 'created_at'),
  );
}

class TaskCard {
  const TaskCard({
    required this.internalId,
    required this.publicId,
    required this.listInternalId,
    required this.title,
    required this.description,
    required this.position,
    required this.createdAt,
    required this.dueDate,
    required this.assignees,
  });

  final int internalId;
  final String publicId;
  final int listInternalId;
  final String title;
  final String description;
  final int position;
  final String createdAt;
  final String? dueDate;
  String get displayTitle => title.isEmpty ? 'Tanpa judul' : title;
  final List<TaskAssignee> assignees;

  factory TaskCard.fromJson(Map<String, dynamic> json) {
    final rawDueDate = json['due_date'];
    if (rawDueDate != null && rawDueDate is! String) {
      throw const FormatException('Invalid card due_date');
    }
    final rawAssignees = json['assignees'];
    if (rawAssignees != null && rawAssignees is! List) {
      throw const FormatException('Invalid card assignees');
    }
    final assignees = <TaskAssignee>[];
    if (rawAssignees != null) {
      for (final value in rawAssignees as List) {
        if (value is! Map) throw const FormatException('Invalid card assignee');
        assignees.add(TaskAssignee.fromJson(_stringMap(value)));
      }
    }
    final parsedDueDate = rawDueDate as String?;
    return TaskCard(
      internalId: _requiredInt(json, 'internal_id'),
      publicId: _requiredString(json, 'public_id'),
      listInternalId: _requiredInt(json, 'list_internal_id'),
      title: _stringValue(json, 'title'),
      description: _optionalString(json, 'description') ?? '',
      position: _requiredInt(json, 'position'),
      createdAt: _requiredString(json, 'created_at'),
      dueDate: _isZeroDate(parsedDueDate) ? null : parsedDueDate,
      assignees: List.unmodifiable(assignees),
    );
  }

  Map<String, dynamic> updatePayload({
    required String listId,
    String? title,
    String? description,
    String? dueDate,
    bool clearDueDate = false,
  }) => {
    'list_id': listId,
    'title': title ?? this.title,
    'description': description ?? this.description,
    'due_date': clearDueDate ? null : dueDate ?? this.dueDate,
    'position': position,
  };
}

class TaskUser {
  const TaskUser({
    required this.publicId,
    required this.name,
    required this.email,
  });

  final String publicId;
  final String name;
  final String email;

  String get displayName => name.isEmpty ? 'Tanpa nama' : name;
  String get displayEmail => email.isEmpty ? 'Email tidak tersedia' : email;

  factory TaskUser.fromJson(Map<String, dynamic> json) => TaskUser(
    publicId: _requiredString(json, 'public_id'),
    name: _stringValue(json, 'name'),
    email: _stringValue(json, 'email'),
  );
}

class TaskAssignee {
  const TaskAssignee({required this.user});

  final TaskUser user;

  factory TaskAssignee.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    if (rawUser is! Map) throw const FormatException('Invalid assignee user');
    return TaskAssignee(user: TaskUser.fromJson(_stringMap(rawUser)));
  }
}

class TaskUserPage {
  const TaskUserPage({
    required this.users,
    required this.page,
    required this.totalPages,
  });

  final List<TaskUser> users;
  final int page;
  final int totalPages;

  factory TaskUserPage.fromJson(Map<String, dynamic> envelope) {
    final data = envelope['data'];
    final meta = envelope['meta'];
    if (data is! List || meta is! Map) {
      throw const FormatException('Invalid user page envelope');
    }
    final users = <TaskUser>[];
    for (final value in data) {
      if (value is! Map) {
        throw const FormatException('Invalid user collection item');
      }
      users.add(TaskUser.fromJson(_stringMap(value)));
    }
    final mappedMeta = _stringMap(meta);
    final page = _requiredInt(mappedMeta, 'page');
    final totalPages = _requiredInt(mappedMeta, 'total_pages');
    return TaskUserPage(
      users: List.unmodifiable(users),
      page: page,
      totalPages: totalPages < 1 ? 1 : totalPages,
    );
  }
}

Map<String, dynamic> _stringMap(Map value) {
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw const FormatException('Invalid object key');
    result[entry.key as String] = entry.value;
  }
  return result;
}

String _stringValue(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('Invalid $key');
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _stringValue(json, key);
  if (value.isEmpty) throw FormatException('Invalid $key');
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value != null && value is! String) throw FormatException('Invalid $key');
  return value as String?;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('Invalid $key');
  return value;
}

bool _isZeroDate(String? value) =>
    value == '0001-01-01T00:00:00Z' || value == '0001-01-01T00:00:00+00:00';
