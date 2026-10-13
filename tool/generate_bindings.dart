// tool/generate_bindings.dart — emit non-Dart bindings from the one dataset.
//
// Why this exists
// ---------------
// `data/nepal_local_levels.json` is the single source of truth. Until now the
// only thing generated from it was the Dart package and the website payload,
// so the dataset was only reachable from Dart. That is a real ceiling: most
// people who want Nepal's administrative structure are reaching for pandas,
// pandas-adjacent CSV, or a JavaScript map, and re-typing 753 rows by hand
// into a spreadsheet is what we are trying to stop.
//
// Every artifact below is emitted from one in-memory projection, so the
// bindings cannot drift apart from each other or from the Dart package. CI
// regenerates and diffs them, exactly as it does for lib/src/nepal_data.dart.
//
// What is generated, and why each shape:
//   csv/       three flat files. For pandas, Excel, R, QGIS, or a merge
//              against a voter register. No runtime, no install.
//   geojson/   centroid FeatureCollections (RFC 7946, WGS84). For web maps,
//              leaflet/geojson.io/QGIS. Centroids, NOT boundaries - see the
//              note below.
//   javascript/ an npm-ready package with a query API mirroring the Dart one,
//              plus .d.ts types. No dependencies.
//   python/    a PyPI-ready package, pure stdlib, no dependencies.
//
// Boundaries are deliberately NOT included. The only geometry vendored is
// data/_raw/boundaries/oknp_local_levels.geojson, which ships 777 features
// against the gazetted 753 and is quarantined pending review (see
// data/SOURCES.md). Shipping centroids now means a map works today and a
// polygon layer can be added later without changing this file's contract.
//
// Determinism
// -----------
// Output is byte-stable: fixed ordering, LF line endings, UTF-8 without BOM,
// no timestamps. Running the generator twice produces identical bytes, which
// is what lets CI use a plain `git diff --exit-code`.
//
// Usage (from the package root):
//   dart run tool/generate_bindings.dart           # write
//   dart run tool/generate_bindings.dart --dry-run # report without writing

import 'dart:convert';
import 'dart:io';

const _outRoot = 'bindings';

Never _fail(String message) {
  stderr.writeln('GENERATE_BINDINGS FAILED: $message');
  exit(1);
}

/// Every generated binding embeds the third-party attribution the data is
/// licensed under. CC-BY-4.0 requires visible attribution in the distributed
/// artifact, so it travels with each package rather than only living in the
/// repository's NOTICE.
const _attribution = '''
THIRD-PARTY DATA ATTRIBUTION

This package redistributes a dataset adapted from third-party sources under
Creative Commons Attribution 4.0 International (CC-BY-4.0) and Creative
Commons Attribution (CC-BY).

  1. Nepal Administrative Divisions (open-admin-data)
     https://github.com/open-admin-data/nepal-administrative-divisions
     CC-BY-4.0 - https://creativecommons.org/licenses/by/4.0/
     Used for: coordinates, postal codes, Devanagari names (second source).

  2. Geographical Codes for States, Districts and Local Bodies
     (Open Data Nepal, harvested from the Central Bureau of Statistics)
     https://opendatanepal.com/dataset/geographical-codes-for-states-districts-and-local-bodies
     CC-BY - https://creativecommons.org/licenses/by/4.0/
     Used for: the authoritative CBS hierarchical codes, and the official
     contact block for local bodies.

  3. local-states-nepal (sagautam5) and nepal-administrative-divisions-json
     (abinrimal) - MIT licensed.
     Used for: ward counts, district headquarters, area, official websites,
     and the primary Devanagari names.

The package's own code is MIT-licensed. Per-field provenance, including
retrieval dates and the SHA-256 manifest, lives in the project repository at
https://github.com/namunaONE/Nepal-Local-Government-Data
(see NOTICE and data/SOURCES.md).

Not affiliated with the Government of Nepal.
''';

