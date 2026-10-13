// tool/merge/resolve_code_tiers.dart
//
// Assigns a confidence TIER to every palika's CBS code and writes it into
// data/nepal_local_levels.json as `cbsCodeConfidence`.
//
// Why this exists
// ---------------
// verify_codes.dart is deliberately strict: a code counts as VERIFIED only
// when postal-2025 and the CBS harvest independently attest the same code
// for the same entity. That rule is correct, but it left 206/753 palikas
// with `cbsCode == null` even though the CBS roster names every one of them.
// For a consumer building a code-keyed map (joining against MoFAGA or other
// government datasets) that silently drops over a quarter of Nepal's local
// bodies.
//
// So we keep the strict tier and add a weaker, clearly-labelled one:
//
//   verified     - doubly-attested (postal-2025 + CBS agree). The original
//                  547. cbsCodeVerified == true.
//   singleSource - the authoritative CBS roster contains exactly one
//                  same-district row of the same palika type whose
//                  normalized name is within Levenshtein distance 2 of
//                  ours, and that row's code is not already claimed.
//                  One attestation, not two.
//   unverified   - no defensible code. cbsCode stays null.
//
// Nothing is guessed: an ambiguous candidate (two rows tied at the best
// distance) is left unverified rather than picked arbitrarily, and the
// assigned set is forced to be a bijection so two palikas can never share
// a code.
//
// Gates (any failure exits non-zero WITHOUT writing):
//   0. provenance (shared gate: data/PROVENANCE.sha256)
//   1. CBS CSV structural asserts (counts, code patterns, uniqueness)
//   2. district resolution for all 77 districts (scopes candidates)
//   3. post-assignment bijection + district-prefix integrity
//
// Usage (from the package root):
//   dart run tool/merge/resolve_code_tiers.dart            # write tiers
//   dart run tool/merge/resolve_code_tiers.dart --dry-run  # report only

import 'dart:convert';
import 'dart:io';

import 'common.dart';

/// Max normalized-name distance accepted for a single-source assignment.
/// Distance 0 is an exact flattened match; 1-2 absorbs observed spelling
/// variants between our roster and the CBS harvest ("Shadananda" /
/// "Shadanand", "Phaktanglung" / "Phaktanlung"). Above 2 the match would be
/// a guess, so it is refused.
const _maxSingleSourceDistance = 2;

