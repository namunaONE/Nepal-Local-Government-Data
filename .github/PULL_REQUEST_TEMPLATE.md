---
name: Pull Request
description: Submit a pull request for review
title: "<type>(<scope>): <subject>"
labels: []
---

## Summary

<!-- Brief description of what this PR does -->

## Type of Change

- [ ] `feat` — New feature
- [ ] `fix` — Bug fix
- [ ] `docs` — Documentation only
- [ ] `style` — Formatting, no code change
- [ ] `refactor` — Code restructuring
- [ ] `perf` — Performance improvement
- [ ] `test` — Adding tests
- [ ] `chore` — Maintenance, deps, tooling
- [ ] `ci` — CI configuration

## Scope

- [ ] `api` — Public API (`lib/`)
- [ ] `explorer` — Data explorer website (`docs/`)
- [ ] `website` — Landing/API pages (`docs/`)
- [ ] `data` — Dataset or pipeline (`data/`, `tool/merge/`)
- [ ] `tool` — Build/tooling scripts (`tool/`)
- [ ] `ci` — CI/CD (`.github/workflows/`)
- [ ] `docs` — Documentation (README, CHANGELOG, etc.)
- [ ] `deps` — Dependencies

## Description

<!--
Explain the changes in detail.
- What problem does this solve?
- How does it solve it?
- Any breaking changes?
-->

## Testing

- [ ] All existing tests pass (`dart test`)
- [ ] New tests added (if applicable)
- [ ] Manual testing performed (describe):

## Checklist

- [ ] Code follows project style (`dart format --set-exit-if-changed .`)
- [ ] No analyze issues (`dart analyze --fatal-infos`)
- [ ] Tests pass (`dart test`)
- [ ] Generated files updated (`dart run tool/generate.dart`)
- [ ] Documentation updated (if API changed)
- [ ] CHANGELOG.md updated (for user-facing changes)
- [ ] Commit messages follow Conventional Commits

## Breaking Changes

<!-- If this introduces breaking changes, describe them and the migration path -->

## Screenshots

<!-- For UI changes (explorer, website), add before/after screenshots -->

## Additional Context

<!-- Any other information, links to issues, etc. -->