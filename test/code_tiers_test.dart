// Tests for the v2.4.0 additions: CBS code confidence tiers, ward-total
// reconciliation, model round-trips and the duplicate-name lookups.
//
// The headline change is that a code is no longer all-or-nothing. 744 of 753
// palikas now carry a CBS code of some confidence (up from 547), and the two
// ward totals are reported side by side instead of one silently shadowing
// the other.

import 'package:nepal_admin_api/nepal_admin_api.dart';
import 'package:test/test.dart';

void main() {
  final bodies = NepalAdminApi.getAllLocalBodies();

  group('CBS code confidence tiers', () {
    test('every palika carries a tier and the tier agrees with the flag', () {
      for (final b in bodies) {
        if (b.cbsCode == null) {
          expect(b.cbsCodeConfidence, CbsCodeConfidence.unverified,
              reason: '${b.fullPath} has no code, so no tier');
          expect(b.cbsCodeVerified, isFalse,
              reason: '${b.fullPath} has no code, so not verified');
        } else {
          expect(b.hasCbsCode, isTrue);
          // The boolean is exactly the "doubly-attested" case of the tier.
          expect(b.cbsCodeVerified,
              b.cbsCodeConfidence == CbsCodeConfidence.verified,
              reason: '${b.fullPath}: flag and tier disagree');
        }
      }
    });

    test('tier counts are 548 verified / 196 single-source / 9 unverified', () {
      final byTier = <CbsCodeConfidence, int>{};
      for (final b in bodies) {
        byTier[b.cbsCodeConfidence] = (byTier[b.cbsCodeConfidence] ?? 0) + 1;
      }
      expect(byTier[CbsCodeConfidence.verified], 548);
      expect(byTier[CbsCodeConfidence.singleSource], 196);
      expect(byTier[CbsCodeConfidence.unverified], 9);
      expect(byTier.values.reduce((a, b) => a + b), 753);
    });

    test('code coverage is 744/753, up from 547 before the tiers existed', () {
      expect(NepalAdminApi.getLocalBodiesWithCode().length, 744);
      expect(bodies.whereCoded.length, 744);
      expect(NepalAdminApi.getUncodedLocalBodies().length, 9);
      expect(bodies.whereUncoded.length, 9);
      expect(
        bodies.whereDoublyAttested.length +
            bodies.whereSingleSource.length +
            bodies.whereUncoded.length,
        bodies.length,
      );
    });

    test('every code sits inside its own district', () {
      for (final b in bodies.whereCoded) {
        expect(b.cbsCode! ~/ 100,
            NepalAdminApi.getDistrictByName(b.districtName)!.cbsCode,
            reason: '${b.fullPath} code ${b.cbsCode} is in the wrong district');
      }
    });

    test('codes are unique nationwide, so a code-keyed join is lossless', () {
      final map = bodies.byCbsCode;
      expect(map.length, 744, reason: 'no code may map to two palikas');
      for (final entry in map.entries) {
        expect(entry.value.cbsCode, entry.key);
      }
    });

    test('the 9 uncoded palikas are documented ambiguities, not omissions', () {
      const expected = {
        'Bajura|Jagannath',
        'Bajura|Khaptad Chhededaha',
        'Jajarkot|Bheri',
        'Jajarkot|Nalagad',
        'Rolpa|Gangadev',
        'Rolpa|Paribartan',
        'Rolpa|Sunil Smriti',
        'Solukhumbu|Mapya Dudhkoshi',
        'Solukhumbu|Thulung Dudhkoshi',
      };
      final actual = {
        for (final b in NepalAdminApi.getUncodedLocalBodies())
          '${b.districtName}|${b.name}',
      };
      expect(actual, expected);
    });

    test('spot checks: single-source and forced-elimination assignments', () {
      // Kanaka Sundari became doubly-attested once the CBS roster's
      // romanized "Gaun Palika" spelling was recognised.
      final kanaka =
          NepalAdminApi.getLocalBodiesByName('Kanaka Sundari', 'Jumla').single;
      expect(kanaka.cbsCode, 60402);
      expect(kanaka.cbsCodeConfidence, CbsCodeConfidence.verified);

      // Pokhara is matched by forced elimination: our roster says "Pokhara",
      // CBS says "Pokhara Lekhnath Metropolitian City".
      final pokhara = NepalAdminApi.getLocalBodyByCbs(40504)!;
      expect(pokhara.name, 'Pokhara');
      expect(pokhara.cbsCodeConfidence, CbsCodeConfidence.singleSource);
      expect(pokhara.cbsCodeVerified, isFalse);

      // Gulmi Durbar is CBS "Gulmi Durbar Gaunpaika" - a spelling variant that
      // had to be added to the type vocabulary.
      final gulmi = NepalAdminApi.getLocalBodyByCbs(50410)!;
      expect(gulmi.name, 'Gulmi Durbar');
      expect(gulmi.type, LocalBodyType.ruralMunicipality);
    });
  });

  group('CBS code lookups', () {
    test('getLocalBodyByCbs resolves any tier (744 reachable)', () {
      final byCode = bodies.byCbsCode;
      for (final entry in byCode.entries) {
        expect(
            NepalAdminApi.getLocalBodyByCbs(entry.key)!.name, entry.value.name);
      }
      expect(NepalAdminApi.getLocalBodyByCbs(99999), isNull);
    });

    test('getLocalBodyByCbsVerified is restricted to the strict tier', () {
      final verified = NepalAdminApi.getVerifiedLocalBodies();
      for (final b in verified.take(50)) {
        expect(
            NepalAdminApi.getLocalBodyByCbsVerified(b.cbsCode!)?.name, b.name);
      }
      // Pokhara's code is single-source, so the strict lookup must miss it.
      expect(NepalAdminApi.getLocalBodyByCbsVerified(40504), isNull);
      expect(NepalAdminApi.getLocalBodyByCbs(40504), isNotNull);
    });

    test('cbsCodeString is zero-padded to the 5-digit PDDPP width', () {
      final bharatpur = NepalAdminApi.getLocalBodyByCbs(31304)!;
      expect(bharatpur.cbsCodeString, '31304');
      // 10101 is Phaktanglung, Taplejung's first rural municipality.
      expect(NepalAdminApi.getLocalBodyByCbs(10101)!.name, 'Phaktanglung');
      final anyCoded = bodies.whereCoded.first;
      expect(anyCoded.cbsCodeString!.length, 5);
      expect(anyCoded.districtCbsCodeString!.length, 3);
      final uncoded = NepalAdminApi.getUncodedLocalBodies().first;
      expect(uncoded.cbsCodeString, isNull);
      expect(uncoded.districtCbsCodeString, isNull);
    });
  });

  group('ward reconciliation', () {
    test('declared and substantiated ward totals are both exposed', () {
      final s = NepalAdminApi.getNationalStats();
      expect(s.wards, 6743, reason: 'the declared national figure');
      expect(s.verifiedWards, 6697, reason: 'the sum of rows we can attest');
      expect(s.wardGaps, 8);
      expect(s.unreconciledWards, 46);
      expect(s.verifiedWards + s.unreconciledWards, s.wards);
    });

    test('no province claims fewer wards than its rows can substantiate', () {
      for (final p in NepalAdminApi.getAllProvinces()) {
        expect(p.unreconciledWards, greaterThanOrEqualTo(0),
            reason: '${p.name} rows exceed its declared total');
        expect(p.verifiedWards, p.localBodies.totalWards);
      }
    });

    test('Lumbini is the one province that reconciles exactly', () {
      final lumbini = NepalAdminApi.getProvinceById('lumbini')!;
      expect(lumbini.unreconciledWards, 0);
      expect(lumbini.wardsReconcile, isTrue);
      expect(lumbini.declaredWards, 983);
      expect(lumbini.verifiedWards, 983);
    });

    test('the other six provinces differ by exactly their known gaps', () {
      const expected = {
        'Koshi': 5,
        'Madhesh': 6,
        'Bagmati': 11,
        'Gandaki': 14,
        'Karnali': 5,
        'Sudurpashchim': 5,
      };
      for (final p in NepalAdminApi.getAllProvinces()) {
        if (expected.containsKey(p.name)) {
          expect(p.unreconciledWards, expected[p.name],
              reason: '${p.name} unreconciled wards');
          expect(p.wardsReconcile, isFalse);
        }
      }
      // The gaps add up to the national difference.
      expect(expected.values.reduce((a, b) => a + b), 46);
    });

    test('district coverage reporting agrees with the national totals', () {
      var withCount = 0;
      var missing = 0;
      for (final d in NepalAdminApi.getAllDistricts()) {
        final c = d.verifiedWardCoverage;
        expect(c.total, d.localBodyCount);
        expect(c.withCount + c.missing, c.total);
        withCount += c.withCount;
        missing += c.missing;
      }
      expect(withCount, 745);
      expect(missing, 8);
    });

    test('wardsFullyVerified is true only for clean districts', () {
      final chitwan = NepalAdminApi.getDistrictByName('Chitwan')!;
      expect(chitwan.wardsFullyVerified, isTrue);
      expect(chitwan.verifiedWardCoverage.missing, 0);

      final withGap = NepalAdminApi.getAllDistricts()
          .where((d) => d.verifiedWardCoverage.missing > 0);
      expect(withGap.length, greaterThan(0),
          reason: 'the 8 documented gaps should surface here');
      expect(withGap.every((d) => d.wardsFullyVerified == false), isTrue);
    });
  });

  group('duplicate-name lookups', () {
    test('getLocalBodiesByName scopes to a district', () {
      final sankhu =
          NepalAdminApi.getLocalBodiesByName('Sunkoshi', 'Okhaldhunga');
      expect(sankhu.length, 1);
      expect(sankhu.single.districtName, 'Okhaldhunga');

      // The same name exists in other districts; scoping disambiguates.
      expect(NepalAdminApi.search('Sunkoshi').localBodies.length,
          greaterThanOrEqualTo(4));
      expect(
          NepalAdminApi.getLocalBodiesByName('Sunkoshi', 'Atlantis'), isEmpty);
    });

    test('getLocalBodyByFullPath resolves an unambiguous path', () {
      final bharatpur =
          NepalAdminApi.getLocalBodyByFullPath('Bharatpur, Chitwan, Bagmati');
      expect(bharatpur?.name, 'Bharatpur');
      expect(bharatpur?.cbsCode, 31304);

      // Order-insensitive and tolerant of a partial path.
      expect(NepalAdminApi.getLocalBodyByFullPath('Bagmati, Bharatpur')?.name,
          'Bharatpur');
      expect(
          NepalAdminApi.getLocalBodyByFullPath('  bharatpur , chitwan  ')?.name,
          'Bharatpur');

      // A bare duplicated name is ambiguous and must resolve to null, not a
      // silently-chosen palika.
      expect(NepalAdminApi.getLocalBodyByFullPath('Sunkoshi'), isNull);
      expect(NepalAdminApi.getLocalBodyByFullPath('Nowhere, Nowhere'), isNull);
      expect(NepalAdminApi.getLocalBodyByFullPath(''), isNull);
    });
  });

  group('model serialization and equality', () {
    test('LocalBody round-trips including the tier', () {
      for (final b in bodies.where((b) => b.cbsCode != null).take(40)) {
        final r = LocalBody.fromJson(b.toJson());
        expect(r.cbsCode, b.cbsCode);
        expect(r.cbsCodeConfidence, b.cbsCodeConfidence);
        expect(r.cbsCodeVerified, b.cbsCodeVerified);
      }
      final uncoded = NepalAdminApi.getUncodedLocalBodies().first;
      final restored = LocalBody.fromJson(uncoded.toJson());
      expect(restored.cbsCode, isNull);
      expect(restored.cbsCodeConfidence, CbsCodeConfidence.unverified);
      expect(restored.cbsCodeVerified, isFalse);
    });

    test('District round-trips and re-attaches province context', () {
      final chitwan = NepalAdminApi.getDistrictByName('Chitwan')!;
      final restored = District.fromJson(chitwan.toJson());
      expect(restored.name, chitwan.name);
      expect(restored.cbsCode, chitwan.cbsCode);
      expect(restored.provinceName, chitwan.provinceName);
      expect(restored.localBodyCount, chitwan.localBodyCount);
      expect(restored.wards, chitwan.wards);
      expect(restored, chitwan, reason: 'value equality');
      expect(restored.hashCode, chitwan.hashCode);
    });

    test('Province round-trips', () {
      final bagmati = NepalAdminApi.getProvinceById('bagmati')!;
      final restored = Province.fromJson(bagmati.toJson());
      expect(restored.name, bagmati.name);
      expect(restored.id, bagmati.id);
      expect(restored.cbsCode, bagmati.cbsCode);
      expect(restored.isoCode, bagmati.isoCode);
      expect(restored.districts.length, bagmati.districts.length);
      // The constructor re-attaches province context to each district.
      expect(
          restored.districts.every((d) => d.provinceName == 'Bagmati'), isTrue);
      expect(restored, bagmati);
    });

    test('LocalBody equality ignores derived coordinates', () {
      final b = bodies.whereCoded.first;
      final copy = LocalBody(
        name: b.name,
        type: b.type,
        districtName: b.districtName,
        provinceName: b.provinceName,
        cbsCode: b.cbsCode,
        lat: 27.0,
        lng: 85.0,
      );
      expect(copy, b);
      expect({b, copy}.length, 1);
    });

    test('a hand-built map cannot claim verified while its tier says otherwise',
        () {
      final b = LocalBody.fromJson({
        'name': 'X',
        'type': 'M',
        'district': 'D',
        'province': 'P',
        'cbsCode': 12345,
        'cbsCodeVerified': true,
        'cbsCodeConfidence': 'singleSource',
      });
      expect(b.cbsCodeVerified, isTrue);
      expect(b.cbsCodeConfidence, CbsCodeConfidence.verified,
          reason: 'the flag wins so the two never contradict');

      // And a code with no tier at all is treated as unverified, not promoted.
      final noTier = LocalBody.fromJson({
        'name': 'Y',
        'type': 'M',
        'district': 'D',
        'province': 'P',
        'cbsCode': 12346,
      });
      expect(noTier.cbsCodeVerified, isFalse);
      expect(noTier.cbsCodeConfidence, CbsCodeConfidence.unverified);
      expect(noTier.hasCbsCode, isTrue);
    });

    test('NationalStats serializes both ward figures', () {
      final json = NepalAdminApi.getNationalStats().toJson();
      expect(json['wards'], 6743);
      expect(json['verifiedWards'], 6697);
      expect(json['wardGaps'], 8);
      expect(json['unreconciledWards'], 46);
    });
  });

  group('code and coordinate coverage together', () {
    test('whereCodeAndCoordinateMapped is the joinable, plottable subset', () {
      final joined = bodies.whereCodeAndCoordinateMapped;
      expect(joined.length, greaterThan(700));
      expect(joined.every((b) => b.hasCbsCode && b.hasCoordinates), isTrue);
    });
  });
}
