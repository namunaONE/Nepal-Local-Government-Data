// tool/merge/verify_codes.dart
//
// Step 2 of the roadmap: verify CBS hierarchical codes and reconcile them
// against postal-2025 and our dataset, producing staged nsoCode assignments.
//
// Gates, in order — any failure exits non-zero WITHOUT writing outputs:
//   0. provenance (shared gate: data/PROVENANCE.sha256)
//   1. structural asserts on the three CBS CSVs (counts, uniqueness,
//      code patterns, per-province prefix sets, palika-prefix integrity)
//   2. alignment guard: EN type-suffix <-> Devanagari suffix correspondence
//      on all 753 palika rows (a row-shifted file breaks this systematically)
//   3. district Devanagari quarantine check (known upstream corruption)
// On success it writes data/_stage/nso_codes.json (all 753 ours palikas,
// verified or explicitly null) and doc/_verify-codes-raw.txt.
//
// Assignment rule (strict): VERIFIED iff a postal-2025 T1/T2-accepted code C
// exists AND CBS row C is in the same district AND CBS's normalized name
// agrees with the postal key's normalized name — i.e. the CODE is
// doubly-attested for the same entity, independent of our spelling.
// Everything else is UNVERIFIED (null), with a suggestion for Step 4 review.
//
// Usage (from the package root):
//   dart run tool/merge/verify_codes.dart

import 'dart:convert';
import 'dart:io';

import 'common.dart';

/// CBS English type suffixes, longest-first. Includes the harvest's own
/// typos ("Metropolitian", "Sub-Metropolitian") so they match as types
/// instead of failing open.
const _cbsTypeSuffixes = [
  'sub-metropolitian city',
  'sub-metropolitan city',
  'metropolitian city',
  'metropolitan city',
  'rural municipality',
  'municipality',
];

/// Our type key -> canonical English suffix (matches postal-2025 keys).
const _ourTypeSuffix = {
  'metropolitan': 'metropolitan city',
  'subMetropolitan': 'sub-metropolitan city',
  'municipality': 'municipality',
  'ruralMunicipality': 'rural municipality',
};

/// Expected Devanagari suffix per CBS English suffix.
const _neSuffix = {
  'sub-metropolitian city': 'उपमहानगरपालिका',
  'sub-metropolitan city': 'उपमहानगरपालिका',
  'metropolitian city': 'महानगरपालिका',
  'metropolitan city': 'महानगरपालिका',
  'rural municipality': 'गाउँपालिका',
  'municipality': 'नगरपालिका',
};

String _cbsTypeOf(String unitEn) {
  final lower = unitEn.toLowerCase().trim();
  for (final s in _cbsTypeSuffixes) {
    if (lower.endsWith(' $s') || lower == s) return s;
  }
  return '';
}

/// Normalized name form for cross-checks: lowercase, parens and CBS typo
/// fixed, type suffix stripped, punctuation removed.
String _normKey(String raw) {
  var s = raw.toLowerCase().trim();
  s = s.replaceAll('metropolitian', 'metropolitan');
  return flatToken(stripSuffix(stripParens(s)));
}

void _fail(String message) {
  stderr.writeln('VERIFY_CODES FAILED: $message');
  exit(1);
}

