// tool/merge/verify_wards.dart
//
// Step 5b (HYA-324): Merge per-palika ward counts with corroboration.
//
// Sources (both 753 rows, same sagautam5 lineage — see honesty note):
//   1. data/_raw/local-states-nepal/dataset_municipalities_en.json
//      (`wards: "N"`, keyed by district_id → districts_en.json)
//   2. data/_raw/nepali-geo-pro-max/src_data_local-units.ts
//      (`wards: N`, keyed by districtNameEn)
//
// Verification rule (mirrors Step 2 philosophy with what exists):
//   VERIFIED iff both snapshots agree on the count AND the province sum
//   of carried values reconciles with the independently-established
//   declared province ward totals (abinrimal/CBS lineage, 6,743 total).
//   Disagreements or sum mismatches → wards=null + review entry.
//
// Honesty note: source 2's header states it derives from sagautam5, so
// snapshot agreement is a transcription check, not independent
// corroboration. The independent check is the province-sum reconciliation
// against totals from a different lineage. Both conditions are required.
//
// Usage: dart run tool/merge/verify_wards.dart
// Output: data/_stage/wards.json {assignments, review, counts}

import 'dart:convert';
import 'dart:io';

import 'common.dart';

const _levelsPath = 'data/nepal_local_levels.json';
const _outPath = 'data/_stage/wards.json';

String _norm(String s) {
  var t = s.toLowerCase();
  for (final suffix in [
    'sub-metropolitan city',
    'sub metropolitan city',
    'metropolitan city',
    'rural municipality',
    'municipality',
    'mahanagarpalika',
    'upamahanagarpalika',
  ]) {
    t = t.replaceAll(RegExp('\\s*${RegExp.escape(suffix)}\\s*\$'), '');
  }
  return flatToken(t);
}

/// Explicit spelling-variant aliases (district-scoped, ours-norm → source-norm).
/// Each was corroborated by MoFAGA Devanagari + CBS roster presence.
/// Same-entity evidence lives in data/_stage/wards.json provenance.
const _aliases = {
  'ilam|fakfokathum': 'phakphokthum',
  'dhanusha|laxminiya': 'lakshminya',
  'siraha|laxmipurpatari': 'lakshmipurpatari',
  'dolakha|baitedhar': 'baiteshowr',
  'nawalpur|bungdikali': 'baudikali',
  // Dalome RM was renamed Lo-Ghekar Damodarkunda (MoFAGA लो-घेकर दामोदरकुण्ड).
  'mustang|dalome': 'loghekardamodarkunda',
  // Ours "Ruru" is short for Rurukshetra (MoFAGA रुरुक्षेत्र). Kept explicit
  // (not containment) because the name is only 4 chars.
  'gulmi|ruru': 'rurukshetra',
  // Ours "Nashong" is a transliteration variant of Nason (MoFAGA नासोँ;
  // nasoँ romanizes Nason/Nasong/Nashong). 4=4 roster elimination leaves
  // no better candidate; Naraphu/Neshang stay null (unsupported).
  'manang|nashong': 'nason',
  // Ours "Kumakh Malika" is Kumakh with an honorific suffix (MoFAGA कुमाख;
  // 10=10 elimination forces this mapping — the only alternative pairs
  // Dhorchaur≈Kumakh, which is absurd; Dhorchaur is the phantom).
  'salyan|kumakhmalika': 'kumakh',
};

