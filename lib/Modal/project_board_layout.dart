import 'package:flutter/material.dart';

import 'create_new_list.dart';
import 'project_list_card.dart';

class ProjectBoardLayout extends StatelessWidget {
  final String boardPublicId;
  final List<Map<String, dynamic>> lists;
  final Map<String, List<dynamic>> cardsByList;
  final String projectInitials;
  final ValueChanged<Map<String, dynamic>> onDeleteList;
  final TaskMovedCallback onTaskMoved;
  final VoidCallback onReload;

  const ProjectBoardLayout({
    super.key,
    required this.boardPublicId,
    required this.lists,
    required this.cardsByList,
    required this.projectInitials,
    required this.onDeleteList,
    required this.onTaskMoved,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 28.0;
        const cardWidth = 236.0;
        const actionWidth = 252.0;
        const actionGap = 8.0;

        final availableWidth = constraints.maxWidth;
        final int columns;
        if (availableWidth >= 3 * cardWidth + 2 * gap) {
          columns = 3;
        } else if (availableWidth >= 2 * cardWidth + gap) {
          columns = 2;
        } else {
          columns = 1;
        }

        final itemWidth = columns == 1 ? availableWidth : cardWidth;
        final actionFits =
            availableWidth >=
            columns * itemWidth + (columns - 1) * gap + actionGap + actionWidth;

        if (lists.isEmpty) {
          return Align(
            alignment: Alignment.topLeft,
            child: CreateNewList(
              boardPublicId: boardPublicId,
              onSuccess: onReload,
              width: columns == 1 ? availableWidth : cardWidth,
            ),
          );
        }

        final rows = <List<Map<String, dynamic>>>[];
        for (var start = 0; start < lists.length; start += columns) {
          final end = start + columns < lists.length
              ? start + columns
              : lists.length;
          rows.add(lists.sublist(start, end));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: rowIndex == rows.length - 1 ? 0 : 20,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (
                      var itemIndex = 0;
                      itemIndex < rows[rowIndex].length;
                      itemIndex++
                    ) ...[
                      ProjectListCard(
                        list: rows[rowIndex][itemIndex],
                        tasks:
                            cardsByList[rows[rowIndex][itemIndex]['public_id']
                                ?.toString()] ??
                            const <dynamic>[],
                        projectInitials: projectInitials,
                        width: itemWidth,
                        onDelete: () => onDeleteList(rows[rowIndex][itemIndex]),
                        onTaskMoved: onTaskMoved,
                        onTaskCreated: onReload,
                      ),
                      if (itemIndex < rows[rowIndex].length - 1)
                        const SizedBox(width: gap)
                      else if (rowIndex == rows.length - 1 && actionFits)
                        const SizedBox(width: actionGap),
                    ],
                    if (rowIndex == rows.length - 1 && actionFits)
                      CreateNewList(
                        boardPublicId: boardPublicId,
                        onSuccess: onReload,
                        width: actionWidth,
                      ),
                  ],
                ),
              ),
            if (!actionFits) ...[
              const SizedBox(height: 16),
              CreateNewList(
                boardPublicId: boardPublicId,
                onSuccess: onReload,
                width: columns == 1 ? availableWidth : actionWidth,
              ),
            ],
          ],
        );
      },
    );
  }
}
