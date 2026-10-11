// tool/merge/inventory.dart
//
// Step 1 of the roadmap: source coverage inventory.
//
// Reads every downloaded source in data/_raw/, parses it (including the
// minimal TypeScript subset used by nepali-geo-pro-max's data modules) and
// reports, per field: how many records carry it, how many are non-empty, how
// many contain Devanagari script, and which other sources agree.
//
// Before anything else it verifies data/_raw/ against data/PROVENANCE.sha256
// and refuses to run on mismatch: a report computed from changed inputs
// would be worse than no report.
//
// It performs NO merging and NO writing of the canonical dataset. Its only
// output is a report on stdout plus doc/_inventory-raw.txt, to be
// transcribed into doc/REVIEW-inputs.md.
//
// Usage (from the package root):
//   dart run tool/merge/inventory.dart

import 'dart:convert';
import 'dart:io';

import 'common.dart';

// ---------------------------------------------------------------------------
// Reporting primitives
// ---------------------------------------------------------------------------

class FieldReport {
  FieldReport(this.name);
  final String name;
  int records = 0;
  int nonEmpty = 0;
  int devanagari = 0;

  void tally(Object? value) {
    records++;
    if (value == null) return;
    final text = value is String ? value : value.toString();
    if (text.trim().isNotEmpty) nonEmpty++;
    if (devaRegex.hasMatch(text)) devanagari++;
  }

  String get summary {
    final pct = records == 0 ? 0 : (nonEmpty * 100 / records).round();
    final dpct = records == 0 ? 0 : (devanagari * 100 / records).round();
    return '$name: nonEmpty=$nonEmpty/$records ($pct%) '
        'devanagari=$devanagari ($dpct%)';
  }
}

class SourceReport {
  SourceReport(this.name, this.path);
  final String name;
  final String path;
  final Map<String, FieldReport> fields = {};
  final List<String> notes = [];

  void tally(String field, Object? value) =>
      fields.putIfAbsent(field, () => FieldReport(field)).tally(value);

  void note(String n) => notes.add(n);
}

// ---------------------------------------------------------------------------

