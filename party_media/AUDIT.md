# Security Audit — `party_media`

**Revision:** not a git repository (working tree as of audit date) · **Date:** 2026-08-23 ·
**Toolchain:** sui 1.77.2

Audit of `party_media`, a party's profile imagery pointer: a single `Media`
dynamic field holding one Walrus quilt blob id. Verdict: **safe — no
findings.**

## What it does

- `set_media` (`party_media.move:61`) — cap-gated set/replace of the quilt
  id; rejects zero (`EZeroQuilt`).
- `clear_media` (`:74`) — cap-gated removal; no-op if unset.
- Views (`:86-93`) — permissionless.

Threat model: unauthorized replacement of a party's imagery pointer; a zero
id masquerading as a real quilt.

## Checks performed (all hold)

- **Authorization.** Both writes call `self.uid_mut(cap)` →
  `party::authorize` (`miso_party` pinned, `party.move:519-522`) before any
  mutation or event. Wrong-cap test present.
- **Zero-id rejection** (`:62`): zero is never a real Walrus blob id and
  would be indistinguishable from "unset" downstream — aborted.
- **Key isolation.** `MediaKey()` (`:25`) is module-private-constructible;
  only this module writes `Media` under it.
- **No validation gap.** The value is a single `u256`; there is nothing else
  to validate on chain (whether the quilt exists or whose it is cannot be
  proven here — a party admin pointing at someone else's quilt is
  self-sovereign presentation, not a protocol risk).
- **Event carries the quilt id** (`MediaSetEvent`, `:48-51`) — small stable
  payload, per repo convention, so indexers skip re-reading.

## Findings

None.

## Edge cases (verified)

- Set-over-set — in-place `quilt` field update (`:66`).
- Clear when unset — no-op, no event.
- Zero quilt id — aborts.
- Quilt patch roles (avatar/header) — client convention, never stored
  (`:12-15`); nothing to spoof on chain.

## Verification

Tests in `tests/party_media_tests.move`: 2 `expected_failure` cases
(wrong-cap, zero id).
