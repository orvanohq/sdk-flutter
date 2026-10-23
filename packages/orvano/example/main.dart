// Spec 0004 PUB-2: the quick start, as a pure Dart program. Run it against
// your own server:
//   ORVANO_ENDPOINT=http://localhost:8080 ORVANO_PROJECT_ID=... \
//   ORVANO_PUBLISHABLE_KEY=orv_pk_... dart run example/main.dart
import 'dart:io';

import 'package:orvano/orvano.dart';

String requireEnv(String name) =>
    Platform.environment[name] ?? (throw StateError('$name is not set'));

Future<void> main() async {
  final orvano = await Orvano.open(
    endpoint: Uri.parse(requireEnv('ORVANO_ENDPOINT')),
    projectId: requireEnv('ORVANO_PROJECT_ID'),
    publishableKey: requireEnv('ORVANO_PUBLISHABLE_KEY'),
  );
  try {
    final health = await orvano.health.get();
    print('Orvano is ${health.status}; it serves ${health.apiVersions}.');
  } on OrvanoException catch (error) {
    print('Orvano did not answer: $error');
  } finally {
    await orvano.close();
  }
}
