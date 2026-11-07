import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mobile_app/Task/kanban_board.dart';
import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/network.dart';
import 'package:my_mobile_app/session_manager.dart';

const _board = '11111111-1111-1111-1111-111111111111';
const _first = '22222222-2222-2222-2222-222222222222';
const _second = '33333333-3333-3333-3333-333333333333';
const _taskId = '55555555-5555-5555-5555-555555555555';
const _otherBoard = '66666666-6666-6666-6666-666666666666';

Map<String, dynamic> _column(
  String id,
  int internalId,
  String title,
  int position,
) => {
  'internal_id': internalId,
  'public_id': id,
  'board_public_id': _board,
  'title': title,
  'position': position,
  'created_at': '2026-11-01T00:00:00Z',
};

Map<String, dynamic> _card({
  String id = _taskId,
  required int listInternalId,
  String title = 'Task A',
}) => {
  'internal_id': 9,
  'public_id': id,
  'list_internal_id': listInternalId,
  'title': title,
  'description': 'Saved description',
  'position': 2,
  'created_at': '2026-11-01T00:00:00Z',
  'due_date': '2026-12-05T00:00:00Z',
};

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

void main() {
  late List<http.Request> requests;
  late List<Map<String, dynamic>> columns;
  late Map<String, List<Map<String, dynamic>>> cardsByColumn;
  late bool failFirstColumn;
  late bool failTaskUpdate;
  late bool missingColumnOrder;
  late bool wrongColumnBoard;
  late int failTaskDetailReads;
  late bool delayFirstColumnCards;
  late Completer<http.Response> delayedFirstColumnCards;
  late bool delayBoardLists;
  late Completer<http.Response> delayedBoardLists;
  late String? moveCardBeforeDetailRead;
  late List<Map<String, dynamic>> boardMembers;
  late bool dropAssigneeAdds;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"t"}',
    });
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
    requests = [];
    columns = [
      _column(_second, 2, 'Second column', 1),
      _column(_first, 1, 'First column', 2),
    ];
    failFirstColumn = false;
    missingColumnOrder = false;
    wrongColumnBoard = false;
    failTaskUpdate = false;
    delayFirstColumnCards = false;
    failTaskDetailReads = 0;
    delayedFirstColumnCards = Completer<http.Response>();
    delayBoardLists = false;
    delayedBoardLists = Completer<http.Response>();
    moveCardBeforeDetailRead = null;
    cardsByColumn = {_first: [], _second: []};
    boardMembers = [
      {
        'public_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'name': 'Alex',
        'email': 'alex@example.test',
        'password': 'secret-hash',
      },
      {
        'public_id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        'name': 'Alex',
        'email': 'alex.two@example.test',
        'password': 'secret-hash',
      },
    ];
    dropAssigneeAdds = false;
    Network.client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (request.method == 'GET' && path.endsWith('/lists')) {
        if (path == '/api/v1/boards/$_otherBoard/lists') {
          return _json({
            'data': {'Lists': []},
          });
        }
        if (delayBoardLists) {
          delayBoardLists = false;
          return delayedBoardLists.future;
        }
        if (wrongColumnBoard) {
          final mismatched = [
            {...columns.first, 'board_public_id': _otherBoard},
            ...columns.skip(1),
          ];
          return _json({
            'data': {'Lists': mismatched},
          });
        }
        if (missingColumnOrder) {
          return _json({
            'message': 'List tidak ditemukan',
            'error': 'list position not found',
          }, 404);
        }
        return _json({
          'data': {'Lists': columns},
        });
      }
      if (request.method == 'GET' && path.endsWith('/members')) {
        return _json({'data': boardMembers});
      }
      if (request.method == 'DELETE' && path.endsWith('/assignees')) {
        final id = path.split('/')[4];
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final removed = List<String>.from(payload['user_id'] as List);
        final card = cardsByColumn.values
            .expand((cards) => cards)
            .firstWhere((item) => item['public_id'] == id);
        card['assignees'] = (card['assignees'] as List)
            .where(
              (entry) => !removed.contains((entry as Map)['user']['public_id']),
            )
            .toList();
        return _json({'status': 'Success'});
      }
      if (request.method == 'POST' && path.endsWith('/assignees')) {
        final id = path.split('/')[4];
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        if (!dropAssigneeAdds) {
          final card = cardsByColumn.values
              .expand((cards) => cards)
              .firstWhere((item) => item['public_id'] == id);
          final existing = List<Map<String, dynamic>>.from(
            card['assignees'] as List? ?? const [],
          );
          for (final userId in List<String>.from(payload['user_id'] as List)) {
            final member = boardMembers.firstWhere(
              (item) => item['public_id'] == userId,
            );
            existing.add({
              'user': {
                'public_id': userId,
                'name': member['name'],
                'email': member['email'],
              },
            });
          }
          card['assignees'] = existing;
        }
        return _json({'status': 'Success'});
      }
      if (request.method == 'POST' && path == '/api/v1/cards') {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final destinationId = payload['list_id'] as String;
        final destination = columns.singleWhere(
          (column) => column['public_id'] == destinationId,
        );
        final created = <String, dynamic>{
          'internal_id': 10,
          'public_id': '77777777-7777-7777-7777-777777777777',
          'list_internal_id': destination['internal_id'],
          'title': payload['title'],
          'description': payload['description'],
          'position': payload['position'],
          'created_at': '2026-11-01T00:00:00Z',
          if (payload['due_date'] != null) 'due_date': payload['due_date'],
        };
        cardsByColumn.putIfAbsent(destinationId, () => []).add(created);
        return _json({'data': created});
      }
      if (request.method == 'GET' && path.endsWith('/cards')) {
        if (failFirstColumn && path.contains(_second)) {
          return _json({'message': 'Kolom gagal'}, 500);
        }
        final columnId = path.split('/')[4];
        if (columnId == _first && delayFirstColumnCards) {
          delayFirstColumnCards = false;
          return delayedFirstColumnCards.future;
        }
        return _json({'data': cardsByColumn[columnId] ?? []});
      }
      if (request.method == 'GET' && path.startsWith('/api/v1/cards/')) {
        if (failTaskDetailReads > 0) {
          failTaskDetailReads--;
          return _json({'message': 'Refresh failed'}, 500);
        }
        final id = path.split('/').last;
        if (moveCardBeforeDetailRead != null) {
          final destinationId = moveCardBeforeDetailRead!;
          moveCardBeforeDetailRead = null;
          final card = cardsByColumn.values
              .expand((cards) => cards)
              .firstWhere((item) => item['public_id'] == _taskId);
          final destination = columns.firstWhere(
            (column) => column['public_id'] == destinationId,
          );
          for (final cards in cardsByColumn.values) {
            cards.removeWhere((item) => item['public_id'] == _taskId);
          }
          card['list_internal_id'] = destination['internal_id'];
          cardsByColumn[destinationId]!.add(card);
        }
        final matches = cardsByColumn.values
            .expand((cards) => cards)
            .where((item) => item['public_id'] == id)
            .toList();
        if (matches.isEmpty) return _json({'message': 'Missing card'}, 404);
        return _json({'data': matches.first});
      }
      if (request.method == 'POST' && path == '/api/v1/lists') {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final created = _column(
          '44444444-4444-4444-4444-444444444444',
          4,
          payload['title'] as String,
          3,
        );
        columns = [...columns, created];
        missingColumnOrder = false;
        return _json({'data': created});
      }
      if (request.method == 'PUT' && path.startsWith('/api/v1/lists/')) {
        final id = path.split('/').last;
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final index = columns.indexWhere((column) => column['public_id'] == id);
        columns[index] = {...columns[index], ...payload};
        return _json({'data': columns[index]});
      }
      if (request.method == 'DELETE' && path.startsWith('/api/v1/lists/')) {
        final id = path.split('/').last;
        columns.removeWhere((column) => column['public_id'] == id);
        return _json({'data': null});
      }
      if (request.method == 'PUT' && path.startsWith('/api/v1/cards/')) {
        if (failTaskUpdate) {
          return _json({'message': 'Move failed'}, 500);
        }
        final id = path.split('/').last;
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        MapEntry<String, List<Map<String, dynamic>>>? source;
        for (final entry in cardsByColumn.entries) {
          if (entry.value.any((item) => item['public_id'] == id)) {
            source = entry;
            break;
          }
        }
        if (source == null) return _json({'message': 'Missing card'}, 404);
        final destinationId = payload['list_id'] as String;
        final destination = columns.firstWhere(
          (column) => column['public_id'] == destinationId,
        );
        final updated = {
          ...source.value.firstWhere((item) => item['public_id'] == id),
          ...payload,
          'list_internal_id': destination['internal_id'],
        };
        source.value.removeWhere((item) => item['public_id'] == id);
        cardsByColumn[destinationId]!.add(updated);
        return _json({'data': updated});
      }
      if (request.method == 'DELETE' && path.startsWith('/api/v1/cards/')) {
        final id = path.split('/').last;
        for (final cards in cardsByColumn.values) {
          cards.removeWhere((item) => item['public_id'] == id);
        }
        return _json({'data': id});
      }
      return _json({
        'message': 'Unexpected request ${request.method} $path',
      }, 404);
    });
  });

  tearDown(() => Network.client.close());

  Future<void> pumpBoard(
    WidgetTester tester, {
    bool settle = true,
    String boardId = _board,
    Size surfaceSize = const Size(900, 2400),
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: KanbanBoard(
            boardId: boardId,
            boardTitle: 'Board',
            expectedGeneration: EnvironmentConfig.generation,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
    }
  }

  Future<void> pumpFrames(WidgetTester tester, [int count = 12]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  testWidgets('renders server order and isolates failed column load', (
    tester,
  ) async {
    failFirstColumn = true;
    await pumpBoard(tester);
    expect(find.text('Second column'), findsOneWidget);
    expect(find.text('First column'), findsOneWidget);
    expect(find.text('Kolom gagal'), findsOneWidget);
    expect(find.text('Belum ada tugas'), findsOneWidget);
    expect(
      requests.where((request) => request.url.path.endsWith('/cards')).length,
      2,
    );
    expect(
      tester.getTopLeft(find.text('Second column')).dx,
      lessThan(tester.getTopLeft(find.text('First column')).dx),
    );
  });

  testWidgets('missing-order 404 offers real Add Column recovery', (
    tester,
  ) async {
    missingColumnOrder = true;
    await pumpBoard(tester);
    expect(find.text('Urutan kolom belum tersedia'), findsOneWidget);
    expect(find.text('List tidak ditemukan'), findsOneWidget);
    await tester.tap(find.text('Tambah kolom').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ready');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(
      requests.any(
        (request) =>
            request.method == 'POST' && request.url.path == '/api/v1/lists',
      ),
      isTrue,
    );
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Belum ada tugas'), findsWidgets);
  });

  testWidgets('generic column 404 is not presented as an empty board', (
    tester,
  ) async {
    Network.client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/lists')) {
        return _json({
          'message': 'Board tidak ditemukan',
          'error': 'board missing',
        }, 404);
      }
      if (request.url.path.endsWith('/members')) return _json({'data': []});
      return _json({'data': []});
    });
    await pumpBoard(tester);
    expect(find.text('Board tidak ditemukan'), findsOneWidget);
    expect(find.text('Belum ada kolom'), findsNothing);
    final addButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Tambah kolom'),
    );

    expect(addButton.onPressed, isNull);
  });
  testWidgets('column rename and confirmed delete persist after reload', (
    tester,
  ) async {
    await pumpBoard(tester);
    await tester.tap(find.byTooltip('Aksi kolom First column'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ganti nama kolom'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Renamed');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Renamed'), findsOneWidget);
    final rename = requests.singleWhere((request) => request.method == 'PUT');
    expect(jsonDecode(rename.body), {'title': 'Renamed'});

    await tester.tap(find.byTooltip('Aksi kolom Renamed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus kolom').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('juga menghapus semua tugas'), findsOneWidget);
    await tester.tap(find.text('Hapus kolom').last);
    await tester.pumpAndSettle();
    expect(
      requests.any(
        (request) =>
            request.method == 'DELETE' &&
            request.url.path == '/api/v1/lists/$_first',
      ),
      isTrue,
    );
    expect(find.text('Renamed'), findsNothing);
  });

  testWidgets(
    'task creation cancel sends no request; success refreshes board',
    (tester) async {
      await pumpBoard(tester);
      await tester.tap(find.text('Tambah tugas').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(
        requests.where(
          (request) =>
              request.method == 'POST' && request.url.path == '/api/v1/cards',
        ),
        isEmpty,
      );

      await tester.tap(find.text('Tambah tugas').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Created from board',
      );
      await tester.tap(find.text('Buat tugas'));
      await tester.pumpAndSettle();

      expect(find.text('Created from board'), findsOneWidget);
      expect(
        requests.where(
          (request) =>
              request.method == 'POST' && request.url.path == '/api/v1/cards',
        ),
        hasLength(1),
      );
      expect(
        requests.where(
          (request) =>
              request.method == 'GET' &&
              request.url.path == '/api/v1/lists/$_second/cards',
        ),
        hasLength(2),
      );
    },
  );
  testWidgets('task move writes full saved fields and appends after refresh', (
    tester,
  ) async {
    cardsByColumn[_second] = [_card(listInternalId: 2)];
    await pumpBoard(tester);
    expect(find.text('Task A'), findsOneWidget);
    await tester.tap(find.text('Task A'));
    await tester.pumpAndSettle();
    expect(find.text('Pindahkan tugas'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First column').last);
    await tester.pumpAndSettle();

    expect(find.text('Task A'), findsOneWidget);
    final move = requests.singleWhere(
      (request) =>
          request.method == 'PUT' &&
          request.url.path == '/api/v1/cards/$_taskId',
    );
    expect(jsonDecode(move.body), {
      'list_id': _first,
      'title': 'Task A',
      'description': 'Saved description',
      'due_date': '2026-12-05T00:00:00Z',
      'position': 2,
    });
    expect(
      requests.any((request) => request.url.path.contains('/positions')),
      isFalse,
    );
    expect(cardsByColumn[_second], isEmpty);
    expect(cardsByColumn[_first]!.single['public_id'], _taskId);
  });
  testWidgets(
    'text draft exposes Save and blocks Move until saved or discarded',
    (tester) async {
      cardsByColumn[_second] = [_card(listInternalId: 2)];
      await pumpBoard(tester);
      await tester.tap(find.text('Task A'));
      await tester.pumpAndSettle();
      final descriptionField = find.byType(TextFormField).last;
      await tester.enterText(descriptionField, 'Draft description');
      await tester.pump();
      expect(
        tester.widget<TextFormField>(descriptionField).controller!.text,
        'Draft description',
      );
      expect(find.text('Simpan perubahan'), findsOneWidget);
      final moveField = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(moveField.onChanged, isNull);
      expect(
        requests.any(
          (request) =>
              request.method == 'PUT' &&
              request.url.path == '/api/v1/cards/$_taskId',
        ),
        isFalse,
      );
      await tester.tap(find.byTooltip('Tutup detail tugas'));
      await tester.pumpAndSettle();
      expect(
        cardsByColumn[_second]!.single['description'],
        'Saved description',
      );
    },
  );
  testWidgets(
    'accepts Unicode title edits within the backend character limit',
    (tester) async {
      cardsByColumn[_second] = [_card(listInternalId: 2)];
      await pumpBoard(tester);
      await tester.tap(find.text('Task A'));
      await tester.pumpAndSettle();
      final title = List.filled(128, '😀').join();
      await tester.enterText(find.byType(TextFormField).first, title);
      await tester.pump();
      final titleField = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(titleField.controller!.text.runes.length, 128);
      expect(find.text('Simpan perubahan'), findsOneWidget);
      await tester.tap(find.text('Simpan perubahan'));
      await tester.pumpAndSettle();
      final update = requests.singleWhere(
        (request) =>
            request.method == 'PUT' && request.url.path.endsWith('/$_taskId'),
      );
      expect((jsonDecode(update.body) as Map<String, dynamic>)['title'], title);
    },
  );
  testWidgets(
    'edits preserve and clear deadline; delete requires confirmation',
    (tester) async {
      cardsByColumn[_second] = [_card(listInternalId: 2)];
      await pumpBoard(tester);
      await tester.tap(find.text('Task A'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).last,
        'Edited description',
      );
      await tester.pump();
      await tester.tap(find.text('Simpan perubahan'));
      await tester.pumpAndSettle();
      final firstUpdate = requests
          .where(
            (request) =>
                request.method == 'PUT' &&
                request.url.path == '/api/v1/cards/$_taskId',
          )
          .first;
      expect(
        (jsonDecode(firstUpdate.body) as Map<String, dynamic>)['due_date'],
        '2026-12-05T00:00:00Z',
      );

      await tester.ensureVisible(find.text('Hapus tenggat'));
      await tester.tap(find.text('Hapus tenggat'));
      await tester.pump();
      expect(find.text('Tidak ada tenggat'), findsOneWidget);
      await tester.tap(find.text('Simpan perubahan'));
      await tester.pumpAndSettle();
      final updates = requests
          .where(
            (request) =>
                request.method == 'PUT' &&
                request.url.path == '/api/v1/cards/$_taskId',
          )
          .toList();
      expect(updates, hasLength(2));
      expect(
        (jsonDecode(updates.last.body) as Map<String, dynamic>)['due_date'],
        isNull,
      );

      await tester.tap(find.text('Hapus tugas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(requests.any((request) => request.method == 'DELETE'), isFalse);

      await tester.tap(find.text('Hapus tugas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus').last);
      await tester.pumpAndSettle();
      expect(
        requests.any(
          (request) =>
              request.method == 'DELETE' &&
              request.url.path == '/api/v1/cards/$_taskId',
        ),
        isTrue,
      );
      expect(cardsByColumn[_second], isEmpty);
      expect(find.text('Task A'), findsNothing);
    },
  );
  testWidgets(
    'failed move keeps task in source and sends no optimistic update',
    (tester) async {
      cardsByColumn[_second] = [_card(listInternalId: 2)];
      failTaskUpdate = true;
      await pumpBoard(tester);
      await tester.tap(find.text('Task A'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('First column').last);
      await tester.pumpAndSettle();
      expect(find.text('Tugas tidak dapat dipindahkan'), findsOneWidget);
      expect(cardsByColumn[_second]!.single['public_id'], _taskId);
      expect(cardsByColumn[_first], isEmpty);
      await tester.tap(find.byTooltip('Tutup detail tugas'));
      await tester.pumpAndSettle();
      expect(find.text('Task A'), findsOneWidget);
    },
  );
  testWidgets('drag drop uses append-only cross-column move handler', (
    tester,
  ) async {
    cardsByColumn[_second] = [_card(listInternalId: 2)];
    await pumpBoard(tester);
    final start = tester.getCenter(find.text('Task A'));
    final destination = tester.getCenter(find.text('First column'));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(destination);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(cardsByColumn[_second], isEmpty);
    expect(cardsByColumn[_first]!.single['public_id'], _taskId);
    expect(
      requests.where(
        (request) =>
            request.method == 'PUT' &&
            request.url.path == '/api/v1/cards/$_taskId',
      ),
      hasLength(1),
    );
  });
  testWidgets('late pre-move task GET cannot overwrite refreshed destination', (
    tester,
  ) async {
    cardsByColumn[_second] = [_card(listInternalId: 2)];
    delayFirstColumnCards = true;
    await pumpBoard(tester, settle: false);
    await pumpFrames(tester);
    expect(find.text('Task A'), findsOneWidget);

    await tester.tap(find.text('Task A'));
    await pumpFrames(tester);
    expect(find.text('Pindahkan tugas'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await pumpFrames(tester);
    await tester.tap(find.text('First column').last);
    await pumpFrames(tester, 20);

    expect(find.text('Pindahkan tugas'), findsNothing);
    expect(cardsByColumn[_first]!.single['public_id'], _taskId);
    expect(
      requests.where(
        (request) =>
            request.method == 'GET' &&
            request.url.path == '/api/v1/lists/$_first/cards',
      ),
      hasLength(2),
    );

    delayedFirstColumnCards.complete(_json({'data': []}));
    await pumpFrames(tester);
    expect(find.text('Task A'), findsOneWidget);
  });
  testWidgets('saved edit retries only detail GET after refresh failure', (
    tester,
  ) async {
    cardsByColumn[_second] = [_card(listInternalId: 2)];
    await pumpBoard(tester);
    await tester.tap(find.text('Task A'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).last,
      'Committed description',
    );
    await tester.pump();
    failTaskDetailReads = 1;
    await tester.tap(find.text('Simpan perubahan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tersimpan, gagal memuat ulang'), findsWidgets);
    expect(
      requests.where(
        (request) =>
            request.method == 'PUT' &&
            request.url.path == '/api/v1/cards/$_taskId',
      ),
      hasLength(1),
    );

    await tester.tap(find.byTooltip('Muat ulang detail'));
    await tester.pumpAndSettle();
    expect(
      requests.where(
        (request) =>
            request.method == 'PUT' &&
            request.url.path == '/api/v1/cards/$_taskId',
      ),
      hasLength(1),
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).last)
          .controller!
          .text,
      'Committed description',
    );
  });
  testWidgets('board switch discards delayed previous-board response', (
    tester,
  ) async {
    final oldColumns = List<Map<String, dynamic>>.from(columns);
    delayBoardLists = true;
    await pumpBoard(tester, settle: false);
    await pumpFrames(tester);
    await pumpBoard(tester, boardId: _otherBoard);
    expect(find.text('Belum ada kolom'), findsOneWidget);
    expect(find.text('Second column'), findsNothing);

    delayedBoardLists.complete(
      _json({
        'data': {'Lists': oldColumns},
      }),
    );
    await pumpFrames(tester);
    expect(find.text('Belum ada kolom'), findsOneWidget);
    expect(find.text('Second column'), findsNothing);
  });
  testWidgets('external task move refreshes both columns after detail closes', (
    tester,
  ) async {
    cardsByColumn[_second] = [_card(listInternalId: 2)];
    moveCardBeforeDetailRead = _first;
    await pumpBoard(tester);
    await tester.tap(find.text('Task A'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Tugas berpindah kolom. Tutup detail'),
      findsOneWidget,
    );
    expect(find.text('Pindahkan tugas'), findsOneWidget);
    final moveField = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(moveField.onChanged, isNull);
    await tester.tap(find.byTooltip('Tutup detail tugas'));
    await tester.pumpAndSettle();
    expect(cardsByColumn[_second], isEmpty);
    expect(cardsByColumn[_first]!.single['public_id'], _taskId);
    expect(find.text('Task A'), findsOneWidget);
    expect(
      requests.any(
        (request) =>
            request.method == 'PUT' &&
            request.url.path == '/api/v1/cards/$_taskId',
      ),
      isFalse,
    );
  });
  testWidgets('rejects columns returned for a different board', (tester) async {
    wrongColumnBoard = true;
    await pumpBoard(tester);
    expect(
      find.textContaining('Kolom tidak cocok dengan proyek ini'),
      findsOneWidget,
    );
    expect(find.text('Second column'), findsNothing);
    expect(find.text('Belum ada kolom'), findsNothing);
  });
  testWidgets(
    'multi-select assignment sends one object and confirms hydration',
    (tester) async {
      cardsByColumn[_second] = [_card(listInternalId: 2)];
      await pumpBoard(tester);
      await tester.tap(find.text('Task A'));
      await tester.pumpAndSettle();
      expect(find.textContaining('secret-hash'), findsNothing);
      await tester.ensureVisible(find.text('alex@example.test'));
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.tap(find.byType(CheckboxListTile).last);
      await tester.pump();
      await tester.tap(find.text('Tugaskan (2)'));
      await tester.pumpAndSettle();
      final post = requests.singleWhere(
        (request) =>
            request.method == 'POST' && request.url.path.endsWith('/assignees'),
      );
      expect(jsonDecode(post.body), {
        'user_id': [
          'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
          'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        ],
      });
      expect(find.text('Assignee tidak diterapkan oleh server'), findsNothing);
      expect(find.text('alex@example.test'), findsOneWidget);
      expect(find.text('alex.two@example.test'), findsOneWidget);
    },
  );
  testWidgets('silent assignee no-op is surfaced from refetched detail', (
    tester,
  ) async {
    cardsByColumn[_second] = [_card(listInternalId: 2)];
    dropAssigneeAdds = true;
    await pumpBoard(tester);
    await tester.tap(find.text('Task A'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('alex@example.test'));
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    await tester.tap(find.text('Tugaskan (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Assignee tidak diterapkan oleh server'), findsOneWidget);
  });
  testWidgets('summary recalculates from hydrated details after tab entry', (
    tester,
  ) async {
    final dueToday = DateTime.now().toUtc();
    final due = DateTime.utc(dueToday.year, dueToday.month, dueToday.day);
    cardsByColumn[_second] = [
      {
        ..._card(listInternalId: 2),
        'due_date': due.toIso8601String(),
        'assignees': [
          {
            'user': {
              'public_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
              'name': 'Alex',
              'email': 'alex@example.test',
            },
          },
        ],
      },
    ];
    await pumpBoard(tester);
    await tester.tap(find.text('Ringkasan'));
    await tester.pumpAndSettle();
    expect(find.text('Total tugas: 1'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Task A'), findsOneWidget);
    expect(
      requests.where(
        (request) =>
            request.method == 'GET' &&
            request.url.path == '/api/v1/cards/$_taskId',
      ),
      hasLength(1),
    );
  });
  testWidgets('summary stays incomplete and retryable when a column fails', (
    tester,
  ) async {
    failFirstColumn = true;
    await pumpBoard(tester);
    await tester.tap(find.text('Ringkasan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('belum lengkap'), findsOneWidget);
    expect(find.text('Kolom gagal'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });
  testWidgets('narrow 360px large-text header does not overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: KanbanBoard(
            boardId: _board,
            boardTitle: 'Board',
            expectedGeneration: EnvironmentConfig.generation,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Anggota'), findsOneWidget);
    expect(find.text('Tambah kolom'), findsOneWidget);
  });
  testWidgets('task detail adapts between phone and wide layouts', (
    tester,
  ) async {
    cardsByColumn[_second] = [_card(listInternalId: 2)];
    await pumpBoard(tester, surfaceSize: const Size(360, 800));
    await tester.tap(find.text('Task A').first);
    await tester.pumpAndSettle();
    final phoneRect = tester.getRect(find.byType(Dialog));
    expect(phoneRect.width, 360);
    expect(phoneRect.height, 800);

    await tester.tap(find.byTooltip('Tutup detail tugas'));
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Task A').first);
    await tester.pumpAndSettle();
    final wideSurface = find.byWidgetPredicate(
      (widget) =>
          widget is ConstrainedBox && widget.constraints.maxWidth == 640,
    );
    final wideRect = tester.getRect(wideSurface);
    expect(wideRect.width, lessThanOrEqualTo(640));
    expect(wideRect.height, lessThanOrEqualTo(768 * .9));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty server titles remain visible and editable', (
    tester,
  ) async {
    columns = [_column(_first, 1, '', 1)];
    cardsByColumn = {
      _first: [_card(listInternalId: 1, title: '')],
    };
    await pumpBoard(tester);
    expect(find.text('Tanpa judul'), findsNWidgets(2));
    expect(find.text('Saved description'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('member dialog scrolls on short screen with large text', (
    tester,
  ) async {
    await pumpBoard(tester, surfaceSize: const Size(360, 480), textScale: 2);
    await tester.tap(find.text('Anggota'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Anggota papan'), findsOneWidget);
    expect(find.text('Cari anggota'), findsOneWidget);
  });
  testWidgets('assignee outside board members stays removable', (tester) async {
    const outsider = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
    cardsByColumn[_second] = [
      {
        ..._card(listInternalId: 2),
        'assignees': [
          {
            'user': {
              'public_id': outsider,
              'name': 'Former Member',
              'email': 'former@example.test',
            },
          },
        ],
      },
    ];
    await pumpBoard(tester);
    await tester.tap(find.text('Task A'));
    await tester.pumpAndSettle();
    expect(find.text('Former Member'), findsOneWidget);
    await tester.ensureVisible(
      find.byTooltip('Hapus Former Member sebagai penanggung jawab'),
    );
    await tester.tap(
      find.byTooltip('Hapus Former Member sebagai penanggung jawab'),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Hapus').last);
    await tester.pumpAndSettle();
    final delete = requests.singleWhere(
      (request) =>
          request.method == 'DELETE' && request.url.path.endsWith('/assignees'),
    );
    expect(jsonDecode(delete.body), {
      'user_id': [outsider],
    });
    expect(find.text('Former Member'), findsNothing);
  });
  testWidgets(
    'summary is incomplete after a detail failure, then retry completes',
    (tester) async {
      cardsByColumn[_second] = [_card(listInternalId: 2)];
      await pumpBoard(tester);
      failTaskDetailReads = 1;
      await tester.tap(find.text('Ringkasan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('belum lengkap'), findsOneWidget);
      expect(find.text('Refresh failed'), findsOneWidget);
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('belum lengkap'), findsNothing);
      expect(find.text('Total tugas: 1'), findsOneWidget);
    },
  );
  testWidgets('summary recalculates after deleting a task from its list', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    cardsByColumn[_second] = [
      {
        ..._card(listInternalId: 2),
        'due_date': DateTime.utc(
          now.year,
          now.month,
          now.day,
        ).toIso8601String(),
      },
    ];
    await pumpBoard(tester);
    await tester.tap(find.text('Ringkasan'));
    await tester.pumpAndSettle();
    expect(find.text('Total tugas: 1'), findsOneWidget);
    await tester.tap(find.text('Task A'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hapus tugas'));
    await tester.tap(find.text('Hapus tugas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus').last);
    await tester.pumpAndSettle();
    expect(find.text('Total tugas: 0'), findsOneWidget);
    expect(find.text('Task A'), findsNothing);
  });
}