void main() {
  // ---- Gate 0: provenance -------------------------------------------------
  final provenanceProblems = verifyProvenance();
  if (provenanceProblems.isNotEmpty) {
    stderr.writeln('PROVENANCE CHECK FAILED — refusing to run.');
    for (final p in provenanceProblems) {
      stderr.writeln('  $p');
    }
    exit(1);
  }

  final out = StringBuffer();
  out.writeln('=' * 78);
  out.writeln('STEP 2 CODE VERIFICATION');
  out.writeln('generated: ${DateTime.now().toUtc().toIso8601String()}');
  out.writeln('CBS harvest: opendatanepal geographical-codes dataset, '
      'license cc-by, metadata 2026-06-14 (re-verified at fetch)');
  out.writeln('=' * 78);

  // ---- Load CBS CSVs -------------------------------------------------------
  final states = loadSimpleCsv('data/_raw/cbs-codes/cbs_states.csv', [
    'state',
    'ne',
    'code',
  ]);
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
  void check(bool cond, String message) {
    if (!cond) _fail(message);
    out.writeln('  ok: $message');
  }

  check(states.length == 7, 'states rows == 7 (got ${states.length})');
  check(
    districts.length == 77,
    'district rows == 77 (got ${districts.length})',
  );
  check(bodies.length == 753, 'palika rows == 753 (got ${bodies.length})');

  final badDistCodes = districts
      .where((d) => !RegExp(r'^[1-7]\d{2}$').hasMatch(d['code']!))
      .toList();
  check(
    badDistCodes.isEmpty,
    'all 77 district codes match PDD (violations: ${badDistCodes.length})',
  );
  final badBodyCodes = bodies
      .where((b) => !RegExp(r'^[1-7]\d{4}$').hasMatch(b['code']!))
      .toList();
  check(
    badBodyCodes.isEmpty,
    'all 753 palika codes match PDDPP (violations: ${badBodyCodes.length})',
  );

  final distCodeSet = districts.map((d) => d['code']!).toSet();
  check(
    distCodeSet.length == 77,
    'district codes unique (distinct: ${distCodeSet.length})',
  );
  final bodyCodeSet = bodies.map((b) => b['code']!).toSet();
  check(
    bodyCodeSet.length == 753,
    'palika codes unique (distinct: ${bodyCodeSet.length})',
  );

  // Per-province district-prefix sets must equal the verified structure.
  const expectDistricts = {
    '1': 14,
    '2': 8,
    '3': 13,
    '4': 11,
    '5': 12,
    '6': 10,
    '7': 9,
  };
  for (final p in expectDistricts.keys) {
    final n = distCodeSet
        .where((c) => c.startsWith(p))
        .map((c) => c.substring(0, 3))
        .toSet()
        .length;
    check(
      n == expectDistricts[p],
      'province $p district prefixes == ${expectDistricts[p]} (got $n)',
    );
    final bodiesN = bodyCodeSet.where((c) => c.startsWith(p)).length;
    out.writeln('  info: province $p palika codes: $bodiesN');
  }

  // Palika-prefix integrity: every palika PDD prefix must be a district code.
  final orphanPrefixes = bodyCodeSet
      .map((c) => c.substring(0, 3))
      .where((pre) => !distCodeSet.contains(pre))
      .toSet();
  check(
    orphanPrefixes.isEmpty,
    'every palika PDD prefix is a district code '
    '(orphans: ${orphanPrefixes.join(',')})',
  );

  // ---- District Devanagari quarantine ---------------------------------------
  // Verified at codepoint level: row sn==43 (NAWALPARASI EAST) is truncated
  // mid-parenthetical and rows 44-77 each carry the previous row's district
  // name (off-by-one cascade). The column is never consumed.
  final row43 = districts.firstWhere((d) => d['sn'] == '43');
  final open = '('.allMatches(row43['ne']!).length;
  final close = ')'.allMatches(row43['ne']!).length;
  if (open != close) {
    out.writeln(
      '  QUARANTINE-CONFIRMED: districts row 43 Ne has unbalanced parens '
      '($open open vs $close close) — upstream corruption signature present; '
      'district Ne column is never consumed.',
    );
  } else {
    out.writeln(
      '  NOTE: districts row 43 Ne parens now balance — upstream may have '
      'fixed the file; quarantine retained for Step 2 (abin/sag cover '
      'district Ne at 64/13), re-evaluate in Step 4.',
    );
  }

  // ---- Gate 2: alignment guard (suffix correspondence) ----------------------
  // A row-shifted CSV breaks EN<->Ne type correspondence systematically.
  // Fail on a consecutive run >= 3 (cascade signature) or rate > 2%.
  final mismatches = <String>[];
  var run = 0;
  var maxRun = 0;
  for (final b in bodies) {
    final enType = _cbsTypeOf(b['unit']!);
    final ne = b['ne']!.trim();
    final ok = enType.isNotEmpty &&
        ne.isNotEmpty &&
        devaRegex.hasMatch(ne) &&
        ne.endsWith(_neSuffix[enType]!);
    if (ok) {
      run = 0;
    } else {
      run++;
      if (run > maxRun) maxRun = run;
      if (mismatches.length < 25) {
        mismatches.add(
          '    sn=${b['sn']} code=${b['code']}: EN="${b['unit']}" '
          'Ne="$ne" (enType=${enType.isEmpty ? '?' : enType})',
        );
      }
    }
  }
  out.writeln(
    '  alignment: ${bodies.length - mismatches.length}/${bodies.length} rows '
    'with EN<->Ne suffix correspondence (max consecutive run: $maxRun)',
  );
  for (final m in mismatches) {
    out.writeln(m);
  }
  if (maxRun >= 3 || mismatches.length > bodies.length * 0.02) {
    _fail(
      'alignment guard: maxRun=$maxRun, mismatches=${mismatches.length} '
      '(file is shifted or suffix vocabulary changed — stop, do not merge)',
    );
  }

  // ---- Load postal-2025 + ours ----------------------------------------------
  final postal = loadTsObject(
    'data/_raw/nepali-geo-pro-max/src_data_postal-codes-2025.ts',
  ).cast<String, String>();
  final ourJson =
      jsonDecode(File('data/nepal_local_levels.json').readAsStringSync())
          as Map<String, dynamic>;

  // CBS lookups.
  final cbsByCode = {for (final b in bodies) b['code']!: b};
  final cbsDistByCanon = <String, Map<String, String>>{};
  for (final d in districts) {
    cbsDistByCanon[canonDistrict(d['district'])] = d;
  }

  // Postal lookups: normalized index + prefix scoping from codes.
  final postalNorm = <String, List<MapEntry<String, String>>>{};
  String normPostal(String raw) {
    var s =
        raw.toLowerCase().trim().replaceAll('metropolitian', 'metropolitan');
    return flatToken(stripSuffix(stripParens(s)));
  }

  for (final e in postal.entries) {
    postalNorm.putIfAbsent(normPostal(e.key), () => []).add(e);
  }
  final postalKeysByPrefix = <String, List<String>>{};
  for (final e in postal.entries) {
    postalKeysByPrefix
        .putIfAbsent(e.value.substring(0, 3), () => [])
        .add(e.key);
  }

  // ---- Gate 3: CBS x postal reconciliation -----------------------------------
  final postalCodeSet = postal.values.toSet();
  if (postalCodeSet.length != postal.length) {
    _fail(
      'postal-2025 codes not unique: ${postal.length} entries, '
      '${postalCodeSet.length} distinct codes',
    );
  }
  out.writeln('  ok: postal-2025 codes unique (${postalCodeSet.length})');
  final postalOnly =
      postal.entries.where((e) => !cbsByCode.containsKey(e.value)).toList();
  final cbsOnly =
      bodies.where((b) => !postal.values.contains(b['code'])).toList();
  out.writeln('CBS codes: ${bodyCodeSet.length}; postal-2025 codes: '
      '${postal.length}');
  out.writeln('codes only in postal-2025 (stale?): ${postalOnly.length}');
  for (final e in postalOnly.take(15)) {
    out.writeln('    POSTAL-ONLY "${e.key}" = ${e.value}');
  }
  out.writeln('codes only in CBS (the coverage gap): ${cbsOnly.length}');
  for (final b in cbsOnly) {
    out.writeln('    CBS-ONLY sn=${b['sn']} ${b['district']} / ${b['unit']} '
        '= ${b['code']}');
  }
  final p7rows = bodies.where((b) => b['code']!.startsWith('7')).length;
  out.writeln('SUDURPASHCHIM VERDICT: CBS P7 rows = $p7rows (ours = 88) — '
      '${p7rows == 88 ? 'STRUCTURAL MATCH; postal-2025 holds 87 P7 codes, so its shortfall is a coverage gap, not a structural difference' : 'MISMATCH — escalate'}');
  if (p7rows != 88) _fail('Sudurpashchim row count $p7rows != 88');

  // ---- Assignments ------------------------------------------------------------
  var verified = 0;
  var unverified = 0;
  final assignments = <Map<String, dynamic>>[];
  final reviewLines = <String>[];
  for (final p in ourJson['provinces'] as List) {
    final pmap = p as Map;
    final prov = pmap['id'] as String;
    for (final d in pmap['districts'] as List) {
      final dmap = d as Map;
      final dname = dmap['name'] as String;
      final cbsDist = cbsDistByCanon[canonDistrict(dname)];
      final prefix = cbsDist?['code'];
      for (final b in dmap['localBodies'] as List) {
        final bmap = b as Map;
        final name = bmap['name'] as String;
        final type = bmap['type'] as String;
        final suffix = _ourTypeSuffix[type]!;
        String? code;
        String? tier;
        String? evidence;

        // T1: exact "<name> <suffix>".
        final exactKey = '${name.toLowerCase()} $suffix';
        if (postal.containsKey(exactKey) &&
            (prefix == null || postal[exactKey]!.startsWith(prefix))) {
          code = postal[exactKey];
          tier = 'T1';
          evidence = 'postal key "$exactKey"';
        } else {
          // T2: normalised-with-suffix, prefix-disambiguated.
          final nf = normPostal('${name.toLowerCase()} $suffix');
          final hits = postalNorm[nf] ?? const [];
          final inPrefix = prefix == null
              ? <MapEntry<String, String>>[]
              : hits.where((h) => h.value.startsWith(prefix)).toList();
          if (inPrefix.length == 1) {
            code = inPrefix.first.value;
            tier = 'T2';
            evidence = 'postal key "${inPrefix.first.key}"';
          }
        }

        // Doubly-attest: CBS row C must be same-district with agreeing name.
        var ok = false;
        if (code != null && prefix != null) {
          final cbs = cbsByCode[code];
          if (cbs != null &&
              cbs['code']!.startsWith(prefix) &&
              _normKey(cbs['unit']!) ==
                  _normKey(
                      postal.entries.firstWhere((e) => e.value == code).key)) {
            ok = true;
            evidence = '$evidence; CBS code $code (${cbs['district']})';
          }
        }

        if (ok) {
          verified++;
          assignments.add({
            'province': prov,
            'district': dname,
            'name': name,
            'type': type,
            'nsoCode': code,
            'nsoCodeVerified': true,
            'evidence': '$evidence (tier $tier)',
          });
        } else {
          unverified++;
          // Suggestion for Step 4 review: best district-scoped postal key.
          final scoped = prefix == null
              ? postal.keys.toList()
              : postalKeysByPrefix[prefix] ?? const <String>[];
          final nf = normPostal('${name.toLowerCase()} $suffix');
          String? best;
          var bestD = 999;
          for (final c in scoped) {
            final dd = levenshtein(nf, normPostal(c), 2);
            if (dd < bestD) {
              bestD = dd;
              best = c;
            }
          }
          final sug = (bestD <= 2 && best != null)
              ? '"$best"=${postal[best]} (d=$bestD)'
              : (best == null ? 'none' : '"$best" (d=$bestD, weak)');
          assignments.add({
            'province': prov,
            'district': dname,
            'name': name,
            'type': type,
            'nsoCode': null,
            'nsoCodeVerified': false,
            'evidence': 'no doubly-attested code; suggestion $sug',
          });
          if (reviewLines.length < 60) {
            reviewLines.add('    REVIEW $name [$dname]: suggestion $sug');
          }
        }
      }
    }
  }

  out.writeln('ASSIGNMENTS: verified=$verified unverified=$unverified '
      'total=${assignments.length}');
  for (final l in reviewLines) {
    out.writeln(l);
  }

  // ---- Write staged mapping -----------------------------------------------------
  final staged = {
    'provenance': {
      'generated': DateTime.now().toUtc().toIso8601String(),
      'tool': 'tool/merge/verify_codes.dart',
      'inputs': [
        'data/_raw/cbs-codes/cbs_local_bodies.csv',
        'data/_raw/cbs-codes/cbs_districts.csv',
        'data/_raw/cbs-codes/cbs_states.csv',
        'data/_raw/nepali-geo-pro-max/src_data_postal-codes-2025.ts',
        'data/nepal_local_levels.json',
      ],
      'rule': 'VERIFIED iff postal-2025 T1/T2 code is doubly-attested by a '
          'same-district CBS row with agreeing normalized name; else null. '
          'Nothing is guessed.',
    },
    'counts': {
      'verified': verified,
      'unverified': unverified,
      'total': assignments.length
    },
    'assignments': assignments,
  };
  Directory('data/_stage').createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  File('data/_stage/nso_codes.json').writeAsStringSync(encoder.convert(staged));

  out.writeln('wrote data/_stage/nso_codes.json '
      '($verified verified, $unverified unverified)');

  stdout.write(out.toString());
  File('doc/_verify-codes-raw.txt').writeAsStringSync(out.toString());
}