Never _fail(String message) {
  stderr.writeln('RESOLVE_CODE_TIERS FAILED: $message');
  exit(1);
}

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');

  // ---- Gate 0: provenance -------------------------------------------------
  final provenanceProblems = verifyProvenance();
  if (provenanceProblems.isNotEmpty) {
    stderr.writeln('PROVENANCE CHECK FAILED - refusing to run.');
    for (final p in provenanceProblems) {
      stderr.writeln('  $p');
    }
    exit(1);
  }

  final out = StringBuffer();
  out.writeln('=' * 78);
  out.writeln('CODE CONFIDENCE TIERS');
  out.writeln('generated: ${DateTime.now().toUtc().toIso8601String()}');
  out.writeln('dry-run: $dryRun');
  out.writeln('=' * 78);

  // ---- Load CBS CSVs -------------------------------------------------------
  final districts = loadSimpleCsv('data/_raw/cbs-codes/cbs_districts.csv', [
    'sn',
    'district',
    'ne',
    'code',
  ]);
  final bodies = loadSimpleCsv('data/_raw/cbs-codes/cbs_local_bodies.csv', [
    'sn',
    'district',
    'unit',
    'ne',
    'code',
  ]);

  // ---- Gate 1: structural asserts ------------------------------------------
  var failed = false;
  void check(bool cond, String message) {
    if (!cond) {
      failed = true;
      _fail(message);
    }
    out.writeln('  ok: $message');
  }

  check(
    districts.length == 77,
    'district rows == 77 (got ${districts.length})',
  );
  check(bodies.length == 753, 'palika rows == 753 (got ${bodies.length})');
  check(
    districts.every((d) => RegExp(r'^[1-7]\d{2}$').hasMatch(d['code']!)),
    'all district codes match PDD',
  );
  check(
    bodies.every((b) => RegExp(r'^[1-7]\d{4}$').hasMatch(b['code']!)),
    'all palika codes match PDDPP',
  );
  final bodyCodes = bodies.map((b) => b['code']!).toSet();
  check(bodyCodes.length == 753, 'palika codes unique');
  if (failed) exit(1);

  // CBS rows grouped by their district code (PDD prefix of the PDDPP code).
  final cbsByDistrict = <String, List<Map<String, String>>>{};
  for (final b in bodies) {
    cbsByDistrict.putIfAbsent(b['code']!.substring(0, 3), () => []).add(b);
  }

  // ---- Load our dataset ----------------------------------------------------
  final levelsFile = File('data/nepal_local_levels.json');
  final levelsJson =
      jsonDecode(levelsFile.readAsStringSync()) as Map<String, dynamic>;
  final provinces =
      (levelsJson['provinces'] as List).cast<Map<String, dynamic>>();

  // ---- Gate 2: district resolution -----------------------------------------
  final cbsDistByCanon = <String, Map<String, String>>{};
  for (final d in districts) {
    cbsDistByCanon[canonDistrict(d['district'])] = d;
  }

  final records = <Map<String, dynamic>>[];
  var forcedTotal = 0;
  for (final province in provinces) {
    final provId = province['id'] as String;
    for (final district in (province['districts'] as List)) {
      final dmap = district as Map<String, dynamic>;
      final dname = dmap['name'] as String;
      final cbsDist = cbsDistByCanon[canonDistrict(dname)];
      final prefix = cbsDist?['code'];

      if (prefix == null) {
        _fail(
          'district "$dname" ($provId) does not resolve to a CBS district - '
          'cannot scope candidate codes safely',
        );
      }
      // Our own 3-digit district code must agree with the CBS roster.
      final ours = dmap['cbsCode'] as int?;
      if (ours != int.parse(prefix)) {
        _fail(
          'district "$dname" ($provId): dataset cbsCode=$ours but CBS roster '
          'says $prefix - dataset and roster disagree, stop',
        );
      }

      final oursRows =
          (dmap['localBodies'] as List).cast<Map<String, dynamic>>();
      final claimed = <String, String>{}; // code -> "District|Name" holder

      // Pass A - reserve the VERIFIED codes only, so a single-source
      // assignment can never collide with a doubly-attested one.
      //
      // Non-verified codes carried by the dataset are deliberately NOT
      // reserved: this tool re-derives every single-source code from the CBS
      // roster on each run, so it is idempotent and can never keep a code
      // that a later run of the roster would no longer support.
      for (final b in oursRows) {
        if (b['cbsCodeVerified'] != true) continue;
        final code = b['cbsCode'] as int?;
        if (code == null) continue;
        final key = '$dname|${b['name']}';
        final holder = claimed['$code'];
        if (holder != null) {
          _fail(
            'duplicate code $code already held by $holder and $key '
            'in $dname - dataset is inconsistent',
          );
        }
        claimed['$code'] = key;
      }

      final rows = cbsByDistrict[prefix] ?? const <Map<String, String>>[];

      // Pass B1 - name-proximity match for every palika lacking a verified code.
      // `pending` keeps the unresolved ones for the elimination pass below.
      final pending = <Map<String, dynamic>>[];

      void record({
        required String name,
        required String type,
        int? code,
        required String tier,
        required String evidence,
      }) {
        records.add({
          'province': provId,
          'district': dname,
          'districtCode': prefix,
          'name': name,
          'type': type,
          'code': code,
          'tier': tier,
          'evidence': evidence,
        });
      }

      for (final b in oursRows) {
        final name = b['name'] as String;
        final type = b['type'] as String;
        final have = b['cbsCode'] as int?;

        if (have != null && b['cbsCodeVerified'] == true) {
          record(
            name: name,
            type: type,
            code: have,
            tier: 'verified',
            evidence: 'doubly-attested (postal-2025 + CBS); carried by '
                'verify_codes.dart',
          );
          continue;
        }

        // CBS rows of this district: same type, free code, close name.
        final scored = <Map<String, dynamic>>[];
        for (final r in rows) {
          if (claimed.containsKey(r['code'])) continue;
          final cbsType = cbsTypeOf(r['unit']!);
          if (cbsType.isEmpty) continue;
          if (canonicalCbsType(cbsType) != ourTypeSuffix[type]) continue;
          final d = levenshtein(normCbsKey(name), normCbsKey(r['unit']!), 3);
          if (d <= _maxSingleSourceDistance) {
            scored.add({'row': r, 'distance': d});
          }
        }
        scored.sort(
          (a, b) => (a['distance'] as int).compareTo(b['distance'] as int),
        );

        final best = scored.isEmpty ? -1 : scored.first['distance'] as int;
        final bestRow =
            scored.isEmpty ? null : scored.first['row'] as Map<String, String>;
        final bestCode = bestRow?['code'];
        final runnerUp =
            scored.length > 1 ? scored[1]['distance'] as int : null;

        // Accept only a UNIQUE best candidate: a tie means two codes are
        // equally plausible, which is a guess, so refuse it.
        final unambiguous = bestCode != null &&
            best >= 0 &&
            (runnerUp == null || runnerUp > best) &&
            !claimed.containsKey(bestCode);

        if (unambiguous) {
          claimed[bestCode] = '$dname|$name';
          record(
            name: name,
            type: type,
            code: int.parse(bestCode),
            tier: 'singleSource',
            evidence: 'CBS roster row "${bestRow!['unit']}" (code $bestCode, '
                'normalized-name distance $best); single attestation',
          );
        } else {
          pending.add({
            'name': name,
            'type': type,
            'scored': scored,
            'best': best,
            'bestCode': bestCode,
          });
        }
      }

      // ---- Pass B2: forced elimination ---------------------------------------
      // If a district roster has exactly ONE of our palikas still unresolved
      // and exactly ONE unclaimed CBS row of that same type, the pairing is
      // forced by elimination - it is not a guess, it is the only bijection
      // that exists. This is what resolves long official names our roster
      // shortens (our "Pokhara" vs CBS "Pokhara Lekhnath Metropolitian City").
      //
      // Gated on this district's roster matching the CBS roster one-for-one by
      // type, so elimination can never fire on a district where we are simply
      // missing a palika.
      final ourUnresolvedByType = <String, List<String>>{};
      for (final p in pending) {
        ourUnresolvedByType
            .putIfAbsent(p['type'] as String, () => [])
            .add(p['name'] as String);
      }
      final freeCbsByType = <String, List<Map<String, String>>>{};
      for (final r in rows) {
        if (claimed.containsKey(r['code'])) continue;
        final cbsType = cbsTypeOf(r['unit']!);
        if (cbsType.isEmpty) continue;
        freeCbsByType.putIfAbsent(canonicalCbsType(cbsType), () => []).add(r);
      }

      // Does our roster match the CBS roster type-for-type in this district?
      // Keyed by the SAME canonical suffix vocabulary on both sides.
      final ourTotalByType = <String, int>{};
      for (final b in oursRows) {
        final t = ourTypeSuffix[b['type'] as String]!;
        ourTotalByType[t] = (ourTotalByType[t] ?? 0) + 1;
      }
      final cbsTotalByType = <String, int>{};
      for (final r in rows) {
        final cbsType = cbsTypeOf(r['unit']!);
        if (cbsType.isEmpty) continue;
        final canon = canonicalCbsType(cbsType);
        cbsTotalByType[canon] = (cbsTotalByType[canon] ?? 0) + 1;
      }
      final rosterAligned = ourTotalByType.length == cbsTotalByType.length &&
          ourTotalByType.entries.every((e) => cbsTotalByType[e.key] == e.value);

      final stillPending = <Map<String, dynamic>>[];
      var forced = 0;
      if (rosterAligned) {
        for (final p in pending) {
          final type = p['type'] as String;
          final names = ourUnresolvedByType[type] ?? const <String>[];
          final free = freeCbsByType[ourTypeSuffix[type]] ?? const [];
          if (names.length == 1 && free.length == 1) {
            final row = free.single;
            claimed[row['code']!] = '$dname|${p['name']}';
            forced++;
            record(
              name: p['name'] as String,
              type: type,
              code: int.parse(row['code']!),
              tier: 'singleSource',
              evidence: 'forced by elimination: ours and the CBS roster each '
                  'have exactly one ${ourTypeSuffix[type]} in $dname '
                  '(CBS row "${row['unit']}", code ${row['code']}); roster '
                  'verified type-for-type',
            );
          } else {
            stillPending.add(p);
          }
        }
      } else {
        stillPending.addAll(pending);
      }

      // Anything still unresolved stays null, with the reason recorded.
      for (final p in stillPending) {
        final scored = p['scored'] as List;
        record(
          name: p['name'] as String,
          type: p['type'] as String,
          tier: 'unverified',
          evidence: scored.isEmpty
              ? 'no CBS row of the same type within distance '
                  '$_maxSingleSourceDistance; elimination not forced '
                  '(${ourUnresolvedByType[p['type']]?.length ?? 0} unresolved '
                  'vs ${freeCbsByType[ourTypeSuffix[p['type']!]]?.length ?? 0} '
                  'free CBS rows)'
              : 'ambiguous: ${scored.length} candidates, best distance '
                  '${p['best']} '
                  '(${scored.map((s) => s['row']!['code']).join(', ')}) - '
                  'refused as a guess',
        );
      }
      forcedTotal += forced;
    }
  }

  // ---- Gate 3: post-assignment invariants ----------------------------------
  final assigned = <String, String>{};
  for (final r in records) {
    final code = r['code'] as int?;
    if (code == null) continue;
    final holder = assigned['$code'];
    if (holder != null) {
      _fail(
        'code $code assigned twice: $holder and ${r['district']}|${r['name']}',
      );
    }
    assigned['$code'] = '${r['district']}|${r['name']}';
  }

  final wrongPrefix = <String>[];
  for (final r in records) {
    final code = r['code'] as int?;
    if (code == null) continue;
    if ('$code'.substring(0, 3) != r['districtCode']) {
      wrongPrefix.add(
        '${r['district']} / ${r['name']}: code $code is not in district '
        '${r['districtCode']}',
      );
    }
  }
  check(
    wrongPrefix.isEmpty,
    'every assigned code sits in its own district '
    '(violations: ${wrongPrefix.length})',
  );
  for (final v in wrongPrefix.take(10)) {
    out.writeln('    PREFIX $v');
  }
  check(records.length == 753, 'records == 753 (got ${records.length})');

  final tiers = <String, int>{};
  for (final r in records) {
    final t = r['tier'] as String;
    tiers[t] = (tiers[t] ?? 0) + 1;
  }
  check(
    (tiers['verified'] ?? 0) +
            (tiers['singleSource'] ?? 0) +
            (tiers['unverified'] ?? 0) ==
        753,
    'tier counts sum to 753',
  );

  out.writeln(
    'TIERS: ${tiers['verified']} verified, ${tiers['singleSource']} '
    'singleSource, ${tiers['unverified']} unverified',
  );
  out.writeln(
    'CODE COVERAGE: ${assigned.length}/753 palikas join-able by CBS code',
  );
  out.writeln('  (of the singleSource tier, $forcedTotal were resolved by '
      'forced elimination rather than name proximity)');

  final unverified = records.where((r) => r['tier'] == 'unverified').toList();
  out.writeln('');
  out.writeln('STILL UNVERIFIED (${unverified.length}):');
  for (final r in unverified.take(40)) {
    out.writeln('  ${r['district']} / ${r['name']}: ${r['evidence']}');
  }
  if (unverified.length > 40) {
    out.writeln('  ... and ${unverified.length - 40} more');
  }

  // ---- Write staged evidence ----------------------------------------------
  final staged = {
    'provenance': {
      'generated': DateTime.now().toUtc().toIso8601String(),
      'tool': 'tool/merge/resolve_code_tiers.dart',
      'inputs': [
        'data/_raw/cbs-codes/cbs_local_bodies.csv',
        'data/_raw/cbs-codes/cbs_districts.csv',
        'data/nepal_local_levels.json',
      ],
      'rule': 'verified = doubly-attested (carried from verify_codes.dart). '
          'singleSource = unique same-district, same-type CBS roster row '
          'within normalized-name distance <= $_maxSingleSourceDistance whose '
          'code is unclaimed. unverified = ambiguous or no candidate, code '
          'stays null. The assigned set is forced to be a bijection.',
      'tier_notes': {
        'verified': 'doubly-attested: postal-2025 and CBS agree',
        'singleSource': 'single attestation from the authoritative CBS roster, '
            'either by normalized-name distance <= $_maxSingleSourceDistance '
            'or by forced elimination inside a district whose roster matches '
            'the CBS roster type-for-type',
        'unverified': 'no defensible code; left null on purpose',
      },
      'forcedByElimination': forcedTotal,
    },
    'counts': {
      'verified': tiers['verified'] ?? 0,
      'singleSource': tiers['singleSource'] ?? 0,
      'unverified': tiers['unverified'] ?? 0,
      'total': records.length,
      'codeCoverage': assigned.length,
    },
    'assignments': records,
  };
  Directory('data/_stage').createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  File(
    'data/_stage/code_tiers.json',
  ).writeAsStringSync(encoder.convert(staged));

  if (dryRun) {
    out.writeln('');
    out.writeln(
      'DRY RUN - dataset NOT modified. Evidence written to '
      'data/_stage/code_tiers.json',
    );
    stdout.write(out.toString());
    return;
  }

  // ---- Apply tiers to the dataset -----------------------------------------
  // cbsCode is filled for singleSource rows; cbsCodeVerified stays true ONLY
  // for the verified tier, so every existing strict check keeps its meaning.
  var changed = 0;
  var demoted = 0;
  for (final province in provinces) {
    for (final district in (province['districts'] as List)) {
      final dmap = district as Map<String, dynamic>;
      final dname = dmap['name'] as String;
      for (final b
          in (dmap['localBodies'] as List).cast<Map<String, dynamic>>()) {
        final name = b['name'] as String;
        final rec = records.firstWhere(
          (r) => r['district'] == dname && r['name'] == name,
          orElse: () => {'tier': 'unverified', 'code': null},
        );
        final tier = rec['tier'] as String;
        final beforeCode = b['cbsCode'] as int?;
        final beforeVerified = b['cbsCodeVerified'] as bool? ?? false;
        b['cbsCode'] = rec['code'];
        b['cbsCodeVerified'] = tier == 'verified';
        b['cbsCodeConfidence'] = tier;
        if (beforeCode != b['cbsCode']) changed++;
        if (beforeVerified && !b['cbsCodeVerified']) demoted++;
      }
    }
  }

  levelsFile.writeAsStringSync(encoder.convert(levelsJson));
  out.writeln('');
  out.writeln(
    'Updated data/nepal_local_levels.json ($changed palikas gained a code, '
    '$demoted lost strict verification)',
  );
  out.writeln('wrote data/_stage/code_tiers.json');

  stdout.write(out.toString());
}
