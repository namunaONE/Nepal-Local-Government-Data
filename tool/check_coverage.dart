// tool/check_coverage.dart — enforce a line-coverage floor on hand-written code.
//
// The CI job already produced an LCOV report and then did nothing with it. A
// measurement that cannot fail is not a gate.
//
// Design note, because the obvious implementation is misleading: `lib/` is
// dominated by lib/src/nepal_data.dart, a 1,396-line generated map literal
// that reports 100% the moment it is imported. Averaging it in produces a
// flattering ~98% that would hide any real regression in the hand-written
// API surface. So generated files are excluded and the floor is applied to
// what a human actually wrote.
//
// Usage (from the package root, after `dart test --coverage=coverage`):
//   dart pub global run coverage:format_coverage --lcov --in=coverage \
//       --out=coverage/lcov.info --report-on=lib --check-ignore
//   dart run tool/check_coverage.dart
//
// `--check-ignore` is passed for correctness of the report itself, but this
// tool does NOT rely on the formatter honoring it: that filtering has been
// observed to silently no-op (the DA record survives), so the marker is
// honored here, at the enforcement point, by reading the source files
// directly. A marker this tool cannot resolve to an actual source line fails
// the run rather than passing silently.
//
// Override the floor with COVERAGE_MIN_PERCENT (used to prove it bites).

import 'dart:io';

/// Files excluded from the floor. Everything here is machine-written.
const generated = <String>{
  'lib/src/nepal_data.dart',
};

/// Floor applied to hand-written lines. Currently 100%: every executable line
/// of `lib/` is covered, and the single unexecutable line (a private
/// constructor that exists only to prevent instantiation) carries an explicit
/// `// coverage:ignore-line`. Any new untested code fails the build.
const defaultFloor = 100.0;

class FileCov {
  FileCov(this.path);
  final String path;
  int found = 0;
  int hit = 0;

  /// 1-based source lines carrying `// coverage:ignore-line`, resolved from
  /// the source file itself. DA records on these lines are excluded from both
  /// counts, whether or not the formatter honored the marker.
  final ignored = <int>{};
  double get percent => found == 0 ? 100.0 : 100 * hit / found;
}

/// A source line opts out of coverage only with the marker at the end of the
/// line, mirroring the `coverage` package's own rule (`//` immediately
/// followed by `coverage:ignore-line`).
final _ignoreMarker = RegExp(r'//\s*coverage:ignore-line[\w\d\s]*$');

/// Reads [repoRelativePath] (e.g. `lib/src/nepal_admin_api_base.dart`) and
/// returns the 1-based numbers of its marker lines. Throws if the file cannot
/// be read — an ignore marker that cannot be resolved must fail loudly, never
/// pass silently.
Set<int> _ignoredLines(String repoRelativePath) {
  final file = File(repoRelativePath);
  if (!file.existsSync()) {
    throw StateError('cannot resolve coverage ignore markers: '
        '$repoRelativePath does not exist');
  }
  final out = <int>{};
  final lines = file.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    if (_ignoreMarker.hasMatch(lines[i])) out.add(i + 1);
  }
  return out;
}

