import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/api/api_client.dart';
import 'package:beels_mobile/features/groups/data/groups_repository.dart';
import 'package:beels_mobile/features/groups/models/group.dart';

class _RecordedCall {
  _RecordedCall(this.method, this.path, {this.query, this.body});

  final String method;
  final String path;
  final Map<String, dynamic>? query;
  final Object? body;

  @override
  String toString() => '$method $path';
}

/// Fake transport implementing the ApiClient contract; captures every call
/// and returns canned envelope responses per path.
class _RecordingApiClient implements ApiClient {
  _RecordingApiClient();

  final List<_RecordedCall> calls = [];
  final Map<String, dynamic Function()> responses = {};

  dynamic _responseFor(String method, String path) {
    final key = '$method $path';
    final producer = responses[key];
    if (producer == null) {
      throw StateError('Unexpected request: $key');
    }
    return producer();
  }

  void _record(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) {
    calls.add(_RecordedCall(method, path, query: query, body: body));
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    _record('GET', path, query: query);
    return _responseFor('GET', path);
  }

  @override
  Future<dynamic> post(String path, {Object? body}) async {
    _record('POST', path, body: body);
    return _responseFor('POST', path);
  }

  @override
  Future<dynamic> patch(String path, {Object? body}) async {
    _record('PATCH', path, body: body);
    return _responseFor('PATCH', path);
  }

  @override
  Future<dynamic> put(String path, {Object? body}) async {
    _record('PUT', path, body: body);
    return _responseFor('PUT', path);
  }

  @override
  Future<dynamic> delete(String path, {Object? body}) async {
    _record('DELETE', path, body: body);
    return _responseFor('DELETE', path);
  }
}

Map<String, dynamic> _groupJson({required int id, required String name}) => {
      'id': id,
      'name': name,
      'invite_link_token': 'tok$id',
      'invite_link': 'https://frontend.test/groups/join/tok$id',
      'members_count': 0,
      'members': <dynamic>[],
      'created_at': '2026-01-15T08:00:00.000Z',
    };

