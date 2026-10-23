// Spec 0004 DQA-5, CLN-1, CLN-5, NET-6: the hand written client. The shared
// runtime's own tests live with its templates in orvanohq/orvano (PKG-3).
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orvano/orvano.dart';
import 'package:test/test.dart';

const String _project = '0192f0c1-0000-7000-8000-000000000001';

Future<Orvano> _server(http.Client client, {String apiKey = 'orv_pk_test'}) =>
    Orvano.open(
      endpoint: Uri.parse('https://orvano.test'),
      projectId: _project,
      publishableKey: apiKey,
      httpClient: client,
    );

final class _ClosingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw UnimplementedError();

  @override
  void close() => closed = true;
}

void main() {
  group('Orvano', () {
    test('calls health.get with its identity and key', () async {
      late http.BaseRequest seen;
      final orvano = await _server(
        MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'apiVersions': [apiVersion],
            }),
            200,
          );
        }),
      );
      final health = await orvano.health.get();
      expect(
        health,
        const HealthResponse(status: 'ok', apiVersions: [apiVersion]),
      );
      expect(seen.url.toString(), 'https://orvano.test/v1/health');
      expect(seen.headers['Orvano-Client'], 'orvano/$packageVersion');
      expect(seen.headers['User-Agent'], 'orvano/$packageVersion');
      expect(seen.headers['Orvano-Api-Version'], apiVersion);
      expect(seen.headers['Orvano-Key'], 'orv_pk_test');
    });

    test('maps an error answer to OrvanoApiException', () async {
      final orvano = await _server(
        MockClient(
          (request) async => http.Response(
            jsonEncode({
              'type': 'about:blank',
              'title': 'Unauthorized',
              'status': 401,
              'detail': 'The key is not valid.',
              'code': 'unauthorized',
              'traceId': '0af7651916cd43dd8448eb211c80319c',
            }),
            401,
          ),
        ),
      );
      await expectLater(
        orvano.health.get(),
        throwsA(
          isA<OrvanoApiException>()
              .having((e) => e.code, 'code', OrvanoErrorCodes.unauthorized)
              .having((e) => e.kind, 'kind', OrvanoErrorKind.unauthenticated),
        ),
      );
    });

    test('refuses a missing project ID, key, or a bad endpoint', () async {
      final client = MockClient((request) async => http.Response('', 204));
      await expectLater(_server(client, apiKey: ''), throwsArgumentError);
      await expectLater(
        Orvano.open(
          endpoint: Uri.parse('https://orvano.test'),
          projectId: '',
          publishableKey: 'orv_pk_test',
          httpClient: client,
        ),
        throwsArgumentError,
      );
      await expectLater(
        Orvano.open(
          endpoint: Uri.parse('http://orvano.example.com'),
          projectId: _project,
          publishableKey: 'orv_pk_test',
          httpClient: client,
        ),
        throwsArgumentError,
      );
    });

    test('close() is safe twice, refuses later calls, and leaves a passed '
        'client open', () async {
      final client = _ClosingClient();
      final orvano = await _server(client);
      await orvano.close();
      await orvano.close();
      await expectLater(orvano.health.get(), throwsStateError);
      expect(client.closed, isFalse);
    });

    test('toString never shows the key', () async {
      final orvano = await _server(
        MockClient((request) async => http.Response('', 204)),
        apiKey: 'orv_pk_very_secret',
      );
      expect(orvano.toString(), isNot(contains('secret')));
      expect(orvano.toString(), contains(_project));
    });
  });
}
