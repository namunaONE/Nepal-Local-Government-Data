// tool/merge/adjudicate.dart
//
// Step 3b: Parse REVIEW.md conflicts, cross-reference sources, stage decisions.
//
// Usage: dart run tool/merge/adjudicate.dart

import 'dart:convert';
import 'dart:io';

import 'common.dart';

void main() {
  final conflicts = _parseConflicts();
  final abin = _index(loadJsonArray('data/_raw/abinrimal/local_levels.json'),
      (l) => palikaKey(_abinDistrict(l['district_code']), l['name_en']));
  final sag = _index(
      loadJsonArray(
          'data/_raw/local-states-nepal/dataset_municipalities_en.json'),
      (m) => palikaKey(_sagDistrict(m['district_id']), m['name']));
  final cbs = _indexCbs();
  final mofagaLoaded = _loadMofaga();
  final mofaga = mofagaLoaded.rows;
  final mofagaDupes = mofagaLoaded.dupes;
  stdout.writeln(
      'MoFAGA rows: ${mofaga.length} unique ($mofagaDupes page-boundary duplicates dropped)');
  // Group MoFAGA rows by bridged (English, canon) district for the
  // slug-identification path. Rows from unbridged districts are counted
  // and reported — they are invisible to district-scoped matching.
  final mofagaByDistrict = <String, List<Map<String, dynamic>>>{};
  var mofagaUnbridged = 0;
  for (final r in mofaga) {
    final en = _neToEn[canonDistrict(r['district'] as String? ?? '')];
    if (en == null) {
      mofagaUnbridged++;
      continue;
    }
    mofagaByDistrict.putIfAbsent(en, () => []).add(r);
  }
  if (mofagaUnbridged > 0) {
    stdout.writeln(
        'MoFAGA rows in unbridged districts (no slug identification): $mofagaUnbridged');
  }
  final ours = _loadOurs();
  final codes = _loadStagedCodes();

  final decisions = <Map<String, dynamic>>[];
  // Manual human decisions (Step 3 human pass). Keyed by flat palika key.
  // Entries: {district, name, chosen_name, basis:'human', evidence}.
  // Applied over tool rules; recorded verbatim in output.
  final manual = <String, Map<String, dynamic>>{};
  final manualFile = File('data/_stage/decisions_manual.json');
  if (manualFile.existsSync()) {
    final raw = jsonDecode(manualFile.readAsStringSync()) as List;
    for (final d in raw) {
      final m = (d as Map).cast<String, dynamic>();
      manual[palikaKey(m['district'] as String?, m['name'] as String?)] = m;
    }
  }

  for (final c in conflicts) {
    final k = palikaKey(c['district'], c['name']);
    final votes = <String, String>{
      for (final e in (c['votes'] as Map<String, dynamic>).entries)
        if ((e.value as String).trim().isNotEmpty) e.key: e.value as String
    };
    final found = findMofaga(mofaga, c['name'], c['district'], votes);
    final mofagaName = found.match;

    // Normalized convergence: all votes share one neKey. With MoFAGA on the
    // same key, the authority's exact orthography is adopted automatically;
    // without MoFAGA coverage a human still picks the final spelling, but
    // the converged key is recorded so the choice is mechanical, not open.
    final normSet = <String>{
      for (final v in votes.values)
        if (v.trim().isNotEmpty) neKey(v),
    }..removeWhere((s) => s.isEmpty);
    final mofagaKey = mofagaName == null ? null : neKey(mofagaName);

    String chosen = '';
    String basis;
    String? convergedKey;
    String? evidence;
    final manualDecision = manual[k];
    // MoFAGA-exact: the authority's stripped form verbatim-equals a vote.
    // Strongest signal: same district, same string, no normalization needed.
    final mofagaBare =
        mofagaName == null ? null : stripNeTypeSuffix(mofagaName);
    final exactVote = mofagaBare == null
        ? null
        : () {
            for (final v in votes.values) {
              if (v.trim().isNotEmpty && v.trim() == mofagaBare) return v;
            }
            return null;
          }();
    // Slug identification (district + palika_type + website-slug, all
    // independent of the disputed Devanagari string).
    final slugRow = _identifyMofagaRow(
        mofagaByDistrict[canonDistrict(c['district'])] ?? const [],
        ours[k]?['name'] ?? c['name'],
        ours[k]?['type'] ?? c['type']);
    if (manualDecision != null) {
      // Human ruling from the adjudication pass. Tool never second-guesses.
      chosen = manualDecision['chosen_name'] as String? ?? '';
      convergedKey = manualDecision['converged_key'] as String?;
      evidence = manualDecision['evidence'] as String?;
      basis = 'human';
    } else if (exactVote != null) {
      chosen = mofagaName!;
      convergedKey = neKey(mofagaName);
      evidence = 'MoFAGA verbatim-equals the "$exactVote" vote';
      basis = 'mofaga-exact';
    } else if (slugRow != null) {
      // Authority identification: district + palika_type + website-slug all
      // point at one MoFAGA row, independently of the disputed Devanagari
      // string. Adopting the authority's orthography; raw dissent retained.
      chosen = slugRow['name'] as String;
      convergedKey = neKey(chosen);
      evidence = 'MoFAGA row identified by district+type+website-slug '
          '(${slugRow['website']}); Devanagari adopted from authority';
      basis = 'mofaga-slug';
    } else if (votes.length == 1) {
      basis = _classify(
          votes.length, votes.values.toSet(), mofagaName, (v) => chosen = v);
    } else if (normSet.length == 1 &&
        mofagaKey != null &&
        mofagaKey == normSet.single) {
      chosen = mofagaName!;
      convergedKey = normSet.single;
      basis = 'mofaga-unanimous';
    } else if (normSet.length == 1) {
      convergedKey = normSet.single;
      basis = 'normalized-unanimous';
    } else if (mofagaName != null) {
      // Authority tiebreak: MoFAGA corroborates one normalized key while raw
      // votes genuinely diverge. The authority's exact string is adopted;
      // dissenting keys are preserved in `votes` for the audit trail.
      chosen = mofagaName;
      convergedKey = mofagaKey;
      evidence =
          'MoFAGA sides with neKey "$mofagaKey"; raw dissent retained in votes';
      basis = 'mofaga-tiebreak';
    } else {
      basis = _classify(
          votes.length, votes.values.toSet(), mofagaName, (v) => chosen = v);
    }

    decisions.add({
      'name': c['name'],
      'district': c['district'],
      'type': c['type'],
      'chosen_name': chosen,
      'basis': basis,
      'auto': basis == 'majority' ||
          basis == 'mofaga' ||
          basis == 'mofaga-unanimous' ||
          basis == 'mofaga-tiebreak' ||
          basis == 'mofaga-exact' ||
          basis == 'mofaga-slug' ||
          basis == 'human',
      'converged_key': convergedKey,
      'evidence': evidence,
      'votes': votes,
      'mofaga_name': mofagaName,
      'mofaga_district_names': found.sameDistrict,
      'has_abin': abin.containsKey(k),
      'has_sag': sag.containsKey(k),
      'has_cbs': cbs.containsKey(k),
      'has_code': codes.containsKey(k),
    });
  }

  // Ambiguity guard: one MoFAGA row corroborating two different conflicts
  // means the row is genuinely ambiguous (two palikas, one matching name).
  // Downgrade both to human — a shared corroboration decides nothing.
  final byMofagaRow = <String, List<Map<String, dynamic>>>{};
  for (final d in decisions) {
    final m = d['mofaga_name'] as String?;
    if (m == null) continue;
    final rowId = '${d['district']}|$m';
    byMofagaRow.putIfAbsent(rowId, () => []).add(d);
  }
  var ambiguous = 0;
  for (final group in byMofagaRow.values) {
    if (group.length < 2) continue;
    for (final d in group) {
      d['basis'] = 'mofaga-ambiguous';
      d['auto'] = false;
      d['evidence'] =
          'MoFAGA row also corroborates ${group.length - 1} other conflict(s); needs human';
      ambiguous++;
    }
  }

  final auto = decisions.where((d) => d['auto'] == true).length;
  final out = {
    'generated': DateTime.now().toUtc().toIso8601String(),
    'tool': 'tool/merge/adjudicate.dart',
    'rule': 'auto iff 2+ sources agree (majority), exactly one source + '
        'MoFAGA corroborates (mofaga), MoFAGA verbatim-equals a vote '
        '(mofaga-exact), all votes converge under neKey with MoFAGA on the '
        'same key (mofaga-unanimous, authority orthography adopted), or '
        'MoFAGA breaks a genuine raw split (mofaga-tiebreak); one MoFAGA row '
        'matching 2+ conflicts downgrades both (mofaga-ambiguous); '
        'normalized convergence without MoFAGA coverage stays human '
        '(normalized-unanimous, converged key recorded)',
    'total': decisions.length,
    'auto_resolved': auto,
    'needs_human': decisions.length - auto,
    'mofaga_ambiguous': ambiguous,
    'decisions': decisions,
  };
  Directory('data/_stage').createSync(recursive: true);
  File('data/_stage/adjudications.json')
      .writeAsStringSync(JsonEncoder.withIndent('  ').convert(out));
  stdout.writeln('Processed ${decisions.length} conflicts: '
      '$auto auto, ${decisions.length - auto} need human');
}

