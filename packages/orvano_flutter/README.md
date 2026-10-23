# orvano_flutter

The [Orvano](https://github.com/orvanohq/orvano) SDK for Flutter apps on Android, iOS, macOS, Windows, Linux, and the web. It includes everything in [`orvano`](https://pub.dev/packages/orvano), so you import only this package.

## Install

```bash
flutter pub add orvano_flutter
```

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:orvano_flutter/orvano_flutter.dart';

Future<void> main() async {
  final orvano = await OrvanoFlutter.open(
    endpoint: Uri.parse('https://orvano.example.com'),
    projectId: '0192f0c1-0000-7000-8000-000000000001',
    publishableKey: 'orv_pk_...',
  );
  runApp(MyApp(orvano: orvano));
}
```

`OrvanoFlutter.open` initializes Flutter's bindings itself and returns the same `Orvano` client the `orvano` package gives; its README covers errors, timeouts, retries, cancelling, and the security notes. The SDK works with any state management library: it gives you `Future`s and `Stream`s and depends on none of them.

The `example/` app opens a client and shows whether your server answers.

## License

Apache License 2.0 (see `LICENSE` and `NOTICE`). The name "Orvano" and its logo aren't covered by the license; see [TRADEMARKS.md](https://github.com/orvanohq/orvano/blob/main/TRADEMARKS.md).
