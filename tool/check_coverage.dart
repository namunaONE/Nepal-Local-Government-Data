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
//       --out=coverage/lcov.info --report-on=lib
//   dart run tool/check_coverage.dart
//
// Override the floor with COVERAGE_MIN_PERCENT (used to prove it bites).

import 'dart:io';

/// Files excluded from the floor. Everything here is machine-written.
const generated = <String>{
  'lib/src/nepal_data.dart',
};

/// Floor applied to hand-written lines. Set with room below the current
/// figure so ordinary work is not blocked, but tight enough that adding
/// untested code fails.
const defaultFloor = 85.0;

class FileCov {
  FileCov(this.path);
  final String path;
  int found = 0;
  int hit = 0;
  double get percent => found == 0 ? 100.0 : 100 * hit / found;
}

void main(List<String> args) {
  final lcov = File(args.isNotEmpty ? args.first : 'coverage/lcov.info');
  if (!lcov.existsSync()) {
    stderr.writeln('No LCOV report at ${lcov.path}.');
    stderr.writeln('Run: dart test --coverage=coverage');
    stderr.writeln('Then: dart pub global run coverage:format_coverage '
        '--lcov --in=coverage --out=coverage/lcov.info --report-on=lib');
    exit(2);
  }

  final files = <String, FileCov>{};
  String? current;
  for (final raw in lcov.readAsLinesSync()) {
    final line = raw.trim();
    if (line.startsWith('SF:')) {
      final path = _normalise(line.substring(3));
      current = path;
      files.putIfAbsent(path, () => FileCov(path));
    } else if (line.startsWith('LF:') && current != null) {
      files[current]!.found = int.parse(line.substring(3));
    } else if (line.startsWith('LH:') && current != null) {
      files[current]!.hit = int.parse(line.substring(3));
    }
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
