// tool/merge/attach_bilingual.dart
//
// Attaches Devanagari names (nameNe) at all three levels, and corroborates
// each one against a second independent Devanagari source.
//
// Why this exists
// ---------------
// The dataset shipped English-only, even though two vendored sources carry
// complete bilingual rosters. For a package about Nepal's own government
// structure, the Nepali name of a palika is not a nicety - it is what appears
// on the building, in the gazette, and on every form a citizen fills in.
//
// Sources (per data/SOURCES.md):
//   primary  - abinrimal/nepal-administrative-divisions-json (MIT)
//              name_ne for 7 provinces, 77 districts, 753 palikas
//   second   - open-admin-data (CC-BY-4.0, attributed in NOTICE)
//              name.local at the same three levels
//
// A name is only published when a source carries it. The two votes are
// compared and recorded, but disagreement never blocks the name - English is
// the identifying field here, Devanagari is a rendering of it, so a single
// attested vote is enough to publish and the second vote only upgrades
// `nameNeVerified`.
//
// Gates (any failure exits non-zero WITHOUT writing):
//   0. provenance (shared gate: data/PROVENANCE.sha256)
//   1. source shape asserts (record counts, Devanagari actually present)
//   2. district resolution for all 77 districts
//   3. post-assignment bijection within each district
//
// Usage (from the package root):
//   dart run tool/merge/attach_bilingual.dart           # write
//   dart run tool/merge/attach_bilingual.dart --dry-run # report only

import 'dart:convert';
import 'dart:io';

import 'common.dart';

Never _fail(String message) {
  stderr.writeln('ATTACH_BILINGUAL FAILED: $message');
  exit(1);
}

/// Max normalized-name distance accepted when matching a palika to its
/// bilingual row.
///
/// 2 is deliberate. It covers the observed transliteration variants
/// ("Pauwa Dunma"/"Pauwadungma", "Shadananda"/"Shadanand") while keeping the
/// match inside what a human would call the same name. Distance 3-4 was
/// measured and REJECTED: it produced confidently wrong pairings across
/// genuinely different neighbouring palikas (our "Dhorchaur" picking up
/// Bagachour's name, "Sulikot" picking up Ajirkot's, "Kanda" picking up
/// Masta's). A palika with no defensible name is published as null; a wrong
/// one is far worse than an absent one.
const _maxDistance = 2;

/// Province names differ only by the suffix the source appends: ours is
/// "Koshi", abinrimal and open-admin-data write "Koshi Pradesh".
String canonProvince(String? raw) =>
    canonDistrict(raw).replaceAll(RegExp(r'\s*(province|pradesh)\s*$'), '');

