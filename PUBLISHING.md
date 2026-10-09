# Publishing nepal_admin_api to pub.dev — step by step

## Step 0 — Prerequisites

- Dart SDK 3.x installed (`dart --version`).
- A **Google account** — pub.dev login is Google-based.
- This repo pushed to `github.com/namunaONE/Nepal-Local-Government-Data` (the pubspec `repository` points here).

## Step 1 — Local quality gate (run all, fix everything)

```bash
dart pub get
dart format .
dart analyze --fatal-infos
dart test
dart pub publish --dry-run
```

The **dry-run is non-negotiable**: published versions are permanent — you
cannot edit or delete one (retraction only hides a version from search and
resolvers; it does not remove the files). Treat the dry-run as your last
chance to fix anything.

## Step 2 — Understand what gets uploaded

`dart publish` packs **everything in the package directory that is not git-ignored**.
Check the dry-run's file list: no secrets, no `.dart_tool`, no scratch files.
For a pure-Dart package with no dependencies, users get a tiny download and
the data offline — that's the selling point.

## Step 3 — First publish

```bash
dart pub publish
```

What happens:

1. pub validates the package again.
2. A browser window opens asking you to **sign in with Google**.
3. **First-time uploaders:** pub.dev emails a verification link to your Google
   account's address — click it, then re-run the command.
4. The terminal shows the exact files and total size, then asks for
   confirmation → type `y`.

Done: the package is live at <https://pub.dev/packages/nepal_admin_api>.

## Step 4 — Verify the listing

- **Page renders** and README shows correctly (badges fill in within minutes).
- **Score**: aim for **130/130 pub points** — typical deductions are missing
  CHANGELOG, analyzer warnings, stale dependency constraints
  (see <https://pub.dev/packages/nepal_admin_api/score>).
- **dartdoc**: check the API reference tab renders the doc comments.

## Step 5 — Post-publish

1. Tag the release and push:

   ```bash
   git tag -a v1.0.0 -m "nepal_admin_api 1.0.0"
   git push origin v1.0.0
   ```

2. Create a **GitHub Release** for `v1.0.0` with the CHANGELOG entry as the body.
3. Announce (X/LinkedIn/Nepali dev communities) with the pub.dev link.
4. Optional next: apply for a **verified publisher** so the package shows under
   your domain instead of personal uploaders (pub.dev → publishers).

## Step 6 — Releasing updates later

1. **Update `CHANGELOG.md` first**, then bump `version` in `pubspec.yaml` (SemVer):
   - patch `1.0.1` — data typo fixes, doc changes
   - minor `1.1.0` — new APIs (e.g. official LGLDC codes, Nepali names)
   - major `2.0.0` — breaking changes
2. `dart test` → `dart pub publish --dry-run` → `dart pub publish`.
3. Tag `vX.Y.Z` on GitHub.

## Golden rules

- **Never `--force` past a validation warning.**
- **Never publish from a dirty working tree** — commit first so the release maps to a tag.
- **Data changes are still code changes**: if the 2027 restructuring changes the
  official count, that's a **minor** version bump plus a CHANGELOG note and an
  updated "data as of" date in the README — update the golden tests in the same
  commit (they *will* fail otherwise, by design).
