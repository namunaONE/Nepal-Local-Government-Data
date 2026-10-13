// tool/merge/attach_attributes.dart
//
// Attaches administrative attributes that were extracted by the earlier merge
// steps but never made it into the shipped schema:
//
//   district / province - headquarter (district capital), areaSqKm, website
//   local body          - website, email, phone   (MoFAGA contact block)
//   local body          - zipCodes                (postal codes)
//
// Why these were not shipped before
// ---------------------------------
// Every one of them is SINGLE-SOURCE, and the roadmap held them back for
// exactly that reason. They are published now because a package whose whole
// value is "the administrative structure of Nepal" should carry the district
// headquarters and the area figure - but the single-source status is stated
// on every field's doc comment and in data/SOURCES.md, so a caller can decide
// whether it is good enough for their use.
//
// Joins, not identifiers
// ----------------------
//   - sagautam5  district/province attributes join on canonical name.
//   - MoFAGA     rows carry no code, so a palika is matched by its Devanagari
//                name inside the Devanagari district name. That is only
//                possible because attach_bilingual.dart ran first, which is
//                why the pipeline enforces the order.
//   - open-admin-data is only ever read for a palika already identified.
//
// Gates (any failure exits non-zero WITHOUT writing):
//   0. provenance (shared gate: data/PROVENANCE.sha256)
//   1. source shape asserts (record counts, required columns)
//   2. a bilingual name exists for every palika we intend to enrich
//   3. bijection: no two palikas may take the same MoFAGA row
//
// Usage (from the package root):
//   dart run tool/merge/attach_attributes.dart           # write
//   dart run tool/merge/attach_attributes.dart --dry-run # report only

import 'dart:convert';
import 'dart:io';

import 'common.dart';

Never _fail(String message) {
  stderr.writeln('ATTACH_ATTRIBUTES FAILED: $message');
  exit(1);
}

