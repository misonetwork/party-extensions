# Security Audit — `party_tags`

**Revision:** not a git repository (working tree as of audit date) · **Date:** 2026-08-23 ·
**Toolchain:** sui 1.77.2

Audit of `party_tags`, free-form tags for a party: a bounded
`VecSet<String>` managed through `typed_set`. Verdict: **safe — no
findings.**

## What it does

- `add_tag` (`party_tags.move:65`) — cap-gated; tag validated non-empty and
  ≤ 50 bytes HERE, then set mechanics (duplicate/capacity) in `typed_set`;
  capacity 30.
- `remove_tag` / `clear_tags` (`:76`, `:83`) — cap-gated.
- Views (`:95-106`) — permissionless.

Threat model: unauthorized tag mutation; unbounded growth; oversized tags.

## Checks performed (all hold)

- **Authorization.** All three writes call `self.uid_mut(cap)` →
  `party::authorize` (`miso_party` pinned, `party.move:519-522`) before any
  mutation or event. Wrong-cap test present. (In `add_tag` tag validation
  runs before the cap gate — both paths abort; cosmetic ordering only.)
- **Bounded.** 30 tags × ≤ 50 bytes — hard ceiling.
- **Set mechanics** — pinned `typed_set` (rev `a63230bb`): duplicate abort,
  capacity check, field reclaimed when the last tag leaves
  (`typed_set.move:37-75`).
- **Key isolation.** `TagsKey()` (`:40`) module-private; single writer
  module; stored value always `VecSet<String>`.
- **Exact-match dedupe, no normalization** (`:12-14`): "Ambient" and
  "ambient" are distinct tags by design; normalization for search/display is
  a client concern. Not a security gap — tags are self-sovereign
  presentation data on one's own party.

## Findings

None.

## Edge cases (verified)

- Empty / 51-byte tag — aborts (`EEmptyTag` / `ETagTooLong`).
- Duplicate add — aborts `typed_set::EDuplicateItem` (location-pinned).
- 31st tag — `EMaxItemsExceeded`.
- Remove absent — `EItemNotPresent`; last removal drops the field, so
  `has_tags` reads false (`:73-75`).
- Clear when unset — no-op, no event.
- Multi-byte UTF-8 — the 50-byte bound is on BYTES (`String::length`), so a
  tag of multi-byte characters is correctly bounded by storage size.

## Verification

Tests in `tests/party_tags_tests.move`: 6 `expected_failure` cases including
wrong-cap and typed_set aborts at `location = typed_set::typed_set`.
