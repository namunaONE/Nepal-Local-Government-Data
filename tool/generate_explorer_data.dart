import 'dart:convert';
import 'dart:io';

void main() {
  // Read the main data file
  final dataFile = File('data/nepal_local_levels.json');
  final json = jsonDecode(dataFile.readAsStringSync()) as Map<String, dynamic>;
  final provinces = (json['provinces'] as List).cast<Map<String, dynamic>>();

  final explorerData = <Map<String, dynamic>>[];

  for (final province in provinces) {
    final provinceName = province['name'] as String;
    final provinceCbsCode = province['cbsCode'] as int;
    final isoCode = 'NP-P$provinceCbsCode';

    final districts =
        (province['districts'] as List).cast<Map<String, dynamic>>();

    for (final district in districts) {
      final districtName = district['name'] as String;

      final localBodies =
          (district['localBodies'] as List).cast<Map<String, dynamic>>();

      for (final body in localBodies) {
        final name = body['name'] as String;
        final type = body['type'] as String;
        final cbsCode = body['cbsCode'] as int?;
        final cbsCodeVerified = body['cbsCodeVerified'] as bool? ?? false;

        explorerData.add({
          'name': name,
          'type': type,
          'district': districtName,
          'province': provinceName,
          'cbsCode': cbsCode,
          'cbsCodeVerified': cbsCodeVerified,
          'isoCode': isoCode,
        });
      }
    }
  }

  // Sort by province, district, name for consistent ordering
  explorerData.sort((a, b) {
    final p = a['province'].toString().compareTo(b['province'].toString());
    if (p != 0) return p;
    final d = a['district'].toString().compareTo(b['district'].toString());
    if (d != 0) return d;
    return a['name'].toString().compareTo(b['name'].toString());
  });

  // Write to docs/data.json
  const encoder = JsonEncoder.withIndent('  ');
  File('docs/data.json').writeAsStringSync(encoder.convert(explorerData));

  // Stats
  final verified = explorerData.where((d) => d['cbsCode'] != null).length;
  print('Generated docs/data.json');
  print('Total records: ${explorerData.length}');
  print('Verified CBS codes: $verified');
  print('Unverified: ${explorerData.length - verified}');
}
