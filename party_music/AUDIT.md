# Security Audit — `party_music`

**Revision:** not a git repository (working tree as of audit date) · **Date:** 2026-08-23 ·
**Toolchain:** sui 1.77.2

Audit of `party_music`, the music-platform payload package for
`platform_link`: eight `…Data` types (Spotify, Bandcamp, SoundCloud, Apple
Music, Deezer, Tidal, Amazon Music, Audiomack) plus validated constructors.
Verdict: **safe — no findings.**

## What it does

Pure payload definitions + constructors (`party_music.move:56-109`). Each
constructor asserts non-empty and `<= platform_link::max_identifier_length()`
(256 bytes) and wraps the payload via `platform_link::new`. This package
**touches no object, holds no state, gates nothing** — authorization happens
at the call site (`party_platform_link::set_link`, which is
`PartyAdminCap`-gated).

Threat model: malformed payloads reaching storage; storage bloat.

## Checks performed (all hold)

- **Uniform validation.** All 8 constructors enforce identical bounds
  (`EEmptyId` / `EIdTooLong`, `:29-32`); the limit comes from the shared
  `platform_link` function, so it cannot drift between payload packages.
- **Struct construction is module-private.** Each `…Data` has private
  fields; the only way to build one is these constructors — no unvalidated
  payload exists.
- **Type-level platform isolation.** Distinct `Data` types → distinct
  `PlatformLinkKey<Data>` df keys downstream; setting one platform's link
  can never collide with another's.
- **No abilities beyond `copy + drop + store`** — plain data values.
- **No URL storage.** Only native ids; URLs are rebuilt client-side
  (`:9-12`), so no stored-URL phishing surface from this package.
  Handles remain untrusted input for renderers (integrator concern).

## Findings

None.

## Edge cases (verified)

- Empty identifier — aborts in every constructor.
- 257-byte identifier — aborts.
- URL reshaping by a platform — no on-chain change needed (by design).

## Verification

Tests in `tests/party_music_tests.move` (3 `expected_failure` — validation
aborts). Consumed only via `party_platform_link`'s cap-gated write path.
