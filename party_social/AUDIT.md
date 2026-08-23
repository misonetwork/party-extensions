# Security Audit — `party_social`

**Revision:** not a git repository (working tree as of audit date) · **Date:** 2026-08-23 ·
**Toolchain:** sui 1.77.2

Audit of `party_social`, the social-platform payload package for
`platform_link`: ten `…Data` types (X, Instagram, Threads, TikTok, YouTube,
Discord, Telegram, Reddit, Twitch, Facebook) plus validated constructors.
Verdict: **safe — no findings.**

## What it does

Pure payload definitions + constructors (`party_social.move:63-130`). Each
asserts non-empty handle, `<= platform_link::max_identifier_length()` (256),
and wraps via `platform_link::new`. No state, no object access, no
authorization logic (that lives in `party_platform_link`'s cap-gated writes).

Threat model: malformed payloads reaching storage; storage bloat.

## Checks performed (all hold)

- **Uniform validation** across all 10 constructors (`EEmptyHandle` /
  `EHandleTooLong`, `:33-35`) against the shared 256-byte backstop — cannot
  drift from the other payload packages.
- **Module-private construction** — handles can only enter a `…Data` through
  these constructors.
- **Type-level platform isolation** — one `PlatformLinkKey<…Data>` field per
  network downstream; no collisions.
- **Handle-format rules deliberately absent** (`:11-13`): format validation
  belongs to the app layer and changes over time; the chain enforces only
  storage hygiene. Handles are untrusted input for renderers.

## Findings

None.

## Edge cases (verified)

- Empty / 257-byte handle — aborts in every constructor.
- Leading-`@` convention (X/Threads/TikTok store without it) — documented
  per-type (`:39-46`); client concern, not chain state.
- Discord stores an invite CODE, not a username (`:49-50`) — documented;
  the constructor bounds it identically.

## Verification

Tests in `tests/party_social_tests.move` (3 `expected_failure` — validation
aborts).
