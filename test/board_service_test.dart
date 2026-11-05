import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mobile_app/environment_config.dart';
import 'package:my_mobile_app/network.dart';
import 'package:my_mobile_app/session_manager.dart';

const _base = 'http://43.173.10.180:3030';
const _id = '11111111-1111-1111-1111-111111111111';

void main() {
  late List<http.Request> requests;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'BACKEND_ENVIRONMENT': 'qa',
      'SESSION_ENVIRONMENT': 'qa',
      'SESSION_KEY': '{"access_token":"t"}',
    });
    EnvironmentConfig.resetForTesting();
    SessionManager.resetForTesting();
    requests = [];
    Network.client = MockClient((request) async {
      requests.add(request);
      return http.Response('{"data":[]}', 200);
    });
  });

  tearDown(() => Network.client.close());

  test('getMyBoards uses default query', () async {
    await BoardService.getMyBoards();
    expect(requests.single.method, 'GET');
    expect(requests.single.url.toString(), '$_base/api/v1/boards/my?filter&limit=10&page=1');
    expect(requests.single.headers['authorization'], 'Bearer t');
  });

  test('getMyBoards encodes search and page', () async {
    await BoardService.getMyBoards(search: 'a&b', page: 2);
    expect(requests.single.url.toString(), '$_base/api/v1/boards/my?filter=a%26b&limit=10&page=2');
  });

  test('deleteBoard targets /api/v1/boards/:id', () async {
    await BoardService.deleteBoard(_id);
    expect(requests.single.method, 'DELETE');
    expect(requests.single.url.toString(), '$_base/api/v1/boards/$_id');
    expect(requests.single.headers['authorization'], 'Bearer t');
  });

  test('createBoard posts payload to /api/v1/boards', () async {
    final payload = {'title': 'T', 'description': 'D', 'due_date': '2026-11-05T00:00:00.000Z'};
    await BoardService.createBoard(payload);
    expect(requests.single.method, 'POST');
    expect(requests.single.url.toString(), '$_base/api/v1/boards');
    expect(jsonDecode(requests.single.body), payload);
    expect(requests.single.headers['content-type'], contains('application/json'));
    expect(requests.single.headers['authorization'], 'Bearer t');
  });

  test('getBoard encodes the id as one path segment', () async {
    await BoardService.getBoard('a/b?x');
    expect(requests.single.method, 'GET');
    expect(requests.single.url.toString(), '$_base/api/v1/boards/a%2Fb%3Fx');
  });

  group('response handling', () {
    void respond(int status, String body) {
      Network.client = MockClient((_) async => http.Response(body, status));
    }

    final calls = <String, Future<dynamic> Function()>{
      'get': () => Network.get('/x'),
      'post': () => Network.post('/x', {}),
      'delete': () => Network.delete('/x'),
    };

    for (final entry in calls.entries) {
      test('${entry.key}: non-JSON error body reports HTTP status', () async {
        respond(404, '<html>Not Found</html>');
        await expectLater(
          entry.value(),
          throwsA(predicate((e) => e.toString().contains('HTTP 404'))),
        );
      });

      test('${entry.key}: backend JSON message is preserved', () async {
        respond(400, '{"message":"Failed to get boards"}');
        await expectLater(
          entry.value(),
          throwsA(predicate((e) => e.toString() == 'Exception: Failed to get boards')),
        );
      });

      test('${entry.key}: JSON error without message falls back with status', () async {
        respond(500, '[1]');
        await expectLater(
          entry.value(),
          throwsA(predicate((e) => e.toString().contains('HTTP 500'))),
        );
      });

      test('${entry.key}: 2xx non-JSON body throws', () async {
        respond(200, 'ok');
        await expectLater(
          entry.value(),
          throwsA(predicate((e) => e.toString().contains('bukan JSON'))),
        );
      });
    }

    for (final entry in calls.entries) {
      test('${entry.key}: authenticated 401 throws UnauthorizedException', () async {
        respond(401, '{"message":"Error unauthorized"}');
        await expectLater(entry.value(), throwsA(isA<UnauthorizedException>()));
      });
    }

    test('login and register 401 stay ordinary errors', () async {
      respond(401, '{"message":"Invalid credentials"}');
      for (final call in <Future<dynamic> Function()>[() => AuthService.login({}), () => AuthService.signUp({})]) {
        await expectLater(
          call(),
          throwsA(predicate((e) => e is! UnauthorizedException && e.toString() == 'Exception: Invalid credentials')),
        );
      }
    });
  });
}