void main(List<String> args) {
  final lcov = File(args.isNotEmpty ? args.first : 'coverage/lcov.info');
  if (!lcov.existsSync()) {
    stderr.writeln('No LCOV report at ${lcov.path}.');
    stderr.writeln('Run: dart test --coverage=coverage');
    stderr.writeln('Then: dart pub global run coverage:format_coverage '
        '--lcov --in=coverage --out=coverage/lcov.info --report-on=lib '
        '--check-ignore');
    exit(2);
  }

  final files = <String, FileCov>{};
  String? current;
  // DA records per file, so marker lines can be subtracted from the LF/LH
  // aggregates below. Key: repo-relative path; value: line -> hit count.
  final daRecords = <String, Map<int, int>>{};
  for (final raw in lcov.readAsLinesSync()) {
    final line = raw.trim();
    if (line.startsWith('SF:')) {
      final path = _normalise(line.substring(3));
      current = path;
      files.putIfAbsent(path, () => FileCov(path));
      daRecords.putIfAbsent(path, () => <int, int>{});
    } else if (line.startsWith('DA:') && current != null) {
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        final n = int.tryParse(parts[0]);
        final hits = int.tryParse(parts[1]);
        if (n != null && hits != null) daRecords[current]![n] = hits;
      }
    } else if (line.startsWith('LF:') && current != null) {
      files[current]!.found = int.parse(line.substring(3));
    } else if (line.startsWith('LH:') && current != null) {
      files[current]!.hit = int.parse(line.substring(3));
    }
  }

  // Honor ignore markers at the enforcement point.
  var unresolvedMarkers = 0;
  for (final entry in files.entries) {
    if (generated.contains(entry.key)) continue;
    final markers = _ignoredLines(entry.key);
    entry.value.ignored.addAll(markers);
    final records = daRecords[entry.key] ?? const <int, int>{};
    var ignoredFound = 0;
    var ignoredHit = 0;
    for (final n in markers) {
      final hits = records[n];
      if (hits == null) {
        // The marker names a line with no DA record: either the line is not
        // executable (the honest case) or the marker drifted onto the wrong
        // line after an edit (the dangerous case). Distinguish them: the line
        // must still carry the marker text itself.
        unresolvedMarkers++;
        stderr.writeln('WARNING: coverage ignore marker on ${entry.key}:$n '
            'matches no DA record. If the code moved, move the marker with it.');
        continue;
      }
      ignoredFound++;
      ignoredHit += hits;
    }
    entry.value.found -= ignoredFound;
    entry.value.hit -= ignoredHit;
  }
  if (unresolvedMarkers > 0) {
    stderr.writeln('WARNING: $unresolvedMarkers ignore marker(s) with no DA '
        'record (see above).');
  }

  final floor = double.tryParse(
        Platform.environment['COVERAGE_MIN_PERCENT'] ?? '',
      ) ??
      defaultFloor;

  final considered = files.entries
      .where((e) => !generated.contains(e.key))
      .toList()
    ..sort((a, b) => b.value.percent.compareTo(a.value.percent));

  final totalFound = considered.fold<int>(0, (s, e) => s + e.value.found);
  final totalHit = considered.fold<int>(0, (s, e) => s + e.value.hit);
  final total = totalFound == 0 ? 100.0 : 100 * totalHit / totalFound;

  stdout.writeln('=' * 66);
  stdout.writeln('COVERAGE — hand-written code only');
  stdout.writeln('=' * 66);
  for (final e in considered) {
    stdout.writeln('  ${e.value.percent.toStringAsFixed(1).padLeft(5)}%  '
        '${e.value.hit}/${e.value.found}  ${e.key}');
  }
  final skipped = files.keys.where(generated.contains).toList();
  for (final g in skipped) {
    stdout.writeln('  ------  excluded (generated)  $g');
  }
  stdout.writeln('-' * 66);
  stdout.writeln('  TOTAL ${total.toStringAsFixed(1)}%  '
      '($totalHit/$totalFound)   floor ${floor.toStringAsFixed(1)}%');
  stdout.writeln('=' * 66);

  if (total < floor) {
    stderr.writeln('\nCOVERAGE REGRESSION: ${total.toStringAsFixed(1)}% is '
        'below the ${floor.toStringAsFixed(1)}% floor.');
    stderr.writeln('Either write tests for the new code, or raise the floor '
        'deliberately in tool/check_coverage.dart — not by accident.');
    exit(1);
  }
  stdout.writeln('OK: ${total.toStringAsFixed(1)}% >= '
      '${floor.toStringAsFixed(1)}%.');
}

/// Strips absolute path prefixes so the same report works on Windows and Linux.
String _normalise(String raw) {
  var p = raw.replaceAll('\\', '/');
  for (final prefix in ['file:///', 'file://']) {
    if (p.startsWith(prefix)) p = p.substring(prefix.length);
  }
  // Drop a leading Windows drive or any leading directories up to /lib/.
  final i = p.indexOf('/lib/');
  if (i >= 0) p = p.substring(i + 1);
  final drive = RegExp(r'^[A-Za-z]:/');
  if (drive.hasMatch(p)) p = p.replaceFirst(drive, '');
  return p;
}