const _mitLicense = '''
MIT License

Copyright (c) namunaONE

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';

/// Version is read from pubspec.yaml so the bindings cannot advertise a
/// version the Dart package does not have.
String _readVersion() {
  final text = File('pubspec.yaml').readAsStringSync();
  final m = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(text);
  if (m == null) _fail('could not read version from pubspec.yaml');
  return m.group(1)!;
}

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');

  final dataFile = File('data/nepal_local_levels.json');
  if (!dataFile.existsSync()) {
    _fail(
        'data/nepal_local_levels.json not found - run from the package root.');
  }
  final version = _readVersion();
  final json = jsonDecode(dataFile.readAsStringSync()) as Map<String, dynamic>;

  final meta = json['meta'] as Map<String, dynamic>;
  final dataAsOf = meta['dataAsOf'] as String;
  final totals = meta['totals'] as Map<String, dynamic>;

  // ---- Build the one projection every emitter reads ----------------------
  final provinces = <Map<String, dynamic>>[];
  final districts = <Map<String, dynamic>>[];
  final localBodies = <Map<String, dynamic>>[];

  for (final p in json['provinces'] as List) {
    final pm = p as Map<String, dynamic>;
    final provName = pm['name'] as String;
    final provIso = pm['isoCode'] as String;

    var mCount = 0, sCount = 0, munCount = 0, rmCount = 0;
    final dists = <Map<String, dynamic>>[];

    for (final d in pm['districts'] as List) {
      final dm = d as Map<String, dynamic>;
      final dName = dm['name'] as String;

      var dWards = 0;
      final bodies = <Map<String, dynamic>>[];
      for (final b in dm['localBodies'] as List) {
        final bm = b as Map<String, dynamic>;
        final type = bm['type'] as String;
        final w = bm['wards'] as int?;
        dWards += w ?? 0;
        switch (type) {
          case 'metropolitan':
            mCount++;
          case 'subMetropolitan':
            sCount++;
          case 'municipality':
            munCount++;
          case 'ruralMunicipality':
            rmCount++;
        }
        bodies.add(<String, dynamic>{
          'name': bm['name'],
          if (bm['nameNe'] != null) 'nameNe': bm['nameNe'],
          'nameNeVerified': bm['nameNeVerified'] == true,
          'type': type,
          'district': dName,
          if (dm['nameNe'] != null) 'districtNe': dm['nameNe'],
          'province': provName,
          'isoCode': provIso,
          'cbsCode': bm['cbsCode'],
          'cbsCodeVerified': bm['cbsCodeVerified'] == true,
          'cbsCodeConfidence': bm['cbsCodeConfidence'] ?? 'unverified',
          'lat': bm['lat'],
          'lng': bm['lng'],
          if (bm['geoSource'] != null) 'geoSource': bm['geoSource'],
          'wards': w,
          'wardsVerified': bm['wardsVerified'] == true,
          if (bm['website'] != null) 'website': bm['website'],
          if (bm['email'] != null) 'email': bm['email'],
          if (bm['phone'] != null) 'phone': bm['phone'],
          if (bm['zipCodes'] != null)
            'zipCodes': [for (final z in bm['zipCodes'] as List) '$z'],
        });
      }
      final record = <String, dynamic>{
        'name': dName,
        if (dm['nameNe'] != null) 'nameNe': dm['nameNe'],
        'nameNeVerified': dm['nameNeVerified'] == true,
        'cbsCode': dm['cbsCode'],
        'province': provName,
        'isoCode': provIso,
        if (dm['headquarter'] != null) 'headquarter': dm['headquarter'],
        if (dm['areaSqKm'] != null) 'areaSqKm': dm['areaSqKm'],
        if (dm['website'] != null) 'website': dm['website'],
        'localBodyCount': bodies.length,
        'wards': dWards,
      };
      dists.add(record);
      districts.add(record);
      localBodies.addAll(bodies);
    }

    provinces.add(<String, dynamic>{
      'id': pm['id'],
      'name': provName,
      if (pm['nameNe'] != null) 'nameNe': pm['nameNe'],
      'nameNeVerified': pm['nameNeVerified'] == true,
      'cbsCode': pm['cbsCode'],
      'isoCode': provIso,
      if (pm['capital'] != null) 'capital': pm['capital'],
      if (pm['areaSqKm'] != null) 'areaSqKm': pm['areaSqKm'],
      if (pm['website'] != null) 'website': pm['website'],
      'districtCount': dists.length,
      'localBodyCount': mCount + sCount + munCount + rmCount,
      'wards': pm['wards'],
      'districts': dists,
    });
  }

  // Coverage counters, reported on every run and mirrored into meta so a
  // regression cannot slip past unnoticed.
  final withCode = localBodies.where((b) => b['cbsCode'] != null).length;
  final doubled =
      localBodies.where((b) => b['cbsCodeConfidence'] == 'verified').length;
  final withNameNe = localBodies.where((b) => b['nameNe'] != null).length;
  final nameNeVerified =
      localBodies.where((b) => b['nameNeVerified'] == true).length;
  final mapped =
      localBodies.where((b) => b['lat'] != null && b['lng'] != null).length;
  final warded = localBodies.where((b) => b['wards'] != null).length;
  final withContact = localBodies
      .where((b) =>
          b['website'] != null || b['email'] != null || b['phone'] != null)
      .length;
  final withZip = localBodies
      .where((b) => (b['zipCodes'] as List?)?.isNotEmpty ?? false)
      .length;
  final substantiatedWards =
      localBodies.fold<int>(0, (s, b) => s + (b['wards'] as int? ?? 0));
  final declaredWards = (totals['wards'] as int);

  void check(bool cond, String message) {
    if (!cond) _fail(message);
    stdout.writeln('  ok: $message');
  }

  check(provinces.length == 7, '7 provinces');
  check(districts.length == 77, '77 districts');
  check(localBodies.length == 753, '753 local bodies');
  check(
      localBodies
              .map((b) => b['cbsCode'])
              .where((c) => c != null)
              .toSet()
              .length ==
          withCode,
      'CBS codes are unique');
  check(withCode >= 700, 'at least 700 palikas carry a code (got $withCode)');
  check(
    withNameNe >= 700,
    'at least 700 palikas carry a Devanagari name (got $withNameNe)',
  );
  check(districts.every((d) => d['nameNe'] != null),
      'every district has a Devanagari name');

  final bindingMeta = <String, dynamic>{
    'name': 'Nepal administrative divisions',
    'version': version,
    'dataAsOf': dataAsOf,
    'source': meta['source'],
    'totals': totals,
    'coverage': {
      'localBodies': localBodies.length,
      'districts': districts.length,
      'provinces': provinces.length,
      'withCbsCode': withCode,
      'doublyAttestedCodes': doubled,
      'singleSourceCodes': withCode - doubled,
      'withNameNe': withNameNe,
      'nameNeCorroborated': nameNeVerified,
      'withCoordinates': mapped,
      'withWards': warded,
      'withContact': withContact,
      'withZipCodes': withZip,
      'declaredWards': declaredWards,
      'substantiatedWards': substantiatedWards,
    },
  };

  final written = <String>[];
  void emit(String relPath, String contents) {
    final file = File('$_outRoot/$relPath');
    if (!dryRun) {
      file.parent.createSync(recursive: true);
      // writeAsStringSync with an explicit '\n' keeps the repository on LF
      // per .gitattributes, regardless of platform.
      file.writeAsStringSync(contents, encoding: utf8, flush: true);
    }
    written.add('$relPath (${contents.length} bytes)');
  }

  const indent = JsonEncoder.withIndent('  ');

  // ---- CSV ---------------------------------------------------------------
  emit(
      'csv/provinces.csv',
      _csv(provinces, const [
        'id',
        'name',
        'nameNe',
        'nameNeVerified',
        'cbsCode',
        'isoCode',
        'capital',
        'areaSqKm',
        'website',
        'districtCount',
        'localBodyCount',
        'wards',
      ]));
  emit(
      'csv/districts.csv',
      _csv(districts, const [
        'name',
        'nameNe',
        'nameNeVerified',
        'cbsCode',
        'province',
        'isoCode',
        'headquarter',
        'areaSqKm',
        'website',
        'localBodyCount',
        'wards',
      ]));
  emit(
      'csv/local_bodies.csv',
      _csv(localBodies, const [
        'name',
        'nameNe',
        'nameNeVerified',
        'type',
        'district',
        'districtNe',
        'province',
        'isoCode',
        'cbsCode',
        'cbsCodeConfidence',
        'lat',
        'lng',
        'geoSource',
        'wards',
        'wardsVerified',
        'website',
        'email',
        'phone',
        'zipCodes',
      ]));

  // ---- GeoJSON (centroids; RFC 7946) -------------------------------------
  emit('geojson/local-bodies.centroids.geojson',
      _geojson(localBodies.where((b) => b['lat'] != null).toList()));
  emit('geojson/districts.centroids.geojson',
      _districtCentroidsGeojson(districts, localBodies));
  emit('geojson/provinces.centroids.geojson',
      _provinceCentroidsGeojson(provinces, districts, localBodies));

  // ---- shared data payload ------------------------------------------------
  final payload = <String, dynamic>{
    'meta': bindingMeta,
    'provinces': [
      for (final p in provinces)
        {
          // Strip the nested district array: the flat arrays are the API.
          ...p,
        }..remove('districts'),
    ],
    'districts': districts,
    'localBodies': localBodies,
  };
  emit('javascript/data.json', '${indent.convert(payload)}\n');
  emit('python/nepal_admin/data.json', '${indent.convert(payload)}\n');

  // ---- JavaScript package -------------------------------------------------
  emit(
      'javascript/package.json',
      _jsonFile({
        'name': 'nepal-admin-data',
        'version': version,
        'description':
            'Offline administrative divisions of Nepal — 7 provinces, 77 districts, '
                '753 local bodies, 6,743 wards. CBS codes, Devanagari names, '
                'coordinates, ward counts. Zero dependencies.',
        'keywords': [
          'nepal',
          'geography',
          'admin',
          'districts',
          'municipality',
          'palika',
          'open-data',
        ],
        'license': 'MIT',
        'type': 'commonjs',
        'main': 'index.js',
        'types': 'index.d.ts',
        'exports': {
          '.': {
            'types': './index.d.ts',
            'default': './index.js',
          },
          './data.json': './data.json',
          './csv/*': './csv/*',
        },
        'files': [
          'index.js',
          'index.d.ts',
          'data.json',
          'csv',
          'NOTICE',
          'LICENSE',
        ],
        'engines': {'node': '>=14'},
      }));
  // The runtime bodies are const strings with placeholders, so substitution
  // happens here rather than by building them as functions.
  emit('javascript/index.js', _jsRuntime.replaceAll('DATA_AS_OF', dataAsOf));
  emit('javascript/index.d.ts', _jsTypes);
  emit('javascript/LICENSE', _mitLicense);
  emit('javascript/NOTICE', _attribution);
  emit('javascript/README.md', _jsReadme(version, dataAsOf));

  // ---- Python package -----------------------------------------------------
  emit('python/pyproject.toml', _pyProject(version));
  emit(
      'python/nepal_admin/__init__.py',
      _pyRuntime
          .replaceAll('VERSION_PLACEHOLDER', version)
          .replaceAll('DATA_AS_OF', dataAsOf));
  emit('python/nepal_admin/__main__.py', _pyMain);
  emit('python/LICENSE', _mitLicense);
  emit('python/NOTICE', _attribution);
  emit('python/README.md', _pyReadme(version, dataAsOf));

  // ---- bindings index -----------------------------------------------------
  emit('meta.json', '${indent.convert(bindingMeta)}\n');
  emit('README.md', _bindingsReadme(version, dataAsOf, written.length));

  stdout.writeln('');
  stdout.writeln('coverage: $withCode/${localBodies.length} codes '
      '($doubled doubly-attested), $withNameNe/${localBodies.length} Devanagari '
      '($nameNeVerified corroborated), $mapped mapped, $warded ward counts, '
      '$withContact contact, $withZip postal codes');
  stdout.writeln('wards: $declaredWards declared, $substantiatedWards '
      'substantiated (difference ${declaredWards - substantiatedWards})');
  stdout.writeln('');
  stdout
      .writeln('${dryRun ? 'DRY RUN - nothing written. Would emit' : 'Wrote'} '
          '${written.length} files under $_outRoot/:');
  for (final w in written) {
    stdout.writeln('  $_outRoot/$w');
  }
}

// ---------------------------------------------------------------------------
// Emitters
// ---------------------------------------------------------------------------

String _jsonFile(Map<String, dynamic> m) =>
    '${const JsonEncoder.withIndent('  ').convert(m)}\n';

/// Minimal RFC 4180 CSV: quote any field holding a comma, quote, CR or LF.
/// zipCodes are lists and become a space-separated string, which is what a
/// spreadsheet column can hold.
String _csv(List<Map<String, dynamic>> rows, List<String> columns) {
  final out = StringBuffer();
  out.writeln(columns.join(','));
  for (final row in rows) {
    out.writeln(columns.map((c) {
      final v = row[c];
      if (v == null) return '';
      final s = v is List ? v.join(' ') : '$v';
      if (s.isEmpty) return '';
      if (s.contains(',') ||
          s.contains('"') ||
          s.contains('\n') ||
          s.contains('\r')) {
        return '"${s.replaceAll('"', '""')}"';
      }
      return s;
    }).join(','));
  }
  return out.toString();
}

/// RFC 7946 FeatureCollection. `crs` is deliberately omitted: RFC 7946 fixes
/// the CRS to WGS84 and deprecates the member.
String _geojson(List<Map<String, dynamic>> rows) {
  final features = <Map<String, dynamic>>[];
  for (final r in rows) {
    final double? lat = (r['lat'] as num?)?.toDouble();
    final double? lng = (r['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) continue;
    final properties = <String, dynamic>{};
    for (final e in r.entries) {
      if (e.key == 'lat' || e.key == 'lng') continue;
      properties[e.key] = e.value;
    }
    features.add({
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [lng, lat]
      },
      'properties': properties,
    });
  }
  return '${const JsonEncoder.withIndent('  ').convert({
        'type': 'FeatureCollection',
        'features': features,
      })}\n';
}

/// District and province centroids are not in the dataset, so they are the
/// mean of the centroids of their members. That is an approximation and is
/// labelled as such in every feature's `centroidMethod` property.
(double, double) _meanOf(List<(double, double)> pts) {
  final l = pts.map((e) => e.$1).reduce((a, b) => a + b) / pts.length;
  final g = pts.map((e) => e.$2).reduce((a, b) => a + b) / pts.length;
  return (l, g);
}

/// Groups mapped local bodies by their district name.
Map<String, List<(double, double)>> _ptsByDistrict(
    List<Map<String, dynamic>> bodies) {
  final out = <String, List<(double, double)>>{};
  for (final b in bodies) {
    final lat = (b['lat'] as num?)?.toDouble();
    final lng = (b['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) continue;
    out.putIfAbsent(b['district'] as String, () => []).add((lat, lng));
  }
  return out;
}

/// Builds an RFC 7946 Point feature. [centre] is a positional
/// (lat, lng) record, matching the tuple order used throughout.
Map<String, dynamic> _pointFeature(
    (double, double) centre, Map<String, dynamic> properties) {
  return {
    'type': 'Feature',
    'geometry': {
      'type': 'Point',
      'coordinates': [
        double.parse(centre.$2.toStringAsFixed(6)),
        double.parse(centre.$1.toStringAsFixed(6)),
      ],
    },
    'properties': properties,
  };
}

String _collection(List<Map<String, dynamic>> features) =>
    '${const JsonEncoder.withIndent('  ').convert({
          'type': 'FeatureCollection',
          'features': features,
        })}\n';

String _districtCentroidsGeojson(
  List<Map<String, dynamic>> districts,
  List<Map<String, dynamic>> bodies,
) {
  final byDistrict = _ptsByDistrict(bodies);
  final features = <Map<String, dynamic>>[];
  for (final d in districts) {
    final pts = byDistrict[d['name'] as String] ?? const [];
    if (pts.isEmpty) continue;
    features.add(_pointFeature(_meanOf([...pts]), {
      'name': d['name'],
      if (d['nameNe'] != null) 'nameNe': d['nameNe'],
      'nameNeVerified': d['nameNeVerified'],
      'cbsCode': d['cbsCode'],
      'province': d['province'],
      'isoCode': d['isoCode'],
      if (d['headquarter'] != null) 'headquarter': d['headquarter'],
      if (d['areaSqKm'] != null) 'areaSqKm': d['areaSqKm'],
      'localBodyCount': d['localBodyCount'],
      'wards': d['wards'],
      'centroidMethod': 'mean of mapped local-body centroids (approximate)',
      'derivedFrom': '${pts.length} mapped local bodies',
    }));
  }
  return _collection(features);
}

String _provinceCentroidsGeojson(
  List<Map<String, dynamic>> provinces,
  List<Map<String, dynamic>> districts,
  List<Map<String, dynamic>> bodies,
) {
  final byDistrict = _ptsByDistrict(bodies);
  final districtsOf = <String, List<String>>{};
  for (final d in districts) {
    districtsOf
        .putIfAbsent(d['province'] as String, () => [])
        .add(d['name'] as String);
  }
  final features = <Map<String, dynamic>>[];
  for (final p in provinces) {
    final pts = <(double, double)>[];
    for (final dName in districtsOf[p['name'] as String] ?? const <String>[]) {
      pts.addAll(byDistrict[dName] ?? const []);
    }
    if (pts.isEmpty) continue;
    features.add(_pointFeature(_meanOf(pts), {
      'id': p['id'],
      'name': p['name'],
      if (p['nameNe'] != null) 'nameNe': p['nameNe'],
      'nameNeVerified': p['nameNeVerified'],
      'cbsCode': p['cbsCode'],
      'isoCode': p['isoCode'],
      if (p['capital'] != null) 'capital': p['capital'],
      if (p['areaSqKm'] != null) 'areaSqKm': p['areaSqKm'],
      'districtCount': p['districtCount'],
      'localBodyCount': p['localBodyCount'],
      'wards': p['wards'],
      'centroidMethod': 'mean of mapped local-body centroids (approximate)',
      'derivedFrom': '${pts.length} mapped local bodies',
    }));
  }
  return _collection(features);
}

const _jsRuntime = r'''
'use strict';

