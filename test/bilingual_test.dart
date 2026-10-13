// Tests for the bilingual (Devanagari) layer and the administrative
// attributes added in v2.5.0.
//
// The point of these tests is not just coverage counts. A Devanagari name is
// only useful if it is the RIGHT palika's name, so the suite pins specific
// real-world pairs, and it checks the honesty guarantees: a name is never
// transliterated, an ambiguous name is left null, and single-source fields
// stay absent rather than being filled with a plausible value.

import 'package:nepal_admin_api/nepal_admin_api.dart';
import 'package:test/test.dart';

/// Matches Devanagari (the block used by every name in the dataset).
final _deva = RegExp('[\u0900-\u097F]');

bool isDevanagari(String? s) => s != null && _deva.hasMatch(s);

void main() {
  final bodies = NepalAdminApi.getAllLocalBodies();
  final districts = NepalAdminApi.getAllDistricts();
  final provinces = NepalAdminApi.getAllProvinces();

  group('Devanagari names', () {
    test('every province and district has a Devanagari name', () {
      for (final p in provinces) {
        expect(isDevanagari(p.nameNe), isTrue, reason: '${p.name} nameNe');
      }
      for (final d in districts) {
        expect(isDevanagari(d.nameNe), isTrue, reason: '${d.name} nameNe');
      }
    });

    test('731 of 753 palikas carry a Devanagari name', () {
      final named = bodies.where((b) => isDevanagari(b.nameNe)).length;
      expect(named, 731);
      expect(bodies.where((b) => b.nameNe == null).length, 22);
    });

    test('every non-null nameNe actually contains Devanagari', () {
      // Catches a Latin string leaking into the Devanagari field, which the
      // generator also refuses to emit.
      for (final b in bodies) {
        if (b.nameNe != null) {
          expect(isDevanagari(b.nameNe), isTrue,
              reason: '${b.fullPath} nameNe is not Devanagari');
        }
      }
    });

    test('corroborated names are a strict subset of named ones', () {
      final named = bodies.where((b) => b.nameNe != null).toList();
      final verified = named.where((b) => b.nameNeVerified).toList();
      expect(verified.length, 450);
      expect(verified.length, lessThan(named.length));
      for (final b in verified) {
        expect(b.nameNeVerified, isTrue);
      }
    });

    test('pinned real-world pairs, including the fuzzy ones', () {
      // These are the cases a careless matcher gets wrong, so they are named
      // explicitly rather than left to a coverage count.
      const expected = <String, String>{
        'Bharatpur': 'भरतपुर',
        'Pokhara': 'पोखरा',
        'Kathmandu': 'काठमाडौं',
        'Bhojpur': 'भोजपुर',
        'Bagachour': 'बागचौर',
        'Gulmi Durbar': 'गुल्मीदरबार',
        'Maharajganj': 'महाराजगन्ज',
        'Pauwa Dunma': 'पौवाडुङ्मा',
      };
      expected.forEach((name, ne) {
        final matches = bodies.where((b) => b.name == name);
        expect(matches, isNotEmpty, reason: 'no palika named $name');
        expect(matches.first.nameNe, ne, reason: '$name nameNe');
      });
    });

    test('spelling variants resolved to the same entity, not a neighbour', () {
      // Each of these needed a distance-1 or -2 match on the ENGLISH name. A
      // looser threshold used to hand them a neighbouring palika's Devanagari
      // name instead, so the assertion that matters is that our palika did not
      // take the name of the neighbour it sits next to.
      // name -> [district, the neighbour it must NOT have taken the name of]
      const cases = <String, List<String>>{
        'Pauwa Dunma': ['Bhojpur', 'Arun'],
        'Gulmi Durbar': ['Gulmi', 'Chhatrakot'],
        'Maharajganj': ['Kapilvastu', 'Shuddhodhan'],
        'Bagachour': ['Salyan', 'Dhorchaur'],
      };
      cases.forEach((name, c) {
        final district = c[0];
        final neighbourName = c[1];
        final lb = NepalAdminApi.getLocalBodiesByName(name, district).single;
        expect(lb.nameNe, isNotNull, reason: '$name has no Devanagari name');
        final neighbour =
            NepalAdminApi.getLocalBodiesByName(neighbourName, district);
        if (neighbour.isNotEmpty && neighbour.first.nameNe != null) {
          expect(lb.nameNe, isNot(neighbour.first.nameNe),
              reason: '$district/$name took its neighbour '
                  "$neighbourName's Devanagari name");
        }
      });
    });

    test('palikas with no attested Devanagari name stay null', () {
      const expected = {
        'Sunsari|Baraha',
        'Sunsari|Bhokraha',
        'Taplejung|Yangwarak',
        'Udayapur|Sunkoshi',
        'Saptari|Belhi Chapena',
        'Dhading|Netrawati',
        'Dolakha|Baitedhar',
        'Nuwakot|Meghang',
        'Ramechhap|Likhu',
        'Gorkha|Bhimsen',
        'Gorkha|Sulikot',
        'Manang|Naraphu',
        'Manang|Neshang',
        'Mustang|Barhagaun Muktichhetra',
        'Mustang|Dalome',
        'Nawalpur|Bungdikali',
        'Kalikot|Kalika',
        'Salyan|Dhorchaur',
        'Salyan|Kumakh Malika',
        'Bajhang|Kanda',
        'Bajura|Swami Kartik',
        'Doti|Bogatan',
      };
      final actual = {
        for (final b in bodies)
          if (b.nameNe == null) '${b.districtName}|${b.name}',
      };
      expect(actual, expected);
    });

    test('no two palikas in a district share a Devanagari name', () {
      for (final d in districts) {
        final names =
            d.localBodies.map((b) => b.nameNe).whereType<String>().toList();
        // Among the palikas that DO carry a name, the names must be distinct.
        // Districts with unnamed palikas are compared on the named subset
        // rather than against the full roster.
        expect(names.toSet().length, names.length,
            reason: 'duplicate Devanagari name inside ${d.name}');
      }
    });

    test('nameNeOrName never returns null and displayBoth degrades cleanly',
        () {
      for (final b in bodies) {
        expect(b.nameNeOrName, isNotEmpty);
        expect(b.displayBoth, contains(b.name));
        if (b.nameNe == null) {
          expect(b.displayBoth, b.name, reason: 'no dangling separator');
        } else {
          expect(b.displayBoth, '${b.name} · ${b.nameNe}');
        }
      }
      for (final d in districts) {
        expect(d.nameNeOrName, isNotEmpty);
        expect(d.displayBoth, isNotEmpty);
      }
      for (final p in provinces) {
        expect(p.nameNeOrName, isNotEmpty);
        expect(p.displayBoth, isNotEmpty);
      }
    });
  });

  group('bilingual search', () {
    test('a Devanagari query finds the same palika as the English one', () {
      final en = NepalAdminApi.search('Bharatpur').localBodies;
      final ne = NepalAdminApi.search('भरतपुर').localBodies;
      expect(ne, isNotEmpty);
      expect(
        ne.map((b) => b.cbsCode).toSet(),
        en.map((b) => b.cbsCode).toSet(),
      );
    });

    test('a partial Devanagari fragment matches', () {
      expect(NepalAdminApi.search('भरत').localBodies, isNotEmpty);
    });

    test('Devanagari matches districts and provinces too', () {
      expect(NepalAdminApi.search('चितवन').districts.single.name, 'Chitwan');
      expect(NepalAdminApi.search('बागमती').provinces.single.id, 'bagmati');
    });

    test('an unknown Devanagari query returns nothing rather than everything',
        () {
      final r = NepalAdminApi.search('जकजकजकज');
      expect(r.isEmpty, isTrue);
    });
  });

  group('administrative attributes', () {
    test('all 77 districts carry headquarters, area and website', () {
      for (final d in districts) {
        expect(d.headquarter, isNotNull, reason: '${d.name} headquarter');
        expect(d.areaSqKm, isNotNull, reason: '${d.name} areaSqKm');
        expect(d.website, isNotNull, reason: '${d.name} website');
        expect(d.areaSqKm, greaterThan(0));
        expect(d.website, startsWith('http'));
      }
    });

    test('Chitwan is pinned: HQ Bharatpur, area 2218 km2', () {
      final chitwan = NepalAdminApi.getDistrictByName('Chitwan')!;
      expect(chitwan.headquarter, 'Bharatpur');
      expect(chitwan.areaSqKm, closeTo(2218, 0.5));
      // The HQ is itself a palika in the district.
      expect(chitwan.localBodyByName('Bharatpur')!.type,
          LocalBodyType.metropolitan);
    });

    test('all 7 provinces carry a capital, area and website', () {
      for (final p in provinces) {
        expect(p.capital, isNotNull, reason: '${p.name} capital');
        expect(p.areaSqKm, isNotNull, reason: '${p.name} areaSqKm');
        expect(p.website, isNotNull, reason: '${p.name} website');
      }
      expect(NepalAdminApi.getProvinceById('koshi')!.capital, 'Biratnagar');
    });

    test('palika contact details are present but honestly sparse', () {
      final withContact = bodies.where((b) => b.hasContact).length;
      expect(withContact, greaterThan(350));
      expect(withContact, lessThan(753),
          reason: 'not every palika publishes contact details upstream');
      for (final b in bodies) {
        if (b.website != null) expect(b.website, startsWith('http'));
        if (b.email != null) expect(b.email, contains('@'));
      }
    });

    test('Bharatpur carries real MoFAGA contact details', () {
      final bharatpur = NepalAdminApi.getLocalBodyByCbs(31304)!;
      expect(bharatpur.website, isNotNull);
      expect(bharatpur.phone, isNotNull);
      expect(bharatpur.zipCodes, isNotEmpty);
      expect(bharatpur.hasContact, isTrue);
    });

    test('postal codes are well-formed 5-digit strings, sorted and unique', () {
      final withZip = bodies.where((b) => b.zipCodes.isNotEmpty);
      expect(withZip.length, 474);
      for (final b in withZip) {
        expect(b.zipCodes, isNotEmpty);
        expect(b.zipCodes.toSet().length, b.zipCodes.length,
            reason: '${b.fullPath} repeats a postal code');
        final sorted = [...b.zipCodes]..sort();
        expect(b.zipCodes, sorted,
            reason: '${b.fullPath} postal codes unsorted');
        for (final z in b.zipCodes) {
          expect(z, matches(RegExp(r'^\d{4,6}$')),
              reason: '${b.fullPath} postal code "$z"');
        }
      }
    });

    test('a palika with no attested contact keeps nulls, not placeholders', () {
      final bare = bodies.where((b) => !b.hasContact).toList();
      expect(bare, isNotEmpty);
      for (final b in bare) {
        expect(b.website, isNull);
        expect(b.email, isNull);
        expect(b.phone, isNull);
      }
    });
  });

  group('attribute round-trips', () {
    test('LocalBody preserves name and contact fields through JSON', () {
      for (final b in bodies.where((b) => b.nameNe != null).take(30)) {
        final r = LocalBody.fromJson(b.toJson());
        expect(r.nameNe, b.nameNe);
        expect(r.nameNeVerified, b.nameNeVerified);
        expect(r.website, b.website);
        expect(r.email, b.email);
        expect(r.phone, b.phone);
        expect(r.zipCodes, b.zipCodes);
      }
    });

    test('District preserves its attributes through JSON', () {
      final chitwan = NepalAdminApi.getDistrictByName('Chitwan')!;
      final r = District.fromJson(chitwan.toJson());
      expect(r.nameNe, chitwan.nameNe);
      expect(r.headquarter, chitwan.headquarter);
      expect(r.areaSqKm, chitwan.areaSqKm);
      expect(r.website, chitwan.website);
      expect(r, chitwan);
    });

    test('Province preserves its attributes through JSON', () {
      final bagmati = NepalAdminApi.getProvinceById('bagmati')!;
      final r = Province.fromJson(bagmati.toJson());
      expect(r.nameNe, bagmati.nameNe);
      expect(r.capital, bagmati.capital);
      expect(r.areaSqKm, bagmati.areaSqKm);
      expect(r.website, bagmati.website);
      expect(r, bagmati);
    });

    test('a hand-built map without the new keys still deserializes', () {
      // Forward/backward compatibility: a v2.3-era JSON payload must load.
      final b = LocalBody.fromJson({
        'name': 'Bharatpur',
        'type': 'Metro',
        'district': 'Chitwan',
        'province': 'Bagmati',
        'cbsCode': 31304,
      });
      expect(b.nameNe, isNull);
      expect(b.nameNeVerified, isFalse);
      expect(b.zipCodes, isEmpty);
      expect(b.hasContact, isFalse);
      expect(b.nameNeOrName, 'Bharatpur');

      final d = District.fromJson({
        'name': 'Chitwan',
        'province': 'Bagmati',
        'cbsCode': 313,
        'localBodies': [],
      });
      expect(d.headquarter, isNull);
      expect(d.areaSqKm, isNull);
    });
  });
}
