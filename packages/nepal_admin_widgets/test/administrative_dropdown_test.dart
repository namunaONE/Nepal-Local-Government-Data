// Widget tests. The cascade logic is covered in administrative_cascade_test;
// these prove the widget layer gates, enables and rebuilds correctly — the class
// of bug that compiles, analyzes clean, and still ships a picker offering a
// district from the wrong province.
//
// Note on counting: dropdown menus are viewport-clipped, so `findsNWidgets` on
// menu items measures the screen, not the data. Assertions here read the
// cascade for counts and check the menu only for *correctness* of what is
// visible.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_admin_api/nepal_admin_api.dart';
import 'package:nepal_admin_widgets/nepal_admin_widgets.dart';

Widget host(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );

/// Whether a dropdown is interactive. A null `onChanged` is how
/// DropdownButtonFormField expresses "disabled".
///
/// Generic on purpose: `ValueChanged<LocalBody?>` is not a subtype of
/// `ValueChanged<Object?>`, so reading `onChanged` through a widened type
/// throws for the local-body field.
bool enabled<T>(WidgetTester tester) =>
    tester
        .widget<DropdownButtonFormField<T>>(
            find.byType(DropdownButtonFormField<T>))
        .onChanged !=
    null;

/// Every `Text` currently painted, for substring assertions.
List<String> visibleTexts(WidgetTester tester) => find
    .byType(Text)
    .evaluate()
    .map((e) => (e.widget as Text).data)
    .whereType<String>()
    .toList();

/// Names of the items in an open menu, as painted.
List<String> menuNames<T>(WidgetTester tester) => find
    .byType(DropdownMenuItem<T>)
    .evaluate()
    .map((e) => ((e.widget as DropdownMenuItem).child as Text).data ?? '')
    .toList();