// nepal-admin-data — offline administrative divisions of Nepal.
// Data as of DATA_AS_OF. Generated from data/nepal_local_levels.json by
// tool/generate_bindings.dart; do not edit by hand.

const raw = require('./data.json');

const meta = raw.meta;
const provinces = raw.provinces;
const districts = raw.districts;
const localBodies = raw.localBodies;

// ---------------------------------------------------------------------------
// Indexes, built once at load. A code-keyed join is the single most common
// thing callers do with this data, so the map is precomputed rather than
// rebuilt per query.
// ---------------------------------------------------------------------------

const provinceById = new Map();
const provinceByIso = new Map();
const districtByName = new Map();
const districtByCbs = new Map();
const localBodyByCbs = new Map();

for (const p of provinces) {
  provinceById.set(p.id, p);
  if (p.isoCode) provinceByIso.set(p.isoCode.toUpperCase(), p);
}
for (const d of districts) {
  districtByName.set(d.name.toLowerCase(), d);
  if (d.cbsCode != null) districtByCbs.set(d.cbsCode, d);
}
for (const b of localBodies) {
  if (b.cbsCode != null) localBodyByCbs.set(b.cbsCode, b);
}

// ---------------------------------------------------------------------------
// Lookups. Names are matched case-insensitively; ISO codes in either case.
// ---------------------------------------------------------------------------

