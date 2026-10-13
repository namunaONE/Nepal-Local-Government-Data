# nepal_admin_widgets

Flutter dropdowns for Nepal's administrative divisions — **7 provinces,
77 districts, 753 local bodies** — bilingual (English + Devanagari), entirely
offline, and backed by the verified [`nepal_admin_api`][api] dataset.

No network calls, no asset loading, no location permissions: the data is
compiled into the app.

## Install

```yaml
dependencies:
  nepal_admin_api: ^2.7.0
  nepal_admin_widgets: ^0.1.0
```

## Use

```dart
import 'package:nepal_admin_widgets/nepal_admin_widgets.dart';

final cascade = AdministrativeCascade();

AdministrativeDropdown(
  cascade: cascade,
  onChanged: (selection) {
    if (selection.isComplete) save(selection.localBody!);
  },
);
```

Or let the widget own its cascade:

```dart
AdministrativeDropdown()  // created internally
```

Read it back from a descendant with `AdministrativeDropdown.cascadeOf(context)`.

## The cascade

`AdministrativeCascade` is a plain `ChangeNotifier` with no widget dependency.
It holds the state transitions and the label rules — the parts worth testing —
so you can drive any UI you like.

```dart
final cascade = AdministrativeCascade()
  ..selectProvince(province)
  ..selectDistrict(district);

cascade.availableLocalBodies;      // scoped to that district
cascade.search('tokha');           // exact → prefix → substring → alphabetical
cascade.selection.isComplete;      // a body, not just a province
```

### Why the cascade rules are what they are

**Local-body names are not unique across Nepal.** `Sunkoshi` names four
different rural municipalities; there are only 719 distinct names across 753
local bodies. So the district is part of any answer, and two rules follow:

* Choosing a province clears the district and body beneath it.
* Choosing a district clears the body beneath it.

A stale child can never outlive the parent that made it meaningful.
`selectLocalBody` is authoritative — it reconciles the levels above it — so a
search hit from any district selects a coherent chain and a body can never be
selected under a district it does not belong to.

For the same reason `availableLocalBodies` is **empty until a province or
district is chosen**: listing all 753 would drop the district out of the answer.

## Labels

```dart
AdministrativeCascade.formatLocalBody(body);                    // "Tokha · टोखा"
AdministrativeCascade.formatLocalBody(body, style: LabelStyle.english);
AdministrativeCascade.formatLocalBodyDisambiguated(body);       // "…, Kathmandu"
```

`LabelStyle.both` falls back to whichever single script is attested, so a label
never ends in a dangling separator — 22 of the 753 palikas have no attested
Devanagari name. `formatLocalBodyDisambiguated` is unique across all 753.

## Verification

```
flutter analyze     # clean
flutter test        # 58 tests
```

The suite runs against the real dataset, not fixtures. It asserts that the
cascade cannot produce a body outside its roster, that clearing a selection
never leaves a stale child, that every label style is non-empty for all 753
records, that the disambiguated label is unique for all 753, and that no search
result contradicts the chosen district.

CI runs `flutter analyze --fatal-infos` and `flutter test` on every push in the
`flutter-widgets` job; the widget code is not covered by the Dart package's own
analysis.

## Example

```
cd packages/nepal_admin_widgets/example
flutter run
```

## Status

`publish_to: none` — this is a monorepo package that depends on the local
`nepal_admin_api` checkout via a path dependency. Change that to a version
constraint before publishing.

## License

MIT, matching [`nepal_admin_api`][api].

[api]: https://pub.dev/packages/nepal_admin_api