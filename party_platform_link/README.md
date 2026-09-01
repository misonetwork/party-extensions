# party_platform_link

The `Party` wiring for `PlatformLink<Data>`: it attaches one independent
external-platform link per platform type — `set_link<XData>`,
`set_link<SpotifyData>`, … — each in its own dynamic field on the party, keyed
by `Data`. One module serves every platform (social, music, pro) because it is
generic over the payload; the payload types live in their own small packages
(`party_social`, `party_music`, `party_pro_link`), so adding a platform is a
new type there, never a change here — and adding one never rewrites another's.

Storage mechanics come entirely from `platform_link`; this module adds only
the two things that are party-specific. Writes are gated by the `PartyAdminCap`
through `party::uid_mut(cap)`; views are permissionless. And every write emits
a phantom-typed event, because dynamic-field mutations are not otherwise
observable: the event's phantom `Data` type tells an indexer *which* platform
changed, and the indexer re-reads the field — events carry no payload by
convention, only `party_id`.

## What it stores

One dynamic field per platform `Data` type on the party's `UID`, held via
`platform_link`:

- Key: `PlatformLinkKey<Data>` (owned by `platform_link`; its `phantom Data`
  makes each platform's key a distinct type, so fields never collide).
- Value: `PlatformLink<Data> { data }`, where `Data: copy + drop + store` is
  the platform's native identifier(s) — a handle, id, or subdomain — defined
  and validated by a payload package.
- Exactly one link per `Data` type per party: `set_link` replaces in place,
  `clear_link` reclaims the field.

No limits are declared here. Payload constructors validate non-empty plus the
shared backstops (`platform_link::max_identifier_length()` 256 bytes,
`max_url_length()` 2000 bytes) before a link can exist.

## API

All writes require `&PartyAdminCap` for the exact party; a wrong cap aborts
with `EUnauthorized` at `miso_party::party`.

### Writes (cap-gated)

| Function | Description | Aborts |
|---|---|---|
| `set_link<Data>(party, cap, PlatformLink<Data>)` | Store the link, replacing any existing one for that platform; emits `LinkSetEvent<Data>` | wrong cap |
| `clear_link<Data>(party, cap)` | Remove the platform's link; emits `LinkClearedEvent<Data>` only when one was stored, no-op otherwise | wrong cap — the cap is verified before the existence check, so a wrong cap aborts even when nothing is stored |

### Views

| Function | Returns |
|---|---|
| `has_link<Data>(party)` | `bool` — whether a link for this platform is set |
| `link<Data>(party)` | `Option<PlatformLink<Data>>` — the stored link, if any |

## Events

| Event | When | Payload |
|---|---|---|
| `LinkSetEvent<phantom Data>` | `set_link` — a link is set or replaced | `party_id` only |
| `LinkClearedEvent<phantom Data>` | `clear_link` removed a stored link (never on the absent no-op) | `party_id` only |

The phantom `Data` type parameter is the signal: it names the platform that
changed. By convention no stored data rides in the event — the indexer
re-reads the field. (Small, stable pointers are the documented exception
elsewhere: `party_media`'s quilt id or a role or tag string.)

## Errors

| Code | Constant | Condition |
|---|---|---|
| 0 | `EUnauthorized` (at `miso_party::party`) | The cap does not belong to this party — both writes gate through `party::uid_mut(cap)` before any mutation or event |

No error constants are declared in this module, and none surface from
`platform_link`: `set_link` / `clear_link` call only its non-aborting
functions (`set`, `clear`, `exists_`, `get`), so `ENoLink` is unreachable
here. Payload-constructor aborts (empty or oversized identifiers) fire in the
payload packages, before `set_link` is ever called.

## Dependencies

- [`miso_party`](https://github.com/misonetwork/party) at
  `ffb2915b9bb1802b4c160d3230c560e40bd2b063` — `Party` authorization.
- [`platform_link`](https://github.com/misonetwork/party-extensions/tree/684eaef752271865f1cbb1aafb819e5bba3c1d6c/lib/platform_link)
  at `684eaef752271865f1cbb1aafb819e5bba3c1d6c` — all storage mechanics.
- [`party_social`](https://github.com/misonetwork/party-extensions/tree/6bd663033267b7c2fddb7ed8b9ce85f980121e2f/party_social)
  at `6bd663033267b7c2fddb7ed8b9ce85f980121e2f`, test-only via
  `modes = ["test"]` — concrete payloads for generic tests; absent from the
  production dependency graph.

All are exact Git pins; this manifest has no local-path dependencies.

## Integrator notes

- **Subscribe per platform.** Filter events by the phantom `Data` type to know
  which platform changed, then re-read with `link<Data>` — the event is a
  change signal, not a payload. `LinkClearedEvent` is emitted only when a link
  was actually removed.
- **URLs are rebuilt, never stored.** The payload carries a handle, id, or
  subdomain; the client constructs the public URL (e.g. `x.com/{handle}`), so
  a platform reshaping its URLs needs no on-chain change.
- **Stored strings are untrusted input.** Sanitize handles before rendering —
  on-chain validation is non-empty plus length backstops, not format or
  safety.
- **One link per platform, by construction.** There is no list to paginate and
  no duplicates to merge; re-setting a platform replaces in place.
- **New platforms don't touch this package.** Define a `…Data` type with a
  validating constructor in the appropriate payload package, and
  `set_link<NewData>` works immediately.