function getProvinceById(id) {
  if (typeof id !== 'string') return undefined;
  const lower = id.toLowerCase();
  const upper = id.toUpperCase();
  return provinceById.get(lower) || provinceByIso.get(upper) || undefined;
}

const getProvinceByIso = (iso) =>
  typeof iso === 'string' ? provinceByIso.get(iso.toUpperCase()) : undefined;

const getProvinceByCbs = (code) => provinces.find((p) => p.cbsCode === code);

const getAllProvinces = () => provinces.slice();
const getAllDistricts = () => districts.slice();
const getAllLocalBodies = () => localBodies.slice();

const getDistrictByName = (name) =>
  typeof name === 'string' ? districtByName.get(name.trim().toLowerCase()) : undefined;

const getDistrictByCbs = (code) => districtByCbs.get(code);

const getLocalBodiesByDistrict = (name) => {
  const d = getDistrictByName(name);
  if (!d) return [];
  // Districts are flat records carrying localBodyCount, not a nested array, so
  // membership is tested against the flat list.
  return localBodies.filter((b) => b.district === d.name);
};

const getLocalBodiesByProvince = (provinceId) => {
  const p = getProvinceById(provinceId);
  if (!p) return [];
  return localBodies.filter((b) => b.province === p.name);
};

const getLocalBodiesByType = (type) => localBodies.filter((b) => b.type === type);

// Duplicate names are common, so scoping to a district is the precise way in.
const getLocalBodiesByName = (name, districtName) => {
  const d = getDistrictByName(districtName);
  if (!d || typeof name !== 'string') return [];
  const lower = name.toLowerCase();
  return localBodies.filter(
    (b) => b.district === d.name && b.name.toLowerCase() === lower,
  );
};

/**
 * Resolve a 'Name, District, Province' path. Order-insensitive and tolerant of
 * a partial path. Returns null when the path matches nothing or more than one
 * body - an ambiguous answer is never guessed.
 */
function getLocalBodyByFullPath(path) {
  if (typeof path !== 'string') return null;
  const parts = path.split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
  if (parts.length === 0) return null;
  const matches = localBodies.filter((b) => {
    const hay = new Set([b.name, b.district, b.province].map((s) => String(s).toLowerCase()));
    return parts.every((p) => hay.has(p));
  });
  return matches.length === 1 ? matches[0] : null;
}

// Any confidence tier. Resolves 744 of 753.
const getLocalBodyByCbs = (code) => localBodyByCbs.get(code);

// Strictly the doubly-attested tier.
const getLocalBodyByCbsVerified = (code) => {
  const b = localBodyByCbs.get(code);
  return b && b.cbsCodeVerified ? b : undefined;
};

const getLocalBodiesWithCode = () => localBodies.filter((b) => b.cbsCode != null);
const getVerifiedLocalBodies = () => localBodies.filter((b) => b.cbsCodeVerified === true);
const getSingleSourceLocalBodies = () => localBodies.filter((b) => b.cbsCodeConfidence === 'singleSource');
const getUncodedLocalBodies = () => localBodies.filter((b) => b.cbsCode == null);

// ---------------------------------------------------------------------------
// Search. Matches BOTH scripts in either direction: search('भरतपुर') and
// search('Bharatpur') return the same palika.
// ---------------------------------------------------------------------------

