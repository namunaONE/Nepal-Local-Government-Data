// tool/pipeline.dart — one command that regenerates every derived artifact.
//
// Usage (from the package root):
//   dart run tool/pipeline.dart            # full regeneration
//   dart run tool/pipeline.dart --dry-run  # run everything, write nothing
//
// Why this exists
// ---------------
// The dataset, the embedded Dart file and the website payload are three
// artifacts of ONE source of truth. Running the merge steps by hand works
// until someone forgets a step, and a forgotten step does not fail loudly —
// it just leaves the website disagreeing with the package. This runs the
// whole chain, in order, and refuses to continue if any step fails.
//
// Steps:
//   1. tool/merge/verify_codes.dart       CBS codes, doubly-attested tier
//   2. tool/merge/apply_cbs_codes.dart   write them into the dataset
//   3. tool/merge/resolve_code_tiers.dart single-source tier + bijection gate
//   4. tool/merge/attach_bilingual.dart  Devanagari names at all 3 levels
//   5. tool/merge/attach_attributes.dart HQ / area / website / contact / postal
//   6. tool/generate.dart                lib/src/nepal_data.dart (validates)
//   7. tool/generate_explorer_data.dart  docs/data.json
//
// Steps 4 and 5 are ORDERED, not incidental: MoFAGA rows carry no codes, so
// attach_attributes joins palikas by their Devanagari name, which only exists
// once step 4 has run. Running them out of order would silently attach
// nothing to 731 records.
//
// Notes:
//   - Steps 1-5 need data/_raw/ and the provenance manifest; run
//     tool/merge/inventory.dart first if you have just re-fetched sources.
//   - Every step is gated on its own exit code. A non-zero anywhere aborts
//     the run, leaving earlier artifacts untouched.

import 'dart:io';

const _steps = <String, String>{
  'verifying CBS codes (step 1/7)': 'tool/merge/verify_codes.dart',
  'applying CBS codes (step 2/7)': 'tool/merge/apply_cbs_codes.dart',
  'resolving code confidence tiers (step 3/7)':
      'tool/merge/resolve_code_tiers.dart',
  'attaching Devanagari names (step 4/7)': 'tool/merge/attach_bilingual.dart',
  'attaching administrative attributes (step 5/7)':
      'tool/merge/attach_attributes.dart',
  'generating lib/src/nepal_data.dart (step 6/7)': 'tool/generate.dart',
  'generating docs/data.json (step 7/7)': 'tool/generate_explorer_data.dart',
};

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');

  if (!File('data/nepal_local_levels.json').existsSync()) {
    _abort('data/nepal_local_levels.json not found — run from the package '
        'root.');
  }

  stdout.writeln('=' * 70);
  stdout.writeln('nepal_admin_api regeneration pipeline'
      '${dryRun ? ' (DRY RUN — no files will be written)' : ''}');
  stdout.writeln('=' * 70);

  var index = 0;
  for (final entry in _steps.entries) {
    index++;
    final label = entry.key;
    final script = entry.value;

    if (!File(script).existsSync()) {
      _abort('step $index: $script is missing — the pipeline cannot run.');
    }

    stdout.writeln('\n[$index/${_steps.length}] $label');
    stdout.writeln('      $script');

    if (dryRun) {
      // Still execute: these tools validate and report, and a dry run that
      // cannot detect a broken dataset is not worth much. Only the writing
      // steps are told to hold off.
      final preview = script.contains('resolve_code_tiers')
          ? <String>['--dry-run']
          : (script.contains('attach_bilingual') ||
                  script.contains('attach_attributes'))
              ? <String>['--dry-run']
              : const <String>[];
      final r = Process.runSync(
        Platform.resolvedExecutable,
        <String>['run', script, ...preview],
      );
      _relay(r, script);
    } else {
      final r = Process.runSync(
        Platform.resolvedExecutable,
        <String>['run', script],
      );
      _relay(r, script);
    }
  }

  stdout.writeln('\n${'=' * 70}');
  stdout.writeln(dryRun
      ? 'DRY RUN complete — no artifacts were written.'
      : 'Pipeline complete. Artifacts regenerated:');
  stdout.writeln('  data/nepal_local_levels.json');
  stdout.writeln('  lib/src/nepal_data.dart');
  stdout.writeln('  docs/data.json');
  stdout.writeln('');
  stdout.writeln('Next: `dart analyze --fatal-infos && dart test`, then commit '
      'the data and the regenerated files together.');
  stdout.writeln('=' * 70);
}

/// Streams a step's output and aborts the whole run on a non-zero exit.
void _relay(ProcessResult r, String script) {
  final out = r.stdout.toString();
  final err = r.stderr.toString();
  if (out.isNotEmpty) stdout.write(out);
  if (err.isNotEmpty) stderr.write(err);

  if (r.exitCode != 0) {
    _abort('$script exited with code ${r.exitCode}. Nothing further was run.');
  }
}

Never _abort(String message) {
  stderr.writeln('\nPIPELINE ABORTED: $message');
  exit(1);
}