// ---- helpers -----------------------------------------------------------------

List<Map<String, dynamic>> _parseConflicts() {
  final out = <Map<String, dynamic>>[];
  var inConflict = false;
  for (final line in File('doc/REVIEW.md').readAsStringSync().split('\n')) {
    if (line.startsWith('    [CONFLICT')) inConflict = true;
    if (inConflict && line.startsWith('    [')) {
      final m = RegExp(r'^\[(CONFLICT-\d+)\]\s+(.+?)\s*\[(.+?)\]:\s*(.+)$')
          .firstMatch(line.trim());
      if (m == null) continue;
      final nd = m.group(2)!;
      final dm = RegExp(r'^\s*(.+?)\s*\[(.+?)\]$').firstMatch(nd);
      final votes = <String, String>{};
      for (final part in m.group(4)!.split(' | ')) {
        // Cut the geo-supplementary annotation before parsing, otherwise the
        // greedy regex swallows it into the last vote's value.
        final clean = part.split(' [geo-supplementary:').first.trim();
        final vm = RegExp(r'(\w+(?:-\w+)*)="([^"]*)"').firstMatch(clean);
        if (vm != null) votes[vm.group(1)!] = vm.group(2)!;
      }
      out.add({
        'type': m.group(1)!,
        // NOTE: the outer regex already split "Name [District]"; group(2) is
        // the bare name and group(3) the district. Do NOT re-parse group(2)
        // for brackets — a previous version did and silently set district
        // to '' for every conflict, which disabled all district matching.
        'name': (dm?.group(1) ?? nd).trim(),
        'district': m.group(3)!.trim(),
        'votes': votes,
      });
    }
    if (inConflict && !line.startsWith('    [')) inConflict = false;
  }
  return out;
}

