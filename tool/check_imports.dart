// Spec 0004 Enforcement: what lib/ may not use. PLT-1 and PLT-3 (dart:mirrors,
// dart:html and the old JS libraries, Flutter), STR-5 (DateTime.now), STR-6
// (compute, Isolate.run), DRT-8 (part files), NET-10 (response.body).
import 'dart:io';

/// Each package's lib/ folder, and whether it may import dart:io (PLT-3) and
/// Flutter.
const Map<String, ({bool io, bool flutter})> _packages = {
  'packages/orvano/lib': (io: false, flutter: false),
  'packages/orvano_flutter/lib': (io: false, flutter: true),
};

final List<(RegExp, String)> _banned = [
  (RegExp(r'''import\s+['"]dart:mirrors['"]'''), 'dart:mirrors (PLT-3)'),
  (
    RegExp(r'''import\s+['"]dart:(html|js|js_util)['"]'''),
    'dart:html and dart:js (PLT-1)',
  ),
  (RegExp(r'\bDateTime\.now\('), 'DateTime.now(); use clock (STR-5)'),
  (RegExp(r'\b(compute|Isolate\.run)\('), 'isolates (STR-6)'),
  (RegExp(r'^\s*part\s', multiLine: true), 'part files (DRT-8)'),
  (RegExp(r'\bresponse\.body\b'), 'response.body; decode bodyBytes (NET-10)'),
];

final RegExp _flutter = RegExp(r'''import\s+['"]package:flutter/''');
final RegExp _comment = RegExp(r'^\s*//.*$', multiLine: true);
final RegExp _dartIo = RegExp(r'''import\s+['"]dart:io['"]''');

void main() {
  final problems = <String>[];
  for (final MapEntry(key: folder, value: allowed) in _packages.entries) {
    final files = Directory(folder)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in files) {
      // Comments may name what is banned, to say why.
      final text = file.readAsStringSync().replaceAll(_comment, '');
      for (final (pattern, what) in _banned) {
        if (pattern.hasMatch(text)) problems.add('${file.path}: $what');
      }
      // The core's platform_io.dart is the one native file behind the
      // conditional import (PLT-1).
      if (!allowed.flutter && _flutter.hasMatch(text)) {
        problems.add('${file.path}: Flutter in a pure Dart package (PLT-1)');
      }
      if (!allowed.io &&
          _dartIo.hasMatch(text) &&
          !file.path.endsWith('platform_io.dart')) {
        problems.add('${file.path}: dart:io outside platform_io.dart (PLT-1)');
      }
    }
  }
  if (problems.isNotEmpty) {
    stderr.writeln('check_imports:\n  ${problems.join('\n  ')}');
    exit(1);
  }
  print('check_imports: lib/ uses nothing spec 0004 bans.');
}
