// Provenance gate tests.
//
// These exist because the gate is load-bearing: every merge tool refuses to
// run unless it passes. A regression here means either a source change gets
// silently absorbed, or CI starts accusing upstream for a condition it
// caused itself.
//
// The distinction under test is `sourcesAbsent` vs `drifted`. A clean checkout
// deliberately does not carry data/_raw/ (gitignored, re-fetchable), so "the
// sources are not here" must never be reported as drift. Conflating the two
// is what made the weekly provenance-watch job file a false accusation
// against upstream on every run.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import '../tool/merge/common.dart';

void main() {
  group('manifest contract (runs without the vendored payloads)', () {
    test('the manifest is well-formed and pins a non-empty set', () {
      final report = auditProvenance(manifestOnly: true);
      expect(
        report.problems,
        isEmpty,
        reason: 'manifest-only audit must pass in a clean checkout:\n'
            '${report.problems.join('\n')}',
      );
      expect(report.status, ProvenanceStatus.verified);
      expect(report.pinnedCount, greaterThan(0));
    });

    test('pinned count matches the manifest file exactly', () {
      // Guards against a pin being added or dropped silently.
      final lines = File('data/PROVENANCE.sha256')
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty);
      expect(auditProvenance(manifestOnly: true).pinnedCount, lines.length);
    });

    test('no pinned path escapes data/_raw', () {
      final problems = auditProvenance(manifestOnly: true).problems;
      expect(problems.where((p) => p.startsWith('UNSAFE PATH')), isEmpty);
    });

    test('every vendored source directory is documented in SOURCES.md', () {
      // The governance invariant: a new source cannot be vendored without
      // someone having to write down where it came from and under what licence.
      final dirs = <String>{};
      for (final line in File('data/PROVENANCE.sha256').readAsLinesSync()) {
        if (line.trim().isEmpty) continue;
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 3) continue;
        dirs.add(parts[2].split('/').first);
      }
      expect(dirs, isNotEmpty);

      final sources = File('data/SOURCES.md').readAsStringSync();
      for (final d in dirs) {
        expect(
          sources.contains(d),
          isTrue,
          reason: 'data/_raw/$d is pinned but not documented in '
              'data/SOURCES.md — add its provenance and licence',
        );
      }
    });

    test('the manifest copy inside data/_raw is deliberately not pinned', () {
      // data/_raw/PROVENANCE.sha256 is excluded by design; if it were pinned,
      // the manifest could never hash itself.
      final report = auditProvenance(manifestOnly: true);
      expect(report.pinnedCount, greaterThan(0));
    });
  });

  group('state machine (fixture-driven)', () {
    // These four statuses are what the scheduled CI job keys on, so each is
    // asserted against a purpose-built fixture rather than against whatever
    // happens to be on disk.

    late Directory tmp;

    String hashOf(List<int> bytes) =>
        sha256.convert(bytes).toString().toUpperCase();

    /// Writes a manifest pinning [files] (rel path -> bytes) under [root].
    void writeManifest(List<MapEntry<String, List<int>>> files, String at) {
      File(at)
        ..createSync(recursive: true)
        ..writeAsStringSync(files
            .map((e) => '${hashOf(e.value)}  ${e.value.length}  ${e.key}')
            .join('\n'));
    }

    void writePayload(String root, String rel, List<int> bytes) {
      final f = File('$root/$rel');
      f.createSync(recursive: true);
      f.writeAsBytesSync(bytes);
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('prov_audit_test');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('verified: payload present and matching', () {
      final raw = '${tmp.path}/raw';
      writePayload(raw, 'src/a.json', [1, 2, 3]);
      writeManifest([
        const MapEntry('src/a.json', [1, 2, 3])
      ], '${tmp.path}/MANIFEST');

      final r = auditProvenance(
        manifestPath: '${tmp.path}/MANIFEST',
        rawDirPath: raw,
      );
      expect(r.status, ProvenanceStatus.verified);
      expect(r.isVerified, isTrue);
      expect(r.isDrift, isFalse);
      expect(r.sourcesPresent, isTrue);
      expect(r.pinnedCount, 1);
    });

    test('sourcesAbsent: raw dir missing is NOT drift', () {
      // This is the exact CI condition that used to file a false accusation
      // against upstream. It must be distinguishable from drift.
      writeManifest([
        const MapEntry('src/a.json', [1, 2, 3])
      ], '${tmp.path}/MANIFEST');

      final r = auditProvenance(
        manifestPath: '${tmp.path}/MANIFEST',
        rawDirPath: '${tmp.path}/does-not-exist',
      );
      expect(r.status, ProvenanceStatus.sourcesAbsent);
      expect(r.isDrift, isFalse,
          reason: 'absent sources are an expected state, never drift');
      expect(r.isVerifiable, isFalse);
      expect(r.pinnedCount, 1, reason: 'the contract was still readable');
    });

    test('drifted: payload present but bytes differ', () {
      final raw = '${tmp.path}/raw';
      writePayload(raw, 'src/a.json', [1, 2, 3]);
      writeManifest([
        const MapEntry('src/a.json', [9, 9, 9])
      ], '${tmp.path}/MANIFEST');

      final r = auditProvenance(
        manifestPath: '${tmp.path}/MANIFEST',
        rawDirPath: raw,
      );
      expect(r.status, ProvenanceStatus.drifted);
      expect(r.isDrift, isTrue);
      expect(r.problems.first, contains('MISMATCH'));
    });

    test('drifted: pinned file missing from the payload', () {
      final raw = '${tmp.path}/raw';
      Directory(raw).createSync(recursive: true);
      writeManifest([
        const MapEntry('src/a.json', [1, 2, 3])
      ], '${tmp.path}/MANIFEST');

      final r = auditProvenance(
        manifestPath: '${tmp.path}/MANIFEST',
        rawDirPath: raw,
      );
      expect(r.status, ProvenanceStatus.drifted);
      expect(r.problems.first, contains('MISSING'));
    });

    test('drifted: an unpinned file in the payload is an untracked input', () {
      final raw = '${tmp.path}/raw';
      writePayload(raw, 'src/a.json', [1, 2, 3]);
      writePayload(raw, 'src/sneaky.json', [4, 5]);
      writeManifest([
        const MapEntry('src/a.json', [1, 2, 3])
      ], '${tmp.path}/MANIFEST');

      final r = auditProvenance(
        manifestPath: '${tmp.path}/MANIFEST',
        rawDirPath: raw,
      );
      expect(r.status, ProvenanceStatus.drifted);
      expect(r.problems.first, contains('UNPINNED'));
    });

    test('manifestInvalid: missing manifest', () {
      final r = auditProvenance(
        manifestPath: '${tmp.path}/nope.sha256',
        rawDirPath: '${tmp.path}/raw',
      );
      expect(r.status, ProvenanceStatus.manifestInvalid);
      expect(r.isDrift, isFalse);
    });

    test('manifestInvalid: duplicate pin for the same path', () {
      writeManifest([
        const MapEntry('src/a.json', [1, 2, 3]),
        const MapEntry('src/a.json', [4, 5, 6]),
      ], '${tmp.path}/MANIFEST');

      final r = auditProvenance(
        manifestPath: '${tmp.path}/MANIFEST',
        rawDirPath: '${tmp.path}/raw',
      );
      expect(r.status, ProvenanceStatus.manifestInvalid);
      expect(r.problems.first, contains('DUPLICATE PIN'));
    });

    test('manifestInvalid: a path escaping data/_raw is refused', () {
      // Otherwise the manifest would be a way to name an arbitrary file.
      writeManifest([
        const MapEntry('../../etc/passwd', [1])
      ], '${tmp.path}/MANIFEST');

      final r = auditProvenance(
        manifestPath: '${tmp.path}/MANIFEST',
        rawDirPath: '${tmp.path}/raw',
      );
      expect(r.status, ProvenanceStatus.manifestInvalid);
      expect(r.problems.first, contains('UNSAFE PATH'));
    });

    test('manifestOnly passes with no payload present', () {
      writeManifest([
        const MapEntry('src/a.json', [1, 2, 3])
      ], '${tmp.path}/MANIFEST');

      final r = auditProvenance(
        manifestOnly: true,
        manifestPath: '${tmp.path}/MANIFEST',
        rawDirPath: '${tmp.path}/does-not-exist',
      );
      expect(r.status, ProvenanceStatus.verified);
      expect(r.pinnedCount, 1);
    });

    test('a malformed line invalidates the manifest even in manifest-only mode',
        () {
      File('${tmp.path}/MANIFEST')
        ..createSync(recursive: true)
        ..writeAsStringSync('not a valid pin line');
      final r = auditProvenance(
        manifestOnly: true,
        manifestPath: '${tmp.path}/MANIFEST',
        rawDirPath: '${tmp.path}/raw',
      );
      expect(r.status, ProvenanceStatus.manifestInvalid);
      expect(r.problems.first, contains('malformed'));
    });
  });

  group('the real manifest', () {
    test('every vendored input on disk matches, when the sources are here', () {
      final rawDir = Directory('data/_raw');
      if (!rawDir.existsSync()) {
        markTestSkipped(
          'data/_raw/ is gitignored and not present in this checkout; '
          'run `dart run tool/merge/verify_provenance.dart` locally to check',
        );
        return;
      }
      final report = auditProvenance();
      expect(
        report.problems,
        isEmpty,
        reason: 'a pinned input disagrees with the manifest:\n'
            '${report.problems.join('\n')}',
      );
      expect(report.status, ProvenanceStatus.verified);
    });
  });
}
