// Guards against documentation drifting away from the package it documents.
//
// The failure this prevents is mundane and real: the install snippet in
// README.md, llms.txt and docs/index.html all still pinned `^2.3.1` while the
// package was at 2.7.0, and the schema.org metadata on the published site
// still declared version 2.5.0. None of it broke a build. All of it is a
// claim the package makes about itself, published to users.
import 'dart:io';

import 'package:test/test.dart';

/// `name: value` on the first line matching [pattern].
String? yamlValue(File f, Pattern pattern) {
  for (final line in f.readAsLinesSync()) {
    if (line.startsWith(pattern)) return line.split(':').last.trim();
  }
  return null;
}

/// A `major.minor.patch` triple.
final _semver = RegExp(r'\b(\d+)\.(\d+)\.(\d+)\b');

/// Compares two dotted triples. Returns negative if [a] < [b].
int compareVersions(String a, String b) {
  final pa = _semver.firstMatch(a)!;
  final pb = _semver.firstMatch(b)!;
  for (var i = 1; i <= 3; i++) {
    final d = int.parse(pa.group(i)!) - int.parse(pb.group(i)!);
    if (d != 0) return d;
  }
  return 0;
}

void main() {
  final pubspec = File('pubspec.yaml');
  final version = yamlValue(pubspec, 'version')!;

  group('the package version itself is well-formed', () {
    test('pubspec.yaml declares a semver', () {
      expect(version, matches(_semver),
          reason: 'pubspec version must be semver, got "$version"');
    });
  });

  /// Files that publish an install instruction or a version claim.
  final claims = <String>[
    'README.md',
    'docs/llms.txt',
    'docs/llms-full.txt',
    'docs/index.html',
  ];

  group('install instructions name the current major.minor', () {
    for (final path in claims) {
      final f = File(path);
      if (!f.existsSync()) continue;
      final text = f.readAsStringSync();

      // `nepal_admin_api: ^X.Y.Z` (install snippet) and
      // `` `nepal_admin_api` vX.Y.Z `` (prose version claim). Both are
      // statements the docs make about which version they describe.
      final pins = RegExp(r'nepal_admin_api[`:\s]*\^?v?(\d+\.\d+\.\d+)')
          .allMatches(text)
          .map((m) => m.group(1)!)
          .toList();

      if (pins.isEmpty) continue;
      test('$path names the current version', () {
        for (final pin in pins) {
          expect(
            compareVersions(pin, version) >= 0,
            isTrue,
            reason: '$path names $pin but pubspec is $version. '
                'A stale version claim sends people to an old API.',
          );
        }
      });
    }
  });

  group('published metadata declares the current version', () {
    // schema.org Dataset.version on the Pages site. This is a machine-readable
    // claim about the dataset and is served to anyone who scrapes the page.
    final f = File('docs/index.html');
    if (f.existsSync()) {
      test('docs/index.html schema.org version is current', () {
        final m = RegExp(r'"version":\s*"(\d+\.\d+\.\d+)"').firstMatch(
          f.readAsStringSync(),
        );
        expect(m, isNotNull, reason: 'schema.org version block went missing');
        expect(
          compareVersions(m!.group(1)!, version) >= 0,
          isTrue,
          reason: 'site declares ${m.group(1)} but pubspec is $version',
        );
      });
    }
  });

  group('CHANGELOG has an entry for the current version', () {
    test('2.x current version is documented', () {
      final changelog = File('CHANGELOG.md').readAsStringSync();
      expect(
        RegExp('^## ${RegExp.escape(version)}\\b', multiLine: true)
            .hasMatch(changelog),
        isTrue,
        reason: 'CHANGELOG.md has no "## $version" heading. '
            'Shipping a version without a changelog entry makes the release '
            'untraceable.',
      );
    });
  });

  group('data as-of date agrees across artifacts', () {
    test('meta.json matches the dataset', () {
      final dataset = File('data/nepal_local_levels.json').readAsStringSync();
      final meta = RegExp('"dataAsOf"\\s*:\\s*"([0-9-]+)"')
          .firstMatch(dataset)!
          .group(1)!;
      final bindings = File('bindings/meta.json').readAsStringSync();
      final m = RegExp('"dataAsOf"\\s*:\\s*"([0-9-]+)"').firstMatch(bindings);
      expect(m, isNotNull, reason: 'bindings/meta.json lost dataAsOf');
      expect(
        m!.group(1),
        meta,
        reason: 'bindings declare a different as-of date than the dataset',
      );
    });
  });
}
