// Spec 0014 AC-17, AC-18, CNF-5, spec 0004 DQA-3: every client scenario on the
// Dart VM. The servers come from api/conformance/compose.yaml at the pinned
// orvano commit (see README.md). Run with `dart test --tags conformance`.
@Tags(['conformance'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'runner.dart';

void main() {
  final environment = Platform.environment;
  final servers = Servers(
    stubUrl: Uri.parse(
      environment['ORVANO_CONFORMANCE_STUB_URL'] ?? 'http://localhost:18081',
    ),
    liveUrl: Uri.parse(
      environment['ORVANO_CONFORMANCE_URL'] ?? 'http://localhost:18080',
    ),
  );
  // CNF-8 is off only when you run a few scenarios with --name; CI never sets it.
  final partial = environment['ORVANO_CONFORMANCE_PARTIAL'] == '1';
  final scenarios = [
    for (final scenario
        in (_readJson('test/conformance/scenarios.g.json')!
                as Map<String, Object?>)['scenarios']!
            as List<Object?>) // Not null: the generator writes it.
      scenario! as Map<String, Object?>, // Not null: a scenario object.
  ];
  final skips = [
    for (final skip
        in _readJson('test/conformance/skip.json')! as List<Object?>)
      skip! as Map<String, Object?>, // Not null: a skip object.
  ];
  final ran = <String>{};

  group('0014 AC-17, AC-18: orvano conformance on the Dart VM', () {
    for (final scenario in scenarios) {
      final id = scenario['id']! as String; // Not null: required.
      final skipped = skips.any((skip) => skip['id'] == id);
      test('$id: ${scenario['title']}', skip: skipped, () async {
        ran.add(id);
        expect(await runScenario(scenario, servers), isEmpty);
      });
    }

    tearDownAll(() {
      if (partial) return;
      final problems = notRun(scenarios, ran, skips);
      if (problems.isNotEmpty) fail('0014 CNF-8: ${problems.join(' ')}');
    });
  });
}

Object? _readJson(String path) => jsonDecode(File(path).readAsStringSync());
