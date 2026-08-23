# Security Audit — `party_genre`

**Revision:** not a git repository (working tree as of audit date) · **Date:** 2026-08-23 ·
**Toolchain:** sui 1.77.2

Audit of `party_genre`, genre tags for a party: a `VecSet<ID>` of canonical
`genre::Genre` object ids, managed through the `typed_set` primitive.
Verdict: **safe — no findings.**

## What it does

- `add_genre` (`party_genre.move:60`) — cap-gated; takes `&Genre` so the
  added id is a real vocabulary entry; capacity 20.
- `remove_genre` / `clear_genres` (`:69`, `:76`) — cap-gated; removal
  reclaims the field when the set empties.
- Views (`:88-99`) — permissionless.

Threat model: unauthorized set mutation; fake genre ids; unbounded growth.

## Checks performed (all hold)

- **Authorization.** All three writes call `self.uid_mut(cap)` →
  `party::authorize` (`miso_party` pinned rev `0127a150`,
  `party.move:519-522`) BEFORE the set is touched or an event emitted.
- **Vocabulary proof.** `add_genre` requires a `&Genre` object reference
  (`:60-63`) — the id stored is `object::id(genre)`, so a party can only tag
  ids of actual `Genre` objects from the pinned `genre` package (rev
  `b94b11e3`). (A `&Genre` proves existence, not ownership — correct here:
  tagging a genre needs no consent from anyone.)
- **Set mechanics are sound.** Read the pinned `typed_set` (rev `a63230bb`):
  duplicate abort, `length() < max` capacity check, `vec_set::insert`,
  field dropped when the last item leaves (`typed_set.move:37-75`). The
  redundant duplicate assert pins the abort LOCATION to `typed_set` — what
  the consumers' tests match on.
- **Key isolation.** `GenresKey()` (`:34`) is module-private-constructible;
  the stored value is always `VecSet<ID>` (single writer module).
- **Bounded.** 20 ids × 32 bytes — trivial ceiling.

## Findings

None.

## Edge cases (verified)

- Duplicate add — aborts `typed_set::EDuplicateItem`.
- Remove absent / clear absent — aborts `EItemNotPresent` / no-op
  respectively.
- 21st genre — `EMaxItemsExceeded`.
- Wrong cap — `EUnauthorized` at `miso_party::party` (tested).

## Verification

Tests in `tests/party_genre_tests.move`: 5 `expected_failure` cases including
wrong-cap and typed_set aborts at `location = typed_set::typed_set`. The
`genre` and `typed_set` dependencies were read at their pinned build copies.
