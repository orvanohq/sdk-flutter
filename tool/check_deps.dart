// Spec 0004 Enforcement: DRT-2 (exactly these runtime dependencies), DRT-3 (no
// dependency_overrides, caret ranges), PKG-5 (no native plugin folders), and
// the Replaces list (banned packages anywhere). Also spec 0009 DEP-1 and DEP-8:
// every resolved package's LICENSE is on the permissive list. GitHub's
// dependency graph has no usable license data for pub packages, so this check
// replaces dependency-review's license gate in the Dart repos.
import 'dart:convert';
import 'dart:io';

/// Each pubspec, and the runtime dependencies DRT-2 allows it.
const Map<String, Set<String>> _allowed = {
  'packages/orvano/pubspec.yaml': {
    'clock',
    'collection',
    'http',
    'logging',
    'meta',
    'web',
  },
  'packages/orvano_flutter/pubspec.yaml': {
    'orvano',
    'flutter',
    'flutter_secure_storage',
    'shared_preferences',
  },
};

/// PKG-4: orvano_flutter depends on orvano within one minor version.
final RegExp _sameMinor = RegExp(r'^">=(\d+)\.(\d+)\.\d+ <(\d+)\.(\d+)\.0"$');

const Set<String> _bannedPackages = {
  'dio',
  'chopper',
  'retrofit',
  'get_it',
  'rxdart',
  'provider',
  'riverpod',
  'flutter_riverpod',
  'bloc',
  'flutter_bloc',
  'get',
  'signals',
  'json_serializable',
  'json_annotation',
  'freezed',
  'freezed_annotation',
  'built_value',
  'build_runner',
  'mockito',
  'mocktail',
  'hive',
  'melos',
};

void main() {
  final problems = <String>[];
  for (final MapEntry(key: path, value: allowed) in _allowed.entries) {
    final sections = _sections(File(path).readAsLinesSync());
    final runtime = sections['dependencies'] ?? const {};
    for (final MapEntry(key: name, value: constraint) in runtime.entries) {
      if (!allowed.contains(name)) {
        problems.add('$path: $name is not on spec 0004 DRT-2\'s list');
      }
      if (name == 'orvano') {
        final match = _sameMinor.firstMatch(constraint);
        final sameMinor =
            match != null &&
            match[1] == match[3] &&
            int.parse(match[2] ?? '') + 1 == int.parse(match[4] ?? '');
        if (!sameMinor) {
          problems.add('$path: orvano needs ">=X.Y.Z <X.(Y+1).0" (PKG-4)');
        }
      } else if (!constraint.startsWith('^') && constraint != 'sdk: flutter') {
        problems.add('$path: $name needs a caret range (DRT-3)');
      }
    }
    for (final name in [
      ...runtime.keys,
      ...?sections['dev_dependencies']?.keys,
    ]) {
      if (_bannedPackages.contains(name)) {
        problems.add('$path: $name is on spec 0004\'s Replaces list');
      }
    }
    if (sections.containsKey('dependency_overrides')) {
      problems.add('$path: dependency_overrides (DRT-3)');
    }
    final root = File(path).parent.path;
    for (final folder in ['android', 'ios', 'macos', 'windows', 'linux']) {
      if (Directory('$root/$folder').existsSync()) {
        problems.add('$root/$folder: native plugin code (PKG-5)');
      }
    }
  }
  problems.addAll(_licenseProblems());
  if (problems.isNotEmpty) {
    stderr.writeln('check_deps:\n  ${problems.join('\n  ')}');
    exit(1);
  }
  print(
    'check_deps: dependencies follow spec 0004 DRT-2 and DRT-3, and every '
    'resolved package has a permissive license (spec 0009 DEP-1).',
  );
}

/// The license of every package `pub get` resolved, read from its LICENSE
/// file through .dart_tool/package_config.json (run `dart pub get` first).
List<String> _licenseProblems() {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) {
    return ['.dart_tool/package_config.json is missing; run dart pub get'];
  }
  final json = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
  final packages = (json['packages'] as List<Object?>?) ?? const [];
  // The Flutter SDK's own packages (flutter, flutter_test, sky_engine) come
  // with the SDK and its BSD 3 license, not a LICENSE file of their own.
  final sdkPackages = {
    for (final match in RegExp(
      r'^  ([a-z0-9_]+):\n(?:    .*\n)*?    source: sdk$',
      multiLine: true,
    ).allMatches(File('pubspec.lock').readAsStringSync()))
      match[1],
  };
  final problems = <String>[];
  for (final entry in packages.whereType<Map<String, Object?>>()) {
    final name = entry['name'];
    final rootUri = entry['rootUri'];
    if (name is! String || rootUri is! String) continue;
    if (sdkPackages.contains(name)) continue;
    // This repo's own packages carry Apache 2.0 (spec 0009 LIC-1).
    if (rootUri == '../' || !rootUri.contains(':')) continue;
    final root = config.uri.resolve(
      rootUri.endsWith('/') ? rootUri : '$rootUri/',
    );
    final license = _licenseOf(Directory.fromUri(root));
    if (license == null) {
      problems.add('$name: no LICENSE on spec 0009 DEP-1\'s permissive list');
    }
  }
  return problems;
}

/// The SPDX ID of a package's license, or null when it has none or it is not
/// one DEP-1 allows.
String? _licenseOf(Directory root) {
  for (final name in ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'COPYING']) {
    final file = File('${root.path}$name');
    if (!file.existsSync()) continue;
    final text = file.readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
    if (text.contains('Apache License') && text.contains('Version 2.0')) {
      return 'Apache-2.0';
    }
    if (text.contains('Redistribution and use in source and binary forms')) {
      return text.contains('Neither the name')
          ? 'BSD-3-Clause'
          : 'BSD-2-Clause';
    }
    if (text.contains('Permission is hereby granted, free of charge')) {
      return 'MIT';
    }
    return null;
  }
  return null;
}

/// The top level sections of a pubspec that list packages, as
/// `{section: {package: constraint}}`. Only the two space indented entries
/// count, which is how every Orvano pubspec is written.
Map<String, Map<String, String>> _sections(List<String> lines) {
  final result = <String, Map<String, String>>{};
  Map<String, String>? current;
  final section = RegExp(r'^([a-z_]+):\s*$');
  final entry = RegExp(r'^  ([a-z0-9_]+):\s*(.*)$');
  for (final line in lines) {
    if (section.firstMatch(line) case final match?) {
      final name = match[1] ?? '';
      current = name.contains('dependencies') || name == 'dependency_overrides'
          ? (result[name] = {})
          : null;
      continue;
    }
    if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
      current = null;
    }
    if (current != null) {
      if (entry.firstMatch(line) case final match?) {
        current[match[1] ?? ''] = (match[2] ?? '').trim();
      } else if (line.startsWith('    sdk:')) {
        final last = current.keys.lastOrNull;
        if (last != null) current[last] = 'sdk: ${line.split(':').last.trim()}';
      }
    }
  }
  return result;
}
