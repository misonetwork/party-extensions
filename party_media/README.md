# party_media

Profile imagery for a party, stored as a single Walrus quilt. All of a
party's images (avatar, header/cover, …) live together in one quilt —
batching them under a single storage reservation is markedly cheaper than
one blob each, which matters when the platform sponsors storage. Only the
quilt's blob id is held on-chain, as a dynamic field on the party's `UID`,
gated by the `PartyAdminCap`; views are permissionless. The chain is
deliberately role-agnostic: which patch is the avatar vs the header is a
client convention, derived off-chain — never stored here.

## What it stores

- Key: `MediaKey()` — one dynamic field per party.
- Value: `Media { quilt: u256 }` — the Walrus quilt blob id holding all of
  the party's images. Individual images are quilt patches addressed by
  identifier ("avatar", "header", …); those roles are not stored.
- `set_media` replaces the id in place; `clear_media` removes the field
  entirely and is a no-op when none is set.

## API

All writes require `&PartyAdminCap` for the exact party; a wrong cap aborts
with `EUnauthorized` (0) at `miso_party::party`.

### Writes (cap-gated)

| Function | Description | Aborts |
|---|---|---|
| `set_media(party, cap, quilt)` | Set or replace the party's media quilt; emits `MediaSetEvent` | `EZeroQuilt` (0) on a zero quilt id |
| `clear_media(party, cap)` | Remove the party's media; emits `MediaClearedEvent` — no-op (and silent) when unset | — |

### Views

| Function | Returns |
|---|---|
| `has_media(party)` | Whether the party has media set |
| `quilt(party)` | `Option<u256>` — the quilt blob id, if set |

## Events

| Event | When | Payload |
|---|---|---|
| `MediaSetEvent` | Quilt set or replaced | `party_id`, `quilt` — the new id rides in the event (a small, stable pointer) so an indexer can skip re-reading the field |
| `MediaClearedEvent` | Media removed | `party_id` |

## Errors

| Code | Constant | Condition |
|---|---|---|
| 0 | `EZeroQuilt` | `set_media` called with a zero quilt id — zero is never a real Walrus blob id and is indistinguishable from "unset" downstream |

## Dependencies

- [`miso_party`](https://github.com/misonetwork/party) at exact revision
  `ffb2915b9bb1802b4c160d3230c560e40bd2b063` — the `Party` /
  `PartyAdminCap` authorization core.
- Otherwise only the Sui framework (`sui::dynamic_field`, `sui::event`). The
  manifest has no local-path or floating dependencies.

## Integrator notes

- **Patch roles are a client convention.** Individual images are quilt
  patches addressed by identifier ("avatar", "header", …); those
  identifiers are agreed off-chain and never stored here. The chain stays
  role-agnostic on purpose.
- **Updating any image is a full re-store.** Re-store the quilt on Walrus,
  then call `set_media` with the new blob id — there is no patch-level
  write on-chain.
- **One quilt, not one blob per image.** A single storage reservation is
  markedly cheaper than one blob each, which matters when the platform
  sponsors storage.
- Indexers can take the new quilt id straight from `MediaSetEvent` instead
  of re-reading the field (dynamic-field mutations are not otherwise
  observable); `MediaClearedEvent` means the field is gone. A no-op
  `clear_media` emits nothing.
