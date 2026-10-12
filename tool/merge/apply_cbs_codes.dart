import 'dart:convert';
import 'dart:io';

/// Reads the staged CBS codes and applies them to nepal_local_levels.json,
/// producing an updated JSON with cbsCode fields at province, district, and localBody levels.
void main() {
  // Load the staged CBS assignments
  final stagedFile = File('data/_stage/nso_codes.json');
  final stagedJson =
      jsonDecode(stagedFile.readAsStringSync()) as Map<String, dynamic>;
  final assignments =
      (stagedJson['assignments'] as List).cast<Map<String, dynamic>>();

  // Build lookup: province|district|name|type -> {nsoCode, nsoCodeVerified, evidence}
  final codeLookup = <String, Map<String, dynamic>>{};
  for (final a in assignments) {
    final key = '${a['province']}|${a['district']}|${a['name']}|${a['type']}';
    codeLookup[key] = a;
  }

  // Load the current local levels JSON
  final levelsFile = File('data/nepal_local_levels.json');
  final levelsJson =
      jsonDecode(levelsFile.readAsStringSync()) as Map<String, dynamic>;
  final provinces =
      (levelsJson['provinces'] as List).cast<Map<String, dynamic>>();

  // Province ID -> CBS province code (1-7)
  // Based on cbs_states.csv and official ordering
  const provinceCbsCodes = <String, int>{
    'koshi': 1,
    'madhesh': 2,
    'bagmati': 3,
    'gandaki': 4,
    'lumbini': 5,
    'karnali': 6,
    'sudurpashchim': 7,
  };

  // District name -> CBS district code (3-digit)
  // Build from assignments by looking at the first 3 digits of local body codes
  final districtCbsCodes = <String, int>{};
  for (final a in assignments) {
    final nsoCodeRaw = a['nsoCode'];
    if (nsoCodeRaw != null && a['nsoCodeVerified'] == true) {
      final code = int.parse(nsoCodeRaw.toString());
      final districtCode = code ~/ 100; // e.g., 10604 -> 106
      final key = '${a['province']}|${a['district']}';
      if (!districtCbsCodes.containsKey(key)) {
        districtCbsCodes[key] = districtCode;
      }
    }
  }

  // District codes are already derived from verified local body codes above.
  // The cbs_districts.csv is used as a cross-reference but not needed for
  // the primary assignment since our verified local body codes implicitly
  // define the district codes.

  // Apply CBS codes to the JSON structure
  for (final province in provinces) {
    final provinceId = province['id'] as String;
    province['cbsCode'] = provinceCbsCodes[provinceId];
    province['isoCode'] = 'NP-P${provinceCbsCodes[provinceId]}';

    final provinceDistricts =
        (province['districts'] as List).cast<Map<String, dynamic>>();
    for (final district in provinceDistricts) {
      final districtName = district['name'] as String;
      final dKey = '$provinceId|$districtName';
      final districtCode = districtCbsCodes[dKey];
      if (districtCode != null) {
        district['cbsCode'] = districtCode;
      }

      final localBodies =
          (district['localBodies'] as List).cast<Map<String, dynamic>>();
      for (final body in localBodies) {
        final bodyName = body['name'] as String;
        final bodyType = body['type'] as String;
        final key = '$provinceId|$districtName|$bodyName|$bodyType';
        final assignment = codeLookup[key];
        if (assignment != null && assignment['nsoCode'] != null) {
          body['cbsCode'] = int.parse(assignment['nsoCode'].toString());
          body['cbsCodeVerified'] = assignment['nsoCodeVerified'];
        }
      }
    }
  }

  // Write the updated JSON
  const encoder = JsonEncoder.withIndent('  ');
  levelsFile.writeAsStringSync(encoder.convert(levelsJson));
  stdout.writeln('Updated data/nepal_local_levels.json with CBS codes');

  // Report stats
  var verifiedCount = 0;
  var totalCount = 0;
  for (final a in assignments) {
    totalCount++;
    if (a['nsoCodeVerified'] == true) verifiedCount++;
  }
  stdout.writeln(
      'CBS codes applied: $verifiedCount verified / $totalCount total');
}