function search(query) {
  const term = typeof query === 'string' ? query.trim().toLowerCase() : '';
  const empty = { provinces: [], districts: [], localBodies: [], isEmpty: true, length: 0 };
  if (term === '') return empty;
  const hit = (s) => typeof s === 'string' && s.toLowerCase().includes(term);
  const foundProvinces = provinces.filter((p) => hit(p.name) || hit(p.nameNe) || hit(p.isoCode));
  const foundDistricts = districts.filter((d) => hit(d.name) || hit(d.nameNe));
  const foundBodies = localBodies.filter(
    (b) => hit(b.name) || hit(b.nameNe) ||
      hit(`${b.name}, ${b.district}, ${b.province}`)
  );
  return {
    provinces: foundProvinces,
    districts: foundDistricts,
    localBodies: foundBodies,
    get isEmpty() {
      return foundProvinces.length + foundDistricts.length + foundBodies.length === 0;
    },
    get length() {
      return foundProvinces.length + foundDistricts.length + foundBodies.length;
    },
  };
}

// ---------------------------------------------------------------------------
// Computed totals. Note the two ward figures: `wards` is the declared
// national total, `verifiedWards` is what the per-palika rows substantiate.
// They differ because 8 palikas carry no verified ward count.
// ---------------------------------------------------------------------------

function getNationalStats() {
  const count = (t) => localBodies.filter((b) => b.type === t).length;
  const verifiedWards = localBodies.reduce((s, b) => s + (b.wards || 0), 0);
  const wardGaps = localBodies.filter((b) => b.wards == null).length;
  const declaredWards = provinces.reduce((s, p) => s + p.wards, 0);
  return {
    provinces: provinces.length,
    districts: districts.length,
    metro: count('metropolitan'),
    subMetro: count('subMetropolitan'),
    municipalities: count('municipality'),
    ruralMunicipalities: count('ruralMunicipality'),
    total: localBodies.length,
    wards: declaredWards,
    verifiedWards,
    wardGaps,
    unreconciledWards: declaredWards - verifiedWards,
  };
}

/** Per-province ward reconciliation, mirroring the Dart API. */
function getProvinceStats(provinceId) {
  const p = getProvinceById(provinceId);
  if (!p) return null;
  const bodies = getLocalBodiesByProvince(p.id);
  const verifiedWards = bodies.reduce((s, b) => s + (b.wards || 0), 0);
  return {
    ...p,
    verifiedWards,
    unreconciledWards: p.wards - verifiedWards,
    wardsReconcile: p.wards === verifiedWards,
  };
}

/** The joinable subset: has a code AND a coordinate. */
const getMappableLocalBodies = () =>
  localBodies.filter((b) => b.cbsCode != null && b.lat != null && b.lng != null);

module.exports = {
  meta,
  provinces,
  districts,
  localBodies,
  provinceById,
  districtByName,
  localBodyByCbs,
  getAllProvinces,
  getAllDistricts,
  getAllLocalBodies,
  getProvinceById,
  getProvinceByIso,
  getProvinceByCbs,
  getDistrictByName,
  getDistrictByCbs,
  getLocalBodiesByDistrict,
  getLocalBodiesByProvince,
  getLocalBodiesByType,
  getLocalBodiesByName,
  getLocalBodyByFullPath,
  getLocalBodyByCbs,
  getLocalBodyByCbsVerified,
  getLocalBodiesWithCode,
  getVerifiedLocalBodies,
  getSingleSourceLocalBodies,
  getUncodedLocalBodies,
  getMappableLocalBodies,
  getNationalStats,
  getProvinceStats,
  search,
};
''';

const _jsTypes = r'''
// Type definitions for nepal-admin-data.
// Generated by tool/generate_bindings.dart; do not edit by hand.

export type LocalBodyType =
  | 'metropolitan'
  | 'subMetropolitan'
  | 'municipality'
  | 'ruralMunicipality';

/** How much evidence stands behind a CBS code. */
export type CbsCodeConfidence = 'verified' | 'singleSource' | 'unverified';

export interface Meta {
  name: string;
  version: string;
  /** ISO date the snapshot was verified, e.g. '2026-10-09'. */
  dataAsOf: string;
  source: string;
  totals: Record<string, number>;
  coverage: Coverage;
}

export interface Coverage {
  localBodies: number;
  districts: number;
  provinces: number;
  /** Palikas carrying a CBS code of any confidence. */
  withCbsCode: number;
  doublyAttestedCodes: number;
  singleSourceCodes: number;
  withNameNe: number;
  nameNeCorroborated: number;
  withCoordinates: number;
  withWards: number;
  withContact: number;
  withZipCodes: number;
  /** The declared national ward total. */
  declaredWards: number;
  /** What the per-palika rows actually substantiate. */
  substantiatedWards: number;
}

export interface Province {
  id: string;
  name: string;
  /** Devanagari name. Present for all 7 provinces. */
  nameNe?: string;
  nameNeVerified: boolean;
  /** 1-7. */
  cbsCode: number;
  /** ISO 3166-2, e.g. 'NP-P3'. */
  isoCode: string;
  capital?: string;
  areaSqKm?: number;
  website?: string;
  districtCount: number;
  localBodyCount: number;
  /** Declared ward total for this province. */
  wards: number;
}

export interface District {
  name: string;
  nameNe?: string;
  nameNeVerified: boolean;
  /** 3-digit CBS code, e.g. 306 for Kathmandu. */
  cbsCode?: number;
  province: string;
  isoCode: string;
  /** Administrative headquarters, e.g. 'Bharatpur' for Chitwan. */
  headquarter?: string;
  areaSqKm?: number;
  website?: string;
  localBodyCount: number;
  wards: number;
}

export interface LocalBody {
  name: string;
  /** Devanagari name. Absent for 22 of 753 - never transliterated. */
  nameNe?: string;
  /** True only when two bilingual sources agree on the spelling. */
  nameNeVerified: boolean;
  type: LocalBodyType;
  district: string;
  districtNe?: string;
  province: string;
  isoCode: string;
  /** 5-digit CBS PDDPP code. Absent for 9 of 753. */
  cbsCode?: number;
  cbsCodeVerified: boolean;
  cbsCodeConfidence: CbsCodeConfidence;
  lat?: number;
  lng?: number;
  geoSource?: string;
  /** Ward count. Absent for 8 of 753, pending roster adjudication. */
  wards?: number;
  wardsVerified: boolean;
  website?: string;
  email?: string;
  phone?: string;
  zipCodes?: string[];
}

export interface SearchResult {
  provinces: Province[];
  districts: District[];
  localBodies: LocalBody[];
  readonly isEmpty: boolean;
  readonly length: number;
}

export interface NationalStats {
  provinces: number;
  districts: number;
  metro: number;
  subMetro: number;
  municipalities: number;
  ruralMunicipalities: number;
  total: number;
  /** Declared national ward total (6,743). */
  wards: number;
  /** Sum of the per-palika rows this package can substantiate (6,697). */
  verifiedWards: number;
  /** Palikas with no verified ward count (8). */
  wardGaps: number;
  /** wards - verifiedWards (46). Real, not a bug. */
  unreconciledWards: number;
}