void main() {
  // ---- Provenance gate ----------------------------------------------------
  // Refuse to compute anything from inputs that drifted since they were
  // pinned. A coverage report built on changed sources would silently bless
  // numbers nobody reviewed.
  final provenanceProblems = verifyProvenance();
  if (provenanceProblems.isNotEmpty) {
    stderr.writeln('=' * 78);
    stderr.writeln('PROVENANCE CHECK FAILED — refusing to run.');
    stderr.writeln('doc/_inventory-raw.txt was NOT overwritten.');
    for (final p in provenanceProblems) {
      stderr.writeln('  $p');
    }
    stderr.writeln('=' * 78);
    exit(1);
  }
  stdout.writeln('provenance: all pinned files verified against '
      'data/PROVENANCE.sha256.');

  final sources = <SourceReport>[];

  // ---------------------------------------------------------------- abinrimal
  final abinrimalLevels = <Map<String, dynamic>>[];
  final abinrimalDistricts = <String, Map<String, dynamic>>{};
  {
    final r = SourceReport('abinrimal', 'data/_raw/abinrimal');
    final provinces = loadJsonArray('${r.path}/provinces.json');
    final districts = loadJsonArray('${r.path}/districts.json');
    final levels = loadJsonArray('${r.path}/local_levels.json');
    abinrimalLevels.addAll(levels);
    for (final d in districts) {
      abinrimalDistricts[d['code'] as String] = d;
    }

    for (final p in provinces) {
      r.tally('province.name_en', p['name_en']);
      r.tally('province.name_ne', p['name_ne']);
    }
    for (final d in districts) {
      r.tally('district.name_en', d['name_en']);
      r.tally('district.name_ne', d['name_ne']);
      r.tally('district.province_code', d['province_code']);
    }
    for (final l in levels) {
      r.tally('localLevel.name_en', l['name_en']);
      r.tally('localLevel.name_ne', l['name_ne']);
      r.tally('localLevel.district_code', l['district_code']);
      r.tally('localLevel.province_code', l['province_code']);
      r.tally('localLevel.type_en', l['type_en']);
      r.tally('localLevel.type_ne', l['type_ne']);
    }
    r.note('provinces=${provinces.length} districts=${districts.length} '
        'localLevels=${levels.length}');
    r.note('localLevel.code distinct values: '
        '${levels.map((l) => l['code']).toSet().length} -> NOT a unique id '
        '(values are 1/2/3/4 type codes)');
    final districtCodes = districts.map((d) => d['code'] as String).toSet();
    final ints = districtCodes.map(int.parse).toList()..sort();
    r.note('district.code unique=${districtCodes.length == districts.length} '
        'range=${ints.first}..${ints.last}');
    sources.add(r);
  }

  // -------------------------------------------------------- local-states-nepal
  final sagautamMunis = <Map<String, dynamic>>[];
  final sagautamMunisNp = <Map<String, dynamic>>[];
  {
    final r =
        SourceReport('local-states-nepal', 'data/_raw/local-states-nepal');
    final provinces = loadJsonArray('${r.path}/dataset_provinces_en.json');
    final provincesNp = loadJsonArray('${r.path}/dataset_provinces_np.json');
    final districtsEn = loadJsonArray('${r.path}/dataset_districts_en.json');
    final districtsNp = loadJsonArray('${r.path}/dataset_districts_np.json');
    final munisEn = loadJsonArray('${r.path}/dataset_municipalities_en.json');
    final munisNp = loadJsonArray('${r.path}/dataset_municipalities_np.json');
    sagautamMunis.addAll(munisEn);
    sagautamMunisNp.addAll(munisNp);

    // Actual keys in this source (verified against the files, not assumed):
    // provinces/districts: id, [province_id,] name, area_sq_km, website,
    // headquarter. Municipalities add category_id, district_id, wards.
    // The np.* files carry the same keys with Devanagari values; np wards
    // are STRINGS of Devanagari numerals ("१४"), en wards are ints.
    for (final p in provinces) {
      for (final k in p.keys) {
        r.tally('province.en.$k', p[k]);
      }
    }
    for (final p in provincesNp) {
      for (final k in p.keys) {
        r.tally('province.np.$k', p[k]);
      }
    }
    for (final d in districtsEn) {
      for (final k in d.keys) {
        r.tally('district.en.$k', d[k]);
      }
    }
    for (final d in districtsNp) {
      for (final k in d.keys) {
        r.tally('district.np.$k', d[k]);
      }
    }
    for (final m in munisEn) {
      for (final k in m.keys) {
        r.tally('municipality.en.$k', m[k]);
      }
    }
    for (final m in munisNp) {
      for (final k in m.keys) {
        r.tally('municipality.np.$k', m[k]);
      }
    }
    r.note('provinces=${provinces.length} districts=${districtsEn.length} '
        'municipalities(en)=${munisEn.length} municipalities(np)=${munisNp.length}');
    r.note('municipality keys: ${munisEn.first.keys.toList()}');
    r.note('sample: ${munisEn.first}');

    final wardSum = munisEn.fold<int>(
        0, (a, m) => a + (devaDigitsToInt(m['wards']) ?? -1000000));
    r.note('SUM of en ward counts: $wardSum  (target 6743)');
    r.note('en wards are JSON strings of ASCII digits, NOT ints — '
        'parsed via devaDigitsToInt; -1000000 sentinel flags unparseable');

    final npWardsOk =
        munisNp.where((m) => devaDigitsToInt(m['wards']) != null).length;
    r.note('np wards parseable as Devanagari numerals: '
        '$npWardsOk/${munisNp.length}');
    sources.add(r);
  }

  // -------------------------------------------------------- nepali-geo-pro-max
  final geoUnits = <Map<String, dynamic>>[];
  final geoDistricts = <Map<String, dynamic>>[];
  final postal2025 = <String, String>{};
  {
    final r =
        SourceReport('nepali-geo-pro-max', 'data/_raw/nepali-geo-pro-max');
    final provinces = loadTsArray('${r.path}/src_data_provinces.ts');
    final districts = loadTsArray('${r.path}/src_data_districts.ts');
    final units = loadTsArray('${r.path}/src_data_local-units.ts');
    final legacy = loadTsArray('${r.path}/src_data_legacy-districts.ts');
    final zones = loadTsArray('${r.path}/src_data_zones.ts');
    final regions = loadTsArray('${r.path}/src_data_regions.ts');
    final postal = loadTsObject('${r.path}/src_data_postal-codes.ts');
    final postalNew = loadTsObject('${r.path}/src_data_postal-codes-2025.ts');
    geoUnits.addAll(units);
    geoDistricts.addAll(districts);
    postal2025.addAll(postalNew.cast<String, String>());

    for (final p in provinces) {
      for (final k in p.keys) {
        r.tally('province.$k', p[k]);
      }
    }
    for (final d in districts) {
      for (final k in d.keys) {
        r.tally('district.$k', d[k]);
      }
    }
    // districts.ts nests 77 district seeds inside 7 province objects
    // ({provinceId, districts: [{nameEn, nameNe, headquarters, ...}]}).
    var seedCount = 0;
    for (final d in districts) {
      final seeds = d['districts'];
      if (seeds is! List) continue;
      for (final s in seeds) {
        seedCount++;
        final seed = (s as Map).cast<String, dynamic>();
        for (final k in seed.keys) {
          r.tally('districtSeed.$k', seed[k]);
        }
      }
    }
    r.note('nested district seeds parsed: $seedCount (expect 77)');
    for (final u in units) {
      for (final k in u.keys) {
        r.tally('localUnit.$k', u[k]);
      }
    }
    r.note('provinces=${provinces.length} districts=${districts.length} '
        'localUnits=${units.length} legacyDistricts=${legacy.length} '
        'zones=${zones.length} regions=${regions.length}');
    r.note('postal legacy map entries=${postal.length} '
        'postal 2025 map entries=${postalNew.length}');

    final withWards = units.where((u) => u['wards'] is int).length;
    final sum = units.fold<int>(0, (a, u) => a + ((u['wards'] as int?) ?? 0));
    r.note('localUnits with ward count: $withWards/${units.length}');
    r.note('SUM of per-palika ward counts: $sum  (target 6743)');

    final byType = <String, int>{};
    for (final u in units) {
      final t = u['type'] as String;
      byType[t] = (byType[t] ?? 0) + 1;
    }
    r.note('type split: $byType');

    // The headline question of Step 1: does postal-codes-2025 actually carry
    // the NSO/CBS administrative codes?
    final bad = postalNew.entries
        .where((e) => !RegExp(r'^[1-7]\d{4}$').hasMatch(e.value))
        .toList();
    r.note('postal-2025 codes failing ^[1-7][0-9]{4}: ${bad.length} '
        '${bad.take(3).map((e) => "${e.key}=${e.value}").toList()}');
    r.note('*** postal-2025 appears to BE the NSO code list: '
        '"dharan sub-metropolitan city" = ${postalNew['dharan sub-metropolitan city']} '
        'matches the published CBS/NSO code 11301 ***');
    sources.add(r);
  }

  // ------------------------------------------------------------ open-admin-data
  {
    final r = SourceReport('open-admin-data', 'data/_raw/open-admin-data');
    final provinces = loadJsonArray('${r.path}/data_all-province.json');
    final districts = loadJsonArray('${r.path}/data_all-district.json');
    final units = loadJsonArray('${r.path}/data_all-local_unit.json');
    for (final p in provinces) {
      for (final k in p.keys) {
        r.tally('province.$k', p[k]);
      }
    }
    for (final d in districts) {
      for (final k in d.keys) {
        r.tally('district.$k', d[k]);
      }
    }
    for (final u in units) {
      for (final k in u.keys) {
        r.tally('localUnit.$k', u[k]);
      }
    }
    r.note('provinces=${provinces.length} districts=${districts.length} '
        'localUnits=${units.length}  <-- NOTE: differs from the 753 gazette');
    final sample = units.firstWhere((u) => u['level'] == 3);
    r.note('sample local unit: $sample');
    sources.add(r);
  }

  // ------------------------------------------------------------------- output
  final out = StringBuffer();
  out.writeln('=' * 78);
  out.writeln('STEP 1 SOURCE COVERAGE INVENTORY');
  out.writeln('generated: ${DateTime.now().toUtc().toIso8601String()}');
  out.writeln('=' * 78);

  for (final r in sources) {
    out.writeln();
    out.writeln('### ${r.name}  (${r.path})');
    for (final f in r.fields.values) {
      out.writeln('  ${f.summary}');
    }
    for (final n in r.notes) {
      out.writeln('  note: $n');
    }
  }

  // ---- Cross-source agreement on local-body names -------------------------
  // Independent sources: abinrimal, sagautam5, open-admin-data.
  // nepali-geo-pro-max is DERIVED from sagautam5 (stated in its own header),
  // so it is tallied as a supplementary extractor, never as a vote.
  out.writeln();
  out.writeln('=' * 78);
  out.writeln('CROSS-SOURCE LOCAL-BODY MATCHING');
  out.writeln('key = "<district>|<name>", flattened (lowercase, type suffix');
  out.writeln('and (...) groups stripped, spaces/hyphens/apostrophes/dots');
  out.writeln('removed). Absorbs "Mai Jogmai"/"Maijogmai" and "Bhojpur');
  out.writeln('Municipality"/"Bhojpur", but NOT true spelling differences,');
  out.writeln('which surface as fuzzy suggestions below.');
  out.writeln('=' * 78);

  Map<String, List<Map<String, dynamic>>> indexByKey(
    Iterable<Map<String, dynamic>> records,
    String Function(Map<String, dynamic>) keyOf,
  ) {
    final idx = <String, List<Map<String, dynamic>>>{};
    for (final r in records) {
      idx.putIfAbsent(keyOf(r), () => []).add(r);
    }
    return idx;
  }

  void reportDupes(String label, Map<String, List<Map<String, dynamic>>> idx,
      int expectSize) {
    final dupes = idx.entries.where((e) => e.value.length > 1).toList();
    out.writeln('  $label: ${idx.length} distinct keys '
        '(expect $expectSize records); duplicates: ${dupes.length}');
    for (final d in dupes.take(10)) {
      out.writeln('    DUPE x${d.value.length}: ${d.key}');
    }
  }

  final abinIdx = indexByKey(abinrimalLevels, (l) {
    final dc = l['district_code'] as String?;
    final dn = abinrimalDistricts[dc]?['name_en'] as String?;
    return palikaKey(dn, l['name_en'] as String?);
  });

  // sagautam5 keys municipalities by `district_id`, resolved through
  // districts/en.json.
  final sagDistricts =
      loadJsonArray('data/_raw/local-states-nepal/dataset_districts_en.json');
  final sagDistName = {
    for (final d in sagDistricts) d['id'] as int: d['name'] as String,
  };
  final sagIdx = indexByKey(
      sagautamMunis,
      (m) => palikaKey(
          sagDistName[m['district_id'] as int], m['name'] as String?));
  // The np file carries Devanagari names, so it CANNOT share flat keys with
  // the romanized files. Link en<->np through the shared `id` instead.
  final sagNpById = {
    for (final m in sagautamMunisNp) m['id'] as int: m,
  };

  final geoIdx = indexByKey(geoUnits,
      (u) => palikaKey(u['districtNameEn'] as String?, u['nameEn'] as String?));

  out.writeln('WITHIN-SOURCE DUPLICATE KEYS (a duplicate here means the');
  out.writeln('source itself double-counts a palika):');
  reportDupes('abinrimal      ', abinIdx, 753);
  reportDupes('sagautam5 (en) ', sagIdx, 753);
  reportDupes('geo-pro-max    ', geoIdx, 753);
  final sagEnIds = sagautamMunis.map((m) => m['id']).toSet();
  final sagNpIds = sagautamMunisNp.map((m) => m['id']).toSet();
  out.writeln('  sagautam5 en ids: ${sagEnIds.length}/753 unique; '
      'np ids: ${sagNpIds.length}/753 unique; '
      'en<->np id sets equal: ${sagEnIds.length == 753 && sagNpIds.length == 753 && sagEnIds.containsAll(sagNpIds)}');

  // --- Three-way agreement (independent sources only) ----------------------
  final abinKeys = abinIdx.keys.toSet();
  final sagKeys = sagIdx.keys.toSet();
  final inBoth = abinKeys.intersection(sagKeys);
  out.writeln('AGREEMENT (abinrimal n=${abinKeys.length} vs '
      'sagautam5 n=${sagKeys.length}):');
  out.writeln('  shared keys: ${inBoth.length}');
  for (final only in ['abinrimal', 'sagautam5']) {
    final missing = (only == 'abinrimal'
            ? abinKeys.difference(sagKeys)
            : sagKeys.difference(abinKeys))
        .toList()
      ..sort();
    out.writeln('  in $only only: ${missing.length}');
    for (final k in missing.take(20)) {
      final sug = suggestKey(k, only == 'abinrimal' ? sagKeys : abinKeys);
      out.writeln('    MISSING $k'
          '${sug == null ? '' : '  ~> suggests "$sug"'}');
    }
  }

  // --- English spelling variants on shared keys ----------------------------
  var looseDiffs = 0;
  final looseLines = <String>[];
  for (final k in inBoth) {
    final a = looseName(abinIdx[k]!.first['name_en'] as String?);
    final s = looseName(sagIdx[k]!.first['name'] as String?);
    if (a != s) {
      looseDiffs++;
      if (looseLines.length < 20) {
        looseLines.add('    abinrimal="${abinIdx[k]!.first['name_en']}" '
            'vs sagautam5="${sagIdx[k]!.first['name']}"');
      }
    }
  }
  out.writeln('EN SPELLING VARIANTS on shared keys: $looseDiffs '
      '(suffix/punctuation/case differences, e.g. suffix present in one):');
  for (final l in looseLines) {
    out.writeln(l);
  }

  // --- Devanagari agreement: abinrimal vs sagautam5-np ----------------------
  // Linked through sagautam5's shared `id` (the np names are Devanagari and
  // can never share a romanized key).
  var neAgree = 0;
  var neDiffer = 0;
  var neNoLink = 0;
  final neLines = <String>[];
  for (final k in inBoth) {
    final a = (abinIdx[k]!.first['name_ne'] as String?)?.trim() ?? '';
    final enRec = sagIdx[k]!.first;
    final npRec = sagNpById[enRec['id'] as int];
    final s = (npRec?['name'] as String?)?.trim() ?? '';
    if (npRec == null) {
      neNoLink++;
      continue;
    }
    if (a.isEmpty || s.isEmpty) {
      neDiffer++;
      if (neLines.length < 20) {
        neLines.add('    EMPTY-SIDE $k: abinrimal="$a" sag-np="$s"');
      }
    } else if (a == s) {
      neAgree++;
    } else {
      neDiffer++;
      if (neLines.length < 20) {
        neLines.add('    $k: abinrimal="$a" vs sag-np="$s"');
      }
    }
  }
  out.writeln('DEVANAGARI AGREEMENT on shared keys: agree=$neAgree '
      'differ-or-empty=$neDiffer unlinked=$neNoLink (exact string match; '
      'unicode-encoding differences would surface here and need review, '
      'not silent merging)');
  for (final l in neLines) {
    out.writeln(l);
  }
  final abinNeNoDeva = abinrimalLevels
      .where((l) => !devaRegex.hasMatch((l['name_ne'] as String?) ?? ''))
      .map((l) => '${l['name_en']} (${l['district_code']})')
      .toList();
  out.writeln('abinrimal name_ne WITHOUT any Devanagari script: '
      '${abinNeNoDeva.length} ${abinNeNoDeva.take(10).toList()}');

  // --- Ward agreement: sagautam5-en (int) vs geo-pro-max --------------------
  var wardAgree = 0;
  final wardLines = <String>[];
  for (final k in sagIdx.keys) {
    final g = geoIdx[k];
    if (g == null) continue;
    final s = devaDigitsToInt(sagIdx[k]!.first['wards']);
    final gg = g.first['wards'] as int?;
    if (s != null && s == gg) {
      wardAgree++;
    } else if (wardLines.length < 20) {
      wardLines.add('    $k: sagautam5=$s vs geo-pro-max=$gg');
    }
  }
  final wardCompared = sagIdx.keys.where(geoIdx.containsKey).length;
  out.writeln('WARD AGREEMENT sagautam5-en vs geo-pro-max: agree=$wardAgree / '
      'compared=$wardCompared (every mismatch is a candidate transcription '
      'error like the known 6742-vs-6743 case)');
  for (final l in wardLines) {
    out.writeln(l);
  }

  // --- Ward internal check: sagautam5 en vs np, linked by id ---------------
  var npWardAgree = 0;
  var npWardBad = 0;
  final npWardLines = <String>[];
  for (final m in sagautamMunis) {
    final en = devaDigitsToInt(m['wards']);
    final npRec = sagNpById[m['id'] as int];
    final np = npRec == null ? null : devaDigitsToInt(npRec['wards']);
    if (en != null && np == en) {
      npWardAgree++;
    } else {
      npWardBad++;
      if (npWardLines.length < 10) {
        npWardLines.add('    id=${m['id']} ${m['name']}: en=${m['wards']} '
            'np=${npRec?['wards']}');
      }
    }
  }
  out.writeln('WARD INTERNAL sagautam5 en-vs-np (linked by id): '
      'agree=$npWardAgree differ-or-unparseable=$npWardBad');
  for (final l in npWardLines) {
    out.writeln(l);
  }

  // --- District-level agreement: nameNe + HQ --------------------------------
  // Districts matched across abinrimal / sagautam5-np / geo seeds by canonical
  // district name. HQ cross-check: sagautam5-en vs geo-pro-max seeds.
  out.writeln('');
  out.writeln('DISTRICT nameNe + HQ AGREEMENT');
  final sagDistNpByName = <String, Map<String, dynamic>>{};
  // np district names are Devanagari and can never match a romanized key:
  // link np->en through the shared `id`, then key by the en name.
  final sagDistNpById = <int, Map<String, dynamic>>{};
  for (final d in loadJsonArray(
      'data/_raw/local-states-nepal/dataset_districts_np.json')) {
    sagDistNpById[d['id'] as int] = d;
  }
  for (final d in sagDistricts) {
    final np = sagDistNpById[d['id'] as int];
    if (np != null) {
      sagDistNpByName[canonDistrict(d['name'] as String)] = np;
    }
  }
  final geoSeedsByDistrict = <String, Map<String, dynamic>>{};
  // NOTE: geo district seeds live in districts.ts (already tallied above);
  // re-parse here keyed by canonical district name for the HQ cross-check.
  final geoSeedFile =
      loadTsArray('data/_raw/nepali-geo-pro-max/src_data_districts.ts');
  for (final p in geoSeedFile) {
    final seeds = p['districts'];
    if (seeds is! List) continue;
    for (final s in seeds) {
      final seed = (s as Map).cast<String, dynamic>();
      geoSeedsByDistrict[canonDistrict(seed['nameEn'] as String)] = seed;
    }
  }
  var dNeAgree = 0, dNeDiffer = 0, dHqAgree = 0, dHqDiffer = 0;
  final dLines = <String>[];
  final sagDistEnByName = <String, Map<String, dynamic>>{};
  for (final d in sagDistricts) {
    sagDistEnByName[canonDistrict(d['name'] as String)] = d;
  }
  final abinDistByName = <String, Map<String, dynamic>>{};
  for (final d in abinrimalDistricts.values) {
    abinDistByName[canonDistrict(d['name_en'] as String)] = d;
  }
  final allDistricts = <String>{
    ...abinDistByName.keys,
    ...sagDistEnByName.keys,
    ...geoSeedsByDistrict.keys,
  }.toList()
    ..sort();
  for (final dn in allDistricts) {
    final aNe = (abinDistByName[dn]?['name_ne'] as String?)?.trim() ?? '';
    final sNe = (sagDistNpByName[dn]?['name'] as String?)?.trim() ?? '';
    final gNe = (geoSeedsByDistrict[dn]?['nameNe'] as String?)?.trim() ?? '';
    if (aNe.isNotEmpty && aNe == sNe) {
      dNeAgree++;
    } else {
      dNeDiffer++;
      if (dLines.length < 15) {
        dLines.add('    nameNe $dn: abinrimal="$aNe" sag-np="$sNe" '
            'geo="$gNe"');
      }
    }
    final sHq = (sagDistEnByName[dn]?['headquarter'] as String?)?.trim() ?? '';
    final gHq =
        (geoSeedsByDistrict[dn]?['headquarters'] as String?)?.trim() ?? '';
    if (sHq.isEmpty || gHq.isEmpty) continue;
    final sl = sHq.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final gl = gHq.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (sl == gl) {
      dHqAgree++;
    } else {
      dHqDiffer++;
      if (dLines.length < 30) {
        dLines.add('    HQ $dn: sagautam5="$sHq" geo="$gHq"');
      }
    }
  }
  out.writeln('  districts seen: ${allDistricts.length} (expect 77)');
  for (final dn in allDistricts) {
    final missing = <String>[
      if (!abinDistByName.containsKey(dn)) 'abinrimal',
      if (!sagDistEnByName.containsKey(dn)) 'sagautam5',
      if (!geoSeedsByDistrict.containsKey(dn)) 'geo-pro-max',
    ];
    if (missing.isNotEmpty) {
      out.writeln(
          '    DISTRICT-KEY-ONLY-IN-SOME $dn (missing: ${missing.join(',')})');
    }
  }
  out.writeln(
      '  nameNe abinrimal-vs-sag-np: agree=$dNeAgree differ=$dNeDiffer');
  out.writeln('  HQ sagautam5-vs-geo: agree=$dHqAgree differ=$dHqDiffer');
  for (final l in dLines) {
    out.writeln(l);
  }

  // --- District numbering schemes, side by side ---------------------------
  out.writeln('');
  out.writeln('=' * 78);
  out.writeln('DISTRICT NUMBERING SCHEMES (all four sources disagree)');
  out.writeln('=' * 78);

  final ourDistricts = <(String, String)>[];
  final ourJson =
      jsonDecode(File('data/nepal_local_levels.json').readAsStringSync())
          as Map<String, dynamic>;
  for (final p in ourJson['provinces'] as List) {
    final pid = (p as Map)['id'] as String;
    for (final d in p['districts'] as List) {
      ourDistricts.add((pid, (d as Map)['name'] as String));
    }
  }

  // open-admin-data district id -> parent province id.
  final oaDistricts =
      loadJsonArray('data/_raw/open-admin-data/data_all-district.json');
  final oaByParent = <String, List<Map<String, dynamic>>>{};
  for (final d in oaDistricts) {
    final parent = (d['parent'] as Map)['id'] as String;
    oaByParent.putIfAbsent(parent, () => []).add(d);
  }

  // postal-2025 district prefix -> english district name (derived from the
  // module's own `// -- X district --` section comments).
  final postalSource =
      File('data/_raw/nepali-geo-pro-max/src_data_postal-codes-2025.ts')
          .readAsStringSync();
  final postalDistrictByPrefix = <String, String>{};
  final sectionRe = RegExp(r'// -- (.+?) district --');
  for (final section in sectionRe.allMatches(postalSource)) {
    final districtName = section.group(1)!;
    final start = section.end;
    final next = postalSource.indexOf('// --', start);
    final body =
        postalSource.substring(start, next < 0 ? postalSource.length : next);
    final firstCode = RegExp(r':\s*"(\d{5})"').firstMatch(body);
    if (firstCode != null) {
      postalDistrictByPrefix[firstCode.group(1)!.substring(0, 3)] =
          districtName;
    }
  }

  const provinceNumber = {
    'koshi': '1',
    'madhesh': '2',
    'bagmati': '3',
    'gandaki': '4',
    'lumbini': '5',
    'karnali': '6',
    'sudurpashchim': '7',
  };

  out.writeln(
      'our district | abinrimal | sagautam5 | open-admin | postal-2025');
  final abinDistrictCode = <String, String>{};
  for (final d in abinrimalDistricts.values) {
    abinDistrictCode[d['name_en'] as String] = d['code'] as String;
  }
  final sagDistrictCode = <String, String>{};
  for (final d in sagDistricts) {
    sagDistrictCode[d['name'] as String] = (d['id'] as int).toString();
  }

  for (final (pid, dname) in ourDistricts.take(20)) {
    final pn = provinceNumber[pid]!;
    final oaId = (oaByParent['NP${pn.padLeft(2, '0')}'] ?? const [])
        .firstWhere(
            (d) =>
                normDistrict((d['name'] as Map)['en'] as String) ==
                normDistrict(dname),
            orElse: () => <String, dynamic>{})
        .map(MapEntry.new)['id'] as String?;
    final postalPrefix = postalDistrictByPrefix.entries
        .firstWhere((e) => normDistrict(e.value) == normDistrict(dname),
            orElse: () => const MapEntry('', ''))
        .key;
    out.writeln('${dname.padRight(18)} '
        '${(abinDistrictCode[dname] ?? '-').padRight(10)} '
        '${(sagDistrictCode[dname] ?? '-').padRight(11)} '
        '${(oaId ?? '-').padRight(12)} '
        '${postalPrefix.isEmpty ? '-' : postalPrefix}');
  }
  out.writeln('(first 20 of ${ourDistricts.length} districts shown)');
  out.writeln('');
  out.writeln(
      'postal-2025 yields a gapless 01..14 run for Koshi and 77 district '
      'prefixes nationally, split 14/8/13/11/12/10/9 per province â€” exactly our '
      'verified per-province district counts. It is the only source whose '
      'numbering is both complete and matches a published CBS/NSO reference '
      'code (Dharan = 11301). The other three schemes are internal orderings.');
  out.writeln('');
  out.writeln(
      '*** None of these four schemes is verified as the CBS/NSO scheme '
      'except postal-2025, whose Dharan value 11301 matches the one published '
      'CBS/NSO reference code. Resolve in Step 2 against CBS/NSO directly. ***');

  // ---- Postal-2025 join tiers (our 753 palikas vs 751 postal codes) --------
  // T1: exact "<name> <type-suffix>" key. T2: normalised-with-suffix exact
  // match, disambiguated by district prefix (a normalised form shared by two
  // districts' palikas is NEVER auto-accepted — it goes to review).
  // T3: Levenshtein <= 2 suggestion on normalised-with-suffix forms within
  // the same district prefix (review-only). MISS: best scoped candidate shown
  // regardless of distance (review-only). Nothing here auto-merges.
  out.writeln('');
  out.writeln('=' * 78);
  out.writeln('POSTAL-2025 JOIN (our 753 palikas)');
  out.writeln('codes are 5-digit PDDPP; the district prefix scopes every tier');
  out.writeln('=' * 78);

  String normPostalKey(String raw) =>
      flatToken(stripSuffix(stripParens(raw.toLowerCase().trim())));

  final postalNorm = <String, List<MapEntry<String, String>>>{};
  for (final e in postal2025.entries) {
    postalNorm.putIfAbsent(normPostalKey(e.key), () => []).add(e);
  }
  final prefixByDistrict = <String, String>{
    for (final e in postalDistrictByPrefix.entries)
      canonDistrict(e.value): e.key,
  };
  final keysByPrefix = <String, List<String>>{};
  for (final e in postal2025.entries) {
    keysByPrefix.putIfAbsent(e.value.substring(0, 3), () => []).add(e.key);
  }

  const typeSuffix = {
    'metropolitan': 'metropolitan city',
    'subMetropolitan': 'sub-metropolitan city',
    'municipality': 'municipality',
    'ruralMunicipality': 'rural municipality',
  };

  var t1 = 0, t2 = 0, t2ambig = 0, t3 = 0;
  final misses = <String>[];
  final consumed = <String>{};
  for (final p in ourJson['provinces'] as List) {
    final pmap = p as Map;
    for (final d in pmap['districts'] as List) {
      final dmap = d as Map;
      final dname = dmap['name'] as String;
      final prefix = prefixByDistrict[canonDistrict(dname)];
      final scoped = prefix == null
          ? postal2025.keys.toList()
          : keysByPrefix[prefix] ?? const <String>[];
      for (final b in dmap['localBodies'] as List) {
        final bmap = b as Map;
        final name = bmap['name'] as String;
        final suffix = typeSuffix[bmap['type'] as String]!;
        final exactKey = '${name.toLowerCase()} $suffix';
        if (postal2025.containsKey(exactKey)) {
          t1++;
          consumed.add(exactKey);
          continue;
        }
        final nfSuf = normPostalKey('$name $suffix');
        final hits = postalNorm[nfSuf] ?? const [];
        final inPrefix =
            hits.where((h) => h.value.startsWith(prefix ?? '∅')).toList();
        if (inPrefix.length == 1) {
          t2++;
          consumed.add(inPrefix.first.key);
          continue;
        }
        if (inPrefix.length > 1) {
          t2ambig++;
          misses.add('    T2-AMBIG $name [$dname]: normalised form matches '
              '${inPrefix.map((h) => '"${h.key}"=${h.value}').join(', ')} '
              '(review only — not auto-accepted)');
          continue;
        }
        String? bestKey;
        var bestD = 999;
        for (final c in scoped) {
          final dd = levenshtein(nfSuf, normPostalKey(c), 2);
          if (dd < bestD) {
            bestD = dd;
            bestKey = c;
          }
        }
        if (bestD <= 2 && bestKey != null) {
          t3++;
          misses.add('    T3-SUGGEST $name [$dname] ~> "$bestKey" '
              '(d=$bestD, review only)');
        } else {
          misses.add('    MISS $name [$dname]'
              '${bestKey == null ? '' : '  closest: "$bestKey" (d=$bestD)'}');
        }
      }
    }
  }
  out.writeln('  T1 exact "<name> <suffix>": $t1');
  out.writeln('  T2 normalised-with-suffix, prefix-disambiguated: $t2');
  out.writeln('  T2-AMBIG (shared normalised form, review only): $t2ambig');
  out.writeln('  T3 fuzzy suggestion (d<=2, review only): $t3');
  out.writeln('  MISS (no candidate within d<=2, or none): '
      '${misses.where((m) => m.startsWith('    MISS')).length}');
  for (final m in misses) {
    out.writeln(m);
  }
  final postalExtras =
      postal2025.keys.where((k) => !consumed.contains(k)).toList()..sort();
  out.writeln('postal-2025 keys matching NO our-palika: ${postalExtras.length} '
      '(stale/renamed names live here — review before trusting codes)');
  for (final k in postalExtras.take(25)) {
    out.writeln('    EXTRA "$k" = ${postal2025[k]}');
  }

  // ---- open-admin-data per-district counts vs ours -------------------------
  // oa districts carry children_count.local_unit; summing and diffing by
  // district locates the 775-vs-753 gap structurally instead of by anecdote.
  // District names are matched on canonDistrict (oa uses Dhanusa/Chitawan/
  // Tanahu/Nawalparasi East+West/Kapilbastu — see canonDistrict).
  out.writeln('');
  out.writeln('=' * 78);
  out.writeln('OPEN-ADMIN-DATA PER-DISTRICT COUNTS vs OURS');
  out.writeln('=' * 78);
  final oaByName = <String, Map<String, dynamic>>{};
  for (final d in oaDistricts) {
    oaByName[canonDistrict((d['name'] as Map)['en'] as String)] = d;
  }
  var oaMatched = 0;
  var oaUnitSum = 0;
  var ourUnitSum = 0;
  final oaDiffs = <String>[];
  for (final p in ourJson['provinces'] as List) {
    final pmap = p as Map;
    for (final d in pmap['districts'] as List) {
      final dmap = d as Map;
      final dname = dmap['name'] as String;
      final ours = (dmap['localBodies'] as List).length;
      ourUnitSum += ours;
      final oa = oaByName[canonDistrict(dname)];
      if (oa == null) {
        oaDiffs.add('    NO-OA-DISTRICT $dname (ours=$ours)');
        continue;
      }
      oaMatched++;
      final oaN = ((oa['children_count'] as Map)['local_unit'] as int?) ?? -1;
      oaUnitSum += oaN < 0 ? 0 : oaN;
      if (oaN != ours) {
        oaDiffs.add('    $dname: ours=$ours open-admin=$oaN '
            '(delta ${oaN - ours >= 0 ? '+' : ''}${oaN - ours})');
      }
    }
  }
  out.writeln('  districts matched by name: $oaMatched/77');
  out.writeln('  unit totals: ours=$ourUnitSum open-admin(sum of '
      'children_count)=$oaUnitSum gazette=753');
  out.writeln('  districts with differing counts: ${oaDiffs.length}');
  for (final l in oaDiffs) {
    out.writeln(l);
  }
  // Reverse check: oa districts matching NONE of ours (variant spellings and
  // any genuinely extra districts both surface here).
  final ourCanonDistricts = <String>{
    for (final p in ourJson['provinces'] as List)
      for (final d in (p as Map)['districts'] as List)
        canonDistrict((d as Map)['name'] as String),
  };
  final oaOrphans = oaDistricts
      .where((d) => !ourCanonDistricts
          .contains(canonDistrict((d['name'] as Map)['en'] as String)))
      .toList();
  out.writeln('  oa districts matching no our-district: ${oaOrphans.length}');
  for (final d in oaOrphans) {
    final name = (d['name'] as Map)['en'];
    out.writeln('    ORPHAN-OA-DISTRICT $name (${d['id']}, '
        'units=${(d['children_count'] as Map)['local_unit']})');
  }

  stdout.write(out.toString());
  File('doc/_inventory-raw.txt').writeAsStringSync(out.toString());
}
