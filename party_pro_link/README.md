# party_pro_link

Professional and industry payloads for the `platform_link` primitive: an
artist's own website, booking/management/publisher/label pages, EPK, and
creator-support platforms (Patreon, Substack, Ko-fi). Two shapes here: a
website, booking page, or EPK has no reconstructable handle — the URL *is*
the identity — so those store a full `url`, while the creator platforms
store just a handle or subdomain with the public URL rebuilt client-side.
Every constructor validates non-empty plus the shared length backstops from
`platform_link`. The package holds no storage and no authorization of its
own — attaching a payload to a party is `party_platform_link`'s job.

## What it stores

Nothing on its own — this package defines payloads, not storage. Each `Data`
struct below rides inside a `PlatformLink<Data>` dynamic field on the party's
`UID` (key `PlatformLinkKey<Data>`), written and cleared by
`party_platform_link`: one field per `Data` type, `set` replaces in place.
Struct fields are module-private, so the validated constructors are the only
way to build a payload.

URL-based payloads — validated non-empty and at most 2000 bytes
(`platform_link::max_url_length()`):

| Payload | Field | Slice |
|---|---|---|
| `WebsiteData` | `url: String` | The artist's official website |
| `BookingPageData` | `url: String` | A booking-agent page |
| `ManagementPageData` | `url: String` | A management-company page |
| `PublisherPageData` | `url: String` | A publisher page |
| `LabelPageData` | `url: String` | A label page |
| `EpkData` | `url: String` | An electronic press kit (EPK) |

Handle-based payloads — validated non-empty and at most 256 bytes
(`platform_link::max_identifier_length()`), URL rebuilt client-side:

| Payload | Field | Platform URL |
|---|---|---|
| `PatreonData` | `handle: String` | `patreon.com/{handle}` |
| `SubstackData` | `subdomain: String` | `{subdomain}.substack.com` |
| `KofiData` | `handle: String` | `ko-fi.com/{handle}` |

## API

### Writes (cap-gated)

None — the constructors below are pure value builders. The cap-gated write
that attaches a link to a party (`party::uid_mut(cap)` through
`PartyAdminCap`) lives in `party_platform_link`.

### Constructors

| Function | Description | Aborts |
|---|---|---|
| `website(url)` | `PlatformLink<WebsiteData>` from a full URL | `EEmptyValue` (0), `EUrlTooLong` (1) |
| `booking_page(url)` | `PlatformLink<BookingPageData>` from a full URL | `EEmptyValue` (0), `EUrlTooLong` (1) |
| `management_page(url)` | `PlatformLink<ManagementPageData>` from a full URL | `EEmptyValue` (0), `EUrlTooLong` (1) |
| `publisher_page(url)` | `PlatformLink<PublisherPageData>` from a full URL | `EEmptyValue` (0), `EUrlTooLong` (1) |
| `label_page(url)` | `PlatformLink<LabelPageData>` from a full URL | `EEmptyValue` (0), `EUrlTooLong` (1) |
| `epk(url)` | `PlatformLink<EpkData>` from a full URL | `EEmptyValue` (0), `EUrlTooLong` (1) |
| `patreon(handle)` | `PlatformLink<PatreonData>` from a handle | `EEmptyValue` (0), `EHandleTooLong` (2) |
| `substack(subdomain)` | `PlatformLink<SubstackData>` from a subdomain | `EEmptyValue` (0), `EHandleTooLong` (2) |
| `kofi(handle)` | `PlatformLink<KofiData>` from a handle | `EEmptyValue` (0), `EHandleTooLong` (2) |

### Accessors

Declared with `public use fun`, so they call as methods on the payload —
`link.data().url()`, `link.data().handle()`, `link.data().subdomain()`.

| Function | Method alias | Returns |
|---|---|---|
| `website_url(&WebsiteData)` | `.url()` | The stored URL |
| `booking_url(&BookingPageData)` | `.url()` | The stored URL |
| `management_url(&ManagementPageData)` | `.url()` | The stored URL |
| `publisher_url(&PublisherPageData)` | `.url()` | The stored URL |
| `label_url(&LabelPageData)` | `.url()` | The stored URL |
| `epk_url(&EpkData)` | `.url()` | The stored URL |
| `patreon_handle(&PatreonData)` | `.handle()` | The stored handle |
| `substack_subdomain(&SubstackData)` | `.subdomain()` | The stored subdomain |
| `kofi_handle(&KofiData)` | `.handle()` | The stored handle |

## Events

None — this package defines payloads only. `party_platform_link` emits the
phantom-typed change events carrying `party_id`.

## Errors

All aborts at `party_pro_link::party_pro_link`:

| Code | Constant | Condition |
|---|---|---|
| 0 | `EEmptyValue` | Constructor called with an empty string |
| 1 | `EUrlTooLong` | URL over 2000 bytes (`platform_link::max_url_length()`) |
| 2 | `EHandleTooLong` | Handle or subdomain over 256 bytes (`platform_link::max_identifier_length()`) |

Reading or removing a link that was never stored aborts with `ENoLink` (0) at
`platform_link::platform_link`, surfaced through `party_platform_link`.

## Dependencies

- `platform_link` (local) — the link primitive these payloads ride in, plus
  the shared length backstops (`max_identifier_length()` = 256,
  `max_url_length()` = 2000) so every payload package validates against the
  same numbers.
- Notably no `miso_party`: the package knows nothing about parties or caps —
  authorization is entirely `party_platform_link`'s concern.

## Integrator notes

- Rebuild public URLs client-side for the handle payloads:
  `patreon.com/{handle}`, `{subdomain}.substack.com`, `ko-fi.com/{handle}`.
- URL payloads are stored verbatim and are untrusted input: the chain checks
  only non-empty and length, never scheme or reachability. Validate the
  scheme and sanitize before rendering or linking.
- Length limits are bytes (`String::length`), not characters — multi-byte
  UTF-8 burns the budget faster.
- Nothing here emits events; watch `party_platform_link`'s events and re-read
  the field on change.
- For the URL-based payloads the URL is the identity, so a moved page means a
  new `set` with the new URL (replacing in place) — there is nothing to
  migrate.
