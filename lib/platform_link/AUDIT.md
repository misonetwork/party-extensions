# Security Audit — `platform_link` (lib primitive)

**Revision:** not a git repository (working tree as of audit date) · **Date:** 2026-08-23 ·
**Toolchain:** sui 1.77.2

Audit of `platform_link`, the protocol-agnostic primitive that stores exactly
one `PlatformLink<Data>` per `Data` type as a dynamic field on any object's
UID. Verdict: **safe — no findings.**

## What it does

A generic typed wrapper (`PlatformLink<Data>`, `platform_link.move:53`) plus
UID storage keyed by `PlatformLinkKey<phantom Data>` (`:59`):
`set` (replace-in-place), `get`/`borrow`, `remove`, `clear`, and the shared
length backstops (`max_identifier_length = 256`, `max_url_length = 2000`,
`:43-47`) every payload package reuses. It holds no state of its own, gates
nothing (authorization is the caller's — e.g. `party::uid_mut(cap)`), and
touches no funds.

Threat model: key-type confusion between platforms or between packages;
storage bloat; a caller reading a field that isn't what its type claims.

## Checks performed (all hold)

- **Key isolation is type-level.** `PlatformLinkKey<Data>()` carries the
  payload type as a phantom parameter, so `PlatformLinkKey<XData>` and
  `PlatformLinkKey<SpotifyData>` are distinct df keys on the same UID
  (`:57-59`). The key's constructor is module-private (struct literals are
  only buildable in this module), so NO other package can name, read over,
  or delete this namespace.
- **Key/value type consistency.** Only this module writes under
  `PlatformLinkKey<Data>`, always with a `PlatformLink<Data>` value
  (`set`, `:85-91`). The replace path's typed `df::borrow_mut` would abort on
  any type mismatch, and none is reachable.
- **`remove`/`borrow` abort on absence** (`ENoLink`, `:103-112`);
  `clear` is a deliberate no-op when absent (`:115-118`).
- **No abilities to abuse.** `PlatformLink` is `copy + drop + store` — a
  plain data value, not a capability; copying it confers nothing.

## Findings

None.

## Edge cases (verified)

- Set-over-set — replace in place, key count stays 1 per Data type.
- Clear-when-absent — no-op, no abort.
- Platform addition — new `Data` type, zero changes here (the design goal).
- Shared limits are functions (no `public const` on this toolchain), so
  dependents cannot drift from these numbers.

## Verification

Unit tests in `tests/platform_link_tests.move`. All ten consuming packages in
`party-extensions` re-read for this audit: each passes a cap-gated
`&mut UID` and only after authorization.
