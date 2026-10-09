// Run with: dart run example/nepal_admin_api_example.dart
import 'package:nepal_admin_api/nepal_admin_api.dart';

void main() {
  print('=======================================');
  print('Nepal Administrative Data API Demo');
  print('=======================================\n');

  // 1. National overview (computed live from the dataset)
  final stats = NepalAdminApi.getNationalStats();
  print('Provinces:      ${stats.provinces}');
  print('Districts:     ${stats.districts}');
  print('Local bodies:   ${stats.total}');
  print('Wards:          ${stats.wards}\n');

  // 2. One province
  final bagmati = NepalAdminApi.getProvinceById('bagmati');
  print('Profile: ${bagmati!.name} Province');
  print('Districts: ${bagmati.stats.districts}, '
      'Local bodies: ${bagmati.stats.total}\n');

  // 3. Local bodies of a district
  print('Local bodies in Chitwan:');
  final chitwan = NepalAdminApi.getDistrictByName('Chitwan')!;
  for (final body in chitwan.localBodies) {
    print(' - ${body.name} (${body.typeName})');
  }

  // 4. Typed search
  print('\nSearching for "Bharatpur"...');
  final results = NepalAdminApi.search('Bharatpur');
  for (final lb in results.localBodies) {
    print('Found: ${lb.name} [${lb.type.shortName}] '
        'in ${lb.districtName}, ${lb.provinceName}');
  }
}
