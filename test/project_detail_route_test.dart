import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_mobile_app/app_routes.dart';

void main() {
  test('builds a detail route for /projects/:id', () {
    final route = AppRoutes.onGenerateRoute(
      const RouteSettings(name: '/projects/abc-123'),
    );

    expect(route, isA<MaterialPageRoute<dynamic>>());
    expect(route?.settings.name, '/projects/abc-123');
  });

  test('leaves unrelated routes to the route table', () {
    final route = AppRoutes.onGenerateRoute(
      const RouteSettings(name: '/login'),
    );

    expect(route, isNull);
  });
}