final _abinD = {
  for (final d in loadJsonArray('data/_raw/abinrimal/districts.json'))
    d['code'] as String: d['name_en'] as String
};
String? _abinDistrict(Object? code) => _abinD[code as String?];

final _sagD = {
  for (final d in loadJsonArray(
      'data/_raw/local-states-nepal/dataset_districts_en.json'))
    d['id'] as int: d['name'] as String
};
String? _sagDistrict(Object? id) => _sagD[id as int?];

Map<String, List<Map<String, dynamic>>> _index(
  List<Map<String, dynamic>> rows,
  String Function(Map<String, dynamic>) keyOf,
) {
  final idx = <String, List<Map<String, dynamic>>>{};
  for (final r in rows) {
    final k = keyOf(r);
    if (k.length > 1) idx.putIfAbsent(k, () => []).add(r);
  }
  return idx;
}

Map<String, List<Map<String, String>>> _indexCbs() {
  final rows = loadSimpleCsv('data/_raw/cbs-codes/cbs_local_bodies.csv',
      ['sn', 'district', 'unit', 'ne', 'code']);
  final idx = <String, List<Map<String, String>>>{};
  for (final r in rows) {
    final k = palikaKey(r['district'], r['unit']);
    if (k.length > 1) idx.putIfAbsent(k, () => []).add(r);
  }
  return idx;
}

