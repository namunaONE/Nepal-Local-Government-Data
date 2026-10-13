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
  var verifiedWards = 0;
  var wardGaps = 0;
  var coded = 0;
  var doublyAttested = 0;
  final byType = <String, int>{};
  final seenCbsCodes = <int, String>{};
  const validTiers = {'verified', 'singleSource', 'unverified'};

  for (final province in provinces) {
    var verifiedWardsInProvince = 0;

    // A nameNe that holds no Devanagari at all is a broken pipeline, not a
    // gap: it means a Latin string reached the Devanagari field.
    void checkNameNe(Object? value, String where) {
      if (value == null) return;
      final s = value as String;
      if (!RegExp('[\u0900-\u097F]').hasMatch(s)) {
        stderr.writeln('ERROR: $where nameNe holds no Devanagari: "$s".');
        exit(1);
      }
    }

    checkNameNe(province['nameNe'], 'province ${province['name']}');
    for (final district in province['districts'] as List) {
      final dmap = district as Map<String, dynamic>;
      checkNameNe(dmap['nameNe'], 'district ${dmap['name']}');
      final units = (dmap['localBodies'] as List).cast<Map<String, dynamic>>();
      districts++;
      for (final unit in units) {
        bodies++;
        final type = unit['type'] as String;
        byType[type] = (byType[type] ?? 0) + 1;

        // --- CBS code confidence integrity -------------------------------
        // The tier and the boolean flag must agree, codes must be unique
        // nationwide, and a code must sit in its own district. A dataset
        // that violates any of these would publish a join-key map that
        // silently returns the wrong palika.
        final cbs = unit['cbsCode'] as int?;
        final tier = unit['cbsCodeConfidence'] as String? ?? 'unverified';
        final verified = unit['cbsCodeVerified'] == true;
        if (!validTiers.contains(tier)) {
          stderr.writeln('ERROR: invalid cbsCodeConfidence "$tier" for '
              '${unit['name']} (${dmap['name']}).');
          exit(1);
        }
        if (cbs == null) {
          if (tier != 'unverified' || verified) {
            stderr.writeln('ERROR: ${unit['name']} (${dmap['name']}) has '
                'cbsCode=null but tier=$tier verified=$verified.');
            exit(1);
          }
        } else {
          coded++;
          if (verified) doublyAttested++;
          if (verified && tier != 'verified') {
            stderr.writeln('ERROR: ${unit['name']} is cbsCodeVerified but '
                'tier=$tier.');
            exit(1);
          }
          if (!verified && tier == 'verified') {
            stderr.writeln('ERROR: ${unit['name']} has tier=verified but '
                'cbsCodeVerified=false.');
            exit(1);
          }
          final owner = seenCbsCodes[cbs];
          if (owner != null) {
            stderr.writeln('ERROR: CBS code $cbs is used by both $owner and '
                '${unit['name']} (${dmap['name']}).');
            exit(1);
          }
          seenCbsCodes[cbs] = '${dmap['name']}/${unit['name']}';
          final dCbs = dmap['cbsCode'] as int?;
          if (dCbs != null && cbs ~/ 100 != dCbs) {
            stderr.writeln('ERROR: ${unit['name']} code $cbs is not in '
                'district ${dmap['name']} ($dCbs).');
            exit(1);
          }
        }

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
                '(${dmap['name']}): lat=$lat lng=$lng.');
            exit(1);
          }
        }
        // Ward-count validation: nullable, but when present must be a
        // sane positive integer (observed range 5-32; cap 40 for safety).
        final w = unit['wards'];
        if (w == null) {
          wardGaps++;
        } else if (w is! int || w < 1 || w > 40) {
          stderr.writeln('ERROR: invalid wards for ${unit['name']} '
              '(${dmap['name']}): wards=$w.');
          exit(1);
        } else {
          verifiedWards += w;
          verifiedWardsInProvince += w;
        }
      }
    }
    wards += province['wards'] as int;
    // A province's declared total can only ever be >= what its rows support.
    // If it is not, the declared figure is stale and must be re-sourced
    // rather than quietly published.
    final declaredInProvince = province['wards'] as int;
    if (verifiedWardsInProvince > declaredInProvince) {
      stderr.writeln(
        'ERROR: ${province['name']} rows sum to $verifiedWardsInProvince '
        'wards but the province declares only $declaredInProvince.',
      );
      exit(1);
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

  // Derived totals are reported, not gated: the gap between the declared
  // national ward total and the substantiated one is a documented data
  // property (8 palikas pending roster adjudication), not a defect. It is
  // printed on every run so a change in the gap cannot pass unnoticed.
  stdout.writeln('Coverage: $coded/$bodies palikas carry a CBS code '
      '($doublyAttested doubly-attested, '
      '${coded - doublyAttested} single-source).');
  stdout.writeln('Wards: $wards declared, $verifiedWards substantiated '
      'across ${bodies - wardGaps}/$bodies palikas ($wardGaps gaps, '
      'difference ${wards - verifiedWards}).');
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
    if (province['nameNe'] != null) {
      b.writeln("      nameNe: '${province['nameNe']}',");
      if (province['nameNeVerified'] == true) {
        b.writeln('      nameNeVerified: true,');
      }
    }
    if (province['capital'] != null) {
      b.writeln("      capital: '${province['capital']}',");
    }
    if (province['areaSqKm'] != null) {
      b.writeln('      areaSqKm: ${province['areaSqKm']},');
    }
    if (province['website'] != null) {
      b.writeln("      website: '${province['website']}',");
    }
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
      if (district['nameNe'] != null) {
        b.writeln("          nameNe: '${district['nameNe']}',");
        if (district['nameNeVerified'] == true) {
          b.writeln('          nameNeVerified: true,');
        }
      }
      final dCbs = district['cbsCode'];
      if (dCbs != null) {
        b.writeln('          cbsCode: $dCbs,');
      }
      if (district['headquarter'] != null) {
        b.writeln("          headquarter: '${district['headquarter']}',");
      }
      if (district['areaSqKm'] != null) {
        b.writeln('          areaSqKm: ${district['areaSqKm']},');
      }
      if (district['website'] != null) {
        b.writeln("          website: '${district['website']}',");
      }
      b.writeln('          units: [');
      for (final unit
          in (district['localBodies'] as List).cast<Map<String, dynamic>>()) {
        final lbCbs = unit['cbsCode'];
        final lbVerified = unit['cbsCodeVerified'] == true;
        final lbConfidence =
            unit['cbsCodeConfidence'] as String? ?? 'unverified';
        final lat = unit['lat'];
        final lng = unit['lng'];
        final geoSource = unit['geoSource'];
        final extra = StringBuffer();
        final nameNe = unit['nameNe'] as String?;
        if (nameNe != null) {
          // Devanagari names come from the dataset and contain no quotes or
          // backslashes, but a single quote is cheap to rule out explicitly:
          // a name containing one would otherwise produce broken Dart.
          if (nameNe.contains("'") ||
              nameNe.contains(r'\') ||
              nameNe.contains(r'$')) {
            stderr.writeln('ERROR: unsafe characters in nameNe for '
                '${unit['name']} (${district['name']}): $nameNe');
            exit(1);
          }
          extra.write(", nameNe: '$nameNe'");
          if (unit['nameNeVerified'] == true) {
            extra.write(', nameNeVerified: true');
          }
        }
        if (lbCbs != null) {
          extra.write(', cbsCode: $lbCbs, cbsCodeVerified: $lbVerified');
          extra.write(
            ', cbsCodeConfidence: '
            'CbsCodeConfidence.$lbConfidence',
          );
        }
        if (lat != null && lng != null) {
          extra.write(', lat: $lat, lng: $lng');
          if (geoSource != null) {
            extra.write(", geoSource: '$geoSource'");
          }
        }
        final wards = unit['wards'];
        if (wards != null) {
          extra.write(', wards: $wards');
          if (unit['wardsVerified'] == true) {
            extra.write(', wardsVerified: true');
          }
        }
        if (unit['website'] != null) {
          extra.write(", website: '${unit['website']}'");
        }
        if (unit['email'] != null) {
          extra.write(", email: '${unit['email']}'");
        }
        if (unit['phone'] != null) {
          extra.write(", phone: '${unit['phone']}'");
        }
        final zips = unit['zipCodes'];
        if (zips is List && zips.isNotEmpty) {
          extra.write(', zipCodes: [');
          extra.write(
            zips.map((z) => "'${'$z'.replaceAll("'", r"\'")}'").join(', '),
          );
          extra.write(']');
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
