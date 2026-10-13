# Contributing to nepal_admin_api

Thank you for your interest in contributing! This document outlines the guidelines for contributing to this project.

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How to Contribute

### Reporting Bugs

Before submitting a bug report:
1. Check the [issue tracker](https://github.com/namunaONE/Nepal-Local-Government-Data/issues) for existing reports
2. Ensure you're using the latest version
3. Provide a minimal reproduction case

When filing a bug, include:
- Package version (`dart pub deps | grep nepal_admin_api`)
- Dart/Flutter version (`dart --version` or `flutter --version`)
- Platform (OS, architecture)
- Steps to reproduce
- Expected vs actual behavior
- Code snippet if applicable

### Suggesting Enhancements

Open an issue with:
- Clear title describing the feature
- Use case / motivation
- Proposed API (if applicable)
- Any breaking change considerations

### Pull Requests

1. **Fork** the repository
2. **Create a branch** from `main`: `git checkout -b feat/your-feature-name`
3. **Make changes** following the guidelines below
4. **Run CI locally** before pushing:
   ```bash
   dart format --set-exit-if-changed .
   dart analyze --fatal-infos
   dart test
   node docs/smoke.cjs
   dart run tool/pipeline.dart   # must produce no diff
   ```
5. **Submit PR** with a clear description

## Development Setup

```bash
git clone https://github.com/namunaONE/Nepal-Local-Government-Data.git
cd Nepal-Local-Government-Data
dart pub get
dart test
dart run tool/generate.dart
```

## Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `dart format` (enforced by CI)
- Use `dart analyze --fatal-infos` (enforced by CI)
- No `// ignore` comments without justification

## Commit Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, no code change
- `refactor`: Code restructuring
- `perf`: Performance improvement
- `test`: Adding tests
- `chore`: Maintenance, deps, tooling
- `ci`: CI configuration

Examples:
```
feat(api): add CBS code lookup by ISO code
fix(explorer): handle null cbsCode in pagination
docs(readme): add quickstart example
ci(workflow): add Dependabot config
```

Scope should be: `api`, `explorer`, `website`, `data`, `tool`, `ci`, `docs`, `deps`

## Data Changes

The dataset (`data/nepal_local_levels.json`) is the **single source of truth**
for every artifact in this repo. Both the Dart package
(`lib/src/nepal_data.dart`) and the website explorer (`docs/data.json`) are
generated from it.

Regenerate everything with one command:

```bash
dart run tool/pipeline.dart            # full regeneration
dart run tool/pipeline.dart --dry-run  # report without writing
```

It runs these steps in order, aborting on the first failure:

```
tool/merge/verify_codes.dart         CBS codes, doubly-attested tier
tool/merge/apply_cbs_codes.dart     write them into the dataset
tool/merge/resolve_code_tiers.dart  single-source tier + bijection gate
tool/generate.dart                  lib/src/nepal_data.dart (validates)
tool/generate_explorer_data.dart    docs/data.json
```

Additional merge tools you may need after re-fetching sources:
`tool/merge/inventory.dart` (source audit), `tool/merge/match.dart` and
`tool/merge/adjudicate.dart` (name conflicts), `tool/merge/verify_wards.dart`
(ward counts), `tool/geocode_centroids.dart` (coordinates).

**Never edit `lib/src/nepal_data.dart` or `docs/data.json` by hand** — they are
generated, and CI fails if they drift from the dataset. When you change the
dataset, commit it **together with both generated files**.

### Data invariants CI enforces

`tool/generate.dart` refuses to emit a dataset that violates any of these, so
a bad merge cannot reach a release:

- official national counts (7 / 77 / 753, split 6 / 11 / 276 / 460, 6,743 wards)
- **bijection** — no two palikas share a CBS code
- **district containment** — a code's PDD prefix matches its district's code
- a `cbsCodeConfidence` tier that contradicts the `cbsCodeVerified` flag
- coordinates inside Nepal's bounding box; ward counts in a sane range
- no province claiming fewer wards than its own rows substantiate

`data/PROVENANCE.sha256` must pin every file in `data/_raw/`; an unpinned or
changed input fails the merge tools before they do anything.

## Testing

- All tests must pass: `dart test`
- New features require tests
- Test file: `test/nepal_admin_api_test.dart`
- Golden tests verify official counts (7/77/753, 6/11/276/460, 6743 wards)

## Versioning

Follows [Semantic Versioning](https://semver.org/):
- MAJOR: Breaking API changes
- MINOR: Backward-compatible features
- PATCH: Bug fixes

## License

By contributing, you agree that your contributions will be licensed under the MIT License (code) and CC-BY-4.0 (data, with attribution per NOTICE).

## Questions?

Open a [discussion](https://github.com/namunaONE/Nepal-Local-Government-Data/discussions) or [issue](https://github.com/namunaONE/Nepal-Local-Government-Data/issues).