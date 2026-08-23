# Security Audit — `party_platform_link`

**Revision:** not a git repository (working tree as of audit date) · **Date:** 2026-08-23 ·
**Toolchain:** sui 1.77.2

Audit of `party_platform_link`, the generic wiring that attaches
`PlatformLink<Data>` records to a `Party` — one independent link per platform
type, written through the `platform_link` primitive. Verdict: **safe — no
findings.**

## What it does

- `set_link<Data>` (`party_platform_link.move:39`) — set or replace one
  platform's link on the party.
- `clear_link<Data>` (`:50`) — remove one platform's link; no-op if unset.
- Views `has_link`/`link` (`:64`, `:69`) — permissionless.

Threat model: an unauthorized caller writing or deleting a party's links;
one platform's write clobbering another's; a wrong cap passing when no link
exists.

## Checks performed (all hold)

- **Every write is cap-gated before any mutation or event.** Both writes go
  through `self.uid_mut(cap)` → `party::authorize`, which asserts
  `cap.party_id == object::id(party)` (`miso_party::party`,
  `party.move:519-522` / `:501-503`, pinned rev `0127a150`).
- **`clear_link` gates FIRST** (`:52-57`): the cap check runs before the
  existence check, so a wrong cap aborts `EUnauthorized` even on an empty
  slot — authorization never depends on state the caller cannot see. This is
  the explicitly correct ordering.
- **Per-platform isolation** inherited from `platform_link`: the df key is
  `PlatformLinkKey<Data>` (phantom-typed), so setting `XData` cannot touch
  `SpotifyData`'s field. Events are phantom-typed per platform
  (`LinkSetEvent<Data>`, `:27`) so indexers see which platform changed.
- **Generic `Data` is not a hole.** A caller must hold the party's
  `PartyAdminCap` to attach anything, and payload validation lives in the
  payload packages (`party_social`, `party_music`, `party_pro_link`), each
  enforcing non-empty + shared max lengths. Attaching a junk custom `Data`
  type requires the cap — self-sovereign by design.
- **No funds, no objects transferred, no loops.**

## Findings

None.

## Edge cases (verified)

- Wrong cap on set and on clear (empty slot included) — `EUnauthorized`;
  covered by the package's wrong-cap test.
- Replace existing link — in-place overwrite via `platform_link::set`.
- Clear absent link — no-op after the cap check, no event.

## Verification

Tests in `tests/party_platform_link_tests.move` (1 `expected_failure` —
wrong cap). Primitive behavior cross-read at
`lib/platform_link/sources/platform_link.move`; cap-gate semantics at the
pinned `miso_party` dependency.
