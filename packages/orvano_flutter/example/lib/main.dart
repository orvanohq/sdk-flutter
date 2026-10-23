// Spec 0004 PUB-2: a small Flutter app that opens an Orvano client and shows
// whether the server answers. Point it at your server with
//   flutter run --dart-define=ORVANO_ENDPOINT=http://localhost:8080 \
//     --dart-define=ORVANO_PROJECT_ID=... --dart-define=ORVANO_PUBLISHABLE_KEY=orv_pk_...
// (on the Android emulator, the host is 10.0.2.2 and needs
// OrvanoClientOptions(allowInsecureEndpoint: true)).
import 'package:flutter/material.dart';
import 'package:orvano_flutter/orvano_flutter.dart';

Future<void> main() async {
  final orvano = await OrvanoFlutter.open(
    endpoint: Uri.parse(
      const String.fromEnvironment(
        'ORVANO_ENDPOINT',
        defaultValue: 'http://localhost:8080',
      ),
    ),
    projectId: const String.fromEnvironment(
      'ORVANO_PROJECT_ID',
      defaultValue: 'example',
    ),
    publishableKey: const String.fromEnvironment(
      'ORVANO_PUBLISHABLE_KEY',
      defaultValue: 'orv_pk_example',
    ),
  );
  runApp(HealthApp(orvano: orvano));
}

class HealthApp extends StatefulWidget {
  const HealthApp({required this.orvano, super.key});

  final Orvano orvano;

  @override
  State<HealthApp> createState() => _HealthAppState();
}

class _HealthAppState extends State<HealthApp> {
  late final Future<HealthResponse> _health = widget.orvano.health.get();

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: FutureBuilder<HealthResponse>(
          future: _health,
          builder: (context, snapshot) => Text(switch (snapshot) {
            AsyncSnapshot(:final HealthResponse data) =>
              'Orvano is ${data.status}',
            AsyncSnapshot(error: OrvanoException(:final message)) => message,
            _ => 'Checking the server…',
          }),
        ),
      ),
    ),
  );
}