export interface ProvinceStats extends Province {
  verifiedWards: number;
  unreconciledWards: number;
  wardsReconcile: boolean;
}

export const meta: Meta;
export const provinces: Province[];
export const districts: District[];
export const localBodies: LocalBody[];

export const provinceById: Map<string, Province>;
export const districtByName: Map<string, District>;
/** The joinable set: 744 of 753 palikas, keyed by 5-digit CBS code. */
export const localBodyByCbs: Map<number, LocalBody>;

export function getAllProvinces(): Province[];
export function getAllDistricts(): District[];
export function getAllLocalBodies(): LocalBody[];

/** By id ('bagmati') or ISO code ('NP-P3'), case-insensitive. */
export function getProvinceById(id: string): Province | undefined;
export function getProvinceByIso(iso: string): Province | undefined;
export function getProvinceByCbs(code: number): Province | undefined;

export function getDistrictByName(name: string): District | undefined;
export function getDistrictByCbs(code: number): District | undefined;

export function getLocalBodiesByDistrict(name: string): LocalBody[];
export function getLocalBodiesByProvince(provinceId: string): LocalBody[];
export function getLocalBodiesByType(type: LocalBodyType): LocalBody[];
/** Disambiguates the duplicate names that make search() ambiguous. */
export function getLocalBodiesByName(name: string, districtName: string): LocalBody[];
/** Null when the path is ambiguous rather than guessing. */
export function getLocalBodyByFullPath(path: string): LocalBody | null;
/** Any confidence tier; resolves 744 of 753. */
export function getLocalBodyByCbs(code: number): LocalBody | undefined;
/** Strictly the doubly-attested tier. */
export function getLocalBodyByCbsVerified(code: number): LocalBody | undefined;

export function getLocalBodiesWithCode(): LocalBody[];
export function getVerifiedLocalBodies(): LocalBody[];
export function getSingleSourceLocalBodies(): LocalBody[];
export function getUncodedLocalBodies(): LocalBody[];
/** Has both a code and a coordinate: ready for a map. */
export function getMappableLocalBodies(): LocalBody[];

export function getNationalStats(): NationalStats;
export function getProvinceStats(provinceId: string): ProvinceStats | null;
/** Matches both scripts, in either direction. */
export function search(query: string): SearchResult;
''';

String _pyProject(String version) => '''
[build-system]
requires = ["setuptools>=61.0"]
build-backend = "setuptools.build_meta"

[project]
name = "nepal-admin-data"
version = "$version"
description = "Offline administrative divisions of Nepal - 7 provinces, 77 districts, 753 local bodies, 6,743 wards. CBS codes, Devanagari names, coordinates, ward counts."
readme = "README.md"
requires-python = ">=3.8"
license = { text = "MIT" }
keywords = ["nepal", "geography", "admin", "districts", "municipality", "palika", "open-data"]
classifiers = [
  "Development Status :: 5 - Production/Stable",
  "Intended Audience :: Developers",
  "License :: OSI Approved :: MIT License",
  "Programming Language :: Python :: 3",
  "Topic :: Scientific/Engineering :: GIS",
]
dependencies = []

[project.urls]
Homepage = "https://github.com/namunaONE/Nepal-Local-Government-Data"
Documentation = "https://namunaONE.github.io/Nepal-Local-Government-Data/"

[tool.setuptools]
packages = ["nepal_admin"]

[tool.setuptools.package-data]
nepal_admin = ["data.json", "NOTICE", "LICENSE"]
''';

const _pyRuntime = r'''
"""Offline administrative divisions of Nepal.

Data as of ``DATA_AS_OF``. Generated from ``data/nepal_local_levels.json`` by
``tool/generate_bindings.dart``; do not edit by hand.

    >>> import nepal_admin as nad
    >>> nad.get_local_body_by_cbs(31304).name
    'Bharatpur'

Pure standard library, no dependencies.
"""

import json
import os
from typing import Dict, List, Optional

__version__ = "VERSION_PLACEHOLDER"

_DATA_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data.json")
with open(_DATA_PATH, encoding="utf-8") as _fh:
    _raw = json.load(_fh)

meta = _raw["meta"]
DATA_AS_OF = meta["dataAsOf"]

#: All 7 provinces, each with its districts nested under ``districts``.
provinces = _raw["provinces"]
#: All 77 districts, flat.
districts = _raw["districts"]
#: All 753 local bodies (palikas), flat.
local_bodies = _raw["localBodies"]

_province_by_id = {p["id"]: p for p in provinces}
_province_by_iso = {p["isoCode"].upper(): p for p in provinces if p.get("isoCode")}
_district_by_name = {d["name"].lower(): d for d in districts}
_district_by_cbs = {d["cbsCode"]: d for d in districts if d.get("cbsCode") is not None}
_local_body_by_cbs = {
    b["cbsCode"]: b for b in local_bodies if b.get("cbsCode") is not None
}

# Type aliases, so a caller can annotate without importing typing machinery.
LocalBody = Dict[str, object]
District = Dict[str, object]
Province = Dict[str, object]


# --------------------------------------------------------------------------
# Lookups. Names are matched case-insensitively.
# --------------------------------------------------------------------------

def get_province_by_id(province_id):
    """By id (``'bagmati'``) or ISO code (``'NP-P3'``), case-insensitive."""
    if not isinstance(province_id, str):
        return None
    return _province_by_id.get(province_id.lower()) or _province_by_iso.get(
        province_id.upper()
    )


def get_province_by_iso(iso):
    return _province_by_iso.get(iso.upper()) if isinstance(iso, str) else None


def get_province_by_cbs(code):
    for p in provinces:
        if p["cbsCode"] == code:
            return p
    return None


def get_all_provinces():
    return list(provinces)


def get_all_districts():
    return list(districts)


def get_all_local_bodies():
    return list(local_bodies)


def get_district_by_name(name):
    return _district_by_name.get(name.strip().lower()) if isinstance(name, str) else None


def get_district_by_cbs(code):
    return _district_by_cbs.get(code)


def get_local_bodies_by_district(district_name):
    d = get_district_by_name(district_name)
    if not d:
        return []
    return [b for b in local_bodies if b["district"] == d["name"]]


def get_local_bodies_by_province(province_id):
    p = get_province_by_id(province_id)
    if not p:
        return []
    return [b for b in local_bodies if b["province"] == p["name"]]


def get_local_bodies_by_type(body_type):
    return [b for b in local_bodies if b["type"] == body_type]


def get_local_bodies_by_name(name, district_name):
    """Disambiguates the duplicate names that make ``search`` ambiguous."""
    d = get_district_by_name(district_name)
    if not d or not isinstance(name, str):
        return []
    target = name.lower()
    return [b for b in local_bodies
            if b["district"] == d["name"] and b["name"].lower() == target]


