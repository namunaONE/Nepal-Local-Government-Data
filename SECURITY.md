# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 2.0.x   | ✅ Yes             |
| 1.0.x   | ❌ No (EOL)        |

Only the latest major version receives security updates.

## Reporting a Vulnerability

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, email **realpoudel@duck.com** with:

1. **Description** of the vulnerability
2. **Steps to reproduce** (if applicable)
3. **Impact** assessment (what could an attacker do?)
4. **Affected versions** (if known)
5. **Suggested fix** (if you have one)

We will:
- Acknowledge receipt within 48 hours
- Provide a preliminary assessment within 5 business days
- Keep you informed of progress
- Credit you in the advisory (if desired)

## Disclosure Timeline

- **Day 0**: Vulnerability reported
- **Day 1-2**: Acknowledgment and triage
- **Day 5**: Preliminary assessment shared
- **Day 30**: Target for fix release (may vary by severity)
- **Day 30+**: Public advisory published after fix is available

## Scope

This policy covers:
- The `nepal_admin_api` Dart package (code in `lib/`)
- The data pipeline tools (code in `tool/`)
- The generated dataset (`data/nepal_local_levels.json`)

Out of scope:
- Third-party dependencies (report to their maintainers)
- GitHub Pages website (static HTML/CSS/JS, no server-side code)
- Data sources (CBS, MoFAGA, etc. — report to respective authorities)

## Security Features

- **Zero dependencies** at runtime — no supply chain risk from transitive deps
- **Pure Dart** — no native code, FFI, or plugins
- **Offline-only** — no network calls, telemetry, or analytics
- **Immutable data** — embedded at compile time, cannot be modified at runtime
- **Dev dependencies only**: `crypto` (build-time SHA-256), `lints`, `test`

## Known Considerations

- The package embeds a ~124 KB JSON dataset — audit if size is a concern for your threat model
- Dev dependencies are not included in published package
- Data sources are CC-BY-4.0 attributed in NOTICE

## Contact

Security contact: **realpoudel@duck.com**

For non-security issues, use [GitHub Issues](https://github.com/namunaONE/Nepal-Local-Government-Data/issues).