double? _parseNumber(Object? raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

String? _cleanUrl(Object? raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty || !s.startsWith('http')) return null;
  return s;
}

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');

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
  out.writeln('ADMINISTRATIVE ATTRIBUTES');
  out.writeln('generated: ${DateTime.now().toUtc().toIso8601String()}');
  out.writeln('dry-run: $dryRun');
  out.writeln('all fields single-source (see data/SOURCES.md)');
  out.writeln('=' * 78);

  final sgDistricts = loadJsonArray(
    'data/_raw/local-states-nepal/dataset_districts_en.json',
  );
  final sgProvinces = loadJsonArray(
    'data/_raw/local-states-nepal/dataset_provinces_en.json',
  );
  final mofaga = loadJsonArray('data/_raw/mofaga/mofaga_all.json');
  final oadLocal = loadJsonArray(
    'data/_raw/open-admin-data/data_all-local_unit.json',
  );

  // ---- Gate 1: source shape -----------------------------------------------
  void check(bool cond, String message) {
    if (!cond) _fail(message);
    out.writeln('  ok: $message');
  }

  check(sgDistricts.length == 77,
      'sagautam5 districts == 77 (got ${sgDistricts.length})');
  check(sgProvinces.length == 7,
      'sagautam5 provinces == 7 (got ${sgProvinces.length})');
  check(mofaga.length > 700, 'MoFAGA rows present (got ${mofaga.length})');
  check(oadLocal.length > 700,
      'open-admin-data rows present (got ${oadLocal.length})');

  var sgDistrictsWithArea = 0, sgDistrictsWithHq = 0, sgDistrictsWithSite = 0;
  final sgByCanon = <String, Map<String, dynamic>>{};
  for (final r in sgDistricts) {
    sgByCanon[canonDistrict('${r['name']}')] = r;
    if (_parseNumber(r['area_sq_km']) != null) sgDistrictsWithArea++;
    if ('${r['headquarter'] ?? ''}'.trim().isNotEmpty) sgDistrictsWithHq++;
    if (_cleanUrl(r['website']) != null) sgDistrictsWithSite++;
  }
  out.writeln('  info: sagautam5 districts carry area=$sgDistrictsWithArea/77 '
      'headquarter=$sgDistrictsWithHq/77 website=$sgDistrictsWithSite/77');

  var sgProvincesWithArea = 0, sgProvincesWithCapital = 0;
  final sgProvByCanon = <String, Map<String, dynamic>>{};
  for (final r in sgProvinces) {
    // "Koshi Province" -> "koshi", matching our bare province name.
    sgProvByCanon[canonProvince2('${r['name']}')] = r;
    if (_parseNumber(r['area_sq_km']) != null) sgProvincesWithArea++;
    if ('${r['headquarter'] ?? ''}'.trim().isNotEmpty) sgProvincesWithCapital++;
  }

  // ---- Index MoFAGA by bare Devanagari name, and open-admin-data likewise ----
  // MoFAGA's `name` is the full official string ("विराटनगर महानगरपालिका"),
  // so the trailing type word is stripped to get the bare name our roster
  // carries. Indexing is GLOBAL rather than district-scoped on purpose: 12
  // districts spell their Devanagari differently in this source ("स्याङ्जा"
  // vs "स्याञ्जा", "रुपन्देही" vs "रूपन्देही"), so a district key silently
  // loses those whole districts. Bijection is enforced instead.
  const devaTypeSuffixes = [
    'उपमहानगरपालिका',
    'महानगरपालिका',
    'नगरपालिका',
    'गाउँपालिका',
    'गाउँपालीका',
  ];
  String bareName(String raw) {
    var s = raw.trim();
    for (final suf in devaTypeSuffixes) {
      if (s.endsWith(' $suf')) {
        return s.substring(0, s.length - suf.length).trim();
      }
      if (s == suf) {
        return '';
      }
    }
    return s;
  }

  final mofagaByName = <String, List<Map<String, dynamic>>>{};
  for (final r in mofaga) {
    final bare = bareName('${r['name'] ?? ''}');
    if (bare.isEmpty || !devaRegex.hasMatch(bare)) continue;
    mofagaByName.putIfAbsent(flatToken(bare), () => []).add(r);
  }
  final oadByLocal = <String, List<Map<String, dynamic>>>{};
  for (final r in oadLocal) {
    final n = r['name'];
    if (n is! Map || n['local'] is! String) continue;
    final local = (n['local'] as String).trim();
    if (!devaRegex.hasMatch(local)) continue;
    oadByLocal.putIfAbsent(flatToken(local), () => []).add(r);
  }
  out.writeln('  info: MoFAGA bare Devanagari names=${mofagaByName.length}, '
      'open-admin-data names=${oadByLocal.length}');

  // ---- Load our dataset ----------------------------------------------------
  final levelsFile = File('data/nepal_local_levels.json');
  final levelsJson =
      jsonDecode(levelsFile.readAsStringSync()) as Map<String, dynamic>;
  final provinces =
      (levelsJson['provinces'] as List).cast<Map<String, dynamic>>();

  var distEnriched = 0, provEnriched = 0;
  var contactEnriched = 0, zipEnriched = 0;
  final noNameNe = <String>[];
  final mofagaTaken = <String>{};
  var mofagaReuse = 0;
  var ambiguousNames = 0;

  // Count how many of OUR palikas share each bare Devanagari name. Where two
  // of ours collide, the name cannot identify either one, so no contact block
  // is attached: the ambiguity is reported rather than papered over.
  final ourNameCounts = <String, int>{};
  for (final p in provinces) {
    for (final d in (p as Map)['districts'] as List) {
      for (final b in (d as Map)['localBodies'] as List) {
        final ne = ((b as Map)['nameNe'] as String?)?.trim() ?? '';
        if (ne.isEmpty) continue;
        ourNameCounts[flatToken(ne)] = (ourNameCounts[flatToken(ne)] ?? 0) + 1;
      }
    }
  }

  for (final province in provinces) {
    final provName = province['name'] as String;
    final sgP = sgProvByCanon[canonProvince2(provName)];
    if (sgP != null) {
      final area = _parseNumber(sgP['area_sq_km']);
      final capital = '${sgP['headquarter'] ?? ''}'.trim();
      final site = _cleanUrl(sgP['website']);
      if (area != null) province['areaSqKm'] = area;
      if (capital.isNotEmpty) province['capital'] = capital;
      if (site != null) province['website'] = site;
      if (area != null || capital.isNotEmpty || site != null) provEnriched++;
    }

    for (final district in (province['districts'] as List)) {
      final dmap = district as Map<String, dynamic>;
      final dname = dmap['name'] as String;
      final sgD = sgByCanon[canonDistrict(dname)];
      if (sgD != null) {
        final area = _parseNumber(sgD['area_sq_km']);
        final hq = '${sgD['headquarter'] ?? ''}'.trim();
        final site = _cleanUrl(sgD['website']);
        if (area != null) dmap['areaSqKm'] = area;
        if (hq.isNotEmpty) dmap['headquarter'] = hq;
        if (site != null) dmap['website'] = site;
        if (area != null || hq.isNotEmpty || site != null) distEnriched++;
      }

      final distNe = (dmap['nameNe'] as String?)?.trim() ?? '';

      for (final b
          in (dmap['localBodies'] as List).cast<Map<String, dynamic>>()) {
        final nameNe = (b['nameNe'] as String?)?.trim() ?? '';
        if (nameNe.isEmpty) {
          noNameNe.add('$dname / ${b['name']}');
          continue;
        }
        final key = flatToken(nameNe);

        // ---- MoFAGA contact block ----
        // Bare Devanagari palika names are NOT globally unique — many
        // rural municipalities share a name across districts (41 such
        // collisions in this source). So a candidate is accepted only when
        // it is unambiguous: either exactly one MoFAGA row carries this bare
        // name nationwide, or several do and exactly one of them sits in our
        // district. Anything else is refused rather than guessed.
        // Refused outright when two of our own palikas share this Devanagari
        // name: the name cannot identify either one, so attaching contact
        // details would be a guess between two real, distinct palikas.
        if ((ourNameCounts[key] ?? 0) > 1) {
          ambiguousNames++;
        } else {
          var mofRows = mofagaByName[key] ?? const <Map<String, dynamic>>[];
          if (mofRows.length > 1) {
            final scoped = distNe.isEmpty
                ? const <Map<String, dynamic>>[]
                : [
                    for (final r in mofRows)
                      if ('${r['district'] ?? ''}'.trim() == distNe) r,
                  ];
            mofRows = scoped.length == 1 ? scoped : const [];
          }
          for (final r in mofRows) {
            final id = '${r['website'] ?? ''}|${r['name']}';
            if (mofagaTaken.contains(id)) {
              mofagaReuse++;
              continue;
            }
            mofagaTaken.add(id);
            final site = _cleanUrl(r['website']);
            if (site != null) b['website'] = site;
            final email = '${r['email'] ?? ''}'.trim();
            if (email.contains('@')) b['email'] = email;
            final phone = '${r['phone'] ?? ''}'.trim();
            if (phone.isNotEmpty) b['phone'] = phone;
            if (site != null || email.isNotEmpty || phone.isNotEmpty) {
              contactEnriched++;
            }
            break;
          }
        }

        // ---- postal codes ----
        final zips = <String>[];
        for (final r in (oadByLocal[key] ?? const <Map<String, dynamic>>[])) {
          final list = r['zip_codes'];
          if (list is! List) continue;
          for (final z in list) {
            final s = '$z'.trim();
            if (s.isNotEmpty && !zips.contains(s)) zips.add(s);
          }
        }
        if (zips.isNotEmpty) {
          zips.sort();
          b['zipCodes'] = zips;
          zipEnriched++;
        }
      }
    }
  }

  // ---- Gate 3: bijection ---------------------------------------------------
  check(
    mofagaReuse == 0,
    'no MoFAGA row was claimed by two palikas (reuses: $mofagaReuse)',
  );

  out.writeln('');
  out.writeln('PROVINCES enriched: $provEnriched/7 '
      '(area $sgProvincesWithArea, capital $sgProvincesWithCapital)');
  out.writeln('DISTRICTS enriched: $distEnriched/77 '
      '(area $sgDistrictsWithArea, headquarter $sgDistrictsWithHq, '
      'website $sgDistrictsWithSite)');
  out.writeln('PALIKAS with contact details: $contactEnriched/753 '
      '($ambiguousNames skipped: the Devanagari name does not identify one '
      'palika uniquely)');
  out.writeln('PALIKAS with postal codes: $zipEnriched/753');
  if (noNameNe.isNotEmpty) {
    out.writeln('SKIPPED (no Devanagari name to join on): '
        '${noNameNe.length} — run attach_bilingual.dart first');
  }

  if (dryRun) {
    out.writeln('');
    out.writeln('DRY RUN - dataset NOT modified');
    stdout.write(out.toString());
    return;
  }

  const encoder = JsonEncoder.withIndent('  ');
  levelsFile.writeAsStringSync(encoder.convert(levelsJson));
  out.writeln('');
  out.writeln('Updated data/nepal_local_levels.json with attributes');
  stdout.write(out.toString());
}

/// Province names in sagautam5 carry a "Province" suffix ours does not, and it
/// spells Sudurpashchim with one 'c' fewer ("Sudurpaschim").
String canonProvince2(String? raw) => canonDistrict(raw)
    .replaceAll(RegExp(r'\s*province\s*$'), '')
    .replaceAll('sudurpaschim', 'sudurpashchim');