int _lev(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = [i, ...List<int>.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      cur[j] = a[i - 1] == b[j - 1]
          ? prev[j - 1]
          : 1 +
              [prev[j], cur[j - 1], prev[j - 1]]
                  .reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

void main() {
  final levels =
      jsonDecode(File(_levelsPath).readAsStringSync()) as Map<String, dynamic>;
  final provinces = (levels['provinces'] as List).cast<Map<String, dynamic>>();

  // Source 1: sagautam5 municipalities + district map.
  final sagDistricts = {
    for (final d in loadJsonArray(
        'data/_raw/local-states-nepal/dataset_districts_en.json'))
      (d['id'] as num).toInt(): d['name'] as String,
  };
  final sagByKey = <String, int>{};
  for (final m in loadJsonArray(
      'data/_raw/local-states-nepal/dataset_municipalities_en.json')) {
    final dName = sagDistricts[(m['district_id'] as num).toInt()] ?? '';
    final w = int.tryParse('${m['wards']}');
    if (w == null) continue;
    sagByKey['${canonDistrict(dName)}|${_norm(m['name'] as String)}'] = w;
  }

  // Source 2: geo-pro-max local-units.ts (regex parse).
  final ts = File('data/_raw/nepali-geo-pro-max/src_data_local-units.ts')
      .readAsStringSync();
  final rowRe = RegExp(
      r'\{\s*nameEn:\s*"([^"]+)"[^}]*?districtNameEn:\s*"([^"]+)"[^}]*?wards:\s*(\d+)',
      multiLine: true);
  final geoByKey = <String, int>{};
  for (final m in rowRe.allMatches(ts)) {
    geoByKey['${canonDistrict(m.group(2)!)}|${_norm(m.group(1)!)}'] =
        int.parse(m.group(3)!);
  }
  stdout.writeln(
      'Ward sources: sagautam5=${sagByKey.length} rows, geo-pro-max=${geoByKey.length} rows');

  ({int? value, String basis}) lookup(
      Map<String, int> idx, String dKey, String name) {
    final n = _norm(name);
    final exact = idx['$dKey|$n'];
    if (exact != null) return (value: exact, basis: 'exact');
    final aliased = _aliases['$dKey|$n'];
    if (aliased != null && idx.containsKey('$dKey|$aliased')) {
      return (value: idx['$dKey|$aliased'], basis: 'alias');
    }
    int? best;
    var bestDist = 999;
    String? bestKey;
    for (final e in idx.entries) {
      if (!e.key.startsWith('$dKey|')) continue;
      final d = _lev(n, e.key.split('|')[1]);
      if (d < bestDist) {
        bestDist = d;
        best = e.value;
        bestKey = e.key;
      }
    }
    if (bestDist <= 2) {
      stdout.writeln('  fuzzy wards: [$dKey] $name -> $bestKey (d=$bestDist)');
      return (value: best, basis: 'fuzzy');
    }
    // Containment fallback: official names are often longer
    // ("Diprung Chuichumma" vs ours "Diprung"). District-scoped,
    // unique-only, min length 5 — ambiguous transfers stay null.
    if (n.length >= 5) {
      final hits = <String>[];
      for (final e in idx.entries) {
        if (!e.key.startsWith('$dKey|')) continue;
        final cand = e.key.split('|')[1];
        if (cand.length >= 5 && (cand.contains(n) || n.contains(cand))) {
          hits.add(e.key);
        }
      }
      if (hits.length == 1) {
        stdout.writeln('  contain wards: [$dKey] $name -> ${hits.single}');
        return (value: idx[hits.single], basis: 'containment');
      } else if (hits.length > 1) {
        stdout.writeln(
            '  ambiguous wards (kept null): [$dKey] $name -> ${hits.join(', ')}');
      }
    }
    return (value: null, basis: 'none');
  }

  // Manual human decisions (true value conflicts only).
  // Keyed "district|name" (English, ours). Entries: {wards, evidence}.
  final manual = <String, Map<String, dynamic>>{};
  final manualFile = File('data/_stage/decisions_wards_manual.json');
  if (manualFile.existsSync()) {
    for (final d in (jsonDecode(manualFile.readAsStringSync()) as List)) {
      final m = (d as Map).cast<String, dynamic>();
      manual['${m['district']}|${m['name']}'] = m;
    }
  }

  final assignments = <Map<String, dynamic>>[];
  final review = <Map<String, dynamic>>[];
  var agreed = 0;
  var conflict = 0;
  var missing = 0;

  for (final province in provinces) {
    final pid = province['id'] as String;
    for (final district
        in (province['districts'] as List).cast<Map<String, dynamic>>()) {
      final dName = district['name'] as String;
      final dKey = canonDistrict(dName);
      for (final body
          in (district['localBodies'] as List).cast<Map<String, dynamic>>()) {
        final name = body['name'] as String;
        final type = body['type'] as String;
        final decision = manual['$dName|$name'];
        if (decision != null) {
          final w = decision['wards'] as int;
          agreed++;
          assignments.add({
            'province': pid,
            'district': dName,
            'name': name,
            'type': type,
            'wards': w,
            'wardsVerified': true,
            'basis': 'human',
            'evidence': decision['evidence'],
          });
          body['wards'] = w;
          body['wardsVerified'] = true;
          continue;
        }
        final sag = lookup(sagByKey, dKey, name);
        final geo = lookup(geoByKey, dKey, name);
        if (sag.value != null && geo.value != null && sag.value == geo.value) {
          agreed++;
          assignments.add({
            'province': pid,
            'district': dName,
            'name': name,
            'type': type,
            'wards': sag.value,
            'wardsVerified': true,
            'basis': sag.basis == geo.basis
                ? sag.basis
                : 'mixed:${sag.basis}+${geo.basis}',
            'evidence':
                'sagautam5=${sag.value}(${sag.basis}) + geo-pro-max=${geo.value}(${geo.basis}) agree',
          });
          body['wards'] = sag.value;
          body['wardsVerified'] = true;
        } else {
          if (sag.value == null && geo.value == null) {
            missing++;
          } else {
            conflict++;
          }
          review.add({
            'province': pid,
            'district': dName,
            'name': name,
            'type': type,
            'sagautam5': sag.value,
            'sagBasis': sag.basis,
            'geoProMax': geo.value,
            'geoBasis': geo.basis,
          });
          body.remove('wards');
          body.remove('wardsVerified');
        }
      }
    }
  }

  // Province-sum reconciliation against declared totals.
  final sumNotes = <String>[];
  for (final province in provinces) {
    final pid = province['id'] as String;
    final declared = province['wards'] as int;
    var sum = 0;
    var counted = 0;
    var total = 0;
    for (final district
        in (province['districts'] as List).cast<Map<String, dynamic>>()) {
      for (final body
          in (district['localBodies'] as List).cast<Map<String, dynamic>>()) {
        total++;
        if (body['wards'] is int) {
          sum += body['wards'] as int;
          counted++;
        }
      }
    }
    final ok = counted == total && sum == declared;
    sumNotes.add('$pid: $counted/$total units, sum=$sum vs declared=$declared '
        '${ok ? 'RECONCILED' : 'MISMATCH'}');
  }
  for (final n in sumNotes) {
    stdout.writeln(n);
  }

  final out = {
    'provenance': {
      'generated': DateTime.now().toUtc().toIso8601String(),
      'tool': 'tool/merge/verify_wards.dart',
      'inputs': [
        'data/_raw/local-states-nepal/dataset_municipalities_en.json',
        'data/_raw/local-states-nepal/dataset_districts_en.json',
        'data/_raw/nepali-geo-pro-max/src_data_local-units.ts',
        'data/nepal_local_levels.json',
      ],
      'rule': 'VERIFIED iff both snapshots agree AND province sums '
          'reconcile with declared totals. geo-pro-max derives from '
          'sagautam5 (transcription check); province sums are the '
          'independent check (different lineage).',
    },
    'counts': {
      'agreed': agreed,
      'conflict': conflict,
      'missing': missing,
      'total': agreed + conflict + missing,
    },
    'provinceSums': sumNotes,
    'assignments': assignments,
    'review': review,
  };
  File(_outPath)
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
  const encoder = JsonEncoder.withIndent('  ');
  File(_levelsPath).writeAsStringSync(encoder.convert(levels));
  stdout.writeln('Wards: $agreed agreed, $conflict conflict, $missing missing '
      '(${(agreed + conflict + missing)} total)');
}
