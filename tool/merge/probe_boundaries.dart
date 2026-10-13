// tool/merge/probe_boundaries.dart — DIAGNOSTIC ONLY, does not write.
//
// Reconciles the vendored boundary GeoJSON against the 753 gazetted local
// bodies and reports what would be required to ship polygons. This exists to
// answer one question with evidence rather than assumption: is
// data/_raw/boundaries/oknp_local_levels.geojson the same vintage as the
// dataset, or an older administrative structure?
//
// Usage (from the package root):
//   dart run tool/merge/probe_boundaries.dart
//
// Writes nothing. If the answer turns out to be "shippable", this becomes the
// basis of tool/merge/attach_boundaries.dart.

import 'dart:convert';
import 'dart:io';

import 'common.dart';

Never _fail(String message) {
  stderr.writeln('PROBE FAILED: $message');
  exit(1);
}

/// The source writes district names in UPPER_SNAKE_CASE with underscores
/// (NAWALPARASI_E); the dataset writes them in title case with spaces
/// (Nawalparasi East). Fold both to the same canonical key.
String canonBoundaryDistrict(String? raw) {
  final base = canonDistrict(raw).replaceAll('_', ' ');
  final n = base.replaceAll(RegExp(r'\s+'), ' ').trim();
  const folds = {
    // The harvest's spellings, each observed in the file:
    'kabhrepalanchok': 'kavrepalanchok',
    'kabhre palanchok': 'kavrepalanchok',
    'makawanpur': 'makwanpur',
  };
  return folds[n] ?? n;
}

