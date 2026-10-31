// Spec 0014 CNF-4, CNF-8: the hand written runner around the generated
// dispatcher. It opens the client, loads a stub scenario's script, runs each
// step, and matches results, errors, the last response, and what the SDK sent.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:orvano/orvano.dart';

import 'dispatch.g.dart';

/// Where the servers are (api/conformance/compose.yaml).
final class Servers {
  /// Creates the server addresses.
  const Servers({required this.stubUrl, required this.liveUrl});

  /// The stub server, port 18081 by default.
  final Uri stubUrl;

  /// The real Orvano server, port 18080 by default.
  final Uri liveUrl;
}

const String _projectId = '0192f0c1-0000-7000-8000-000000000001';
const String _defaultKey = 'conformance-key';
final Random _random = Random.secure();

/// The project and keys `orvano admin bootstrap-project` printed (spec 0017
/// SDK-4).
final class BootstrappedProject {
  /// Creates the project from the command's JSON.
  BootstrappedProject.fromJson(Map<String, Object?> json)
    : projectId = json['projectId']! as String, // Not null: BST-4 prints it.
      publishableKey = json['publishableKey']! as String, // Not null: BST-4.
      secretKey = json['secretKey']! as String; // Not null: BST-4.

  /// The project's ID.
  final String projectId;

  /// The publishable key, for a client SDK.
  final String publishableKey;

  /// The secret key, for a server SDK.
  final String secretKey;
}

/// CNF-7: makes a project on the running server, once per run, when the run
/// list holds a scenario that requires one. Its JSON is the only copy of the
/// keys.
Future<BootstrappedProject> bootstrapProject() async {
  final result = await Process.run(
    'docker',
    [
      'compose',
      '--file',
      '../../.orvano/api/conformance/compose.yaml',
      'exec',
      '-T',
      'orvano',
      '/app/orvano',
      'admin',
      'bootstrap-project',
      '--owner-email',
      'conformance@orvano.test',
      '--organization',
      'Conformance',
      '--project',
      'conformance-dart',
    ],
    // `exec` only finds the running container, but Compose reads the whole
    // file first, and the file needs a tag.
    environment: {
      'ORVANO_IMAGE_TAG': Platform.environment['ORVANO_IMAGE_TAG'] ?? 'unused',
    },
  );
  if (result.exitCode != 0) {
    throw StateError('orvano admin bootstrap-project: ${result.stderr}');
  }
  return BootstrappedProject.fromJson(
    jsonDecode(result.stdout as String)! as Map<String, Object?>,
  );
}

/// Runs one scenario and returns every mismatch; an empty list is a pass.
Future<List<String>> runScenario(
  Map<String, Object?> scenario,
  Servers servers, {
  BootstrappedProject? project,
}) async {
  final id = scenario['id']! as String; // Not null: the generator writes it.
  final stub = scenario['mode'] == 'stub';
  final token = 'run-${_randomToken()}';
  final real = requiresProject(scenario) ? project : null;
  if (requiresProject(scenario) && real == null) {
    return ['the scenario requires a project, and the run has none'];
  }
  final key = switch (scenario['client']) {
    {'key': final String key} => key,
    _ => real?.publishableKey ?? _defaultKey,
  };
  final projectId = real?.projectId ?? _projectId;
  final variables = {
    'apiVersion': apiVersion,
    'clientName': 'orvano/$packageVersion',
    'key': key,
    'projectId': projectId,
  };

  final plain = http.Client();
  final recording = RecordingClient(plain);
  final client = await Orvano.open(
    endpoint: stub ? servers.stubUrl : servers.liveUrl,
    projectId: projectId,
    publishableKey: key,
    httpClient: recording,
  );
  try {
    if (stub) {
      final loaded = await plain.post(
        servers.stubUrl.resolve('/__stub/runs/$token/scenarios/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'stub': substitute(scenario['stub'], variables)}),
      );
      if (loaded.statusCode != 204) {
        return ['the stub refused the scenario (${loaded.statusCode})'];
      }
    }

    final problems = <String>[];
    final steps = scenario['steps']! as List<Object?>; // Not null: required.
    for (final (index, raw) in steps.indexed) {
      final step = raw! as Map<String, Object?>; // Not null: a step object.
      final where = 'step ${index + 1}';
      final options = ConformanceOptions.fromJson(
        substitute(step['options'] ?? const <String, Object?>{}, variables)!
            as Map<String, Object?>, // Not null: substitute keeps a map.
        headers: stub ? {'Orvano-Stub-Run': token} : const {},
      );
      final outcome = await dispatch(
        client,
        step['call']! as String, // Not null: required.
        substitute(step['params'] ?? const <String, Object?>{}, variables)!
            as Map<String, Object?>, // Not null: substitute keeps a map.
        options,
      );
      final expected =
          substitute(step['expect'], variables)!
              as Map<String, Object?>; // Not null: required.
      if (expected.containsKey('result')) {
        problems.addAll(
          outcome.ok
              ? match(expected['result'], outcome.result, '$where result')
              : ['$where: failed with ${jsonEncode(outcome.error)}'],
        );
      } else {
        problems.addAll(
          outcome.ok
              ? ['$where: succeeded, expected an error']
              : match(expected['error'], outcome.error, '$where error'),
        );
      }
      if (expected['response'] != null) {
        problems.addAll(
          match(
            expected['response'],
            recording.last?.toJson(),
            '$where response',
          ),
        );
      }
    }

    if (stub) {
      final recorded = await plain.get(
        servers.stubUrl.resolve('/__stub/runs/$token/requests'),
      );
      final requests =
          (jsonDecode(recorded.body) as Map<String, Object?>)['requests'];
      problems.addAll(
        match(
          substitute(scenario['expectRequests'], variables),
          requests,
          'requests',
        ),
      );
    }
    return problems;
  } finally {
    await client.close();
    plain.close();
  }
}

/// Whether a scenario needs a real project (spec 0014 CNF-7).
bool requiresProject(Map<String, Object?> scenario) =>
    (scenario['requires'] as List<Object?>?)?.contains('project') ?? false;

/// CNF-8: every scenario either ran or is in skip.json with a reason and an
/// issue.
List<String> notRun(
  List<Map<String, Object?>> scenarios,
  Set<String> ran,
  List<Map<String, Object?>> skips,
) {
  final issue = RegExp(r'^https://github\.com/orvanohq/[^/]+/issues/\d+$');
  final problems = <String>[
    for (final skip in skips)
      if (skip case {
        'reason': final String reason,
        'issue': final String link,
      } when reason.isNotEmpty && issue.hasMatch(link))
        ...const <String>[]
      else
        'skip.json: ${skip['id']} needs a reason and an orvanohq issue link.',
  ];
  final skipped = {for (final skip in skips) skip['id']};
  for (final scenario in scenarios) {
    final id = scenario['id'];
    if (!ran.contains(id) && !skipped.contains(id)) {
      problems.add('$id did not run and is not in skip.json.');
    }
  }
  return problems;
}

String _randomToken() =>
    [for (var i = 0; i < 16; i++) _random.nextInt(36).toRadixString(36)].join();
