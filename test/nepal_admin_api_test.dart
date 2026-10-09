import 'package:nepal_admin_api/nepal_admin_api.dart';
import 'package:test/test.dart';

void main() {
  group('national structure (official figures)', () {
    test('7 provinces, 77 districts, 753 local bodies', () {
      expect(NepalAdminApi.getAllProvinces().length, 7);
      expect(NepalAdminApi.getAllDistricts().length, 77);
      expect(NepalAdminApi.getAllLocalBodies().length, 753);
    });

    test('type split: 6 metro, 11 sub-metro, 276 municipalities, 460 RMs', () {
      final bodies = NepalAdminApi.getAllLocalBodies();
      int count(LocalBodyType t) => bodies.where((b) => b.type == t).length;
      expect(count(LocalBodyType.metropolitan), 6);
      expect(count(LocalBodyType.subMetropolitan), 11);
      expect(count(LocalBodyType.municipality), 276);
      expect(count(LocalBodyType.ruralMunicipality), 460);
      expect(count(LocalBodyType.unknown), 0,
          reason: 'a raw string failed to parse');
    });

    test('6,743 wards in total', () {
      final stats = NepalAdminApi.getNationalStats();
      expect(stats.wards, 6743);
    });
  });

  group('declared province stats match parsed data', () {
    test('every province reconciles', () {
      for (final p in NepalAdminApi.getAllProvinces()) {
        final bodies = [for (final d in p.districts) ...d.localBodies];
        int count(LocalBodyType t) =>
            bodies.where((b) => b.type == t).length;

        expect(p.districts.length, p.stats.districts,
            reason: '${p.name} districts');
        expect(count(LocalBodyType.metropolitan), p.stats.metro,
            reason: '${p.name} metro');
        expect(count(LocalBodyType.subMetropolitan), p.stats.subMetro,
            reason: '${p.name} sub-metro');
        expect(count(LocalBodyType.municipality), p.stats.mun,
            reason: '${p.name} municipalities');
        expect(count(LocalBodyType.ruralMunicipality), p.stats.ruralMun,
            reason: '${p.name} rural');
        expect(bodies.length, p.stats.total, reason: '${p.name} total');
      }
    });
  });

  group('data hygiene', () {
    test('every local body has a province and district context', () {
      for (final d in NepalAdminApi.getAllDistricts()) {
        for (final b in d.localBodies) {
          expect(b.name, isNotEmpty, reason: 'empty name in ${d.name}');
          expect(b.provinceName, isNotEmpty,
              reason: '${b.name} lost its province');
          expect(b.districtName, d.name);
        }
      }
    });

    test('no duplicate local body names inside a district', () {
      for (final d in NepalAdminApi.getAllDistricts()) {
        final names = d.localBodies.map((b) => b.name).toSet();
        expect(names.length, d.localBodyCount,
            reason: 'duplicates inside ${d.name}');
      }
    });
  });

  group('lookups', () {
    test('getProvinceById is case-insensitive', () {
      expect(NepalAdminApi.getProvinceById('Bagmati')!.name, 'Bagmati');
      expect(NepalAdminApi.getProvinceById('atlantis'), isNull);
    });

    test('getDistrictByName + local bodies of Chitwan', () {
      final chitwan = NepalAdminApi.getDistrictByName('chitwan')!;
      expect(chitwan.provinceName, 'Bagmati');
      expect(chitwan.localBodyCount, 7);
      expect(chitwan.localBodies.first.name, 'Bharatpur');
    });

    test('search is typed and disambiguates by district/province', () {
      final result = NepalAdminApi.search('Bharatpur');
      expect(result.localBodies, isNotEmpty);
      expect(
        result.localBodies
            .any((b) => b.districtName == 'Chitwan' && b.provinceName == 'Bagmati'),
        isTrue,
      );
    });

    test('searching a duplicated name returns every match', () {
      // 4 palikas are named Sunkoshi across the country.
      final result = NepalAdminApi.search('Sunkoshi');
      expect(result.localBodies.length, greaterThanOrEqualTo(4));
    });

    test('national stats are computed, not hardcoded', () {
      final s = NepalAdminApi.getNationalStats();
      expect(s.provinces, 7);
      expect(s.districts, 77);
      expect(s.total, 753);
    });

    test('json round-trip of a local body', () {
      final bharatpur =
          NepalAdminApi.search('Bharatpur').localBodies.first;
      final restored = LocalBody.fromJson(bharatpur.toJson());
      expect(restored.name, bharatpur.name);
      expect(restored.type, bharatpur.type);
      expect(restored.districtName, bharatpur.districtName);
      expect(restored.provinceName, bharatpur.provinceName);
    });
  });
}
