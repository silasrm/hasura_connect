import 'package:hasura_connect/src/core/interceptors/log_interceptor.dart';
import 'package:hasura_connect/src/di/injection.dart';
import 'package:hasura_connect/src/di/module.dart';
import 'package:hasura_connect/src/domain/entities/snapshot.dart';
import 'package:hasura_connect/src/domain/errors/errors.dart';
import 'package:hasura_connect/src/domain/models/query.dart';
import 'package:hasura_connect/src/external/websocket_connector.dart';
import 'package:hasura_connect/src/presenter/hasura_connect_base.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:websocket/websocket.dart';

import '../utils/client_response.dart';

class ClientMock extends Mock implements http.Client {}

class WrapperMock extends Mock implements WebSocketWrapper {}

class WebSocketMock extends Mock implements WebSocket {}

void main() {
  HasuraConnect connect;
  final client = ClientMock();
  final wrapper = WrapperMock();

  setUp(() {
    connect = HasuraConnect('https://fake-hasura.com',
        interceptors: [LogInterceptor()]);
    when(client.post(
      any,
      body: anyNamed('body'),
      headers: anyNamed('headers'),
    )).thenAnswer((_) async => http.Response(stringJsonReponse, 200));

    when(wrapper.connect(any)).thenAnswer((_) async => WebSocketMock());
    cleanModule();
    startModule(() => client, wrapper);
  });

  tearDownAll(() {
    connect.dispose();
  });

  group('Query | ', () {
    test('should execute query', () {
      expect(connect.query('query'), completes);
    });

    test('should execute with error', () {
      expect(connect.query('mutation'), throwsA(isA<HasuraError>()));
    });
  });

  group('Mutation | ', () {
    test('should execute', () {
      expect(connect.mutation('mutation'), completes);
    });

    test('should execute with error', () {
      expect(connect.mutation('query'), throwsA(isA<HasuraError>()));
    });
  });

  group('Subscription | ', () {
    test('should return Snapshot and Connect to Websocket', () async {
      final snapshot = await connect.subscription('subscription');
      expect(snapshot, isA<Snapshot>());
      final snapshot2 = await connect.subscription('subscription');
      expect(snapshot2 == snapshot, true);
      await snapshot.close();
      await snapshot2.close();
    });

    test('should execute with error', () {
      expect(connect.subscription('query'), throwsA(isA<HasuraError>()));
    });
  });
  group('rootStreamListener | ', () {
    test('should send snapshot to controller', () async {
      final snapshot = Snapshot(query: Query(document: 'null'));
      expect(snapshot, emits('test'));
      connect.snapmap['fdfhsf'] = snapshot;
      connect.rootStreamListener(
          {'id': 'fdfhsf', 'payload': 'test', 'type': 'data'});
      await snapshot.close();
    });
    test('should execute with HasuraRequestError', () async {
      final snapshot = Snapshot(query: Query(document: 'null'));
      expect(snapshot, emitsError(isA<HasuraRequestError>()));
      connect.snapmap['fdfhsf'] = snapshot;
      connect.rootStreamListener({
        'id': 'fdfhsf',
        'payload': {'error': 'test'},
        'type': 'error'
      });
      await snapshot.close();
    });

    test('should execute with HasuraRequestError', () async {
      final snapshot = Snapshot(query: Query(document: 'null'));
      expect(snapshot, emitsError(isA<HasuraRequestError>()));
      connect.snapmap['fdfhsf'] = snapshot;
      connect.rootStreamListener({
        'id': 'fdfhsf',
        'payload': {
          'errors': [
            {'error': 'test'}
          ]
        },
        'type': 'error'
      });
      await snapshot.close();
    });
  });

  group('normalizeStreamValue | ', () {
    test('should send controller', () async {
      final snapshot = Snapshot(query: Query(document: 'null'));
      connect.snapmap['fdfhsf'] = snapshot;
      final data = {'id': 'fdfhsf', 'payload': 'test', 'type': 'data'};
      expect(connect.controller.stream, emits(data));
      await connect.normalizeStreamValue(data);
      await snapshot.close();
    });
    test('should execute connection_ack', () async {
      final snapshot = Snapshot(query: Query(document: 'null'));
      connect.snapmap['fdfhsf'] = snapshot;
      final data = {
        'id': 'fdfhsf',
        'payload': 'test',
        'type': 'connection_ack'
      };
      await connect.normalizeStreamValue(data);
      await snapshot.close();
    });
    test('should execute connection_error', () async {
      final data = {
        'id': 'fdfhsf',
        'payload': 'test',
        'type': 'connection_error'
      };
      await connect.normalizeStreamValue(data);
    });
  });

  test('querySubscription', () async {
    expect(connect.querySubscription(Query(document: 'null')), isA<String>());
  });
  test('sendToWebSocketServer', () async {
    connect.sendToWebSocketServer('s');
  });
}
