# Security Audit — `party_roles`

**Revision:** not a git repository (working tree as of audit date) · **Date:** 2026-08-23 ·
**Toolchain:** sui 1.77.2

Audit of `party_roles`, artist-type roles for a party: a bounded
`VecSet<ArtistRole>` (closed enum + validated `Custom` escape hatch) managed
through `typed_set`. Verdict: **safe — no findings.**

## What it does

- Role constructors (`party_roles.move:82-96`) — 8 canonical variants plus
  `custom(name)` (non-empty, ≤ 60 bytes).
- `add_role` / `remove_role` / `clear_roles` (`:117`, `:126`, `:134`) —
  cap-gated set ops, capacity 12.
- Views (`:146-157`) — permissionless.

Threat model: unauthorized role mutation; unbounded or malformed custom
roles; enum/Custom confusion.

## Checks performed (all hold)

- **Authorization.** All three writes call `self.uid_mut(cap)` →
  `party::authorize` (`miso_party` pinned, `party.move:519-522`) before any
  mutation or event. Wrong-cap test present.
- **Custom names are validated at the only constructor** (`custom`, `:92-96`);
  enum variants are closed — no other construction path exists.
- **Set mechanics** — pinned `typed_set` (rev `a63230bb`): duplicate abort,
  `length() < max` capacity check, field reclaimed when the set empties
  (`typed_set.move:37-75`). Capacity 12 (`MAX_ROLES`, `:36`).
- **Key isolation.** `RolesKey()` (`:42`) module-private; single writer
  module; stored value always `VecSet<ArtistRole>`.
- **Events carry the role name** (`:64-73`) — small stable payload per repo
  convention.
- **Dedupe is exact-struct** — `Custom("DJ")` and `Dj` are distinct set
  members. Deliberate (Custom covers what canonical variants don't);
  presentation de-dup is a client concern.

## Findings

None.

## Edge cases (verified)

- Empty / 61-byte custom name — aborts.
- Duplicate role add — aborts `typed_set::EDuplicateItem` (location-pinned).
- 13th role — `EMaxItemsExceeded`.
- Remove absent — `EItemNotPresent`; last removal drops the field, so
  `has_roles` reads false.
- Clear when unset — no-op, no event.

## Verification

Tests in `tests/party_roles_tests.move`: 6 `expected_failure` cases including
wrong-cap and typed_set aborts at `location = typed_set::typed_set`.
