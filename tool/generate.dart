// tool/generate.dart
//
// Generates lib/src/nepal_data.dart from data/nepal_local_levels.json.
//
// Usage (from the package root):
//   dart run tool/generate.dart
//
// The generator validates the dataset against the official federal
// structure before writing anything, so a corrupted or hand-mangled
// JSON fails loudly instead of producing a broken package.

import 'dart:convert';
import 'dart:io';

const jsonPath = 'data/nepal_local_levels.json';
const outputPath = 'lib/src/nepal_data.dart';

void main() {
  final jsonFile = File(jsonPath);
  if (!jsonFile.existsSync()) {
    stderr.writeln('ERROR: $jsonPath not found — run from the package root.');
    exit(1);
  }

  final Map<String, dynamic> json =
      jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;
  final List<Map<String, dynamic>> provinces =
      (json['provinces'] as List).cast<Map<String, dynamic>>();
  final Map<String, int> totals =
      (json['meta']['totals'] as Map<String, dynamic>).cast<String, int>();

  _validate(provinces, totals);

  File(outputPath).writeAsStringSync(_generate(provinces));

  final formatted = Process.runSync('dart', ['format', outputPath]);
  stdout.write(formatted.stdout as String);
  stderr.write(formatted.stderr as String);
  if (formatted.exitCode != 0) exit(formatted.exitCode);

  stdout.writeln('Generated $outputPath from $jsonPath.');
}

void _validate(List<Map<String, dynamic>> provinces, Map<String, int> totals) {
  var districts = 0;
  var bodies = 0;
  var wards = 0;
  final byType = <String, int>{};

  for (final province in provinces) {
    wards += province['wards'] as int;
    final provinceDistricts =
        (province['districts'] as List).cast<Map<String, dynamic>>();
    districts += provinceDistricts.length;
    for (final district in provinceDistricts) {
      final units =
          (district['localBodies'] as List).cast<Map<String, dynamic>>();
      bodies += units.length;
      for (final unit in units) {
        final type = unit['type'] as String;
        byType[type] = (byType[type] ?? 0) + 1;
        // Coordinate validation: nullable, but when present must be
        // numeric and inside the Nepal bounding box.
        final lat = unit['lat'];
        final lng = unit['lng'];
        if (lat != null || lng != null) {
          final latD = (lat as num?)?.toDouble();
          final lngD = (lng as num?)?.toDouble();
          if (latD == null ||
              lngD == null ||
              latD < 26.0 ||
              latD > 31.0 ||
              lngD < 80.0 ||
              lngD > 89.0) {
            stderr.writeln('ERROR: invalid coordinates for ${unit['name']} '
                '(${district['name']}): lat=$lat lng=$lng.');
            exit(1);
          }
        }
      }
    }
  }

  void check(String label, int actual, int expected) {
    if (actual != expected) {
      stderr.writeln('ERROR: $label = $actual, expected $expected.');
      exit(1);
    }
  }

  check('provinces', provinces.length, totals['provinces']!);
  check('districts', districts, totals['districts']!);
  check('localBodies', bodies, totals['localBodies']!);
  check('metropolitan', byType['metropolitan'] ?? 0, totals['metropolitan']!);
  check('subMetropolitan', byType['subMetropolitan'] ?? 0,
      totals['subMetropolitan']!);
  check('municipality', byType['municipality'] ?? 0, totals['municipality']!);
  check('ruralMunicipality', byType['ruralMunicipality'] ?? 0,
      totals['ruralMunicipality']!);
  check('wards', wards, totals['wards']!);
}

String _generate(List<Map<String, dynamic>> provinces) {
  final b = StringBuffer();
  b.writeln('// GENERATED CODE — DO NOT MODIFY BY HAND.');
  b.writeln('//');
  b.writeln('// Source of truth: $jsonPath');
  b.writeln('// Regenerate with: dart run tool/generate.dart');
  b.writeln('//');
  b.writeln(
      '// Official federal structure: 7 provinces, 77 districts, 753 local');
  b.writeln(
      '// bodies (6 metropolitan, 11 sub-metropolitan, 276 municipalities,');
  b.writeln(
      '// 460 rural municipalities), 6,743 wards. Data as of October 2026.');
  b.writeln(
      '// Schema v2: includes CBS codes (province: NP-P1..NP-P7, district: 3-digit, localBody: 5-digit PDDPP).');
  b.writeln();
  b.writeln("import 'nepal_admin_api_base.dart';");
  b.writeln();
  b.writeln("/// The package's embedded dataset. Do not construct by hand —");
  b.writeln('/// use [NepalAdminApi] to query it.');
  b.writeln('class NepalData {');
  b.writeln('  static final List<Province> provinces = [');

  for (final province in provinces) {
    final provinceDistricts =
        (province['districts'] as List).cast<Map<String, dynamic>>();
    var total = 0;
    final byType = <String, int>{};
    for (final district in provinceDistricts) {
      final units =
          (district['localBodies'] as List).cast<Map<String, dynamic>>();
      total += units.length;
      for (final unit in units) {
        final type = unit['type'] as String;
        byType[type] = (byType[type] ?? 0) + 1;
      }
    }

    b.writeln('    Province(');
    b.writeln("      id: '${province['id']}',");
    b.writeln("      name: '${province['name']}',");
    b.writeln("      cbsCode: ${province['cbsCode']},");
    b.writeln("      isoCode: '${province['isoCode']}',");
    b.writeln('      stats: const ProvinceStats(');
    b.writeln('        districts: ${provinceDistricts.length},');
    b.writeln('        metro: ${byType['metropolitan'] ?? 0},');
    b.writeln('        subMetro: ${byType['subMetropolitan'] ?? 0},');
    b.writeln('        mun: ${byType['municipality'] ?? 0},');
    b.writeln('        ruralMun: ${byType['ruralMunicipality'] ?? 0},');
    b.writeln('        total: $total,');
    b.writeln("        wards: ${province['wards']},");
    b.writeln('      ),');
    b.writeln('      districts: [');

    for (final district in provinceDistricts) {
      b.writeln('        District(');
      b.writeln("          name: '${district['name']}',");
      final dCbs = district['cbsCode'];
      if (dCbs != null) {
        b.writeln('          cbsCode: $dCbs,');
      }
      b.writeln('          units: [');
      for (final unit
          in (district['localBodies'] as List).cast<Map<String, dynamic>>()) {
        final lbCbs = unit['cbsCode'];
        final lbVerified = unit['cbsCodeVerified'] == true;
        final lat = unit['lat'];
        final lng = unit['lng'];
        final geoSource = unit['geoSource'];
        final extra = StringBuffer();
        if (lbCbs != null) {
          extra.write(', cbsCode: $lbCbs, cbsCodeVerified: $lbVerified');
        }
        if (lat != null && lng != null) {
          extra.write(', lat: $lat, lng: $lng');
          if (geoSource != null) {
            extra.write(", geoSource: '$geoSource'");
          }
        }
        b.writeln(
            "            LocalBody(name: '${unit['name']}', type: LocalBodyType.${unit['type']}, districtName: '${district['name']}', provinceName: '${province['name']}'$extra),");
      }
      b.writeln('          ],');
      b.writeln('        ),');
    }

    b.writeln('      ],');
    b.writeln('    ),');
  }

  b.writeln('  ];');
  b.write('}');
  return b.toString();
}
