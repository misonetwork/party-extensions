# Security Audit — `party_profile`

**Revision:** not a git repository (working tree as of audit date) · **Date:** 2026-08-23 ·
**Toolchain:** sui 1.77.2

Audit of `party_profile`, a party's editable profile card (short/long bio,
country, languages) stored as one `Profile` dynamic field. Verdict: **safe —
no findings.**

## What it does

- `set_profile` (`party_profile.move:89`) — cap-gated whole-card replace;
  validates bio_short (non-empty, ≤ 300), optional bio_long (non-empty when
  present, ≤ 8192), languages (≤ 10, no duplicates).
- `clear_profile` (`:113`) — cap-gated removal; no-op if unset.
- Views (`:125-138`) — permissionless; `profile()` aborts `ENoProfile` when
  unset.

Threat model: unauthorized profile writes; unbounded storage; invalid
country/language codes; duplicate language padding.

## Checks performed (all hold)

- **Authorization.** Both writes call `self.uid_mut(cap)` →
  `party::authorize` (`miso_party` pinned, `party.move:519-522`). In
  `set_profile` validation runs before the cap gate (`:97-99` vs `:103`) —
  a wrong-cap call with invalid input aborts with a validation error instead
  of `EUnauthorized`; both abort, nothing is revealed or mutated (cosmetic
  ordering note only).
- **Bounded storage.** Hard ceiling: 300 + 8192 + 2-byte country + 10
  language codes — no unbounded vector reachable.
- **Codes are valid by construction.** `CountryCode` and `LanguageCode` are
  constructor-gated primitives from pinned dependencies
  (`country_code` rev `23fad25f`, `language_code` rev `c5973df8`); e.g.
  `country_code::new` asserts membership in the 249-code ISO 3166-1 alpha-2
  set embedded in bytecode. This package cannot be handed an invalid code.
- **Duplicate languages rejected** (`validate_languages`, `:157-163`) via a
  `vec_set` seen-check — no padding the 10-slot budget with repeats.
- **Key isolation.** `ProfileKey()` (`:59`) is module-private-constructible;
  `Profile` has no `copy`, and only this module writes the field.
- **No name duplication** — the party's name stays on the core `Party`
  (`:12-14`), so no two-sources-of-truth drift.

## Findings

None.

## Edge cases (verified)

- Empty bio_short / empty-when-present bio_long — aborts
  (`EEmptyBioShort` / `EEmptyBioLong`).
- Oversized bios — aborts (`EBioShortTooLong` / `EBioLongTooLong`).
- 11 languages / duplicate language — aborts (`ETooManyLanguages` /
  `EDuplicateLanguage`).
- `none` country / empty languages vector / `none` bio_long — all valid
  (validation is conditional on `is_some`, `:147-153`).
- Clear when unset — no-op, no event; `profile()` view aborts `ENoProfile`.
- Wrong cap — `EUnauthorized` (tested).

## Verification

Tests in `tests/party_profile_tests.move`: 5 `expected_failure` cases
including wrong-cap. Dependency primitives read at their pinned build copies
under `build/party_profile/sources/dependencies/`.
