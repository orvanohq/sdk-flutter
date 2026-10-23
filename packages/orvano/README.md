# orvano

The [Orvano](https://github.com/orvanohq/orvano) client for Dart: Flutter apps, Dart web apps, and command line tools. Orvano is an open source, self hostable backend as a service. In a Flutter app, add [`orvano_flutter`](https://pub.dev/packages/orvano_flutter) instead; it includes everything here.

## Install

```bash
dart pub add orvano
```

It runs on Android, iOS, macOS, Windows, Linux, and the web (dart2js and dart2wasm), with no Flutter dependency.

## Quick start

```dart
import 'package:orvano/orvano.dart';

Future<void> main() async {
  final orvano = await Orvano.open(
    endpoint: Uri.parse('https://orvano.example.com'),
    projectId: '0192f0c1-0000-7000-8000-000000000001',
    publishableKey: 'orv_pk_...',
  );
  try {
    final health = await orvano.health.get();
    print(health.status);
  } on OrvanoException catch (error) {
    print('The call failed: $error');
  } finally {
    await orvano.close();
  }
}
```

Open one client per project and endpoint, and `close()` it when you're done. A publishable key (`orv_pk_...`) is safe in app code; never put a secret key in an app. Every failure is an `OrvanoException`, a sealed family you can `switch` over: `OrvanoApiException` (compare `code` with `OrvanoErrorCodes`), `OrvanoNetworkException`, `OrvanoTimeoutException`, `OrvanoCancelledException`, and `OrvanoProtocolException`.

## Timeouts and retries

Each attempt has 30 seconds (`OrvanoClientOptions(timeout: ...)`, or per call with `OrvanoRequestOptions`). GET requests are retried up to 2 times after a 408, 429, 502, 503, or 504, a timeout, or a dropped connection, with backoff or the server's `Retry-After` (up to 30 seconds; a longer one throws). Other methods are never retried. So the worst case for one GET is 3 attempts of 30 seconds plus the waits. `RetryOptions(maxRetries: 0)` turns retries off. Pass an `OrvanoCancelToken` in `OrvanoRequestOptions(cancelToken: ...)` to cancel calls, for example when a screen closes.

## Security notes

- The endpoint must be `https`, except for `localhost`, `127.0.0.1`, `::1`, and `*.localhost`. Set `OrvanoClientOptions(allowInsecureEndpoint: true)` for a server on your own network or the Android emulator's `10.0.2.2`. Android and iOS also block plain HTTP unless your app allows it.
- The SDK never follows a redirect, so your key never reaches another host.
- Pass your own `http.Client` (`httpClient:`), such as `cupertino_http` or `cronet_http`. Aborting a timed out or cancelled call needs a client that supports `package:http`'s abortable requests. The SDK never closes a client it did not create.

## Testing your code

Use the real client with `MockClient` from `package:http/testing.dart`:

```dart
final orvano = await Orvano.open(
  endpoint: Uri.parse('https://orvano.test'),
  projectId: 'test-project',
  publishableKey: 'orv_pk_test',
  httpClient: MockClient(
    (request) async => http.Response('{"status":"ok","apiVersions":["2026-10-22"]}', 200),
  ),
);
```

## License

Apache License 2.0 (see `LICENSE` and `NOTICE`). The name "Orvano" and its logo aren't covered by the license; see [TRADEMARKS.md](https://github.com/orvanohq/orvano/blob/main/TRADEMARKS.md).
