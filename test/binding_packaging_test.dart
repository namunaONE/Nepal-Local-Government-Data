// Guards the published artifacts' packaging.
//
// Both bindings ship a data file that the code opens relative to __file__ /
// __dirname. If the packaging configuration forgets it, everything works in
// the source tree and fails only after install — the worst possible moment to
// discover it, because CI tests the source tree and never the artifact.
//
// The Python binding is checked statically rather than by building a wheel:
// the release machine has no interpreter, so `python -m build` cannot run
// here. Asserting that every runtime-opened file is covered by the packaging
// declaration catches the actual failure mode without needing one.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('python binding packaging', () {
    final pkgDir = Directory('bindings/python/nepal_admin');
    final pyproject = File('bindings/python/pyproject.toml');
    test('package files exist', () {
      expect(pkgDir.existsSync(), isTrue);
      expect(pyproject.existsSync(), isTrue);
    });

    test('the data file the runtime opens is actually there', () {
      // __init__.py does: open(os.path.join(dirname(__file__), "data.json"))
      expect(
        File('${pkgDir.path}/data.json').existsSync(),
        isTrue,
        reason: 'the module opens data.json at import time; without it the '
            'package cannot even be imported',
      );
    });

    test('every runtime-opened file is covered by package-data', () {
      final text = pyproject.readAsStringSync();
      // Everything from [tool.setuptools.package-data] until the next [section].
      // Done with plain string handling: Dart's RegExp (Irregexp) supports
      // neither the lookahead used by the obvious regex nor the \z anchor.
      const marker = '[tool.setuptools.package-data]';
      expect(
        text.contains(marker),
        isTrue,
        reason: 'pyproject has no $marker section',
      );
      final rest = text.substring(text.indexOf(marker) + marker.length);
      final nextSection = rest.indexOf('\n[');
      final block = nextSection == -1 ? rest : rest.substring(0, nextSection);

      final declared = RegExp(r'"([^"]+)"')
          .allMatches(block)
          .map((m) => m.group(1)!)
          .toList();
      expect(declared, isNotEmpty,
          reason: 'package-data section declares no files');

      // Files the module actually opens at runtime.
      final opens = RegExp(r'"([A-Za-z0-9_.-]+\.(?:json|txt|csv))"')
          .allMatches(File('${pkgDir.path}/__init__.py').readAsStringSync())
          .map((m) => m.group(1)!)
          .toSet();

      expect(opens, isNotEmpty, reason: 'parsed no runtime file references');
      for (final f in opens) {
        expect(
          declared.contains(f),
          isTrue,
          reason: 'nepal_admin/$f is opened at runtime but is not listed in '
              '[tool.setuptools.package-data]. It would ship absent from the '
              'sdist/wheel and fail on first import after install.',
        );
      }
    });

    test('packages declares the importable package', () {
      final text = pyproject.readAsStringSync();
      expect(
        RegExp(r'packages\s*=\s*\[\s*"nepal_admin"\s*\]').hasMatch(text),
        isTrue,
        reason: 'pyproject must list nepal_admin under [tool.setuptools] '
            'packages or setuptools will not include it',
      );
    });

    test('the declared version matches bindings/meta.json', () {
      final meta = jsonDecode(File('bindings/meta.json').readAsStringSync());
      final m = RegExp(r'^version\s*=\s*"([^"]+)"', multiLine: true)
          .firstMatch(pyproject.readAsStringSync());
      expect(m, isNotNull);
      expect(m!.group(1), meta['version'],
          reason: 'pyproject version and bindings/meta.json disagree; the '
              'published package would claim a different version than the '
              'data it ships');
    });

    test('the runtime version constant matches meta.json', () {
      final meta = jsonDecode(File('bindings/meta.json').readAsStringSync());
      final m = RegExp(r'^__version__\s*=\s*"([^"]+)"', multiLine: true)
          .firstMatch(File('${pkgDir.path}/__init__.py').readAsStringSync());
      expect(m, isNotNull, reason: '__version__ missing from __init__.py');
      expect(m!.group(1), meta['version']);
    });
  });

  group('javascript binding packaging', () {
    final pkg = File('bindings/javascript/package.json');

    test('the npm manifest exists and parses', () {
      expect(pkg.existsSync(), isTrue);
      expect(() => jsonDecode(pkg.readAsStringSync()), returnsNormally);
    });

    test('every runtime-opened file is present and listed', () {
      final js = File('bindings/javascript/index.js');
      final text = js.readAsStringSync();
      final opens = RegExp(r'''require\(['"]\./([^'"]+)['"]\)''')
          .allMatches(text)
          .map((m) => m.group(1)!)
          .toSet();
      expect(opens, isNotEmpty, reason: 'index.js opens no local files');

      final manifest =
          jsonDecode(pkg.readAsStringSync()) as Map<String, dynamic>;
      final files = manifest['files'] as List?;
      for (final f in opens) {
        expect(
          File('bindings/javascript/$f').existsSync(),
          isTrue,
          reason: 'index.js requires ./$f but it does not exist',
        );
        if (files != null) {
          expect(
            files.contains(f),
            isTrue,
            reason: './$f is required at runtime but is not in the npm '
                '"files" allowlist, so it would be missing from the tarball',
          );
        }
      }
    });

    test('the declared version matches bindings/meta.json', () {
      final meta = jsonDecode(File('bindings/meta.json').readAsStringSync());
      final manifest =
          jsonDecode(pkg.readAsStringSync()) as Map<String, dynamic>;
      expect(manifest['version'], meta['version']);
    });
  });
}
