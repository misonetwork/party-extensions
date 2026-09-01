# party_cta

Off-Miso call-to-action links for a party — the "what do you want people to
do" row: Tickets, Merch, Newsletter, an external Listen. A CTA is deliberately
just a `{ label, url }`: on-Miso actions (collect / listen-on-Miso / pin) are
a different, interactive concern and live in `party_featured`, which
references object ids and can render live state — so this package stays a
plain, dependency-light external link hub.

The CTAs are an ordered list: **position is priority**. The whole list is
written at once (`set_ctas`) — the natural fit for a drag-to-reorder editor
that saves on submit — so there are no per-entry ids to track. Writes are
gated by the `PartyAdminCap` through `party::uid_mut(cap)`; views are
permissionless.

## What it stores

- Key: `CtasKey()` — a unit struct, so exactly one CTA-list field per party.
- Value: `vector<Cta>`, where `Cta { label: String, url: String }`. Order is
  preserved on-chain; position is priority.
- `set_ctas` replaces the whole list in place; `clear_ctas` removes the field
  entirely.

Limits, enforced in `new_cta` and `set_ctas`:

| Constant | Value | Applies to |
|---|---|---|
| `MAX_LABEL_LENGTH` | 60 bytes | a CTA's label |
| `MAX_URL_LENGTH` | 2000 bytes | a CTA's url |
| `MAX_CTAS` | 20 | the list as a whole |

## API

All writes require `&PartyAdminCap` for the exact party; a wrong cap aborts
with `EUnauthorized` at `miso_party::party`.

### Constructor / accessors

| Function | Description | Aborts |
|---|---|---|
| `new_cta(label, url)` | Build a validated `Cta`; callers assemble the ordered `vector<Cta>` client-side and submit it with `set_ctas` | `EEmptyLabel` (0), `ELabelTooLong` (1), `EEmptyUrl` (2), `EUrlTooLong` (3) |
| `label(&cta)` | The CTA's display label | — |
| `url(&cta)` | The CTA's destination url | — |

### Writes (cap-gated)

| Function | Description | Aborts |
|---|---|---|
| `set_ctas(party, cap, ctas)` | Set or replace the party's ordered CTA list | `ETooManyCtas` (4) when the list exceeds 20 |
| `clear_ctas(party, cap)` | Remove the party's CTA list | — (no-op when none is set) |

### Views

| Function | Returns |
|---|---|
| `has_ctas(party)` | Whether a CTA list is stored |
| `ctas(party)` | The party's ordered CTA list (empty when unset) |

## Events

| Event | When | Payload |
|---|---|---|
| `CtasSetEvent` | `set_ctas` writes the list (set or replace) | `party_id`, `count` (list length) |
| `CtasClearedEvent` | `clear_ctas` removes an existing list — not emitted on a no-op clear | `party_id` |

## Errors

| Code | Constant | Condition |
|---|---|---|
| 0 | `EEmptyLabel` | CTA label is empty |
| 1 | `ELabelTooLong` | CTA label exceeds 60 bytes |
| 2 | `EEmptyUrl` | CTA url is empty |
| 3 | `EUrlTooLong` | CTA url exceeds 2000 bytes |
| 4 | `ETooManyCtas` | List exceeds 20 CTAs |

A wrong `PartyAdminCap` aborts with `EUnauthorized` (0) at
`miso_party::party`, before any mutation or event.

## Dependencies

- [`miso_party`](https://github.com/misonetwork/party) at exact revision
  `ffb2915b9bb1802b4c160d3230c560e40bd2b063` — the `Party` /
  `PartyAdminCap` authorization core.
- Nothing else beyond the Sui framework (`sui::dynamic_field`, `sui::event`,
  `std::string`) — no primitive or protocol dependencies, by design. The
  manifest has no local-path or floating dependencies.

## Integrator notes

- **Full URLs, stored verbatim.** Unlike `platform_link` payloads (handles
  rebuilt into platform URLs client-side), a CTA's destination is arbitrary,
  so the URL itself is stored. There is no scheme or host validation on-chain:
  treat labels and URLs as untrusted input — sanitize before rendering, and
  decide which schemes (e.g. `https:`) you are willing to link to.
- **Order is the payload.** Render in stored order; do not re-sort. There are
  no per-entry ids, so entry identity does not survive a rewrite — diff by
  position, not by id.
- **Re-read on event.** Events carry `party_id` (plus `count` on set), not the
  list — an indexer re-reads `ctas`.
- **Empty vs. absent.** `set_ctas` with an empty vector stores an empty list
  (`CtasSetEvent` with `count = 0`); `clear_ctas` removes the field. `ctas()`
  returns an empty vector in both cases — treat both as "no CTAs", and use
  `has_ctas` only if the distinction matters to you.
