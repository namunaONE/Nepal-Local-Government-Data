# Changelog

## 0.1.0

Initial release.

- `AdministrativeCascade` — a widget-free `ChangeNotifier` holding the
  province → district → local body state transitions and the bilingual label
  rules. Scoped, search, `selectAll`, `clear`, and an immutable
  `AdministrativeSelection` that distinguishes same-named bodies in different
  districts.
- `AdministrativeDropdown` — three dependent dropdowns, each disabled until
  its parent is chosen, with a helper line reporting how many options are
  available. Exposes its cascade to descendants via `cascadeOf`.
- `LocalBodySearchField` — debounced bilingual search scoped to the cascade,
  every result labelled with its district.
- `LabelStyle` (`english` / `devanagari` / `both`) with single-script fallback,
  so a label never ends in a dangling separator for the 22 local bodies that
  have no attested Devanagari name.

Requires `nepal_admin_api` 2.7.0 or later. Not yet published (`publish_to:
none`) while it resolves `nepal_admin_api` by path.