// Spec 0014 RGN-1 to RGN-3: regenerates this repo's generated code from the
// orvano commit in orvano-contract.json.
//   dart run tool/regenerate.dart                fetch the pinned commit into
//                                                .orvano/, check the contract
//                                                hash, run the generator
//   dart run tool/regenerate.dart --pin <sha>    move the pin to that commit
//                                                first (writes the pin file)
//   dart run tool/regenerate.dart --fetch-only   fetch and check, no generator
// CI runs it and then `git diff --exit-code` (the drift check). It needs git,
// Node 24, and pnpm (through corepack) on PATH.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const String _target = 'dart-client';

/// The package root, relative to the repo root.
const String _out = 'packages/orvano';

/// What the target owns (GNR-9), formatted after it runs.
const List<String> _owned = [
  'lib/src/generated',
  'lib/src/core',
  'test/conformance/dispatch.g.dart',
];

final RegExp _commitPattern = RegExp(r'^[0-9a-f]{40}$');

Future<void> main(List<String> args) async {
  final root = Directory.fromUri(Platform.script.resolve('..')).path;
  final pinFile = File('${root}orvano-contract.json');
  final checkout = '$root.orvano';

  final pinIndex = args.indexOf('--pin');
  if (pinIndex >= 0) {
    final commit = pinIndex + 1 < args.length ? args[pinIndex + 1] : '';
    if (!_commitPattern.hasMatch(commit)) {
      _fail('--pin needs a 40 character lowercase commit SHA.', 2);
    }
    _fetch(checkout, commit);
    final facts = _contractFacts(checkout);
    pinFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'commit': commit, ...facts})}\n',
    );
  }

  final pin = jsonDecode(pinFile.readAsStringSync()) as Map<String, Object?>;
  final commit = pin['commit'];
  if (commit is! String || !_commitPattern.hasMatch(commit)) {
    _fail('orvano-contract.json needs a 40 character lowercase commit.');
  }
  _fetch(checkout, commit);

  // RGN-3: the pin must describe the contract at its commit.
  final facts = _contractFacts(checkout);
  if (facts['contractSha256'] != pin['contractSha256'] ||
      facts['apiVersion'] != pin['apiVersion']) {
    _fail(
      'orvano-contract.json says ${pin['apiVersion']} (sha256 '
      '${pin['contractSha256']}), but api/openapi.json at $commit is '
      '${facts['apiVersion']} (sha256 ${facts['contractSha256']}). Run '
      'dart run tool/regenerate.dart --pin $commit.',
    );
  }
  if (args.contains('--fetch-only')) return;

  _run(
    'pnpm',
    ['install', '--frozen-lockfile', '--filter', '@orvano/sdk-generator...'],
    workingDirectory: checkout,
    quiet: true,
  );
  _run('node', [
    '$checkout/api/generator/src/cli.ts',
    '--target',
    _target,
    '--contract',
    '$checkout/api/openapi.json',
    '--out',
    '$root$_out',
    '--commit',
    commit,
  ]);
  _run(
    'dart',
    ['format', ..._owned.map((path) => '$_out/$path')],
    workingDirectory: root,
    quiet: true,
  );
  stdout.writeln(
    'regenerate: $_out matches orvano ${commit.substring(0, 7)} '
    '(contract ${pin['apiVersion']}).',
  );
}

/// Fetches one orvano commit into [checkout] with no token (the repo is
/// public), unless it is already there.
void _fetch(String checkout, String commit) {
  if (!Directory('$checkout/.git').existsSync()) {
    _run('git', ['init', '-q', checkout]);
  }
  final head = Process.runSync('git', ['-C', checkout, 'rev-parse', 'HEAD']);
  if ((head.stdout as String).trim() == commit) return;
  _run('git', [
    '-C',
    checkout,
    'fetch',
    '-q',
    '--depth',
    '1',
    'https://github.com/orvanohq/orvano',
    commit,
  ]);
  _run('git', ['-C', checkout, 'checkout', '-q', '--detach', 'FETCH_HEAD']);
}

/// The public contract's version and hash at the checked out commit (RGN-1).
Map<String, String> _contractFacts(String checkout) {
  final bytes = File('$checkout/api/openapi.json').readAsBytesSync();
  final document = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
  final info = document['info'] as Map<String, Object?>?;
  return {
    'apiVersion': '${info?['version']}',
    'contractSha256': sha256.convert(bytes).toString(),
  };
}

void _run(
  String executable,
  List<String> args, {
  String? workingDirectory,
  bool quiet = false,
}) {
  final result = Process.runSync(
    executable,
    args,
    workingDirectory: workingDirectory,
    environment: {'ORVANO_SKIP_HOOKS': '1'},
    runInShell: Platform.isWindows,
  );
  if (!quiet) stdout.write(result.stdout);
  if (result.exitCode != 0) {
    stderr
      ..write(result.stdout)
      ..write(result.stderr);
    _fail('`$executable ${args.join(' ')}` failed.', result.exitCode);
  }
}

Never _fail(String message, [int code = 1]) {
  stderr.writeln('regenerate: $message');
  exit(code);
}