void main() {
  Province province(String n) =>
      NepalAdminApi.getAllProvinces().firstWhere((p) => p.name == n);
  District district(String n) => NepalAdminApi.getDistrictByName(n)!;

  /// Dropdown menus are anchored overlays clipped to the viewport. On the
  /// default 800x600 test surface the local-body menu opens below the fold and
  /// its items cannot be tapped, so give these tests a tall surface.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> open(WidgetTester tester, Type t) async {
    await tester.tap(find.byType(t));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, Type t, String label) async {
    await open(tester, t);
    await tester.tap(find.textContaining(label).last, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  group('AdministrativeDropdown', () {
    setUp(() {});

    testWidgets('renders all three levels and the search field',
        (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(host(const AdministrativeDropdown()));

      expect(find.byType(DropdownButtonFormField<Province>), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<District>), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<LocalBody>), findsOneWidget);
      expect(find.byType(LocalBodySearchField), findsOneWidget);
      expect(find.text('Search local bodies'), findsOneWidget);
    });

    testWidgets('omits the search field on request', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(
        host(const AdministrativeDropdown(showSearch: false)),
      );
      expect(find.byType(LocalBodySearchField), findsNothing);
    });

    testWidgets('offers all 7 provinces', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(host(const AdministrativeDropdown()));
      await open(tester, DropdownButtonFormField<Province>);

      final names = menuNames<Province>(tester);
      expect(names, hasLength(7));
      for (final p in NepalAdminApi.getAllProvinces()) {
        expect(names.any((n) => n.contains(p.name)), isTrue,
            reason: 'missing ${p.name}');
      }
    });

    testWidgets('gates both child fields until their parents are chosen',
        (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(host(const AdministrativeDropdown()));

      expect(enabled<District>(tester), isFalse);
      expect(enabled<LocalBody>(tester), isFalse);
      expect(find.text('Choose a province first'), findsOneWidget);
      expect(find.text('Choose a district first'), findsOneWidget);
    });

    testWidgets('enables the district field once a province is chosen',
        (tester) async {
      useTallViewport(tester);
      final c = AdministrativeCascade();
      await tester.pumpWidget(host(AdministrativeDropdown(cascade: c)));
      await choose(tester, DropdownButtonFormField<Province>, 'Koshi');

      expect(enabled<District>(tester), isTrue);
      expect(c.availableDistricts, hasLength(14));
      expect(find.text('14 available'), findsOneWidget);

      await open(tester, DropdownButtonFormField<District>);
      final names = menuNames<District>(tester);
      expect(names, hasLength(14), reason: 'every Koshi district must fit');
      // Every painted entry must belong to the chosen province. Checked in
      // this direction: a substring test the other way round would false-fire
      // whenever some other district happens to share a name.
      final allowed = c.availableDistricts.map((d) => d.name).toSet();
      for (final n in names) {
        expect(allowed.any((a) => n.startsWith(a)), isTrue,
            reason: 'leaked "$n"');
      }
    });

    testWidgets('lists a district\'s local bodies and enables the third field',
        (tester) async {
      useTallViewport(tester);
      final c = AdministrativeCascade();
      await tester.pumpWidget(host(AdministrativeDropdown(cascade: c)));
      await choose(tester, DropdownButtonFormField<Province>, 'Bagmati');
      await choose(tester, DropdownButtonFormField<District>, 'Kathmandu');

      expect(enabled<LocalBody>(tester), isTrue);
      expect(c.availableLocalBodies, hasLength(11));
      expect(find.text('11 in Kathmandu'), findsOneWidget);

      await open(tester, DropdownButtonFormField<LocalBody>);
      final names = menuNames<LocalBody>(tester);
      expect(names, hasLength(11));
      // Every painted entry must belong to the chosen district — nothing from
      // the 742 other local bodies may leak in.
      final allowed = c.availableLocalBodies.map((b) => b.name).toSet();
      for (final n in names) {
        expect(allowed.any((a) => n.startsWith(a)), isTrue,
            reason: 'leaked "$n"');
      }
    });

    testWidgets('clears the body when the district changes', (tester) async {
      useTallViewport(tester);
      final c = AdministrativeCascade();
      await tester.pumpWidget(host(AdministrativeDropdown(cascade: c)));

      await choose(tester, DropdownButtonFormField<Province>, 'Bagmati');
      await choose(tester, DropdownButtonFormField<District>, 'Kathmandu');
      await choose(tester, DropdownButtonFormField<LocalBody>, 'Tokha');
      expect(c.localBody!.name, 'Tokha');

      await choose(tester, DropdownButtonFormField<District>, 'Lalitpur');

      expect(c.district!.name, 'Lalitpur');
      expect(c.localBody, isNull,
          reason: 'a body from Kathmandu must not survive under Lalitpur');
      expect(c.availableLocalBodies.map((b) => b.districtName).toSet(),
          {'Lalitpur'});
    });

    testWidgets('reports a completed selection only when one exists',
        (tester) async {
      useTallViewport(tester);
      final seen = <bool>[];
      await tester.pumpWidget(host(
        AdministrativeDropdown(onChanged: (s) => seen.add(s.isComplete)),
      ));

      await choose(tester, DropdownButtonFormField<Province>, 'Koshi');
      expect(seen.last, isFalse, reason: 'a province is not an answer');

      await choose(tester, DropdownButtonFormField<District>, 'Jhapa');
      expect(seen.last, isFalse, reason: 'a district is not an answer');

      await choose(tester, DropdownButtonFormField<LocalBody>, 'Bhadrapur');
      expect(seen.last, isTrue);
    });

    testWidgets('honours labelStyle', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(
        host(const AdministrativeDropdown(labelStyle: LabelStyle.english)),
      );
      await choose(tester, DropdownButtonFormField<Province>, 'Koshi');
      await open(tester, DropdownButtonFormField<Province>);

      for (final n in menuNames<Province>(tester)) {
        expect(n, isNot(contains('·')), reason: n);
      }
    });

    testWidgets('bilingual labels carry both scripts by default',
        (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(host(const AdministrativeDropdown()));
      await choose(tester, DropdownButtonFormField<Province>, 'Koshi');
      await open(tester, DropdownButtonFormField<Province>);

      final koshi = province('Koshi');
      expect(koshi.nameNe, isNotNull);
      final names = menuNames<Province>(tester);
      expect(
        names.where((n) =>
            n.contains('Koshi') &&
            n.contains('·') &&
            n.contains(koshi.nameNe!)),
        isNotEmpty,
      );
    });

    testWidgets('renders an untranslated unit without a dangling separator',
        (tester) async {
      useTallViewport(tester);
      // Udayapur's Sunkoshi has no attested Devanagari name; a dropdown full
      // of "Sunkoshi · " is the failure this guards.
      final s = NepalAdminApi.getLocalBodiesByDistrict('Udayapur')
          .firstWhere((b) => b.name == 'Sunkoshi');
      expect(s.nameNe, isNull);

      await tester.pumpWidget(host(const AdministrativeDropdown()));
      await choose(tester, DropdownButtonFormField<Province>, 'Koshi');
      await choose(tester, DropdownButtonFormField<District>, 'Udayapur');
      await open(tester, DropdownButtonFormField<LocalBody>);

      final entry = menuNames<LocalBody>(tester)
          .firstWhere((n) => n.contains('Sunkoshi'));
      expect(entry, 'Sunkoshi');
    });

    testWidgets('an internally-created cascade survives rebuilds',
        (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(host(const AdministrativeDropdown()));
      await choose(tester, DropdownButtonFormField<Province>, 'Koshi');
      final first = AdministrativeDropdown.cascadeOf(
        tester.element(find.byType(LocalBodySearchField)),
      );

      await tester.pumpWidget(host(const AdministrativeDropdown()));
      final second = AdministrativeDropdown.cascadeOf(
        tester.element(find.byType(LocalBodySearchField)),
      );

      expect(identical(first, second), isTrue);
    });
  });

  group('cascadeOf', () {
    testWidgets('returns the cascade driving an enclosing dropdown',
        (tester) async {
      useTallViewport(tester);
      final c = AdministrativeCascade();
      await tester.pumpWidget(host(AdministrativeDropdown(cascade: c)));

      // The search field lives inside the dropdown's scope.
      final seen = AdministrativeDropdown.cascadeOf(
        tester.element(find.byType(LocalBodySearchField)),
      );
      expect(identical(seen, c), isTrue);
    });

    testWidgets('throws a descriptive error when there is no dropdown',
        (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(host(const SizedBox.shrink()));

      expect(
        () => AdministrativeDropdown.cascadeOf(
            tester.element(find.byType(SizedBox))),
        throwsA(isA<FlutterError>().having(
          (e) => e.toString(),
          'message',
          contains('No AdministrativeDropdown found'),
        )),
      );
    });
  });

  group('LocalBodySearchField', () {
    testWidgets('finds a body by English name and selects it', (tester) async {
      useTallViewport(tester);
      final c = AdministrativeCascade()..selectDistrict(district('Kathmandu'));
      await tester.pumpWidget(host(
        LocalBodySearchField(cascade: c, onSelected: c.selectLocalBody),
      ));

      await tester.enterText(find.byType(TextField), 'tokha');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsWidgets);
      expect(visibleTexts(tester), contains(contains('Tokha')));

      await tester.tap(find.textContaining('Tokha').first);
      await tester.pumpAndSettle();

      expect(c.localBody!.name, 'Tokha');
      expect(c.localBody!.districtName, 'Kathmandu');
    });

    testWidgets('matches a Devanagari query', (tester) async {
      useTallViewport(tester);
      final c = AdministrativeCascade()..selectDistrict(district('Kathmandu'));
      await tester.pumpWidget(host(LocalBodySearchField(cascade: c)));

      final ne = district('Kathmandu').nameNe!;
      await tester.enterText(find.byType(TextField), ne);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(c.search(ne), isNotEmpty);
    });

    testWidgets('labels every result with its district, because names collide',
        (tester) async {
      useTallViewport(tester);
      // Two Koshi districts each have a local body called Sunkoshi.
      final c = AdministrativeCascade()..selectProvince(province('Koshi'));
      await tester.pumpWidget(host(LocalBodySearchField(cascade: c)));

      await tester.enterText(find.byType(TextField), 'sunkoshi');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      final texts = visibleTexts(tester);
      expect(texts, contains(contains('Okhaldhunga')));
      expect(texts, contains(contains('Udayapur')));
    });

    testWidgets('disambiguates a name shared with another district',
        (tester) async {
      useTallViewport(tester);
      // Two Bagmati districts each have a local body called Sunkoshi, so the
      // bare name cannot stand in for a result.
      final sunkoshi =
          NepalAdminApi.getAllLocalBodies().where((b) => b.name == 'Sunkoshi');
      expect(sunkoshi, hasLength(4));
      expect(sunkoshi.where((b) => b.provinceName == 'Bagmati'), hasLength(2));

      final c = AdministrativeCascade()..selectProvince(province('Bagmati'));
      await tester.pumpWidget(host(LocalBodySearchField(cascade: c)));

      await tester.enterText(find.byType(TextField), 'sunkoshi');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      final texts = visibleTexts(tester);
      expect(texts, contains(contains('Sindhuli')));
      expect(texts, contains(contains('Sindhupalchok')));
      expect(c.localBody, isNull, reason: 'search must not auto-select');
    });

    testWidgets('returns nothing for a nonsense query', (tester) async {
      useTallViewport(tester);
      final c = AdministrativeCascade()..selectDistrict(district('Kathmandu'));
      await tester.pumpWidget(host(LocalBodySearchField(cascade: c)));

      await tester.enterText(find.byType(TextField), 'qqqqzzzz');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('re-scopes when the cascade narrows underneath it',
        (tester) async {
      useTallViewport(tester);
      final c = AdministrativeCascade()..selectProvince(province('Bagmati'));
      await tester.pumpWidget(host(LocalBodySearchField(cascade: c)));

      await tester.enterText(find.byType(TextField), 'b');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      final wide = c.search('b').length;
      expect(wide, greaterThan(20));
      expect(find.byType(ListTile), findsWidgets);

      c.selectDistrict(district('Kathmandu'));
      await tester.pumpAndSettle();

      // Re-scoped, not stale: what is painted now belongs to the narrowed
      // district, and a result the cascade could not select is gone.
      expect(find.textContaining('Kathmandu'), findsWidgets);
      expect(find.textContaining('Lalitpur'), findsNothing);
      expect(c.search('b').length, lessThan(wide));
      expect(
        c.search('b').every((b) => b.districtName == 'Kathmandu'),
        isTrue,
      );
    });

    testWidgets('clearing the field hides the results', (tester) async {
      useTallViewport(tester);
      final c = AdministrativeCascade()..selectDistrict(district('Kathmandu'));
      await tester.pumpWidget(host(LocalBodySearchField(cascade: c)));

      await tester.enterText(find.byType(TextField), 'tokha');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsWidgets);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNothing);
      expect(c.localBody, isNull);
    });

    testWidgets('stays silent when no district is chosen yet', (tester) async {
      useTallViewport(tester);
      final c = AdministrativeCascade();
      await tester.pumpWidget(host(LocalBodySearchField(cascade: c)));

      await tester.enterText(find.byType(TextField), 'tokha');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // No province or district means no scoped pool, so no results — rather
      // than an unscoped list of all 753 that ignores the district.
      expect(find.byType(ListTile), findsNothing);
    });
  });
}