void main() {
  late _RecordingApiClient api;
  late GroupsRepository repository;

  setUp(() {
    api = _RecordingApiClient();
    repository = GroupsRepository(api);
  });

  group('list', () {
    test('GETs /groups and unwraps the double-nested data.data envelope',
        () async {
      api.responses['GET /groups'] = () => {
            'statusCode': 200,
            'message': 'Groups fetched',
            'data': {
              'data': [
                _groupJson(id: 1, name: 'Family'),
                _groupJson(id: 2, name: 'Church'),
              ],
            },
          };

      final groups = await repository.list();

      expect(api.calls, hasLength(1));
      expect(api.calls.single.method, 'GET');
      expect(api.calls.single.path, '/groups');
      expect(api.calls.single.query, isNull);
      expect(groups, hasLength(2));
      expect(groups[0].id, 1);
      expect(groups[0].name, 'Family');
      expect(groups[1].name, 'Church');
    });

    test('also tolerates a single-nested data array', () async {
      api.responses['GET /groups'] = () => {
            'statusCode': 200,
            'message': 'Groups fetched',
            'data': [_groupJson(id: 7, name: 'Solo')],
          };

      final groups = await repository.list();

      expect(groups, hasLength(1));
      expect(groups.single.id, 7);
    });
  });

  group('get', () {
    test('GETs /groups/:id and parses the envelope data', () async {
      api.responses['GET /groups/12'] = () => {
            'statusCode': 200,
            'message': 'Group fetched',
            'data': _groupJson(id: 12, name: 'Market women'),
          };

      final group = await repository.get(12);

      expect(api.calls.single.method, 'GET');
      expect(api.calls.single.path, '/groups/12');
      expect(group.name, 'Market women');
    });
  });

  group('create', () {
    test('POSTs /groups with name, description and member payloads',
        () async {
      api.responses['POST /groups'] = () => {
            'statusCode': 200,
            'message': 'Group created',
            'data': _groupJson(id: 20, name: 'New group'),
          };

      final group = await repository.create(
        name: 'New group',
        description: 'Test group',
        members: [
          const GroupMember(
            firstName: 'Ada',
            lastName: 'Obi',
            email: 'ada@example.com',
            phoneNumber: '08012345678',
          ),
        ],
      );

      expect(api.calls.single.method, 'POST');
      expect(api.calls.single.path, '/groups');
      expect(api.calls.single.body, {
        'name': 'New group',
        'description': 'Test group',
        'members': [
          {
            'first_name': 'Ada',
            'last_name': 'Obi',
            'email': 'ada@example.com',
            'phone_number': '08012345678',
          },
        ],
      });
      expect(group.id, 20);
    });

    test('omits blank description and empty members list', () async {
      api.responses['POST /groups'] = () => {
            'statusCode': 200,
            'message': 'Group created',
            'data': _groupJson(id: 21, name: 'Minimal'),
          };

      await repository.create(name: 'Minimal');

      expect(api.calls.single.body, {'name': 'Minimal'});
    });
  });

  group('addMember', () {
    test('POSTs /groups/:id/members and parses the returned member',
        () async {
      api.responses['POST /groups/12/members'] = () => {
            'statusCode': 200,
            'message': 'Member added',
            'data': {
              'id': 33,
              'first_name': 'Ngozi',
              'last_name': 'Eze',
              'email': 'ngozi@example.com',
              'phone_number': '08099999999',
            },
          };

      final member = await repository.addMember(
        12,
        firstName: 'Ngozi',
        lastName: 'Eze',
        email: 'ngozi@example.com',
        phoneNumber: '08099999999',
      );

      expect(api.calls.single.method, 'POST');
      expect(api.calls.single.path, '/groups/12/members');
      expect(api.calls.single.body, {
        'first_name': 'Ngozi',
        'last_name': 'Eze',
        'email': 'ngozi@example.com',
        'phone_number': '08099999999',
      });
      expect(member.id, 33);
      expect(member.fullName, 'Ngozi Eze');
    });

    test('omits optional fields that were not provided', () async {
      api.responses['POST /groups/12/members'] = () => {
            'statusCode': 200,
            'message': 'Member added',
            'data': {'first_name': 'Bola'},
          };

      await repository.addMember(12, firstName: 'Bola');

      expect(api.calls.single.body, {'first_name': 'Bola'});
    });
  });

  group('removeMember', () {
    test('DELETEs /groups/:id/members/:memberId', () async {
      api.responses['DELETE /groups/12/members/33'] = () =>
          {'statusCode': 200, 'message': 'Member removed'};

      await repository.removeMember(12, 33);

      expect(api.calls.single.method, 'DELETE');
      expect(api.calls.single.path, '/groups/12/members/33');
    });
  });

  group('regenerateInvite', () {
    test('POSTs /groups/:id/invite-link and parses the token pair',
        () async {
      api.responses['POST /groups/12/invite-link'] = () => {
            'statusCode': 200,
            'message': 'Invite link generated',
            'data': {
              'invite_link_token': 'brandNewToken',
              'invite_link': 'https://frontend.test/groups/join/brandNewToken',
            },
          };

      final invite = await repository.regenerateInvite(12);

      expect(api.calls.single.method, 'POST');
      expect(api.calls.single.path, '/groups/12/invite-link');
      expect(invite.token, 'brandNewToken');
      expect(invite.url, 'https://frontend.test/groups/join/brandNewToken');
    });
  });

  group('delete', () {
    test('DELETEs /groups/:id', () async {
      api.responses['DELETE /groups/12'] = () =>
          {'statusCode': 200, 'message': 'Group deleted'};

      await repository.delete(12);

      expect(api.calls.single.method, 'DELETE');
      expect(api.calls.single.path, '/groups/12');
    });
  });
}