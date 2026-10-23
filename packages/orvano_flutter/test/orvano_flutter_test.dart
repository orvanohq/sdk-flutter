// Spec 0004 DQA-1, DQA-5, NET-6, PKG-4: the Flutter layer. A loopback server
// stands in for Orvano, since OrvanoFlutter.open takes no http.Client.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orvano_flutter/orvano_flutter.dart';

void main() {
  group('OrvanoFlutter', () {
    test('opens a client that sends orvano_flutter/<version>', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final seen = <String, String?>{};
      server.listen((request) async {
        seen['client'] = request.headers.value('orvano-client');
        seen['key'] = request.headers.value('orvano-key');
        seen['path'] = request.uri.path;
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'ok',
              'apiVersions': [apiVersion],
            }),
          );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final orvano = await OrvanoFlutter.open(
        endpoint: Uri.parse('http://127.0.0.1:${server.port}'),
        projectId: '0192f0c1-0000-7000-8000-000000000001',
        publishableKey: 'orv_pk_test',
      );
      addTearDown(orvano.close);
      final health = await orvano.health.get();

      expect(health.status, 'ok');
      expect(seen['client'], 'orvano_flutter/0.1.0');
      expect(seen['key'], 'orv_pk_test');
      expect(seen['path'], '/v1/health');
    });

    test('refuses an http endpoint that is not local', () {
      expect(
        () => OrvanoFlutter.open(
          endpoint: Uri.parse('http://orvano.example.com'),
          projectId: 'p1',
          publishableKey: 'orv_pk_test',
        ),
        throwsArgumentError,
      );
    });

    test('exports everything in orvano', () {
      // A compile time check as much as a runtime one (PKG-4).
      expect(OrvanoErrorCodes.notFound, 'not_found');
      expect(const OrvanoClientOptions().timeout, const Duration(seconds: 30));
    });
  });
}
