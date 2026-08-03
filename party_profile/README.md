# party_profile

A party's editable profile card — the free-form identity fields a profile page
renders: a short bio, an optional long bio, an optional country, and language
tags. The whole card is stored as one `Profile` dynamic field on the party's
UID and written in a single call (`set_profile`) — there are no per-field
setters. Only cohesive identity fields live here: typed or collection-shaped
concerns (roles, tags, genres, media, links) each have their own extension,
the party's `name` stays on the core `Party` (`party::set_name`), and the join
date comes from the party's creation event (the indexer has it for free).
`country` and `languages` use validated code primitives (`country_code`,
`language_code`), so a stored value is always a real code.

## What it stores

- Key: `ProfileKey()` (unit struct — one profile per party).
- Value: `Profile { bio_short: String, bio_long: Option<String>,
  country: Option<CountryCode>, languages: vector<LanguageCode> }`.
- Limits: `bio_short` 1–300 bytes (the only required field); `bio_long`
  1–5000 bytes when present; up to 10 language tags, no duplicates.
- `set_profile` replaces in place — the card is overwritten, never stacked.
  `clear_profile` removes the dynamic field entirely (storage reclaimed) and
  is a no-op when no profile is set.

## API

All writes require `&PartyAdminCap` for the exact party; a wrong cap aborts
with `EUnauthorized` at `miso_party::party`.

### Writes (cap-gated)

| Function | Description | Aborts |
|---|---|---|
| `set_profile(party, cap, bio_short, bio_long, country, languages)` | Create or replace the whole profile card in one call | wrong cap; `EEmptyBioShort` (0), `EBioShortTooLong` (1), `EEmptyBioLong` (2), `EBioLongTooLong` (3), `ETooManyLanguages` (4), `EDuplicateLanguage` (6) |
| `clear_profile(party, cap)` | Remove the profile; no-op when none is set (no event then) | wrong cap |

### Views

| Function | Returns |
|---|---|
| `has_profile(party)` | `bool` — whether the party has a profile |
| `profile(party)` | `&Profile` — borrows the card; aborts `ENoProfile` (5) when none is set |
| `bio_short(&Profile)` | `String` |
| `bio_long(&Profile)` | `Option<String>` |
| `country(&Profile)` | `Option<CountryCode>` |
| `languages(&Profile)` | `vector<LanguageCode>` |

## Events

| Event | When | Payload |
|---|---|---|
| `ProfileSetEvent` | Profile created or replaced via `set_profile` | `party_id` |
| `ProfileClearedEvent` | Profile removed via `clear_profile` — not emitted when the call is a no-op | `party_id` |

## Errors

| Code | Constant | Condition |
|---|---|---|
| 0 | `EEmptyBioShort` | `bio_short` is empty |
| 1 | `EBioShortTooLong` | `bio_short` exceeds 300 bytes |
| 2 | `EEmptyBioLong` | `bio_long` is `some("")` — empty when provided |
| 3 | `EBioLongTooLong` | `bio_long` exceeds 5000 bytes |
| 4 | `ETooManyLanguages` | More than 10 language tags |
| 5 | `ENoProfile` | `profile()` with no profile set |
| 6 | `EDuplicateLanguage` | A language tag appears more than once |

Both writes also surface `EUnauthorized` (0) at `miso_party::party` on a
wrong cap.

## Dependencies

- `miso_party` (local sibling checkout, `../../miso-party`) — the `Party` /
  `PartyAdminCap` authorization core.
- `country_code` (git, pinned by SHA) — validated `CountryCode` primitive.
- `language_code` (git, pinned by SHA) — validated `LanguageCode` primitive;
  every value is a real ISO 639-1 code by construction, so only count and
  duplicates are checked here.

## Integrator notes

- **Whole-card replace.** Editing one field means re-sending the entire card:
  read the current profile, modify client-side, call `set_profile`. There is
  no partial update.
- **Lengths are bytes, not characters.** `bio_short` (300) and `bio_long`
  (5000) bound the UTF-8 byte length, so multibyte text reaches the limit
  sooner. Validate before sending to avoid aborts.
- **Free text is untrusted input.** `bio_short` / `bio_long` are
  user-controlled strings — sanitize before rendering.
- **The display name is not here.** Read it from the core `Party` object; the
  join date comes from the party's creation event. Do not expect either in
  `Profile`.
- Events are change signals carrying only `party_id` — re-read the profile on
  `ProfileSetEvent`; drop it on `ProfileClearedEvent`.
