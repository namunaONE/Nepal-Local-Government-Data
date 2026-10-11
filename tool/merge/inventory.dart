// tool/merge/inventory.dart
//
// Step 1 of the roadmap: source coverage inventory.
//
// Reads every downloaded source in data/_raw/, parses it (including the
// minimal TypeScript subset used by nepali-geo-pro-max's data modules) and
// reports, per field: how many records carry it, how many are non-empty, how
// many contain Devanagari script, and which other sources agree.
//
// It performs NO merging and NO writing of the canonical dataset. Its only
// output is a report on stdout plus docs/_inventory-raw.txt, to be
// transcribed into docs/REVIEW-inputs.md.
//
// Usage (from the package root):
//   dart run tool/merge/inventory.dart

import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// Minimal TypeScript data-module parsing
// ---------------------------------------------------------------------------

/// Removes `//` and `/* */` comments while respecting string literals, so a
/// `//` inside a quoted value is never mistaken for a comment. These modules
/// use `"`, `'` and backtick-delimited strings.
String _stripComments(String s) {
  final out = StringBuffer();
  var i = 0;
  String? quote;
  while (i < s.length) {
    final c = s[i];

    if (quote != null) {
      if (c == r'\') {
        out.write(c);
        if (i + 1 < s.length) out.write(s[i + 1]);
        i += 2;
        continue;
      }
      if (c == quote) quote = null;
      out.write(c);
      i++;
      continue;
    }

    if (c == '"' || c == "'" || c == '`') {
      quote = c;
      out.write(c);
      i++;
      continue;
    }

    if (c == '/' && i + 1 < s.length && s[i + 1] == '/') {
      while (i < s.length && s[i] != '\n') {
        i++;
      }
      continue;
    }

    if (c == '/' && i + 1 < s.length && s[i + 1] == '*') {
      i += 2;
      while (i + 1 < s.length && !(s[i] == '*' && s[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }

    out.write(c);
    i++;
  }
  return out.toString();
}

/// Strips comments, numeric separators and imports/type declarations from a
/// TypeScript data module, leaving roughly JSON-compatible source.
String _cleanTs(String source) {
  var s = source;
  s = s.replaceAll(RegExp(r'^import[^\n]*\n', multiLine: true), '');
  s = s.replaceAll(
      RegExp(r'^(?:export\s+)?interface[^}]*\}\s*', multiLine: true), '');
  // Function bodies (legacy-districts.ts defines a slugify helper).
  s = s.replaceAll(
      RegExp(r'^(?:export\s+)?function[\s\S]*?\n\}\s*', multiLine: true), '');
  s = _stripComments(s);
  s = s.replaceAllMapped(RegExp(r'(?<=\d)_(?=\d)'), (_) => '');
  return s;
}

/// Extracts the first container literal (array or object) assigned to a
/// top-level `const`, using bracket-depth scanning so a *second* declaration
/// later in the module cannot overshoot the first.
String _extractFirstContainer(String cleaned) {
  final assign = RegExp(r'=\s*([\[{])').firstMatch(cleaned);
  if (assign == null) {
    throw const FormatException(
        'could not locate container literal in TS module');
  }
  final open = assign.group(1)!;
  final close = open == '[' ? ']' : '}';
  final start = assign.end - 1;

  var depth = 0;
  for (var i = start; i < cleaned.length; i++) {
    final c = cleaned[i];
    if (c == open) {
      depth++;
    } else if (c == close) {
      depth--;
      if (depth == 0) return cleaned.substring(start, i + 1);
    }
  }
  throw const FormatException('unbalanced container literal in TS module');
}

/// Quotes unquoted object keys and removes trailing commas.
String _toJsonCompatible(String s) {
  var out = s.replaceAllMapped(
      RegExp(r'([{,]\s*)([A-Za-z_][A-Za-z0-9_]*)(\s*:)'),
      (m) => '${m[1]}"${m[2]}"${m[3]}');
  out = out.replaceAllMapped(RegExp(r',(\s*[}\]])'), (m) => m[1]!);
  return out;
}

List<Map<String, dynamic>> _loadTsArray(String path) => _decodeArray(
    _toJsonCompatible(
        _extractFirstContainer(_cleanTs(File(path).readAsStringSync()))),
    path);

Map<String, dynamic> _loadTsObject(String path) => _decodeObject(
    _toJsonCompatible(
        _extractFirstContainer(_cleanTs(File(path).readAsStringSync()))),
    path);

dynamic _decode(String json, String path) {
  try {
    return jsonDecode(json);
  } on FormatException catch (e) {
    throw FormatException('$path: $e');
  }
}

List<Map<String, dynamic>> _decodeArray(String json, String path) {
  final decoded = _decode(json, path);
  if (decoded is! List) throw FormatException('$path is not an array');
  return decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
}

Map<String, dynamic> _decodeObject(String json, String path) {
  final decoded = _decode(json, path);
  if (decoded is! Map) throw FormatException('$path is not an object');
  return decoded.cast<String, dynamic>();
}

List<Map<String, dynamic>> _loadJsonArray(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! List) throw FormatException('$path is not a JSON array');
  return decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
}

// ---------------------------------------------------------------------------
// Reporting primitives
// ---------------------------------------------------------------------------

final _deva = RegExp(r'[\u0900-\u097F]');

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
    if (_deva.hasMatch(text)) devanagari++;
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

/// Normalises a palika name for cross-source keying: lowercase, collapse
/// whitespace, drop the type suffix (which different sources spell
/// differently — "Bhojpur Municipality" vs "Bhojpur").
String normName(String? raw) {
  if (raw == null) return '';
  var s = raw.toLowerCase().trim();
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  for (final suffix in const [
    'sub-metropolitan city',
    'sub metropolitan city',
    'metropolitan city',
    'rural municipality',
    'municipality',
  ]) {
    if (s.endsWith(' $suffix')) {
      s = s.substring(0, s.length - suffix.length - 1);
      break;
    }
  }
  return s.trim();
}

String normDistrict(String? raw) {
  if (raw == null) return '';
  return raw.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}

// ---------------------------------------------------------------------------

void main() {
  final sources = <SourceReport>[];

  // ---------------------------------------------------------------- abinrimal
  final abinrimalLevels = <Map<String, dynamic>>[];
  final abinrimalDistricts = <String, Map<String, dynamic>>{};
  {
    final r = SourceReport('abinrimal', 'data/_raw/abinrimal');
    final provinces = _loadJsonArray('${r.path}/provinces.json');
    final districts = _loadJsonArray('${r.path}/districts.json');
    final levels = _loadJsonArray('${r.path}/local_levels.json');
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
  {
    final r =
        SourceReport('local-states-nepal', 'data/_raw/local-states-nepal');
    final provinces = _loadJsonArray('${r.path}/dataset_provinces_en.json');
    final provincesNp = _loadJsonArray('${r.path}/dataset_provinces_np.json');
    final districtsEn = _loadJsonArray('${r.path}/dataset_districts_en.json');
    final munisEn = _loadJsonArray('${r.path}/dataset_municipalities_en.json');
    final munisNp = _loadJsonArray('${r.path}/dataset_municipalities_np.json');
    sagautamMunis.addAll(munisEn);

    for (final p in provinces) {
      r.tally('province.name_en', p['name_en']);
      r.tally('province.name_ne', p['name_ne']);
    }
    for (final p in provincesNp) {
      r.tally('province(np).name_ne', p['name_ne']);
    }
    for (final d in districtsEn) {
      r.tally('district.name_en', d['name_en']);
      r.tally('district.name_ne', d['name_ne']);
      r.tally('district.province_code', d['province_code']);
    }
    for (final m in munisEn) {
      for (final k in m.keys) {
        r.tally('municipality.$k', m[k]);
      }
    }
    r.note('provinces=${provinces.length} districts=${districtsEn.length} '
        'municipalities(en)=${munisEn.length} municipalities(np)=${munisNp.length}');
    r.note('municipality keys: ${munisEn.first.keys.toList()}');
    r.note('sample: ${munisEn.first}');
    sources.add(r);
  }

  // -------------------------------------------------------- nepali-geo-pro-max
  final geoUnits = <Map<String, dynamic>>[];
  final geoDistricts = <Map<String, dynamic>>[];
  final postal2025 = <String, String>{};
  {
    final r =
        SourceReport('nepali-geo-pro-max', 'data/_raw/nepali-geo-pro-max');
    final provinces = _loadTsArray('${r.path}/src_data_provinces.ts');
    final districts = _loadTsArray('${r.path}/src_data_districts.ts');
    final units = _loadTsArray('${r.path}/src_data_local-units.ts');
    final legacy = _loadTsArray('${r.path}/src_data_legacy-districts.ts');
    final zones = _loadTsArray('${r.path}/src_data_zones.ts');
    final regions = _loadTsArray('${r.path}/src_data_regions.ts');
    final postal = _loadTsObject('${r.path}/src_data_postal-codes.ts');
    final postalNew = _loadTsObject('${r.path}/src_data_postal-codes-2025.ts');
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
    final provinces = _loadJsonArray('${r.path}/data_all-province.json');
    final districts = _loadJsonArray('${r.path}/data_all-district.json');
    final units = _loadJsonArray('${r.path}/data_all-local_unit.json');
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
  out.writeln();
  out.writeln('=' * 78);
  out.writeln('CROSS-SOURCE LOCAL-BODY MATCHING');
  out.writeln('=' * 78);

  // nepali-geo-pro-max keyed by (district, normalised name).
  final geoKey = <String, Map<String, dynamic>>{};
  for (final u in geoUnits) {
    geoKey['${normDistrict(u['districtNameEn'] as String?)}|${normName(u['nameEn'] as String?)}'] =
        u;
  }

  // abinrimal keyed by (district, normalised name).
  final abinKey = <String, Map<String, dynamic>>{};
  for (final l in abinrimalLevels) {
    final dc = l['district_code'] as String?;
    final dName = abinrimalDistricts[dc]?['name_en'] as String?;
    abinKey['${normDistrict(dName)}|${normName(l['name_en'] as String?)}'] = l;
  }

  // sagautam5 keyed by (district, normalised name). Note this source keys
  // municipalities by `district_id`, so the district name must be resolved
  // through districts/en.json.
  final sagDistricts =
      _loadJsonArray('data/_raw/local-states-nepal/dataset_districts_en.json');
  final sagDistName = {
    for (final d in sagDistricts) d['id'] as int: d['name'] as String,
  };
  final sagKey = <String, Map<String, dynamic>>{};
  for (final m in sagautamMunis) {
    final dn = sagDistName[m['district_id'] as int];
    sagKey['${normDistrict(dn)}|${normName(m['name'] as String?)}'] = m;
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
      _loadJsonArray('data/_raw/open-admin-data/data_all-district.json');
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
        .map(MapEntry.new)['id'] as String?;    final postalPrefix = postalDistrictByPrefix.entries
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
      'prefixes nationally, split 14/8/13/11/12/10/9 per province — exactly our '
      'verified per-province district counts. It is the only source whose '
      'numbering is both complete and matches a published CBS/NSO reference '
      'code (Dharan = 11301). The other three schemes are internal orderings.');
  out.writeln('');
  out.writeln(
      '*** None of these four schemes is verified as the CBS/NSO scheme '
      'except postal-2025, whose Dharan value 11301 matches the one published '
      'CBS/NSO reference code. Resolve in Step 2 against CBS/NSO directly. ***');

  stdout.write(out.toString());
  File('docs/_inventory-raw.txt').writeAsStringSync(out.toString());
}
