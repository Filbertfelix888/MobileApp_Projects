import 'package:flutter/material.dart';

import 'Modal/project_detail_page.dart';

class AppRoutes {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final match = RegExp(r'^/projects/([^/]+)$')
        .firstMatch(settings.name ?? '');
    if (match != null) {
      final boardPublicId = Uri.decodeComponent(match.group(1)!);

      return MaterialPageRoute(
        settings: settings,
        builder: (context) => ProjectDetailPage(boardPublicId: boardPublicId),
      );
    }

    return null;
  }
}
