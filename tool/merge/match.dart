// tool/merge/match.dart
//
// Step 3 of the roadmap: join every source against OUR 753 palikas and
// classify each field for adjudication.
//
// For each ours palika it carries:
//   - nameNe votes from the three INDEPENDENT sources (abinrimal, sagautam5-np
//     via shared id, CBS harvest) — geo-pro-max is derived from sagautam5 and
//     never votes (shown supplementary only)
//   - wardCount from sagautam5-en (single authority; never fuzzy-carried)
//   - nsoCode from the staged Step 2 mapping (never recomputed here)
//   - EN spelling variants (recorded; ours names are NOT changed here)
//
// Only EXACT flat-key matches vote. Fuzzy suggestions are recorded for
// review, never auto-joined.
//
// Classification per palika, nameNe:
//   UNANIMOUS (3 equal) / MAJORITY (2 equal, dissent logged) /
//   MAJORITY-2 (2 votes, equal) / CONFLICT-3 / CONFLICT-2 /
//   SINGLE-SOURCE / MISSING (+ FUZZY-CANDIDATE notes where applicable)
//
// Outputs: doc/REVIEW.md (human worksheet) + data/_stage/merge_candidates.json
// (machine-readable). If data/_stage/adjudications.json exists (written by a
// human from REVIEW.md v1), its decisions render as a DECISIONS-APPLIED
// section — workflow: run once, adjudicate, run again.
//
// Hard gates (exit non-zero): ours structure still 7/77/753; every palika
// processed exactly once; carried ward accounting complete (no silent drops).
//
// Usage (from the package root):
//   dart run tool/merge/match.dart

import 'dart:convert';
import 'dart:io';

import 'common.dart';

/// CBS English unit-name normalisation before keying: fix the harvest's own
/// typos so "Dharan Sub-Metropolitian City" keys as "dharan", and map the
/// "Gaunpaika"/"Gaun Palika" variants to the canonical suffix so the shared
/// stripSuffix/ logic applies. Matching-only; source strings are preserved
/// in the candidate records for review.
String _cbsUnitKey(String raw) {
  var s = raw.toLowerCase().trim();
  s = s.replaceAll('metropolitian', 'metropolitan');
  s = s.replaceAll('gaunpaika', 'rural municipality');
  s = s.replaceAll('gaun palika', 'rural municipality');
  return flatToken(stripSuffix(stripParens(s)));
}

/// Strips the palika-type suffix from a CBS Devanagari value ("धरान
/// उपमहानगरपालिका" -> "धरान") so it compares against the bare names that
/// abinrimal/sagautam5 store. Longest-first: every suffix ends in
/// "नगरपालिका". Matching-only; the raw value is preserved in candidates.
String _stripNeSuffix(String raw) {
  var s = raw.trim();
  for (final suffix in const [
    'उपमहानगरपालिका',
    'महानगरपालिका',
    'गाउँपालिका',
    'नगरपालिका',
  ]) {
    if (s.endsWith(' $suffix')) {
      return s.substring(0, s.length - suffix.length - 1).trim();
    }
    if (s == suffix) return '';
  }
  return s;
}

Map<String, List<Map<String, String>>> _indexCbs(
  List<Map<String, String>> rows,
) {
  final idx = <String, List<Map<String, String>>>{};
  for (final r in rows) {
    final key =
        '${flatToken(canonDistrict(r['district']))}|${_cbsUnitKey(r['unit']!)}';
    idx.putIfAbsent(key, () => []).add(r);
  }
  return idx;
}

void _fail(String message) {
  stderr.writeln('MATCH FAILED: $message');
  exit(1);
}

