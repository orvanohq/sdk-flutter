// Spec 0004 NET-6: the version the SDK sends in Orvano-Client
// (lib/src/version.dart) equals the pubspec's version.
import 'dart:io';

/// Each package root.
const List<String> _packages = ['packages/orvano', 'packages/orvano_flutter'];

void main() {
  final problems = <String>[];
  for (final root in _packages) {
    final pubspec = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(File('$root/pubspec.yaml').readAsStringSync())?[1];
    final constant = RegExp(
      r"packageVersion = '([^']+)'",
    ).firstMatch(File('$root/lib/src/version.dart').readAsStringSync())?[1];
    if (pubspec == null || pubspec != constant) {
      problems.add('$root: pubspec.yaml says $pubspec, version.dart $constant');
    }
  }
  if (problems.isNotEmpty) {
    stderr.writeln('check_version:\n  ${problems.join('\n  ')}');
    exit(1);
  }
  print('check_version: version.dart matches pubspec.yaml.');
}
