# Security Audit — `party_cta`

**Revision:** not a git repository (working tree as of audit date) · **Date:** 2026-08-23 ·
**Toolchain:** sui 1.77.2

Audit of `party_cta`, the off-Miso call-to-action list for a party — an
ordered `vector<Cta>` (`{label, url}`) stored as one dynamic field, replaced
whole on each save. Verdict: **safe — no findings.**

## What it does

- `new_cta` (`party_cta.move:75`) — validated constructor: non-empty label ≤
  60 bytes, non-empty url ≤ 2000 bytes. `Cta` fields are private and
  construction is module-private, so no unvalidated `Cta` can exist.
- `set_ctas` (`:96`) — cap-gated whole-list replace, ≤ 20 entries.
- `clear_ctas` (`:110`) — cap-gated removal; no-op if unset.
- Views (`:122-130`) — permissionless.

Threat model: unauthorized write/clear of a party's CTAs; unbounded storage;
malformed entries reaching renderers.

## Checks performed (all hold)

- **Authorization.** Both writes call `self.uid_mut(cap)` →
  `party::authorize` asserts `cap.party_id == object::id(party)` (pinned
  `miso_party`, `party.move:519-522`). The wrong-cap test covers it.
- **Bounded storage.** `MAX_CTAS = 20` × (60 + 2000) bytes max — a hard
  ceiling on the df's size (`:39-43`, `:97`).
- **Validation cannot be bypassed.** The only `Cta` constructor validates;
  the vector is validated at the boundary (`set_ctas` count check) and every
  element was built through `new_cta`.
- **Key isolation.** `CtasKey()` (`:48`) is module-private-constructible;
  no other package can touch this field.
- **Ordering note (not a finding).** In `set_ctas` the count assert (`:97`)
  runs before the cap gate (`:100`), so a wrong-cap call with an oversized
  list aborts `ETooManyCtas` rather than `EUnauthorized`. Both abort; nothing
  is revealed or mutated. (Contrast `party_platform_link::clear_link`, which
  deliberately gates first.)

## Findings

None.

## Edge cases (verified)

- Empty/oversized label or url — aborts in `new_cta`.
- 21+ CTAs — `ETooManyCtas`.
- Replace-existing vs first-write — both paths handled (`:101-105`).
- Clear when unset — no-op, no event.
- URLs are untrusted external input — a client concern (integrator note, not
  a chain issue): renderers must sanitize, since a party admin can point a
  CTA anywhere, including phishing lookalikes, on their OWN party.

## Verification

Tests in `tests/party_cta_tests.move`: 4 `expected_failure` cases including
wrong-cap (`EUnauthorized` at `miso_party::party`). Deliberately does NOT
depend on `platform_link` (per repo convention); limits match the shared
backstops (2000-byte url) by coincidence of policy, verified equal here.
