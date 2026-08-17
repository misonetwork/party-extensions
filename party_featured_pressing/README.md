# party_featured_pressing

The one drop a party wants to headline — the "featured release" slot on a
profile. A party's full discography is *derived* (an indexer lists every
pressing across the party's releases), but which one to feature is a choice
the artist authors: it exists nowhere on-chain until declared, so it can't be
derived and must be stored. This extension stores it.

Unlike the other party extensions, this one takes a protocol dependency
(`miso_pressing`) on purpose: `set_featured` requires the live `Pressing`
object, so the pinned id is *proven* to be a real pressing at write time — no
garbage or dangling ids. A `Pressing` is a shared, `key`-only object that is
never destroyed, so the stored `ID` cannot dangle after the fact either. One
slot, replace-in-place; writes are gated by the `PartyAdminCap`, views are
permissionless.

## What it stores

- Key: `FeaturedKey()` — a unit dynamic-field key; one slot per party.
- Value: a bare `ID` — the featured `Pressing`'s object id. Nothing else: no
  strings, no collections, so no limits or capacities apply.
- `set_featured` replaces any existing pin in place; `clear_featured` removes
  the dynamic field entirely (a second clear is a no-op).

## API

All writes require `&PartyAdminCap` for the exact party; a wrong cap aborts
with `EUnauthorized` at `miso_party::party`.

### Writes (cap-gated)

| Function | Description | Aborts |
|---|---|---|
| `set_featured(party, cap, pressing)` | Feature `pressing`, replacing any existing pin; only its id is kept | wrong cap |
| `clear_featured(party, cap)` | Remove the featured drop; no-op when none is set | wrong cap |

### Views

| Function | Returns |
|---|---|
| `has_featured(party)` | Whether the party has a featured drop |
| `featured(party)` | `Option<ID>` — the featured drop id (a `Pressing` id), or `none` if unset |

## Events

| Event | When | Payload |
|---|---|---|
| `FeaturedSetEvent` | `set_featured` — on set and on replace | `party_id`, `drop_id` |
| `FeaturedClearedEvent` | `clear_featured`, only when a pin actually existed | `party_id` |

`drop_id` rides in the event — a small, stable pointer — so an indexer can
skip re-reading the field (dynamic-field mutations are not otherwise
observable).

## Errors

No local error constants — the module never aborts on its own. The only abort
that surfaces comes from the authorization core:

| Code | Constant | Condition |
|---|---|---|
| 0 | `EUnauthorized` (at `miso_party::party`) | Cap does not match the party — from `party::uid_mut(cap)` on either write |

## Dependencies

- `miso_party` (local) — the `Party` / `PartyAdminCap` authorization core.
- `miso_pressing` (local, `../../miso-pressing/move`) — the `Pressing` type. This
  is the one party extension that reaches into the protocol.

Local deps, not git: `miso_pressing`'s own dependencies (`miso`,
`miso_record`) are cross-repo local paths a git dep can't resolve, so this
package only builds with the sibling repos checked out side by side under
`misonetwork/`. There is no duplicate-package conflict: `miso_party` has no
dependencies of its own, so it shares no package with the pressing subtree.

## Integrator notes

- **`drop_id` is a `Pressing` object id.** "Drop" is profile-page vocabulary;
  on-chain the object is the release's `Pressing`, one per release. The field
  name is kept for indexer stability — do not key off it as a different type.
- **Read live state by id at render time.** Price, sale window, sold-out —
  all of it lives on the pressing and its listings and is never copied here.
  Treat this package as a pointer, not a cache.
- **The pointer cannot dangle.** The id is proven to be a real pressing at
  write time, and pressings are never destroyed — a featured id read from
  storage or an event always resolves.
- **`FeaturedClearedEvent` means a pin existed.** Clearing an unset slot is a
  no-op and emits nothing, so the event always signals an actual removal.