/// Loads MoFAGA rows, deduplicated by district|name (the directory
/// double-lists ~42 palikas across page boundaries). Returns rows + dropped
/// duplicate count. Duplicates are byte-identical repeats, so keeping the
/// first loses nothing; the count is reported for the audit trail.
({List<Map<String, dynamic>> rows, int dupes}) _loadMofaga() {
  // Full 750-row pull preferred; the original 73-row mun-prov-2 file was
  // removed as redundant once mofaga_all.json superseded it.
  for (final path in [
    'data/_raw/mofaga/mofaga_all.json',
    'data/_raw/mofaga_mun_prov2.json',
  ]) {
    final f = File(path);
    if (f.existsSync()) {
      final rows = (jsonDecode(f.readAsStringSync()) as List)
          .map((m) => (m as Map).cast<String, dynamic>())
          .toList();
      final seen = <String>{};
      final unique = <Map<String, dynamic>>[];
      var dupes = 0;
      for (final r in rows) {
        // Key on trimmed district + trimmed name: page-boundary repeats are
        // byte-identical except for occasional trailing whitespace, which
        // must not defeat the dedupe.
        final key =
            '${(r['district'] as String? ?? '').trim()}|${(r['name'] as String? ?? '').trim()}';
        if (!seen.add(key)) {
          dupes++;
          continue;
        }
        unique.add(r);
      }
      return (rows: unique, dupes: dupes);
    }
  }
  return (rows: const [], dupes: 0);
}

Map<String, bool> _loadStagedCodes() => {
      for (final a
          in (jsonDecode(File('data/_stage/nso_codes.json').readAsStringSync())
              as Map)['assignments'] as List)
        if ((a as Map)['nsoCodeVerified'] == true)
          '${(a)['province']}|${(a)['district']}|${(a)['name']}': true
    };

/// Devanagari -> our-English district name bridge. MoFAGA's table names
/// districts in Devanagari, and its orthography differs from abinrimal's in
/// 12 districts — so the bridge unions abinrimal's districts with
/// sagautam5-np's (joined to English through the shared integer id), plus
/// MoFAGA's own official spellings below (pinned by codepoint: console
/// output mangles Devanagari, so every entry here is an exact escape
/// verified against the pulled bytes).
/// Two sources mapping one Ne key to different En names would be an
/// ambiguity: the builder below keeps the first and the verifier reports it.
final _neToEn = (() {
  final bridge = <String, String>{};
  final clashes = <String>[];
  void add(String ne, String en) {
    final k = canonDistrict(ne);
    final v = canonDistrict(en);
    if (k.isEmpty || v.isEmpty) return;
    final prev = bridge[k];
    if (prev == null) {
      bridge[k] = v;
    } else if (prev != v) {
      clashes.add('Ne key "$k" maps to both "$prev" and "$v"');
    }
  }

  for (final d in loadJsonArray('data/_raw/abinrimal/districts.json')) {
    add(d['name_ne'] as String, d['name_en'] as String);
  }
  for (final d in loadJsonArray(
      'data/_raw/local-states-nepal/dataset_districts_np.json')) {
    // sag-np carries no English: resolve through the en file by id.
    add(d['name'] as String, _sagEnDistrict(d['id']));
  }
  // MoFAGA's official district spellings (mofaga_all.json pull, 2026-10-11).
  const mofagaVariants = {
    'काठमाण्डौं': 'kathmandu',
    'स्याङजा': 'syangja',
    'बाग्लुङ': 'baglung',
    'नवलपरासी (बर्दघाट सुस्ता पूर्व)': 'nawalpur',
    'रूपन्देही': 'rupandehi',
    'नवलपरासी (बर्दघाट सुस्ता पश्चिम)': 'nawalparasi west',
    'कपिलबस्तु': 'kapilvastu',
    'प्यूठान': 'pyuthan',
    'रुकुम (पूर्वी भाग)': 'rukum east',
    'रुकुम (पश्चिम भाग)': 'rukum west',
    'डडेल्धुरा': 'dadeldhura',
  };
  mofagaVariants.forEach(add);
  if (clashes.isNotEmpty) {
    stderr.writeln('DISTRICT BRIDGE CLASHES (kept first, review):');
    for (final c in clashes) {
      stderr.writeln('  $c');
    }
  }
  return bridge;
})();