/// Devanagari key for corroboration. The two sources append "प्रदेश" to a
/// province name inconsistently ("कोशी प्रदेश" vs "कोशी"), so that suffix is
/// stripped before the two votes are compared.
String canonDevaProvince(String? raw) {
  if (raw == null) return '';
  return raw
      .trim()
      .replaceAll(RegExp(r'\s*प्रदेश(म्)?\s*$'), '')
      .replaceAll(RegExp(r'\s+'), '');
}

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');
  final debugDistricts = args
      .where((a) => a.startsWith('--debug='))
      .map((a) => a.substring('--debug='.length))
      .toSet();

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
  out.writeln('BILINGUAL NAMES (Devanagari)');
  out.writeln('generated: ${DateTime.now().toUtc().toIso8601String()}');
  out.writeln('dry-run: $dryRun');
  out.writeln('=' * 78);

  // ---- Load sources --------------------------------------------------------
  final abProvinces = loadJsonArray('data/_raw/abinrimal/provinces.json');
  final abDistricts = loadJsonArray('data/_raw/abinrimal/districts.json');
  final abLocal = loadJsonArray('data/_raw/abinrimal/local_levels.json');
  final oadLocal = loadJsonArray(
    'data/_raw/open-admin-data/data_all-local_unit.json',
  );
  final oadDistrict = loadJsonArray(
    'data/_raw/open-admin-data/data_all-district.json',
  );
  final oadProvince = loadJsonArray(
    'data/_raw/open-admin-data/data_all-province.json',
  );

  // ---- Gate 1: source shape -----------------------------------------------
  void check(bool cond, String message) {
    if (!cond) _fail(message);
    out.writeln('  ok: $message');
  }

  check(abProvinces.length == 7,
      'abinrimal provinces == 7 (got ${abProvinces.length})');
  check(
    abDistricts.length == 77,
    'abinrimal districts == 77 (got ${abDistricts.length})',
  );
  check(
    abLocal.length == 753,
    'abinrimal palikas == 753 (got ${abLocal.length})',
  );

  final abLocalWithNe =
      abLocal.where((r) => devaRegex.hasMatch('${r['name_ne']}')).length;
  // The harvest has a couple of rows with no Devanagari name at all. That is
  // an upstream gap to report, not a reason to refuse the run - only a broad
  // loss of the column would suggest we parsed the file wrongly.
  check(
    abLocalWithNe >= abLocal.length * 0.99,
    'abinrimal palikas carry Devanagari names '
    '($abLocalWithNe/${abLocal.length}; '
    '${abLocal.length - abLocalWithNe} upstream gap(s))',
  );
  for (final r in abLocal) {
    if (devaRegex.hasMatch('${r['name_ne']}')) continue;
    out.writeln('    NO DEVANAGARI IN SOURCE: district_code '
        '${r['district_code']} / ${r['name_en']} (code ${r['code']})');
  }
  final abDistWithNe =
      abDistricts.where((r) => devaRegex.hasMatch('${r['name_ne']}')).length;
  check(
    abDistWithNe == abDistricts.length,
    'every abinrimal district carries a Devanagari name '
    '($abDistWithNe/${abDistricts.length})',
  );

  // ---- Index the sources ---------------------------------------------------
  // abinrimal keys palikas by its own 1..77 district_code (NOT the CBS PDD
  // code), so districts are joined by canonical name.
  final abLocalByDistrict = <String, List<Map<String, dynamic>>>{};
  for (final r in abLocal) {
    abLocalByDistrict.putIfAbsent('${r['district_code']}', () => []).add(r);
  }
  final abDistrictByCanon = <String, Map<String, dynamic>>{};
  for (final r in abDistricts) {
    abDistrictByCanon[canonDistrict('${r['name_en']}')] = r;
  }
  final abProvinceByCanon = <String, Map<String, dynamic>>{};
  for (final r in abProvinces) {
    abProvinceByCanon[canonProvince('${r['name_en']}')] = r;
  }

  // open-admin-data is keyed by an NP-prefixed hierarchy id and is known to
  // over-count (775 units vs 753), so it is only ever read as a second vote
  // for a palika we have already identified - never as an identifier.
  final oadLocalByParent = <String, List<Map<String, dynamic>>>{};
  for (final r in oadLocal) {
    final parent = (r['parent'] as Map?)?['name'] as Map?;
    final parentEn = parent?['en'];
    if (parentEn is! String) continue;
    oadLocalByParent.putIfAbsent(canonDistrict(parentEn), () => []).add(r);
  }
  final oadDistrictByCanon = <String, Map<String, dynamic>>{};
  for (final r in oadDistrict) {
    final n = r['name'];
    if (n is Map && n['en'] is String) {
      oadDistrictByCanon[canonDistrict(n['en'] as String)] = r;
    }
  }
  final oadProvinceByCanon = <String, Map<String, dynamic>>{};
  for (final r in oadProvince) {
    final n = r['name'];
    if (n is Map && n['en'] is String) {
      oadProvinceByCanon[canonProvince(n['en'] as String)] = r;
    }
  }

  String devaName(Object? container) {
    if (container is Map && container['local'] is String) {
      final s = container['local'] as String;
      if (devaRegex.hasMatch(s)) return cleanDisplayName(s);
    }
    return '';
  }

  // ---- Load our dataset ----------------------------------------------------
  final levelsFile = File('data/nepal_local_levels.json');
  final levelsJson =
      jsonDecode(levelsFile.readAsStringSync()) as Map<String, dynamic>;
  final provinces =
      (levelsJson['provinces'] as List).cast<Map<String, dynamic>>();

  final palikaRecords = <Map<String, dynamic>>[];
  // The dataset row each record came from, so a conflict can be applied to
  // both the staged evidence and the JSON we are about to write.
  final palikaRows = <Map<String, dynamic>>[];
  var provinceDe = 0, provinceDeVerified = 0;

  for (final province in provinces) {
    final provName = province['name'] as String;
    final abP = abProvinceByCanon[canonProvince(provName)];
    final oadP = oadProvinceByCanon[canonProvince(provName)];

    // abinrimal labels provinces "Koshi Pradesh"; ours is "Koshi". The
    // canonical fold handles that, but keep the raw name for evidence.
    String? provNe;
    if (abP != null && devaRegex.hasMatch('${abP['name_ne']}')) {
      provNe = cleanDisplayName('${abP['name_ne']}');
    }
    final oadProvNe = devaName((oadP?['name']));
    if (provNe != null) provinceDe++;
    final provVerified = provNe != null &&
        oadProvNe.isNotEmpty &&
        canonDevaProvince(provNe) == canonDevaProvince(oadProvNe);
    if (provVerified) provinceDeVerified++;

    for (final district in (province['districts'] as List)) {
      final dmap = district as Map<String, dynamic>;
      final dname = dmap['name'] as String;
      final canon = canonDistrict(dname);

      final abD = abDistrictByCanon[canon];
      final oadD = oadDistrictByCanon[canon];

      String? distNe;
      if (abD != null && devaRegex.hasMatch('${abD['name_ne']}')) {
        distNe = cleanDisplayName('${abD['name_ne']}');
      }
      final oadDistNe = devaName(oadD?['name']);
      dmap['nameNe'] = distNe;
      dmap['nameNeVerified'] = distNe != null &&
          oadDistNe.isNotEmpty &&
          flatToken(distNe) == flatToken(oadDistNe);

      final cands =
          (abD == null ? null : abLocalByDistrict['${abD['code']}']) ??
              const <Map<String, dynamic>>[];
      if (debugDistricts.contains(dname)) {
        stderr.writeln(
            'DEBUG $dname: abD=${abD == null ? 'NULL' : 'code ${abD['code']}'}'
            ' canon=${canonDistrict(dname)} cands=${cands.length}');
        for (final r in cands) {
          stderr.writeln('   cand code=${r['code']} name_en=${r['name_en']} '
              'norm="${flatToken(normCbsKey('${r['name_en']}'))}"');
        }
      }
      final oadCands =
          oadLocalByParent[canon] ?? const <Map<String, dynamic>>[];
      final taken = <String>{};
      final usedOad = <String>{};

      for (final b
          in (dmap['localBodies'] as List).cast<Map<String, dynamic>>()) {
        final name = b['name'] as String;
        final key = flatToken(normCbsKey(name));

        // Pick the unique best candidate at or under the threshold, from a
        // list of [rowKey, nameEn, nameNe] triples. A tie is ambiguous, so it
        // is refused rather than guessed. Returns nulls when nothing is
        // close enough or two candidates are equally plausible.
        List<Object?> pick(List<List<Object?>> scored) {
          if (scored.isEmpty) return [null, -1, null];
          final best = scored.first[3] as int;
          final runnerUp = scored.length > 1 ? scored[1][3] as int : null;
          if (runnerUp != null && runnerUp <= best) {
            return [scored.first[1], best, null];
          }
          return [scored.first[1], best, scored.first[2]];
        }

        // ---- vote 1: abinrimal (primary) ----
        final abScored = <List<Object?>>[];
        for (final r in cands) {
          // NOTE: abinrimal's `code` column carries only four distinct values
          // (it is a type code, not an identifier - documented in
          // data/SOURCES.md), so it cannot key an "already matched" set.
          // district_code + name_en is unique within a district.
          final rowKey = '${r['district_code']}|${r['name_en']}';
          if (taken.contains(rowKey)) continue;
          final rawNe = '${r['name_ne']}';
          final d = levenshtein(
            key,
            flatToken(normCbsKey('${r['name_en']}')),
            _maxDistance + 1,
          );
          if (d <= _maxDistance) {
            abScored.add([
              rowKey,
              '${r['name_en']}',
              devaRegex.hasMatch(rawNe) ? cleanDisplayName(rawNe) : null,
              d,
            ]);
          }
        }
        abScored.sort((a, b) => (a[3] as int).compareTo(b[3] as int));
        final abPick = pick(abScored);
        final abNameEn = abPick[0] as String?;
        final abDistance = abPick[1] as int;
        final abNe = abPick[2] as String?;

        // ---- vote 2: open-admin-data ----
        // Scored independently over the same district so it can both
        // corroborate the primary vote AND stand in for it: abinrimal's
        // roster is short in a few districts and blank in two rows
        // (documented in data/SOURCES.md), and this source covers those.
        final oadScored = <List<Object?>>[];
        for (final r in oadCands) {
          final rowKey = '${r['id']}';
          if (usedOad.contains(rowKey)) continue;
          final rn = r['name'];
          if (rn is! Map || rn['en'] is! String) continue;
          final rawNe = devaName(rn);
          if (rawNe.isEmpty) continue;
          final d = levenshtein(
            key,
            flatToken(normCbsKey(rn['en'] as String)),
            _maxDistance + 1,
          );
          if (d <= _maxDistance) {
            oadScored.add([rowKey, rn['en'] as String, rawNe, d]);
          }
        }
        oadScored.sort((a, b) => (a[3] as int).compareTo(b[3] as int));
        final oadPick = pick(oadScored);
        final oadNameEn = oadPick[0] as String?;
        final oadDistance = oadPick[1] as int;
        final oadNe = oadPick[2] as String?;

        if (abPick[0] != null) taken.add(abPick[0] as String);
        if (oadPick[0] != null) usedOad.add(oadPick[0] as String);

        // The primary source wins; the fallback only fills a gap.
        final ne = abNe ?? oadNe;
        final source = abNe != null
            ? 'abinrimal'
            : (oadNe != null ? 'open-admin-data' : null);
        // Corroborated only when both sources were able to vote AND agreed.
        final agree = abNe != null &&
            oadNe != null &&
            flatToken(abNe) == flatToken(oadNe);

        b['nameNe'] = ne;
        b['nameNeVerified'] = agree;

        final record = <String, dynamic>{
          'province': provName,
          'district': dname,
          'name': name,
          'nameNe': ne,
          'nameNeSource': source,
          'nameNeVerified': agree,
          'abinrimalNameEn': abNameEn,
          'abinrimalNameNe': abNe,
          'abinrimalDistance': abDistance < 0 ? null : abDistance,
          'openAdminDataNameEn': oadNameEn,
          'openAdminDataNameNe': oadNe,
          'openAdminDataDistance': oadDistance < 0 ? null : oadDistance,
        };
        // Kept for review: why a palika got no name. A close-but-rejected
        // candidate means the roster spells it differently or holds a
        // duplicate; no candidate at all means the row is simply absent.
        if (ne == null) {
          final near = <String>[];
          if (abScored.isNotEmpty) {
            near.add(
                'abinrimal "${abScored.first[1]}" (d=${abScored.first[3]})');
          }
          if (oadScored.isNotEmpty) {
            near.add('open-admin-data "${oadScored.first[1]}" '
                '(d=${oadScored.first[3]})');
          }
          record['rejectedCandidates'] = near.join('; ');
          record['rejectedBecause'] = near.isEmpty
              ? 'neither source has a row within distance $_maxDistance '
                  'in this district'
              : 'closest candidate(s) ${near.join('; ')} — ambiguous tie or '
                  'missing Devanagari upstream; refused as a guess';
        }
        palikaRecords.add(record);
        palikaRows.add(b);
      }
    }
  }

  // ---- Conflict resolution: one Devanagari name per palika, per district ----
  // Two of our palikas can end up claiming the same Devanagari name when a
  // source holds a duplicate row (abinrimal's roster duplicates
  // "Gulmi | Chatrakot", documented in data/SOURCES.md). That is a defect in
  // the source, not evidence about our roster, so the conflict is resolved
  // by evidence strength: the best-supported claim keeps the name and the
  // others are dropped rather than duplicating a name across two palikas.
  var conflicts = 0;
  final byDistrict = <String, List<int>>{};
  for (var i = 0; i < palikaRecords.length; i++) {
    final r = palikaRecords[i];
    if (r['nameNe'] == null) continue;
    byDistrict.putIfAbsent('${r['district']}', () => []).add(i);
  }
  byDistrict.forEach((district, indices) {
    final groups = <String, List<int>>{};
    for (final i in indices) {
      groups.putIfAbsent('${palikaRecords[i]['nameNe']}', () => []).add(i);
    }
    groups.forEach((name, members) {
      if (members.length < 2) return;
      // Rank by corroboration first, then by match distance.
      members.sort((a, b) {
        final va = palikaRecords[a]['nameNeVerified'] == true ? 0 : 1;
        final vb = palikaRecords[b]['nameNeVerified'] == true ? 0 : 1;
        if (va != vb) return va.compareTo(vb);
        int d(Map<String, dynamic> r) =>
            (r['abinrimalDistance'] as int?) ??
            (r['openAdminDataDistance'] as int?) ??
            99;
        return d(palikaRecords[a]).compareTo(d(palikaRecords[b]));
      });
      final winner = members.first;
      for (final loser in members.skip(1)) {
        final r = palikaRecords[loser];
        r['nameNe'] = null;
        r['nameNeSource'] = null;
        r['nameNeVerified'] = false;
        r['rejectedBecause'] =
            'source duplicate: "$name" in $district is also claimed by '
            '"${palikaRecords[winner]['name']}" with stronger evidence; '
            'refused rather than duplicating a name across two palikas';
        palikaRows[loser]['nameNe'] = null;
        palikaRows[loser]['nameNeVerified'] = false;
        conflicts++;
      }
    });
  });
  if (conflicts > 0) {
    out.writeln('  resolved $conflicts duplicate Devanagari name(s) by '
        'evidence strength');
  }

  // ---- Gate 3: bijection ----------------------------------------------------
  final dupes = <String>[];
  final seen = <String, String>{};
  for (final r in palikaRecords) {
    if (r['nameNe'] == null) continue;
    final k = '${r['district']}|${r['nameNe']}';
    final prev = seen[k];
    if (prev != null) {
      dupes.add('$k also used by ${prev.split('|').last}');
    }
    seen[k] = k;
  }
  check(
    dupes.isEmpty,
    'no two palikas in a district share a Devanagari name '
    '(violations: ${dupes.length})',
  );
  for (final d in dupes.take(10)) {
    out.writeln('    DUPLICATE $d');
  }

  // ---- Report ---------------------------------------------------------------
  final palikaDe = palikaRecords.where((r) => r['nameNe'] != null).length;
  final palikaDeVerified =
      palikaRecords.where((r) => r['nameNeVerified'] == true).length;
  final palikaDeUnmatched =
      palikaRecords.where((r) => r['nameNe'] == null).length;
  final distDe = <int>[];
  for (final p in provinces) {
    for (final d in (p as Map)['districts'] as List) {
      if ((d as Map)['nameNe'] != null) distDe.add(0);
    }
  }
  check(provinceDe == 7,
      'every province carries a Devanagari name ($provinceDe/7)');
  check(distDe.length == 77,
      'every district carries a Devanagari name (${distDe.length}/77)');

  out.writeln('');
  out.writeln(
      'PROVINCES: $provinceDe/7 named, $provinceDeVerified/7 corroborated');
  out.writeln('DISTRICTS: ${distDe.length}/77 named');
  out.writeln('PALIKAS:   $palikaDe/753 named '
      '($palikaDeVerified corroborated by both sources, '
      '$palikaDeUnmatched unmatched)');

  final unmatched = palikaRecords.where((r) => r['nameNe'] == null).toList();
  if (unmatched.isNotEmpty) {
    out.writeln('');
    out.writeln('UNMATCHED (${unmatched.length}):');
    for (final r in unmatched) {
      out.writeln('  ${r['district']} / ${r['name']}');
      out.writeln('      ${r['rejectedBecause']}');
    }
  }

  // ---- Stage evidence -------------------------------------------------------
  final staged = {
    'provenance': {
      'generated': DateTime.now().toUtc().toIso8601String(),
      'tool': 'tool/merge/attach_bilingual.dart',
      'inputs': [
        'data/_raw/abinrimal/provinces.json',
        'data/_raw/abinrimal/districts.json',
        'data/_raw/abinrimal/local_levels.json',
        'data/_raw/open-admin-data/data_all-province.json',
        'data/_raw/open-admin-data/data_all-district.json',
        'data/_raw/open-admin-data/data_all-local_unit.json',
        'data/nepal_local_levels.json',
      ],
      'rule': 'nameNe is published whenever abinrimal carries a Devanagari '
          'name for a palika identified by a unique normalized-name match '
          'inside its district (distance <= $_maxDistance, ties refused). '
          'nameNeVerified is true only when open-admin-data independently '
          'agrees. open-admin-data is never used as an identifier: it ships '
          '775 units against 753.',
    },
    'counts': {
      'provincesNamed': provinceDe,
      'provincesCorroborated': provinceDeVerified,
      'districtsNamed': distDe.length,
      'palikasNamed': palikaDe,
      'palikasCorroborated': palikaDeVerified,
      'palikasUnmatched': palikaDeUnmatched,
      'total': palikaRecords.length,
    },
    'assignments': palikaRecords,
  };
  Directory('data/_stage').createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  File(
    'data/_stage/bilingual.json',
  ).writeAsStringSync(encoder.convert(staged));

  if (dryRun) {
    out.writeln('');
    out.writeln('DRY RUN - dataset NOT modified. Evidence written to '
        'data/_stage/bilingual.json');
    stdout.write(out.toString());
    return;
  }

  // ---- Write the Devanagari names back -------------------------------------
  for (final province in provinces) {
    final provName = province['name'] as String;
    final abP = abProvinceByCanon[canonProvince(provName)];
    final oadP = oadProvinceByCanon[canonProvince(provName)];
    final provNe = (abP != null && devaRegex.hasMatch('${abP['name_ne']}'))
        ? cleanDisplayName('${abP['name_ne']}')
        : null;
    final oadProvNe = devaName((oadP?['name']));
    province['nameNe'] = provNe;
    province['nameNeVerified'] = provNe != null &&
        oadProvNe.isNotEmpty &&
        canonDevaProvince(provNe) == canonDevaProvince(oadProvNe);
  }
  levelsFile.writeAsStringSync(encoder.convert(levelsJson));
  out.writeln('');
  out.writeln('Updated data/nepal_local_levels.json with Devanagari names');
  out.writeln('wrote data/_stage/bilingual.json');

  stdout.write(out.toString());
}
