// tool/geocode_centroids.dart
//
// Step 5a: Merge palika centroid coordinates (lat/lng) into
// data/nepal_local_levels.json from local-first sources.
//
// Priority:
//   1. data/_raw/open-admin-data/data_all-local_unit.json (vendored, offline)
//   2. Nominatim fallback (opt-in via --geocode-network; 1 req/s, cached)
//
// Usage:
//   dart run tool/geocode_centroids.dart [--geocode-network] [--limit=N]
//
// Policy compliance (Nominatim Usage Policy):
//   - single thread, max 1 req/s, custom User-Agent with contact
//   - results cached in data/_stage/geocodes.json (re-runs hit cache)
//   - district fuzzy-match gate: reject coords whose returned district
//     does not match ours (prevents wrong-town adoption)

import 'dart:convert';
import 'dart:io';

import 'merge/common.dart';

const _levelsPath = 'data/nepal_local_levels.json';
const _localUnitsPath = 'data/_raw/open-admin-data/data_all-local_unit.json';
const _cachePath = 'data/_stage/geocodes.json';
const _ua =
    'nepal_admin_api-geocoder/1.0 (contact: realpoudel@duck.com; project: https://github.com/namunaONE/Nepal-Local-Government-Data)';

// Nepal bounding box: lat 26-31, lng 80-89.
bool _inNepal(double lat, double lng) =>
    lat >= 26.0 && lat <= 31.0 && lng >= 80.0 && lng <= 89.0;

String _norm(String s) => flatToken(
    s.toLowerCase().replaceAll(RegExp(r'\s*(rural\s+)?municipality\s*$'), ''));

int _lev(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    var cur = [i, ...List<int>.filled(b.length, 0)];
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

Future<void> main(List<String> args) async {
  final useNetwork = args.contains('--geocode-network');
  var limit = -1;
  for (final a in args) {
    if (a.startsWith('--limit=')) limit = int.tryParse(a.substring(8)) ?? -1;
  }

  final levels =
      jsonDecode(File(_levelsPath).readAsStringSync()) as Map<String, dynamic>;
  final provinces = (levels['provinces'] as List).cast<Map<String, dynamic>>();

  // Index vendored local units by district|norm-name.
  final rawUnits =
      (jsonDecode(File(_localUnitsPath).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
  final byDistrictName = <String, List<Map<String, dynamic>>>{};
  for (final u in rawUnits) {
    final geo = u['geo'] as Map<String, dynamic>?;
    final lat = double.tryParse('${geo?['lat'] ?? ''}');
    final lng = double.tryParse('${geo?['lon'] ?? geo?['lng'] ?? ''}');
    if (lat == null || lng == null || !_inNepal(lat, lng)) continue;
    final parent = u['parent'] as Map<String, dynamic>?;
    final district = canonDistrict(
        (parent?['name'] as Map<String, dynamic>?)?['en'] as String? ?? '');
    final nameEn = (u['name'] as Map<String, dynamic>)['en'] as String? ?? '';
    byDistrictName
        .putIfAbsent(district, () => [])
        .add({'name': nameEn, 'norm': _norm(nameEn), 'lat': lat, 'lng': lng});
  }

  // Load network cache.
  final cacheFile = File(_cachePath);
  final cache = <String, dynamic>{
    if (cacheFile.existsSync())
      ...(jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>),
  };

  var localHits = 0;
  var netHits = 0;
  var cacheHits = 0;
  var missing = 0;
  var processed = 0;

  for (final province in provinces) {
    for (final district
        in (province['districts'] as List).cast<Map<String, dynamic>>()) {
      final dName = district['name'] as String;
      final dKey = canonDistrict(dName);
      for (final body
          in (district['localBodies'] as List).cast<Map<String, dynamic>>()) {
        if (limit >= 0 && processed >= limit) break;
        processed++;
        final name = body['name'] as String;
        final key = '$dKey|${_norm(name)}';

        // 1. Local-first match within same district.
        Map<String, dynamic>? best;
        var bestDist = 999;
        for (final cand in byDistrictName[dKey] ?? const []) {
          final d = _lev(_norm(name), cand['norm'] as String);
          if (d < bestDist) {
            bestDist = d;
            best = cand;
          }
        }
        // Accept exact or close fuzzy (typo-level) match.
        if (best != null && bestDist <= 2) {
          body['lat'] = best['lat'];
          body['lng'] = best['lng'];
          body['geoSource'] = 'open-admin-data';
          localHits++;
          continue;
        }

        // 2. Network cache.
        if (cache.containsKey(key)) {
          final c = cache[key] as Map<String, dynamic>;
          if (c['lat'] != null) {
            body['lat'] = c['lat'];
            body['lng'] = c['lng'];
            body['geoSource'] = c['geoSource'];
            cacheHits++;
          } else {
            missing++;
          }
          continue;
        }

        // 3. Nominatim fallback (opt-in only).
        if (!useNetwork) {
          missing++;
          continue;
        }
        final result = await _geocodeNominatim(name, dName);
        // Rate limit: 1 req/s.
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        if (result != null) {
          body['lat'] = result['lat'];
          body['lng'] = result['lng'];
          body['geoSource'] = 'osm-nominatim';
          cache[key] = result;
          netHits++;
        } else {
          cache[key] = {'lat': null};
          missing++;
        }
      }
    }
  }

  // Persist cache + updated levels.
  cacheFile
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(cache));
  const encoder = JsonEncoder.withIndent('  ');
  File(_levelsPath).writeAsStringSync(encoder.convert(levels));

  stdout.writeln('Centroids: $localHits local + $cacheHits cache + '
      '$netHits network = ${localHits + cacheHits + netHits}/$processed '
      '($missing without coordinates)');
}

Future<Map<String, dynamic>?> _geocodeNominatim(
    String palika, String district) async {
  final q = Uri.encodeComponent('$palika, $district, Nepal');
  final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$q&format=json&limit=3&countrycodes=np');
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    req.headers.set('User-Agent', _ua);
    req.headers.set('Accept', 'application/json');
    final resp = await req.close();
    if (resp.statusCode != 200) {
      stderr.writeln('Nominatim HTTP ${resp.statusCode} for $palika');
      return null;
    }
    final list = jsonDecode(await resp.transform(utf8.decoder).join()) as List;
    for (final r in list.cast<Map<String, dynamic>>()) {
      final lat = double.tryParse('${r['lat']}');
      final lng = double.tryParse('${r['lon']}');
      if (lat == null || lng == null || !_inNepal(lat, lng)) continue;
      // District gate: display_name must mention our district (fuzzy).
      final display = '${r['display_name']}'.toLowerCase();
      if (!display.contains(district.toLowerCase()) &&
          _lev(display, district.toLowerCase()) > 3) {
        continue;
      }
      return {'lat': lat, 'lng': lng, 'geoSource': 'osm-nominatim'};
    }
  } catch (e) {
    stderr.writeln('Nominatim error for $palika: $e');
  } finally {
    client.close();
  }
  return null;
}
