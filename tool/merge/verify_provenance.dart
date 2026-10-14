// tool/merge/verify_provenance.dart — provenance check with a meaningful
// exit code.
//
// Why this exists rather than calling verify_codes.dart from CI:
//
//   data/_raw/ is deliberately gitignored (~2.5 MB of CC-BY snapshots), so a
//   clean CI checkout does not contain it. The old setup ran the full hash
//   verification anyway and, on failure, opened a GitHub issue titled
//   "[provenance] vendored source drift detected" — blaming upstream for the
//   condition "we chose not to ship the snapshots". The job had never run,
//   so this was found by reading it rather than by it firing.
//
// This tool separates the three cases that were previously conflated:
//
//   0  verified        every pinned input present and matching
//   2  sourcesAbsent   data/_raw/ is not here — expected in CI, NOT drift
//   1  drift / invalid  a real problem: manifest malformed, or a pinned file
//                       is missing, altered, or unpinned
//
// Usage (from the package root):
//   dart run tool/merge/verify_provenance.dart              # full check
//   dart run tool/merge/verify_provenance.dart --manifest   # contract only,
//                                                          # works with no _raw
//
// Exit code 2 is the whole point: it lets a scheduled job stay quiet when
// there is nothing to check, and speak up only when something is actually wrong.

import 'dart:io';

import 'common.dart';

void main(List<String> args) {
  final manifestOnly =
      args.contains('--manifest') || args.contains('--manifest-only');

  final report = auditProvenance(manifestOnly: manifestOnly);

  stdout.writeln('=' * 70);
  stdout.writeln('PROVENANCE  ${manifestOnly ? "(manifest only)" : "(full)"}');
  stdout.writeln('=' * 70);
  stdout.writeln('pinned inputs : ${report.pinnedCount}');
  stdout.writeln('sources present: ${report.sourcesPresent}');
  stdout.writeln('status        : ${report.status.name}');

  if (report.problems.isNotEmpty) {
    stdout.writeln('\nproblems (${report.problems.length}):');
    for (final p in report.problems) {
      stdout.writeln('  - $p');
    }
  }
  stdout.writeln('=' * 70);

  switch (report.status) {
    case ProvenanceStatus.verified:
      stdout.writeln(manifestOnly
          ? 'OK: the manifest is well-formed. Payloads not checked.'
          : 'OK: every pinned input matches its recorded hash and size.');
      exit(0);

    case ProvenanceStatus.sourcesAbsent:
      // Not a failure, and not drift. A clean checkout cannot check payloads.
      stdout.writeln(
        'SKIPPED: no vendored inputs present, so nothing could be verified.\n'
        'This is expected in CI and is NOT evidence of upstream drift.\n'
        'To run the merge locally, re-fetch per data/SOURCES.md.',
      );
      exit(2);

    case ProvenanceStatus.drifted:
      stderr.writeln(
        'DRIFT: at least one vendored input disagrees with the manifest.\n'
        'An upstream source has changed. Do NOT re-run the merge to paper over\n'
        'it - see data/SOURCES.md (re-fetch, re-review, re-pin, re-merge).',
      );
      exit(1);

    case ProvenanceStatus.manifestInvalid:
      stderr.writeln(
        'INVALID: the pinning contract itself is broken, so no statement about\n'
        'the inputs can be trusted. Fix data/PROVENANCE.sha256 first.',
      );
      exit(1);
  }
}
