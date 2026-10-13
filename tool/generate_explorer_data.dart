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
        final confidence = body['cbsCodeConfidence'] as String? ??
            (cbsCodeVerified ? 'verified' : 'unverified');

        explorerData.add({
          'name': name,
          if (body['nameNe'] != null) 'nameNe': body['nameNe'],
          if (body['nameNeVerified'] == true) 'nameNeVerified': true,
          'type': type,
          'district': districtName,
          'province': provinceName,
          if (district['nameNe'] != null) 'districtNe': district['nameNe'],
          'cbsCode': cbsCode,
          'cbsCodeVerified': cbsCodeVerified,
          'cbsCodeConfidence': confidence,
          'isoCode': isoCode,
          if (body['lat'] != null) 'lat': body['lat'],
          if (body['lng'] != null) 'lng': body['lng'],
          if (body['geoSource'] != null) 'geoSource': body['geoSource'],
          if (body['wards'] != null) 'wards': body['wards'],
          if (body['wardsVerified'] == true) 'wardsVerified': true,
          if (body['website'] != null) 'website': body['website'],
          if (body['email'] != null) 'email': body['email'],
          if (body['phone'] != null) 'phone': body['phone'],
          if (body['zipCodes'] != null) 'zipCodes': body['zipCodes'],
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
  final coded = explorerData.where((d) => d['cbsCode'] != null).length;
  final doubled =
      explorerData.where((d) => d['cbsCodeConfidence'] == 'verified').length;
  final mapped = explorerData.where((d) => d['lat'] != null).length;
  final warded = explorerData.where((d) => d['wards'] != null).length;
  print('Generated docs/data.json');
  print('Total records: ${explorerData.length}');
  print('With CBS code: $coded ($doubled doubly-attested, '
      '${coded - doubled} single-source)');
  print('Without CBS code: ${explorerData.length - coded}');
  print('With coordinates: $mapped');
  print('Without coordinates: ${explorerData.length - mapped}');
  print('With wards: $warded');
  print('Without wards: ${explorerData.length - warded}');
}
