import 'dart:convert';
import 'dart:io';

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
        int count(LocalBodyType t) => bodies.where((b) => b.type == t).length;

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

    test('getProvinceById also matches ISO codes', () {
      expect(NepalAdminApi.getProvinceById('NP-P3')!.name, 'Bagmati');
      expect(NepalAdminApi.getProvinceById('np-p1')!.name, 'Koshi');
    });

    test('getProvinceByIso / getProvinceByCbs', () {
      expect(NepalAdminApi.getProvinceByIso('NP-P1')!.id, 'koshi');
      expect(NepalAdminApi.getProvinceByIso('np-p7')!.id, 'sudurpashchim');
      expect(NepalAdminApi.getProvinceByCbs(3)!.name, 'Bagmati');
      expect(NepalAdminApi.getProvinceByCbs(99), isNull);
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
        result.localBodies.any(
            (b) => b.districtName == 'Chitwan' && b.provinceName == 'Bagmati'),
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
      final bharatpur = NepalAdminApi.search('Bharatpur').localBodies.first;
      final restored = LocalBody.fromJson(bharatpur.toJson());
      expect(restored.name, bharatpur.name);
      expect(restored.type, bharatpur.type);
      expect(restored.districtName, bharatpur.districtName);
      expect(restored.provinceName, bharatpur.provinceName);
    });
  });

  group('v2.1 code-first lookups + helpers', () {
    test('getDistrictByCbs finds Kathmandu (306)', () {
      final ktm = NepalAdminApi.getDistrictByCbs(306)!;
      expect(ktm.name, 'Kathmandu');
      expect(ktm.provinceName, 'Bagmati');
      expect(NepalAdminApi.getDistrictByCbs(999), isNull);
    });

    test('getLocalBodyByCbs finds Bharatpur (31304)', () {
      final b = NepalAdminApi.getLocalBodyByCbs(31304)!;
      expect(b.name, 'Bharatpur');
      expect(b.districtName, 'Chitwan');
      expect(b.cbsCodeVerified, isTrue);
      expect(NepalAdminApi.getLocalBodyByCbs(99999), isNull);
    });

    test('getLocalBodiesByProvince accepts id or ISO', () {
      final byId = NepalAdminApi.getLocalBodiesByProvince('bagmati');
      final byIso = NepalAdminApi.getLocalBodiesByProvince('NP-P3');
      expect(byId.length, byIso.length);
      expect(byId, isNotEmpty);
      expect(NepalAdminApi.getLocalBodiesByProvince('atlantis'), isEmpty);
    });

    test('getLocalBodiesByType + getVerifiedLocalBodies counts', () {
      expect(
          NepalAdminApi.getLocalBodiesByType(LocalBodyType.metropolitan).length,
          6);
      expect(
          NepalAdminApi.getLocalBodiesByType(LocalBodyType.ruralMunicipality)
              .length,
          460);
      final verified = NepalAdminApi.getVerifiedLocalBodies();
      expect(verified.length, 547);
      expect(verified.every((b) => b.cbsCodeVerified), isTrue);
    });

    test('fullPath + list extensions', () {
      final bharatpur = NepalAdminApi.search('Bharatpur').localBodies.first;
      expect(bharatpur.fullPath, 'Bharatpur, Chitwan, Bagmati');
      expect(bharatpur.isUrban, isTrue);
      expect(bharatpur.isRural, isFalse);

      final bodies = NepalAdminApi.getAllLocalBodies();
      final sorted = bodies.sortedByName;
      expect(
        sorted.first.name
                .toLowerCase()
                .compareTo(sorted.last.name.toLowerCase()) <=
            0,
        isTrue,
        reason: 'sortedByName should order alphabetically',
      );
      expect(
          bodies.whereUrban.length + bodies.whereRural.length, bodies.length);
      expect(bodies.whereVerified.length, 547);
      expect(bodies.ofType(LocalBodyType.metropolitan).length, 6);
    });

    test('search matches ISO codes and full paths', () {
      expect(NepalAdminApi.search('NP-P3').provinces.map((p) => p.id),
          contains('bagmati'));
      expect(
          NepalAdminApi.search('Bharatpur, Chitwan').localBodies, isNotEmpty);
    });
  });

  group('v2.2 coordinates', () {
    test('coordinates are inside the Nepal bounding box', () {
      for (final b in NepalAdminApi.getAllLocalBodies()) {
        if (b.lat != null && b.lng != null) {
          expect(b.lat!, greaterThanOrEqualTo(26.0),
              reason: '${b.fullPath} lat');
          expect(b.lat!, lessThanOrEqualTo(31.0), reason: '${b.fullPath} lat');
          expect(b.lng!, greaterThanOrEqualTo(80.0),
              reason: '${b.fullPath} lng');
          expect(b.lng!, lessThanOrEqualTo(89.0), reason: '${b.fullPath} lng');
        }
      }
    });

    test('majority of palikas are mapped', () {
      final mapped = NepalAdminApi.getAllLocalBodies().whereMapped;
      expect(mapped.length, greaterThanOrEqualTo(700));
    });

    test('hasCoordinates + whereMapped agree', () {
      final bodies = NepalAdminApi.getAllLocalBodies();
      expect(bodies.whereMapped.length,
          bodies.where((b) => b.hasCoordinates).length);
    });

    test('json round-trip preserves coordinates', () {
      final mapped =
          NepalAdminApi.getAllLocalBodies().firstWhere((b) => b.hasCoordinates);
      final restored = LocalBody.fromJson(mapped.toJson());
      expect(restored.lat, mapped.lat);
      expect(restored.lng, mapped.lng);
      expect(restored.geoSource, mapped.geoSource);
    });

    test('unmapped palikas have null coordinates', () {
      for (final b in NepalAdminApi.getAllLocalBodies()) {
        if (!b.hasCoordinates) {
          expect(b.lat, isNull);
          expect(b.lng, isNull);
        }
      }
    });
  });

  group('v2.3 ward counts', () {
    test('wards are sane positive integers when present', () {
      for (final b in NepalAdminApi.getAllLocalBodies()) {
        if (b.wards != null) {
          expect(b.wards!, greaterThanOrEqualTo(1),
              reason: '${b.fullPath} wards');
          expect(b.wards!, lessThanOrEqualTo(40),
              reason: '${b.fullPath} wards');
        }
      }
    });

    test('745 palikas carry verified ward counts', () {
      final bodies = NepalAdminApi.getAllLocalBodies();
      final verified = bodies.whereWardsVerified;
      expect(verified.length, 745);
      expect(verified.every((b) => b.wards != null), isTrue);
    });

    test('the 8 known gaps are exactly the roster-defect set', () {
      const expectedGaps = {
        'Udayapur|Sunkoshi',
        'Saptari|Belhi Chapena',
        'Nuwakot|Meghang',
        'Rasuwa|Aamachhodingmo',
        'Manang|Naraphu',
        'Manang|Neshang',
        'Salyan|Dhorchaur',
        'Bajhang|Kanda',
      };
      final actualGaps = {
        for (final b in NepalAdminApi.getAllLocalBodies())
          if (b.wards == null) '${b.districtName}|${b.name}',
      };
      expect(actualGaps, expectedGaps);
    });

    test('Lumbini reconciles fully (109 units, 983 wards)', () {
      final lumbini = NepalAdminApi.getProvinceById('lumbini')!;
      final bodies = lumbini.localBodies;
      expect(bodies.length, 109);
      expect(bodies.every((b) => b.wards != null), isTrue);
      final sum = bodies.fold<int>(0, (s, b) => s + b.wards!);
      expect(sum, lumbini.stats.wards);
      expect(sum, 983);
    });

    test('District.wards sums verified counts', () {
      final chitwan = NepalAdminApi.getDistrictByName('Chitwan')!;
      expect(chitwan.wards,
          chitwan.localBodies.fold<int>(0, (s, b) => s + (b.wards ?? 0)));
      // Spot check: Bharatpur metro has 29 wards.
      final bharatpur = NepalAdminApi.getLocalBodyByCbs(31304)!;
      expect(bharatpur.wards, 29);
      expect(bharatpur.wardsVerified, isTrue);
    });

    test('json round-trip preserves wards', () {
      final withWards =
          NepalAdminApi.getAllLocalBodies().firstWhere((b) => b.wards != null);
      final restored = LocalBody.fromJson(withWards.toJson());
      expect(restored.wards, withWards.wards);
      expect(restored.wardsVerified, withWards.wardsVerified);
    });
  });

  group('provenance freshness', () {
    test('meta.dataAsOf never regresses below last verification', () {
      // Floor = v2.3.1 verification date. Bump the floor (not the
      // assertion) whenever the snapshot is re-verified.
      final raw = File('data/nepal_local_levels.json').readAsStringSync();
      final meta = (jsonDecode(raw) as Map)['meta'] as Map;
      final asOf = DateTime.parse(meta['dataAsOf'] as String);
      expect(asOf.isBefore(DateTime(2026, 10, 13)), isFalse,
          reason: 'dataAsOf ${meta['dataAsOf']} predates last verification; '
              're-verify the snapshot and bump the date + test floor');
    });
  });
}