void main() {
  // ---- Provenance gate ------------------------------------------------------
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
  out.writeln('STEP 3 MERGE CANDIDATES + REVIEW WORKSHEET');
  out.writeln('generated: ${DateTime.now().toUtc().toIso8601String()}');
  out.writeln('rule: only EXACT flat-key matches vote; fuzzy is review-only;');
  out.writeln('geo-pro-max never votes (derived from sagautam5).');
  out.writeln('=' * 78);

  // ---- Load everything --------------------------------------------------------
  final ourJson =
      jsonDecode(File('data/nepal_local_levels.json').readAsStringSync())
          as Map<String, dynamic>;
  final abinLevels = loadJsonArray('data/_raw/abinrimal/local_levels.json');
  final abinDistricts = loadJsonArray('data/_raw/abinrimal/districts.json');
  final abinDistName = {
    for (final d in abinDistricts) d['code'] as String: d['name_en'] as String,
  };
  final sagEn = loadJsonArray(
      'data/_raw/local-states-nepal/dataset_municipalities_en.json');
  final sagNp = loadJsonArray(
      'data/_raw/local-states-nepal/dataset_municipalities_np.json');
  final sagDistricts = loadJsonArray(
    'data/_raw/local-states-nepal/dataset_districts_en.json',
  );
  final sagDistName = {
    for (final d in sagDistricts) d['id'] as int: d['name'] as String,
  };
  final sagNpById = {for (final m in sagNp) m['id'] as int: m};
  final geoUnits =
      loadTsArray('data/_raw/nepali-geo-pro-max/src_data_local-units.ts');
  final cbsBodies = loadSimpleCsv('data/_raw/cbs-codes/cbs_local_bodies.csv', [
    'sn',
    'district',
    'unit',
    'ne',
    'code',
  ]);
  final staged = jsonDecode(
    File('data/_stage/nso_codes.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final stagedByKey = <String, Map<String, dynamic>>{};
  for (final a in staged['assignments'] as List) {
    final m = (a as Map).cast<String, dynamic>();
    stagedByKey['${m['province']}|${m['district']}|${m['name']}'] = m;
  }

  // ---- Index sources by flat key -----------------------------------------------
  Map<String, List<Map<String, dynamic>>> indexBy(
    Iterable<Map<String, dynamic>> records,
    String Function(Map<String, dynamic>) keyOf,
  ) {
    final idx = <String, List<Map<String, dynamic>>>{};
    for (final r in records) {
      idx.putIfAbsent(keyOf(r), () => []).add(r);
    }
    return idx;
  }

  final abinIdx = indexBy(
    abinLevels,
    (l) => palikaKey(
      abinDistName[l['district_code'] as String],
      l['name_en'] as String?,
    ),
  );
  final sagIdx = indexBy(
    sagEn,
    (m) => palikaKey(
      sagDistName[m['district_id'] as int],
      m['name'] as String?,
    ),
  );
  final geoIdx = indexBy(
    geoUnits,
    (u) => palikaKey(
      u['districtNameEn'] as String?,
      u['nameEn'] as String?,
    ),
  );
  final cbsIdx = _indexCbs(cbsBodies);

  // ---- Walk ours ------------------------------------------------------------------
  var provCount = 0;
  var distCount = 0;
  var palikaCount = 0;
  final seenOursKeys = <String>{};
  var dupOursKeys = 0;

  final statusCounts = <String, int>{};
  final candidates = <Map<String, dynamic>>[];

  // Buckets for REVIEW.md.
  final conflict = <String>[];
  final single = <String>[];
  final missing = <String>[];
  final majority = <String>[];
  final enVariants = <String>[];
  final fuzzyNotes = <String>[];
  var wardCarried = 0;
  var wardMissing = 0;
  var wardSum = 0;
  var codeVerified = 0;
  var codeUnverified = 0;

  for (final p in ourJson['provinces'] as List) {
    final pmap = p as Map;
    provCount++;
    for (final d in pmap['districts'] as List) {
      final dmap = d as Map;
      distCount++;
      final dname = dmap['name'] as String;
      for (final b in dmap['localBodies'] as List) {
        final bmap = b as Map;
        palikaCount++;
        final name = bmap['name'] as String;
        final type = bmap['type'] as String;
        final key = palikaKey(dname, name);
        if (!seenOursKeys.add(key)) dupOursKeys++;

        final abinRecs = abinIdx[key] ?? const [];
        final sagRecs = sagIdx[key] ?? const [];
        final geoRecs = geoIdx[key] ?? const [];
        final cbsRecs = cbsIdx[key] ?? const [];

        // --- nameNe votes (independents only) ---
        final votes = <String, String>{}; // source -> value
        if (abinRecs.isNotEmpty) {
          final v = (abinRecs.first['name_ne'] as String?)?.trim() ?? '';
          if (v.isNotEmpty) votes['abinrimal'] = v;
        }
        Map<String, dynamic>? sagNpRec;
        if (sagRecs.isNotEmpty) {
          sagNpRec = sagNpById[sagRecs.first['id'] as int];
          final v = (sagNpRec?['name'] as String?)?.trim() ?? '';
          if (v.isNotEmpty) votes['sagautam5-np'] = v;
        }
        if (cbsRecs.isNotEmpty) {
          final v = _stripNeSuffix(cbsRecs.first['ne'] ?? '');
          if (v.isNotEmpty) votes['cbs'] = v;
        }
        final distinct = votes.values.toSet();
        String status;
        String? value;
        if (distinct.length >= 3) {
          status = 'CONFLICT-3';
        } else if (distinct.length == 2) {
          if (votes.length >= 3) {
            status = 'MAJORITY';
            final counts = <String, int>{};
            for (final v in votes.values) {
              counts[v] = (counts[v] ?? 0) + 1;
            }
            value =
                counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
          } else {
            status = 'CONFLICT-2';
          }
        } else if (distinct.length == 1) {
          if (votes.length >= 3) {
            status = 'UNANIMOUS';
            value = distinct.single;
          } else if (votes.length == 2) {
            status = 'MAJORITY-2';
            value = distinct.single;
          } else {
            status = 'SINGLE-SOURCE';
          }
        } else {
          status = 'MISSING';
        }
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        final voteStr =
            votes.entries.map((e) => '${e.key}="${e.value}"').join(' | ');
        final sup = geoRecs.isEmpty
            ? ''
            : ' [geo-supplementary: "${geoRecs.first['nameNe'] ?? ''}"]';
        switch (status) {
          case 'CONFLICT-3':
          case 'CONFLICT-2':
            conflict.add('    [$status] $name [$dname]: $voteStr$sup');
          case 'SINGLE-SOURCE':
            single.add('    $name [$dname]: $voteStr$sup');
          case 'MISSING':
            missing.add('    $name [$dname]: no independent nameNe vote$sup');
          case 'MAJORITY':
          case 'MAJORITY-2':
            majority.add('    [$status] $name [$dname] => "$value" '
                '(dissent: $voteStr$sup)');
        }

        // --- fuzzy candidates (review-only, never votes) ---
        final allKeysForSuggest = <String>{
          ...abinIdx.keys,
          ...sagIdx.keys,
          ...geoIdx.keys,
          ...cbsIdx.keys,
        };
        if (votes.isEmpty) {
          final sug = suggestKey(key, allKeysForSuggest);
          if (sug != null && fuzzyNotes.length < 80) {
            fuzzyNotes.add('    $name [$dname] ~> $sug');
          }
        }

        // --- EN variants (recorded; ours names unchanged here) ---
        final enSeen = <String, String>{};
        if (abinRecs.isNotEmpty) {
          enSeen['abinrimal'] = '${abinRecs.first['name_en']}';
        }
        if (sagRecs.isNotEmpty) {
          enSeen['sagautam5'] = '${sagRecs.first['name']}';
        }
        if (geoRecs.isNotEmpty) {
          enSeen['geo'] = '${geoRecs.first['nameEn']}';
        }
        if (cbsRecs.isNotEmpty) {
          enSeen['cbs'] = '${cbsRecs.first['unit']}';
        }
        final oursLoose = looseName(name);
        final enDiff = enSeen.entries
            .where((e) => looseName(e.value) != oursLoose)
            .toList();
        if (enDiff.isNotEmpty && enVariants.length < 120) {
          enVariants.add(
            '    $name [$dname] (ours) vs '
            '${enDiff.map((e) => '${e.key}="${e.value}"').join(' | ')}',
          );
        }

        // --- ward (sag authority; never fuzzy-carried) ---
        int? ward;
        String wardStatus;
        if (sagRecs.isNotEmpty) {
          ward = devaDigitsToInt(sagRecs.first['wards']);
          if (ward != null) {
            wardStatus = 'CARRIED-sagautam5';
            wardCarried++;
            wardSum += ward;
          } else {
            wardStatus = 'MISSING-unparseable';
            wardMissing++;
          }
        } else {
          wardStatus = 'MISSING-no-sag-match';
          wardMissing++;
        }

        // --- code (staged Step 2 mapping, never recomputed) ---
        final stagedRec = stagedByKey['${pmap['id']}|$dname|$name'];
        final nsoCode = stagedRec?['nsoCode'] as String?;
        final nsoVerified = (stagedRec?['nsoCodeVerified'] as bool?) ?? false;
        if (nsoVerified) {
          codeVerified++;
        } else {
          codeUnverified++;
        }

        candidates.add({
          'province': pmap['id'],
          'district': dname,
          'name': name,
          'type': type,
          'nameNe': {
            'status': status,
            'value': value,
            'votes': votes,
            'geoSupplementary':
                geoRecs.isEmpty ? null : geoRecs.first['nameNe'],
          },
          'wardCount': ward,
          'wardStatus': wardStatus,
          'nsoCode': nsoCode,
          'nsoCodeVerified': nsoVerified,
          'nsoEvidence': stagedRec?['evidence'],
          'enVariants': enSeen,
        });
      }
    }
  }

  // ---- Hard gates -------------------------------------------------------------------
  if (provCount != 7 || distCount != 77 || palikaCount != 753) {
    _fail(
      'structure drift: provinces=$provCount districts=$distCount '
      'palikas=$palikaCount (expect 7/77/753)',
    );
  }
  if (dupOursKeys != 0) {
    _fail('$dupOursKeys duplicate ours keys — canonical spine drifted');
  }
  if (candidates.length != 753) {
    _fail('processed ${candidates.length} palikas, expect 753');
  }
  out.writeln('GATES: 7 provinces / 77 districts / 753 palikas, '
      'all processed exactly once.');
  out.writeln('WARDS: carried=$wardCarried missing=$wardMissing '
      'sum(carried)=$wardSum ${wardMissing == 0 && wardSum == 6743 ? '(MATCHES gazette 6743)' : '(RESOLVE in adjudication)'}');
  out.writeln('CODES (staged): verified=$codeVerified '
      'unverified=$codeUnverified');

  // ---- REVIEW.md body ------------------------------------------------------------------
  out.writeln('');
  out.writeln('=' * 78);
  out.writeln(
      'NAME-NE CLASSIFICATION (independents: abinrimal, sagautam5-np, cbs)');
  for (final s in [
    'UNANIMOUS',
    'MAJORITY',
    'MAJORITY-2',
    'CONFLICT-3',
    'CONFLICT-2',
    'SINGLE-SOURCE',
    'MISSING',
  ]) {
    out.writeln('  $s: ${statusCounts[s] ?? 0}');
  }
  void section(String title, List<String> lines) {
    out.writeln('');
    out.writeln('-' * 78);
    out.writeln('$title (${lines.length})');
    for (final l in lines) {
      out.writeln(l);
    }
  }

  section('CONFLICT — needs MoFAGA adjudication', conflict);
  section('SINGLE-SOURCE — flag for Step 4', single);
  section('MISSING — no independent nameNe vote', missing);
  section(
    'MAJORITY — auto-accept winner, dissent logged (roadmap: accept + flag)',
    majority,
  );
  section(
    'EN-VARIANTS — recorded only; ours names unchanged in Step 3',
    enVariants,
  );
  out.writeln('');
  out.writeln('FUZZY-CANDIDATE notes for MISSING palikas (review-only):');
  for (final l in fuzzyNotes) {
    out.writeln(l);
  }

  // ---- Adjudications (human input, optional this run) ------------------------------------
  final adjFile = File('data/_stage/adjudications.json');
  if (adjFile.existsSync()) {
    final adj = jsonDecode(adjFile.readAsStringSync()) as Map<String, dynamic>;
    final decisions = (adj['decisions'] as List).length;
    out.writeln('');
    out.writeln('=' * 78);
    out.writeln('DECISIONS-APPLIED (from data/_stage/adjudications.json)');
    out.writeln('  decisions recorded: $decisions');
    final byBasis = <String, int>{};
    for (final d in adj['decisions'] as List) {
      final b = (d as Map)['basis'] as String? ?? '?';
      byBasis[b] = (byBasis[b] ?? 0) + 1;
    }
    for (final e in byBasis.entries) {
      out.writeln('  ${e.key}: ${e.value}');
    }
  } else {
    out.writeln('');
    out.writeln('No adjudications.json yet — write decisions from this '
        'worksheet, then re-run to render DECISIONS-APPLIED.');
  }

  // ---- Write outputs --------------------------------------------------------------------------
  Directory('data/_stage').createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  File('data/_stage/merge_candidates.json').writeAsStringSync(
    encoder.convert({
      'provenance': {
        'generated': DateTime.now().toUtc().toIso8601String(),
        'tool': 'tool/merge/match.dart',
        'inputs': [
          'data/nepal_local_levels.json',
          'data/_raw/abinrimal/local_levels.json',
          'data/_raw/abinrimal/districts.json',
          'data/_raw/local-states-nepal/dataset_municipalities_en.json',
          'data/_raw/local-states-nepal/dataset_municipalities_np.json',
          'data/_raw/local-states-nepal/dataset_districts_en.json',
          'data/_raw/nepali-geo-pro-max/src_data_local-units.ts',
          'data/_raw/cbs-codes/cbs_local_bodies.csv',
          'data/_stage/nso_codes.json',
        ],
        'rule': 'only EXACT flat-key matches vote; geo-pro-max never votes.',
      },
      'counts': {
        'provinces': provCount,
        'districts': distCount,
        'palikas': palikaCount,
        'nameNe': statusCounts,
        'wards': {
          'carried': wardCarried,
          'missing': wardMissing,
          'sum': wardSum,
        },
        'codes': {'verified': codeVerified, 'unverified': codeUnverified},
      },
      'candidates': candidates,
    }),
  );

  // REVIEW.md is the human worksheet: header + the same body.
  final review = StringBuffer();
  review.writeln('# REVIEW — merge adjudication worksheet (Step 3)');
  review.writeln();
  review
      .writeln('Generated by `dart run tool/merge/match.dart`. Do not edit by');
  review
      .writeln('hand: write decisions to `data/_stage/adjudications.json` and');
  review.writeln(
      're-run to render DECISIONS-APPLIED. Raw: `doc/_inventory-raw.txt`,');
  review.writeln('`doc/_verify-codes-raw.txt`.');
  review.write(out.toString());
  File('doc/REVIEW.md').writeAsStringSync(review.toString());

  stdout.write(out.toString());
}