def get_local_body_by_full_path(path):
    """Resolve ``'Bharatpur, Chitwan, Bagmati'``.

    Order-insensitive and tolerant of a partial path. Returns ``None`` when the
    path matches nothing *or* more than one body: an ambiguous answer is never
    guessed.
    """
    if not isinstance(path, str):
        return None
    parts = [p.strip().lower() for p in path.split(",") if p.strip()]
    if not parts:
        return None
    matches = []
    for b in local_bodies:
        haystack = {b["name"].lower(), b["district"].lower(), b["province"].lower()}
        if all(p in haystack for p in parts):
            matches.append(b)
    return matches[0] if len(matches) == 1 else None


def get_local_body_by_cbs(code):
    """Any confidence tier; resolves 744 of 753."""
    return _local_body_by_cbs.get(code)


def get_local_body_by_cbs_verified(code):
    """Strictly the doubly-attested tier."""
    b = _local_body_by_cbs.get(code)
    return b if b and b.get("cbsCodeVerified") else None


def get_local_bodies_with_code():
    return [b for b in local_bodies if b.get("cbsCode") is not None]


def get_verified_local_bodies():
    return [b for b in local_bodies if b.get("cbsCodeVerified")]


def get_single_source_local_bodies():
    return [b for b in local_bodies if b.get("cbsCodeConfidence") == "singleSource"]


def get_uncoded_local_bodies():
    return [b for b in local_bodies if b.get("cbsCode") is None]


# --------------------------------------------------------------------------
# Search. Matches BOTH scripts in either direction.
# --------------------------------------------------------------------------

def _hit(value, term):
    return isinstance(value, str) and term in value.lower()


def search(query):
    """Case-insensitive search across provinces, districts and local bodies.

    Matches both scripts, so ``search('भरतपुर')`` and ``search('Bharatpur')``
    return the same palika.

    Returns a dict with ``provinces``, ``districts`` and ``localBodies`` keys.
    """
    term = query.strip().lower() if isinstance(query, str) else ""
    if not term:
        return {"provinces": [], "districts": [], "localBodies": []}
    return {
        "provinces": [
            p for p in provinces
            if _hit(p.get("name"), term) or _hit(p.get("nameNe"), term) or _hit(p.get("isoCode"), term)
        ],
        "districts": [d for d in districts if _hit(d.get("name"), term) or _hit(d.get("nameNe"), term)],
        "localBodies": [
            b for b in local_bodies
            if _hit(b.get("name"), term) or _hit(b.get("nameNe"), term)
            or term in "{} , {}, {}".format(b["name"], b["district"], b["province"]).lower()
        ],
    }


# --------------------------------------------------------------------------
# Computed totals.
#
# ``wards`` is the declared national total; ``verified_wards`` is what the
# per-palika rows substantiate. They differ because 8 palikas carry no verified
# ward count. Both are reported rather than one silently shadowing the other.
# --------------------------------------------------------------------------

def get_national_stats():
    def count(t):
        return sum(1 for b in local_bodies if b["type"] == t)

    verified_wards = sum(b.get("wards") or 0 for b in local_bodies)
    declared_wards = sum(p["wards"] for p in provinces)
    return {
        "provinces": len(provinces),
        "districts": len(districts),
        "metro": count("metropolitan"),
        "sub_metro": count("subMetropolitan"),
        "municipalities": count("municipality"),
        "rural_municipalities": count("ruralMunicipality"),
        "total": len(local_bodies),
        "wards": declared_wards,
        "verified_wards": verified_wards,
        "ward_gaps": sum(1 for b in local_bodies if b.get("wards") is None),
        "unreconciled_wards": declared_wards - verified_wards,
    }


def get_province_stats(province_id):
    """Per-province ward reconciliation, mirroring the Dart API."""
    p = get_province_by_id(province_id)
    if not p:
        return None
    bodies = get_local_bodies_by_province(p["id"])
    verified = sum(b.get("wards") or 0 for b in bodies)
    out = dict(p)
    out["verified_wards"] = verified
    out["unreconciled_wards"] = p["wards"] - verified
    out["wards_reconcile"] = p["wards"] == verified
    return out


def get_mappable_local_bodies():
    """The joinable, plottable subset: has a code AND a coordinate."""
    return [
        b for b in local_bodies
        if b.get("cbsCode") is not None and b.get("lat") is not None and b.get("lng") is not None
    ]


__all__ = [
    "meta", "DATA_AS_OF", "provinces", "districts", "local_bodies",
    "get_province_by_id", "get_province_by_iso", "get_province_by_cbs",
    "get_all_provinces", "get_all_districts", "get_all_local_bodies",
    "get_district_by_name", "get_district_by_cbs",
    "get_local_bodies_by_district", "get_local_bodies_by_province",
    "get_local_bodies_by_type", "get_local_bodies_by_name",
    "get_local_body_by_full_path", "get_local_body_by_cbs",
    "get_local_body_by_cbs_verified", "get_local_bodies_with_code",
    "get_verified_local_bodies", "get_single_source_local_bodies",
    "get_uncoded_local_bodies", "get_mappable_local_bodies",
    "get_national_stats", "get_province_stats", "search",
]
''';

const _pyMain = r'''
"""Print a summary: ``python -m nepal_admin``."""

from . import (
    DATA_AS_OF,
    get_national_stats,
    get_province_stats,
    get_province_by_id,
    get_local_body_by_cbs,
)


def main():
    s = get_national_stats()
    print("Nepal administrative divisions (data as of {})".format(DATA_AS_OF))
    print("  provinces          {}".format(s["provinces"]))
    print("  districts          {}".format(s["districts"]))
    print("  local bodies       {}".format(s["total"]))
    print("  wards (declared)   {}".format(s["wards"]))
    print("  wards (verified)   {}".format(s["verified_wards"]))
    b = get_local_body_by_cbs(31304)
    if b:
        print("\n  31304 = {} ({})".format(b["name"], b["nameNe"]))
    bagmati = get_province_by_id("bagmati")
    if bagmati:
        ps = get_province_stats("bagmati")
        print("  Bagmati: {} districts, {} wards ({} unreconciled)".format(
            bagmati["districtCount"], ps["verified_wards"], ps["unreconciled_wards"]
        ))


if __name__ == "__main__":
    main()
''';

String _jsReadme(String version, String dataAsOf) => '''
# nepal-admin-data

Offline administrative divisions of Nepal for JavaScript — **7 provinces,
77 districts, 753 local bodies, 6,743 wards**, with official CBS codes,
Devanagari names, coordinates and ward counts.

