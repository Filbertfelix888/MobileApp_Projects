import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_mobile_app/Modal/create_new_list.dart';
import 'package:my_mobile_app/Modal/project_board_layout.dart';
import 'package:my_mobile_app/Modal/project_list_card.dart';

Map<String, dynamic> _list(int index) {
  return {'public_id': 'list-$index', 'title': 'List $index'};
}

Widget _board(
  List<Map<String, dynamic>> lists, {
  Map<String, List<dynamic>> cardsByList = const {},
  void Function(Map<String, dynamic>, String, String)? onTaskMoved,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 1100,
          child: ProjectBoardLayout(
            boardPublicId: 'board-1',
            lists: lists,
            cardsByList: cardsByList,
            projectInitials: 'CS',
            onDeleteList: (_) {},
            onTaskMoved: onTaskMoved ?? (_, _, _) {},
            onReload: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('keeps three lists in the first row with the add button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_board([_list(1), _list(2), _list(3)]));

    final cards = find.byType(ProjectListCard);
    expect(cards, findsNWidgets(3));

    final firstTop = tester.getTopLeft(cards.at(0)).dy;
    expect(tester.getTopLeft(cards.at(1)).dy, firstTop);
    expect(tester.getTopLeft(cards.at(2)).dy, firstTop);
    expect(tester.getTopLeft(find.byType(CreateNewList)).dy, firstTop);
  });

  testWidgets('moves the fourth list down instead of to the side', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_board([_list(1), _list(2), _list(3), _list(4)]));

    final cards = find.byType(ProjectListCard);
    expect(cards, findsNWidgets(4));

    final firstTop = tester.getTopLeft(cards.at(0)).dy;
    expect(tester.getTopLeft(cards.at(1)).dy, firstTop);
    expect(tester.getTopLeft(cards.at(2)).dy, firstTop);
    expect(tester.getTopLeft(cards.at(3)).dy, greaterThan(firstTop));
    expect(
      tester.getTopLeft(find.byType(CreateNewList)).dy,
      tester.getTopLeft(cards.at(3)).dy,
    );
  });

  testWidgets('list card shows task count, tasks, and triggers delete', (
    tester,
  ) async {
    var deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ProjectListCard(
              list: const {'public_id': 'list-1', 'title': 'API'},
              tasks: const [
                {'public_id': 'card-1', 'internal_id': 1, 'title': 'Task satu'},
                {'public_id': 'card-2', 'internal_id': 2, 'title': 'Task dua'},
              ],
              projectInitials: 'CS',
              onDelete: () => deleted = true,
              onTaskCreated: () {},
              onTaskMoved: (_, _, _) {},
              width: 236,
            ),
          ),
        ),
      ),
    );

    expect(find.text('2'), findsOneWidget);
    expect(find.text('Task satu'), findsOneWidget);
    expect(find.text('CS-1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete));
    expect(deleted, isTrue);
  });

  testWidgets('drags a task from one list to another', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? movedTask;
    String? fromListId;
    String? toListId;

    await tester.pumpWidget(
      _board(
        [_list(1), _list(2)],
        cardsByList: const {
          'list-1': [
            {'public_id': 'card-1', 'internal_id': 1, 'title': 'Task satu'},
          ],
        },
        onTaskMoved: (task, from, to) {
          movedTask = task;
          fromListId = from;
          toListId = to;
        },
      ),
    );

    final taskFinder = find.text('Task satu');
    expect(taskFinder, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(taskFinder));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

    // Holding the card should make it visibly liftable/movable.
    expect(find.text('Tugas diangkat'), findsOneWidget);
    expect(find.text('Geser ke daftar tujuan'), findsOneWidget);

    await gesture.moveTo(tester.getCenter(find.text('List 2')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Tugas diangkat'), findsNothing);
    expect(find.text('Geser ke daftar tujuan'), findsNothing);
    expect(movedTask?['public_id'], 'card-1');
    expect(fromListId, 'list-1');
    expect(toListId, 'list-2');
  });
}