void main() {
  if (verifyProvenance().isNotEmpty) {
    _fail('provenance check failed; run the merge tools instead');
  }

  final ours = jsonDecode(
    File('data/nepal_local_levels.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final ourByDistrict = <String, List<String>>{};
  for (final p in ours['provinces'] as List) {
    for (final d in (p as Map)['districts'] as List) {
      final dm = d as Map<String, dynamic>;
      ourByDistrict[canonBoundaryDistrict('${dm['name']}')] = [
        for (final b in dm['localBodies'] as List) (b as Map)['name'] as String,
      ];
    }
  }

  final geo = jsonDecode(
    File('data/_raw/boundaries/oknp_local_levels.geojson').readAsStringSync(),
  ) as Map<String, dynamic>;
  final features = geo['features'] as List;

  stdout.writeln('=' * 78);
  stdout.writeln('BOUNDARY SOURCE RECONCILIATION (diagnostic, writes nothing)');
  stdout.writeln('vendored features: ${features.length}');
  stdout.writeln('=' * 78);

  // ---- 1. what kinds of things are in there? ----
  final byType = <String, int>{};
  for (final f in features) {
    final p = (f as Map)['properties'] as Map<String, dynamic>;
    final t = '${p['Type_GN']}';
    byType[t] = (byType[t] ?? 0) + 1;
  }
  stdout.writeln('\n1. FEATURE TYPES');
  final sorted = byType.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final e in sorted) {
    stdout.writeln('   ${e.value.toString().padLeft(4)}  ${e.key}');
  }
  const palikaTypes = {
    'Gaunpalika',
    'Nagarpalika',
    'Mahanagarpalika',
    'Upamahanagarpalika',
  };
  final palikaCount = palikaTypes.fold<int>(0, (s, t) => s + (byType[t] ?? 0));
  final nonPalika = features.length - palikaCount;
  stdout.writeln('   -> $palikaCount palika-type, $nonPalika NOT palikas '
      '(parks, reserves, conservation areas)');

  // ---- 2. geometry health ----
  var rings = 0, unclosed = 0, degenerate = 0, points = 0, maxRing = 0;
  var bboxOk = true;
  double? minX, minY, maxX, maxY;
  for (final f in features) {
    final g = (f as Map)['geometry'];
    if (g == null) continue;
    final gm = g as Map<String, dynamic>;
    if (gm['type'] != 'Polygon') continue;
    for (final r in gm['coordinates'] as List) {
      final ring = (r as List).cast<List>();
      rings++;
      points += ring.length;
      if (ring.length > maxRing) maxRing = ring.length;
      if (ring.length < 4) degenerate++;
      final a = ring.first, b = ring.last;
      if (a[0] != b[0] || a[1] != b[1]) unclosed++;
      for (final p in ring) {
        final x = (p[0] as num).toDouble();
        final y = (p[1] as num).toDouble();
        if (minX == null || x < minX) minX = x;
        if (maxX == null || x > maxX) maxX = x;
        if (minY == null || y < minY) minY = y;
        if (maxY == null || y > maxY) maxY = y;
      }
    }
  }
  stdout.writeln('\n2. GEOMETRY HEALTH');
  stdout.writeln('   rings: $rings | points: $points | max ring: $maxRing');
  stdout.writeln('   UNCLOSED rings: $unclosed  '
      '(RFC 7946 requires the first and last position to be identical)');
  stdout.writeln('   degenerate rings (<4 positions): $degenerate');
  if (minX != null) {
    stdout.writeln('   bbox: lng $minX..$maxX, lat $minY..$maxY');
    if (minX < 80 || maxX! > 89 || minY! < 26 || maxY! > 31) {
      bboxOk = false;
      stdout
          .writeln("   WARNING: coordinates fall outside Nepal's bounding box");
    }
  }

  // ---- 3. name matching with proper district folding ----
  final candidates = <String, List<int>>{};
  for (var i = 0; i < features.length; i++) {
    final p = (features[i] as Map)['properties'] as Map<String, dynamic>;
    if (!palikaTypes.contains('${p['Type_GN']}')) continue;
    candidates
        .putIfAbsent(canonBoundaryDistrict('${p['DISTRICT']}'), () => [])
        .add(i);
  }

  var exact = 0, d1 = 0, d2 = 0, tie = 0, none = 0;
  // Start from every palika-type feature so that whatever the matcher does not
  // claim remains visible in the report.
  final unclaimed = <int>{
    for (var i = 0; i < features.length; i++)
      if (palikaTypes
          .contains('${(features[i] as Map)['properties']!['Type_GN']}'))
        i,
  };
  final pairs = <String>[];
  final unmatched = <String>[];

  for (final entry in ourByDistrict.entries) {
    final cands = candidates[entry.key] ?? const [];
    final taken = <int>{};
    for (final name in entry.value) {
      final key = flatToken(normCbsKey(name));
      final scored = <List<dynamic>>[];
      for (final i in cands) {
        if (taken.contains(i)) continue;
        final p = (features[i] as Map)['properties'] as Map<String, dynamic>;
        final d =
            levenshtein(key, flatToken(normCbsKey('${p['GaPa_NaPa']}')), 3);
        if (d <= 2) scored.add([i, d]);
      }
      scored.sort((a, b) => (a[1] as int).compareTo(b[1] as int));
      if (scored.isEmpty) {
        none++;
        unmatched.add('${entry.key} / $name');
        continue;
      }
      final best = scored.first[1] as int;
      final runnerUp = scored.length > 1 ? scored[1][1] as int : null;
      if (runnerUp != null && runnerUp <= best) {
        tie++;
        unmatched.add('${entry.key} / $name (ambiguous)');
        continue;
      }
      final idx = scored.first[0] as int;
      taken.add(idx);
      unclaimed.remove(idx);
      if (best == 0) {
        exact++;
      } else {
        if (best == 1) {
          d1++;
        } else {
          d2++;
        }
        pairs.add('${entry.key}: "$name" <- '
            '"${(features[idx] as Map)['properties']['GaPa_NaPa']}" (d=$best)');
      }
    }
  }

  final matched = exact + d1 + d2;
  stdout.writeln('\n3. NAME MATCHING (district-scoped, distance <= 2)');
  stdout.writeln('   exact=$exact  d1=$d1  d2=$d2  ambiguous=$tie  '
      'unmatched=$none');
  stdout.writeln('   COVERAGE: $matched/753 '
      '(${(100 * matched / 753).toStringAsFixed(1)}%)');
  stdout.writeln('   palika-type features left unclaimed: $unclaimed');

  stdout.writeln('\n   all d=2 pairings (the risky ones) - count $d2:');
  for (final p in pairs.where((s) => s.contains('d=2')).take(30)) {
    stdout.writeln('     $p');
  }

  stdout.writeln('\n4. WHAT THE UNCLAIMED FEATURES ARE');
  // A pre-2017 vintage contains units that were later split or renamed.
  // Compare each unclaimed feature's name against our roster district by
  // district: a close variant means a rename, a far one means a split unit.
  var renameLike = 0, splitLike = 0;
  final splitExamples = <String>[];
  for (final i in unclaimed) {
    final p = (features[i] as Map)['properties'] as Map<String, dynamic>;
    final dist = canonBoundaryDistrict('${p['DISTRICT']}');
    final gname = '${p['GaPa_NaPa']}';
    var best = 99;
    for (final n in (ourByDistrict[dist] ?? const <String>[])) {
      final d = levenshtein(
          flatToken(normCbsKey(gname)), flatToken(normCbsKey(n)), 5);
      if (d < best) best = d;
    }
    if (best <= 3) {
      renameLike++;
    } else {
      splitLike++;
      if (splitExamples.length < 14) {
        splitExamples
            .add('   ${p['DISTRICT']} / $gname  (nearest ours d=$best)');
      }
    }
  }
  stdout.writeln('   close variant of one of ours (d<=3): $renameLike');
  stdout.writeln('   NO close match to any current palika:  $splitLike');
  stdout.writeln('   examples of the latter:');
  for (final s in splitExamples) {
    stdout.writeln('     $s');
  }

  stdout.writeln('\n${'=' * 78}');
  stdout.writeln('VERDICT INPUTS');
  stdout.writeln('  non-palika features present      : $nonPalika');
  stdout.writeln('  unclosed rings                  : $unclosed / $rings');
  stdout.writeln('  degenerate rings                : $degenerate');
  stdout.writeln('  polygon coverage of our 753     : $matched');
  stdout.writeln('  unclaimed features w/ no match   : $splitLike');
  stdout.writeln('  bbox sane                       : $bboxOk');
  stdout.writeln('=' * 78);
}