final _sagEnDistrictsById = {
  for (final d in loadJsonArray(
      'data/_raw/local-states-nepal/dataset_districts_en.json'))
    d['id'] as int: d['name'] as String,
};

String _sagEnDistrict(Object? id) => _sagEnDistrictsById[id as int?] ?? '';

/// Devanagari type suffixes used by MoFAGA's table (all end in नगरपालिका).
const _neTypeSuffixes = [
  'उपमहानगरपालिका',
  'महानगरपालिका',
  'गाउँपालिका',
  'नगरपालिका',
];

/// Devanagari comparison key for MoFAGA corroboration. Collapses ONLY
/// presentation-level differences that make near-identical strings compare
/// unequal, so कंकालिनी (ka+anusvara+ka) converges with कङ्कालिनी
/// (ka+nga+virama+ka) instead of diverging:
///   - ZWJ / ZWNJ (U+200C/U+200D) removed entirely
///   - virama (U+094D) between two consonants dropped (conjunct -> pair)
///   - anusvara (U+0902) between two consonants mapped to the homorganic
///     nasal of the FOLLOWING consonant (ka-class -> nga, ca-class -> nya,
///     tta-class -> nna, ta-class -> na, pa-class -> ma); left untouched
///     anywhere else.
/// Deliberately conservative: vowel signs, spacing and all other characters
/// are untouched, so genuine spelling differences still surface as conflicts.
/// Comparison-only: source strings stay verbatim in `votes` and decisions.
String neKey(String raw) {
  var s = raw.trim();
  for (final suffix in _neTypeSuffixes) {
    if (s.endsWith(' $suffix')) {
      s = s.substring(0, s.length - suffix.length - 1).trim();
      break;
    }
    if (s == suffix) return '';
  }
  s = s.replaceAll('\u200D', '').replaceAll('\u200C', '').trim();
  int nasalFor(int next) {
    if (next >= 0x0915 && next <= 0x0918) return 0x0919; // ka-kha-ga-gha -> nga
    if (next >= 0x091A && next <= 0x091D) return 0x091E; // ca-ja -> nya
    if (next >= 0x091F && next <= 0x0922) return 0x0923; // tta -> nna
    if (next >= 0x0924 && next <= 0x0927) return 0x0928; // ta-tha-da-dha -> na
    if (next >= 0x092A && next <= 0x092D) return 0x092E; // pa-pha-ba-bha -> ma
    return -1;
  }

  final out = StringBuffer();
  final runes = s.runes.toList();
  for (var i = 0; i < runes.length; i++) {
    final c = runes[i];
    final prevCons = i > 0 && runes[i - 1] >= 0x0915 && runes[i - 1] <= 0x0939;
    final next = i + 1 < runes.length ? runes[i + 1] : -1;
    final nextCons = next >= 0x0915 && next <= 0x0939;
    if (c == 0x094D && prevCons && nextCons) continue; // conjunct -> pair
    if (c == 0x0902 && prevCons && nextCons) {
      final nasal = nasalFor(next);
      if (nasal >= 0) {
        out.writeCharCode(nasal);
        continue;
      }
    }
    out.writeCharCode(c);
  }
  return out.toString();
}

/// Slug core of a MoFAGA website: hostname minus scheme, www, TLDs and the
/// trailing mun/municipality-style suffix offices append to domains.
/// E.g. http://barahapokharimun.gov.np -> "barahapokhari".
String _slugCore(String website) {
  var s = website.toLowerCase().trim();
  s = s.replaceAll(RegExp(r'^https?://'), '');
  s = s.replaceAll(RegExp(r'^www\.'), '');
  s = s.split('/').first;
  for (final tld in [
    '.gov.np',
    '.com.np',
    '.org.np',
    '.edu.np',
    '.np',
    '.com',
    '.org',
    '.gov',
  ]) {
    if (s.endsWith(tld)) {
      s = s.substring(0, s.length - tld.length);
      break;
    }
  }
  for (final tail in [
    'ruralmunicipality',
    'ruralmun',
    'municipality',
    'gaunpalika',
    'nagarpalika',
    'mahanagarpalika',
    'upamahanagarpalika',
    'mun',
  ]) {
    if (s.endsWith(tail) && s.length > tail.length) {
      s = s.substring(0, s.length - tail.length);
      break;
    }
  }
  return s;
}

