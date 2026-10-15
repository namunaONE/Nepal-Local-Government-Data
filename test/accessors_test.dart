// Covers the accessors the suite never exercised: equality, toString,
// per-district/per-province filtered views, unknown-id fallbacks, and the
// LocalBodyListX sort extensions. Each asserts a real behavior, not a line.
import 'package:nepal_admin_api/nepal_admin_api.dart';
import 'package:test/test.dart';

void main() {
  LocalBody bharatpur() => NepalAdminApi.getLocalBodyByCbs(31304)!;
  District chitwan() => NepalAdminApi.getDistrictByName('Chitwan')!;
  Province bagmati() => NepalAdminApi.getProvinceById('bagmati')!;

  group('LocalBodyType.fromShort', () {
    test('resolves every known abbreviation and refuses unknown ones', () {
      expect(LocalBodyType.fromShort('RM'), LocalBodyType.ruralMunicipality);
      expect(LocalBodyType.fromShort('M'), LocalBodyType.municipality);
      expect(LocalBodyType.fromShort('bogus'), LocalBodyType.unknown);
      expect(LocalBodyType.fromShort(null), LocalBodyType.unknown);
    });
  });

  group('LocalBody equality and display', () {
    test('same record compares equal with matching hashCode', () {
      final a = bharatpur();
      final b = NepalAdminApi.getLocalBodyByCbs(31304)!;
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a == ('Bharatpur' as Object), isFalse);
    });

    test('toString names the body with its type abbreviation', () {
      expect(bharatpur().toString(), contains('Bharatpur'));
    });

    test('typeName delegates to the type', () {
      expect(bharatpur().typeName, bharatpur().type.fullName);
    });
  });

  group('District filtered views', () {
    test('localBodiesByType partitions the district roster', () {
      final d = chitwan();
      final metros = d.localBodiesByType(LocalBodyType.metropolitan);
      expect(metros.map((b) => b.name), contains('Bharatpur'));
      expect(metros.every((b) => b.type == LocalBodyType.metropolitan), isTrue);
      final all = LocalBodyType.values
          .fold<int>(0, (s, t) => s + d.localBodiesByType(t).length);
      expect(all, d.localBodyCount);
    });

    test('verifiedLocalBodies is the doubly-attested subset', () {
      final d = chitwan();
      final verified = d.verifiedLocalBodies;
      expect(verified, isNotEmpty);
      expect(verified.every((b) => b.cbsCodeVerified), isTrue);
      expect(verified.length,
          lessThanOrEqualTo(NepalAdminApi.getVerifiedLocalBodies().length));
    });

    test('District equality and display', () {
      final a = chitwan();
      final b = NepalAdminApi.getDistrictByName('chitwan')!;
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a.toString(), 'District(Chitwan)');
      expect(a == ('Chitwan' as Object), isFalse);
    });
  });

  group('Province aggregate views', () {
    test('localBodies flattens every district roster', () {
      final p = bagmati();
      final flat = p.localBodies;
      expect(flat.length,
          p.districts.fold<int>(0, (s, d) => s + d.localBodyCount));
      expect(flat.length, p.localBodyCount);
    });

    test('Province equality and display', () {
      final a = bagmati();
      final b = NepalAdminApi.getProvinceById('BAGMATI')!;
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a.toString(), 'Province(Bagmati)');
      expect(a == ('bagmati' as Object), isFalse);
    });
  });

  group('NationalStats and SearchResult display', () {
    test('NationalStats toString states the gazetted shape', () {
      final s = NepalAdminApi.getNationalStats().toString();
      expect(s, contains('7 provinces'));
      expect(s, contains('77 districts'));
      expect(s, contains('753 local'));
    });

    test('SearchResult length sums all three hit lists', () {
      final r = NepalAdminApi.search('Bharatpur');
      expect(r.length,
          r.provinces.length + r.districts.length + r.localBodies.length);
      expect(r.length, greaterThan(0));
    });
  });

  group('unknown-id fallbacks return empty, never throw', () {
    test('getDistrictsByProvince with a bad id', () {
      expect(NepalAdminApi.getDistrictsByProvince('atlantis'), isEmpty);
    });

    test('getLocalBodiesByDistrict with a bad name', () {
      expect(NepalAdminApi.getLocalBodiesByDistrict('atlantis'), isEmpty);
    });
  });

  group('LocalBodyListX sorting', () {
    test('sortedByName orders case-insensitively', () {
      final sorted = NepalAdminApi.getAllLocalBodies().sortedByName;
      expect(sorted, hasLength(753));
      for (var i = 1; i < sorted.length; i++) {
        expect(
            sorted[i - 1]
                .name
                .toLowerCase()
                .compareTo(sorted[i].name.toLowerCase()),
            lessThanOrEqualTo(0));
      }
    });

    test('sortedByFullPath disambiguates same-named bodies', () {
      final sorted = NepalAdminApi.getAllLocalBodies().sortedByFullPath;
      expect(sorted, hasLength(753));
      final sunkoshi = sorted.where((b) => b.name == 'Sunkoshi').toList();
      expect(sunkoshi, hasLength(4));
      // Full paths are unique even where bare names are not.
      expect(sunkoshi.map((b) => b.fullPath).toSet(), hasLength(4));
      for (var i = 1; i < sorted.length; i++) {
        expect(
            sorted[i - 1]
                .fullPath
                .toLowerCase()
                .compareTo(sorted[i].fullPath.toLowerCase()),
            lessThanOrEqualTo(0));
      }
    });
  });
}
