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
   dart run tool/generate.dart
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

The dataset (`data/nepal_local_levels.json`) is generated from source files via the merge pipeline:

```
tool/merge/inventory.dart     → Source inventory
tool/merge/match.dart         → Conflict detection (REVIEW.md)
tool/merge/adjudicate.dart    → Resolution (decisions_manual.json)
tool/merge/verify_codes.dart  → CBS code verification
tool/merge/apply_cbs_codes.dart → Apply codes to dataset
tool/generate.dart            → Generate lib/src/nepal_data.dart
```

**Never edit `lib/src/nepal_data.dart` or `data/nepal_local_levels.json` directly.** Run the pipeline instead.

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