Data as of **$dataAsOf**. Generated from
[`data/nepal_local_levels.json`](https://github.com/namunaONE/Nepal-Local-Government-Data)
by `tool/generate_bindings.dart` — do not edit by hand.

- **Zero dependencies.** Pure data plus a small query layer.
- **Bilingual.** Devanagari names for all 7 provinces, 77 districts and
  731 of 753 palikas. Never transliterated.
- **Typed.** `.d.ts` included.
- Same data, same numbers and the same API shape as the Dart package
  [`nepal_admin_api`](https://pub.dev/packages/nepal_admin_api).

## Install

```bash
npm install nepal-admin-data
```

## Use

```js
const nad = require('nepal-admin-data');

// Lookups
nad.getLocalBodyByCbs(31304);
// { name: 'Bharatpur', nameNe: 'भरतपुर', district: 'Chitwan', ... }

nad.getDistrictByName('Chitwan').headquarter;   // 'Bharatpur'
nad.getLocalBodyByFullPath('Bharatpur, Chitwan, Bagmati').name;

// Search works in BOTH scripts, in either direction.
nad.search('Bharatpur').localBodies.length === nad.search('भरतपुर').localBodies.length; // true
nad.search('भारत').localBodies.length;   // fragment match

// Building a code-keyed join (the common case)
const byCode = new Map(nad.getLocalBodiesWithCode().map(b => [b.cbsCode, b]));
byCode.size;   // 744

// National totals
nad.getNationalStats();
// { provinces: 7, districts: 77, total: 753, wards: 6743,
//   verifiedWards: 6697, wardGaps: 8, unreconciledWards: 46, ... }
```

## Two ward totals, on purpose

`wards` is the **declared** national figure (6,743). `verifiedWards` is what
the per-palika rows this package substantiates add up to (6,697). The 46-ward
difference is 8 palikas documented as roster defects — reported, not hidden.

## Data files

Also ships `csv/` for pandas, Excel, R and QGIS, and `geojson/` centroid
FeatureCollections (RFC 7946) for Leaflet, geojson.io and QGIS.

## License

MIT for the code. The data is CC-BY-4.0 / CC-BY derived and attributed in
[NOTICE](NOTICE). Not affiliated with the Government of Nepal.
''';

String _pyReadme(String version, String dataAsOf) => '''
# nepal-admin-data

Offline administrative divisions of Nepal for Python — **7 provinces,
77 districts, 753 local bodies, 6,743 wards**, with official CBS codes,
Devanagari names, coordinates and ward counts.

Data as of **$dataAsOf**. Generated from
[`data/nepal_local_levels.json`](https://github.com/namunaONE/Nepal-Local-Government-Data)
by `tool/generate_bindings.dart` — do not edit by hand.

- **Zero dependencies.** Pure standard library.
- **Bilingual.** Devanagari names for all 7 provinces, 77 districts and
  731 of 753 palikas. Never transliterated.
- Same data, same numbers and the same API shape as the Dart package
  [`nepal_admin_api`](https://pub.dev/packages/nepal_admin_api).

## Install

```bash
pip install nepal-admin-data
```

## Use

```python
import nepal_admin as nad

b = nad.get_local_body_by_cbs(31304)
b["name"]        # 'Bharatpur'
b["nameNe"]      # 'भरतपुर'

nad.get_district_by_name("Chitwan")["headquarter"]     # 'Bharatpur'
nad.get_local_body_by_full_path("Bharatpur, Chitwan, Bagmati")["name"]

# Search works in BOTH scripts, in either direction.
len(nad.search("Bharatpur")["localBodies"]) == len(nad.search("भरतपुर")["localBodies"])

# Building a code-keyed join (the common case)
by_code = {b["cbsCode"]: b for b in nad.get_local_bodies_with_code()}
len(by_code)     # 744

# With pandas, using the shipped CSV:
#   pd.read_csv("csv/local_bodies.csv")

nad.get_national_stats()
# {'provinces': 7, 'districts': 77, 'total': 753, 'wards': 6743,
#  'verified_wards': 6697, 'ward_gaps': 8, 'unreconciled_wards': 46, ...}
```

```bash
python -m nepal_admin      # print a summary
```

## Two ward totals, on purpose

`wards` is the **declared** national figure (6,743). `verified_wards` is what
the per-palika rows this package substantiates add up to (6,697). The 46-ward
difference is 8 palikas documented as roster defects — reported, not hidden.

## Data files

Also ships `csv/` for pandas, Excel, R and QGIS, and `geojson/` centroid
FeatureCollections (RFC 7946) for Folium, geojson.io and QGIS.

## License

MIT for the code. The data is CC-BY-4.0 / CC-BY derived and attributed in
[NOTICE](NOTICE). Not affiliated with the Government of Nepal.
''';

String _bindingsReadme(String version, String dataAsOf, int count) => '''
# Bindings

Everything in this directory is **generated**. Do not edit any file here by
hand — edit `data/nepal_local_levels.json` and run:

```bash
dart run tool/generate_bindings.dart      # or: dart run tool/pipeline.dart
```

CI regenerates and diffs the output, so a binding can never disagree with the
Dart package. Output is byte-stable (fixed ordering, LF endings, no
timestamps), which is what makes that check a plain `git diff`.

| Path | What it is | Verified by |
|---|---|---|
| `csv/` | `provinces.csv`, `districts.csv`, `local_bodies.csv` | `bindings/verify_bindings.cjs` |
| `geojson/` | Centroid FeatureCollections, RFC 7946 WGS84 | `bindings/verify_bindings.cjs` |
| `javascript/` | npm package `nepal-admin-data` (`index.js`, `index.d.ts`) | `bindings/verify_bindings.cjs` |
| `python/` | PyPI package `nepal-admin-data` (stdlib only) | CI job (needs Python) |
| `meta.json` | Version, dataAsOf, coverage counters | — |

## Why these shapes

- **CSV** — because the most common real use is a pandas merge or a
  spreadsheet, and copying 753 rows by hand is the thing this project exists
  to stop.
- **GeoJSON centroids** — so a map works today. Boundary polygons are *not*
  included: the only vendored geometry ships 777 features against the gazetted
  753 and is quarantined pending review (`data/SOURCES.md`). Centroids now
  means a polygon layer can be added later without changing this contract.
- **JavaScript / Python** — same numbers and the same API shape as the Dart
  package, so moving between them is a rename, not a rewrite.

All three bindings expose the same honesty guarantees as the Dart package:
absent means absent (`null` / omitted), confidence tiers are explicit, and
nothing is fabricated to fill a column.

## Verification status

- JavaScript, CSV and GeoJSON are executed and asserted locally against the
  source dataset on every run (`bindings/verify_bindings.cjs`).
- The Python binding is **generated and reviewed but not executed locally** —
  the development machine used for this release has no Python interpreter. It
  is exercised in CI, which is the first place it is actually run.

## Not here

- **Ward-level records.** No vendored source names individual wards, so
  `wards` is a count. See `data/SOURCES.md` § "Ward-level records".
- **Boundary polygons.** See above.

Generated $count files · version $version · data as of $dataAsOf.
''';