/// Loads ours palikas keyed by flat key: {type, province, name}.
Map<String, Map<String, String>> _loadOurs() {
  final ourJson =
      jsonDecode(File('data/nepal_local_levels.json').readAsStringSync())
          as Map<String, dynamic>;
  final out = <String, Map<String, String>>{};
  for (final p in ourJson['provinces'] as List) {
    final pmap = p as Map;
    for (final d in pmap['districts'] as List) {
      final dmap = d as Map;
      for (final b in dmap['localBodies'] as List) {
        final bmap = b as Map;
        out[palikaKey(dmap['name'] as String?, bmap['name'] as String?)] = {
          'province': pmap['id'] as String,
          'district': dmap['name'] as String,
          'name': bmap['name'] as String,
          'type': bmap['type'] as String,
        };
      }
    }
  }
  return out;
}

/// Identifies THE MoFAGA row for an ours palika through three independent
/// channels — same bridged district, same palika_type, slug-core matching
/// the ours English name (substring either way, else Levenshtein <= 2).
/// Returns the row, or null when zero-or-many rows qualify (human decides).
/// The Devanagari string itself is NEVER part of identification, so there is
/// no circularity in then adopting it.
Map<String, dynamic>? _identifyMofagaRow(
  List<Map<String, dynamic>> districtRows,
  String oursName,
  String oursType,
) {
  final flat = flatToken(oursName.toLowerCase().trim());
  final scored = <Map<String, dynamic>, int>{};
  for (final r in districtRows) {
    if (r['palika_type'] != oursType) continue;
    final slug = _slugCore(r['website'] as String? ?? '');
    if (slug.isEmpty) continue;
    if (slug.contains(flat) || flat.contains(slug)) {
      scored[r] = 0;
    } else if (levenshtein(slug, flat, 2) <= 2) {
      scored[r] = levenshtein(slug, flat, 2);
    }
  }
  if (scored.length != 1) return null;
  return scored.keys.single;
}

/// Finds the MoFAGA row whose Devanagari name matches a vote under neKey.
/// Returns the raw MoFAGA name plus all same-district names for review.
({String? match, List<String> sameDistrict}) findMofaga(
  List<Map<String, dynamic>> rows,
  String name,
  String district,
  Map<String, String> votes,
) {
  final wantDistrict = canonDistrict(district);
  final want = <String>{
    for (final v in votes.values)
      if (v.trim().isNotEmpty) neKey(v),
  }..removeWhere((s) => s.isEmpty);

  final sameDistrict = <String>[];
  String? match;
  for (final r in rows) {
    final rDist =
        canonDistrict(_neToEn[canonDistrict(r['district'])] ?? r['district']);
    if (rDist != wantDistrict) continue;
    sameDistrict.add(r['name'] as String? ?? '');
    if (match == null && want.contains(neKey(r['name'] ?? ''))) {
      match = r['name'] as String?;
    }
  }
  return (match: match, sameDistrict: sameDistrict);
}

String _classify(
  int votes,
  Set<String> distinct,
  String? mofaga,
  void Function(String) setChosen,
) {
  void pick(String v) => setChosen(v);
  // 2+ sources that already agree on the same string.
  if (votes >= 2 && distinct.length == 1) {
    pick(distinct.first);
    return 'majority';
  }
  // 1 source + MoFAGA corroborates the same record exists.
  if (votes == 1 && mofaga != null) {
    pick(distinct.first);
    return 'mofaga';
  }
  // No vote at all but MoFAGA has the palika: record for human entry.
  if (votes == 0 && mofaga != null) {
    pick('');
    return 'mofaga-empty';
  }
  if (votes == 1) {
    pick(distinct.first);
    return 'tie-human';
  }
  pick(distinct.isEmpty ? '' : distinct.first);
  return 'conflict-human';
}
