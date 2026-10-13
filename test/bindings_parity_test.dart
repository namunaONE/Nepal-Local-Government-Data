// Cross-binding parity: the generated JavaScript, Python, CSV and GeoJSON
// artifacts must describe exactly the same 753 local bodies as the Dart
// package the caller is actually using.
//
// The single source of truth is data/nepal_local_levels.json, so drift is
// theoretically impossible - but "theoretically" is not a test. This reads the
// shipped artifacts and compares them field by field against the live Dart
// API, so a generator bug that drops or reshapes a field fails here rather
// than in a consumer's project.
//
// Files are read relative to the package root, so this only runs from the
// repository (which is where the artifacts live).

import 'dart:convert';
import 'dart:io';

import 'package:nepal_admin_api/nepal_admin_api.dart';
import 'package:test/test.dart';

void main() {
  final bodies = NepalAdminApi.getAllLocalBodies();

  Map<String, dynamic> loadJson(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  // `bindings/` is excluded from the published Dart package (.pubignore), so
  // these assertions only make sense in a working copy of the repository. When
  // the artifacts are absent - someone running `dart test` from the published
  // tarball - the group reports as skipped rather than failing for a missing
  // file that is not supposed to be there.
  final bindingsPresent = Directory('bindings').existsSync() &&
      File('bindings/javascript/data.json').existsSync();
  final skipReason = bindingsPresent
      ? null
      : 'bindings/ is not present (expected in a repository checkout; '
          'excluded from the published package)';

  group('generated bindings agree with the Dart package', () {
    test('the artifacts exist', () {
      for (final p in const [
        'bindings/javascript/index.js',
        'bindings/javascript/index.d.ts',
        'bindings/javascript/data.json',
        'bindings/javascript/package.json',
        'bindings/python/nepal_admin/__init__.py',
        'bindings/python/nepal_admin/data.json',
        'bindings/python/pyproject.toml',
        'bindings/csv/provinces.csv',
        'bindings/csv/districts.csv',
        'bindings/csv/local_bodies.csv',
        'bindings/geojson/local-bodies.centroids.geojson',
        'bindings/geojson/districts.centroids.geojson',
        'bindings/geojson/provinces.centroids.geojson',
        'bindings/meta.json',
      ]) {
        expect(File(p).existsSync(), isTrue, reason: '$p is missing');
      }
    });

    test('bindings/javascript/data.json mirrors the Dart API record for record',
        () {
      final payload = loadJson('bindings/javascript/data.json');
      final js = (payload['localBodies'] as List).cast<Map<String, dynamic>>();
      expect(js.length, bodies.length);

      // The bindings carry the DATASET's type vocabulary
      // ('metropolitan' | 'subMetropolitan' | 'municipality' |
      // 'ruralMunicipality'), not LocalBodyType.shortName ('M', 'RM'). That is
      // deliberate: 'M' is meaningless in a CSV column or a JSON payload, and
      // the bindings are read by people who never see the Dart enum.
      for (var i = 0; i < bodies.length; i++) {
        final d = bodies[i];
        final j = js[i];
        final where = 'index $i (${d.fullPath})';
        expect(j['name'], d.name, reason: where);
        expect(j['nameNe'], d.nameNe, reason: where);
        expect(j['type'], d.type.name, reason: where);
        expect(j['district'], d.districtName, reason: where);
        expect(j['province'], d.provinceName, reason: where);
        expect(j['cbsCode'], d.cbsCode, reason: where);
        expect(j['cbsCodeVerified'], d.cbsCodeVerified, reason: where);
        expect(j['cbsCodeConfidence'], d.cbsCodeConfidence.wireName,
            reason: where);
        expect(j['wards'], d.wards, reason: where);
        expect(j['wardsVerified'], d.wardsVerified, reason: where);
        expect(j['lat'], d.lat, reason: where);
        expect(j['lng'], d.lng, reason: where);
        expect(j['website'], d.website, reason: where);
        expect(j['email'], d.email, reason: where);
        expect(j['phone'], d.phone, reason: where);
        expect(j['zipCodes'] ?? const <String>[], d.zipCodes, reason: where);
      }
    });

    test('the Python binding ships a byte-identical payload', () {
      final js = File('bindings/javascript/data.json').readAsBytesSync();
      final py =
          File('bindings/python/nepal_admin/data.json').readAsBytesSync();
      // Two packages in two languages must not be able to drift apart, and a
      // copy that differs by one byte is exactly how they would.
      expect(py.length, js.length);
      expect(
        List<int>.generate(js.length, (i) => js[i] == py[i] ? 1 : 0)
            .reduce((a, b) => a + b),
        js.length,
        reason: 'the two binding payloads differ',
      );
    });

    test('bindings/meta.json coverage counters match the live API', () {
      final meta = loadJson('bindings/meta.json');
      final cov = meta['coverage'] as Map<String, dynamic>;
      final stats = NepalAdminApi.getNationalStats();

      expect(cov['localBodies'], bodies.length);
      expect(cov['districts'], NepalAdminApi.getAllDistricts().length);
      expect(cov['provinces'], NepalAdminApi.getAllProvinces().length);
      expect(cov['withCbsCode'], NepalAdminApi.getLocalBodiesWithCode().length);
      expect(cov['doublyAttestedCodes'],
          NepalAdminApi.getVerifiedLocalBodies().length);
      expect(cov['singleSourceCodes'],
          NepalAdminApi.getSingleSourceLocalBodies().length);
      expect(cov['withNameNe'], bodies.where((b) => b.nameNe != null).length);
      expect(cov['nameNeCorroborated'],
          bodies.where((b) => b.nameNeVerified).length);
      expect(cov['withCoordinates'], bodies.whereMapped.length);
      expect(cov['withWards'], bodies.whereWardsVerified.length);
      expect(cov['withContact'], bodies.where((b) => b.hasContact).length);
      expect(cov['withZipCodes'],
          bodies.where((b) => b.zipCodes.isNotEmpty).length);
      expect(cov['declaredWards'], stats.wards);
      expect(cov['substantiatedWards'], stats.verifiedWards);
    });

    test('the CSV local-body file has one row per palika, in the same order',
        () {
      final rows = _parseCsv(
        File('bindings/csv/local_bodies.csv').readAsStringSync(),
      );
      final header = rows.first;
      final data = rows.skip(1).toList();
      expect(data.length, bodies.length);

      int col(String name) => header.indexOf(name);
      for (var i = 0; i < bodies.length; i++) {
        final d = bodies[i];
        final r = data[i];
        final where = 'row $i (${d.fullPath})';
        expect(r[col('name')], d.name, reason: where);
        expect(r[col('nameNe')], d.nameNe ?? '', reason: where);
        expect(r[col('type')], d.type.name, reason: where);
        expect(r[col('district')], d.districtName, reason: where);
        expect(r[col('province')], d.provinceName, reason: where);
        expect(r[col('cbsCode')], d.cbsCode?.toString() ?? '', reason: where);
        expect(r[col('wards')], d.wards?.toString() ?? '', reason: where);
        expect(r[col('zipCodes')], d.zipCodes.join(' '), reason: where);
      }
    });

    test('the GeoJSON carries every mapped palika at its exact coordinate', () {
      final fc = loadJson('bindings/geojson/local-bodies.centroids.geojson');
      final features = (fc['features'] as List).cast<Map<String, dynamic>>();
      final mapped = bodies.where((b) => b.hasCoordinates).toList();
      expect(features.length, mapped.length);

      // Key by code so the comparison does not depend on ordering. Eight palikas
      // are mapped but carry no attested code, so they have no key here and
      // are checked separately below.
      final byCode = <int, Map<String, dynamic>>{};
      var withoutCode = 0;
      for (final f in features) {
        final props = f['properties'] as Map<String, dynamic>;
        final code = props['cbsCode'] as int?;
        if (code == null) {
          withoutCode++;
          continue;
        }
        byCode[code] = f;
      }
      final mappedUncoded =
          bodies.where((b) => b.hasCoordinates && b.cbsCode == null).length;
      expect(withoutCode, mappedUncoded,
          reason:
              'mapped-but-uncoded palikas must still appear in the GeoJSON');
      for (final b in mapped.where((b) => b.cbsCode != null)) {
        final f = byCode[b.cbsCode];
        expect(f, isNotNull, reason: '${b.fullPath} missing from GeoJSON');
        final geometry = f!['geometry'] as Map<String, dynamic>;
        final coords = geometry['coordinates'] as List;
        // RFC 7946 orders coordinates [longitude, latitude].
        expect((coords[0] as num).toDouble(), b.lng!,
            reason: '${b.fullPath} longitude');
        expect((coords[1] as num).toDouble(), b.lat!,
            reason: '${b.fullPath} latitude');
      }
    });

    test('every exported Dart name a binding relies on exists', () {
      // The bindings re-implement these lookups. This pins the contract they
      // mirror, so a Dart-side rename cannot leave the bindings calling
      // something that no longer resolves.
      expect(NepalAdminApi.getLocalBodyByCbs(31304)!.name, 'Bharatpur');
      expect(NepalAdminApi.getLocalBodyByCbsVerified(40504), isNull);
      expect(NepalAdminApi.getLocalBodiesWithCode().length, 744);
      expect(NepalAdminApi.getSingleSourceLocalBodies().length, 196);
      expect(NepalAdminApi.getUncodedLocalBodies().length, 9);
      expect(
          NepalAdminApi.getLocalBodiesByName('Sunkoshi', 'Okhaldhunga').length,
          1);
      expect(NepalAdminApi.getLocalBodyByFullPath('Sunkoshi'), isNull);
      expect(
          NepalAdminApi.getDistrictByName('Chitwan')!.headquarter, 'Bharatpur');
      expect(NepalAdminApi.getProvinceById('koshi')!.capital, 'Biratnagar');
    });
  }, skip: skipReason);
}

/// Minimal RFC 4180 reader: enough to verify what the generator wrote, without
/// pulling in a CSV dependency for a test.
List<List<String>> _parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
      continue;
    }
    if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n') {
      row.add(field.toString());
      rows.add(row);
      row = <String>[];
      field.clear();
    } else if (c != '\r') {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows
      .where((r) => r.length > 1 || (r.length == 1 && r[0].isNotEmpty))
      .toList();
}
