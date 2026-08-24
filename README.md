# Miso Party Extensions

Artist/entity profile pages on Sui, built as small, independent Move packages.
Each **extension** attaches one coherent slice of a profile to a core
[`miso_party::party::Party`](../miso-party) object as a dynamic field — bio,
roles, tags, links, imagery, and CTAs. Extensions ship,
upgrade, and evolve independently: Move cannot add
fields to a published struct without a migration, so many small extensions
beat one mega-struct.

Design principles, the field-placement rules (declare vs. derive vs. reference
vs. off-chain), and the phasing live in [ROADMAP.md](ROADMAP.md). The process
for documenting an extension — required reading before adding one — lives in
[AGENTS.md](AGENTS.md).

## Architecture

- **One slice per package.** Each extension owns its dynamic-field key(s) and
  value types on the party's `UID`. Keys are distinct types per package, so
  extensions never collide on the same party.
- **Cap-gated writes, permissionless reads.** Every write goes through
  `party::uid_mut(cap)`, which aborts unless the `PartyAdminCap` belongs to
  that exact party. Views read `party::uid()` freely.
- **Shared primitives do the mechanics.** `lib/platform_link` stores one typed
  link per platform on any `UID`; `lib/typed_set` stores one bounded
  `VecSet<T>` per key type on any `UID`. Extensions keep only their domain
  types, validation, and events — never re-implement storage.
- **Reference, don't embed.** Media is a Walrus blob id; links store the
  platform's native handle/id (the client rebuilds the URL). Nothing large or
  derivable is copied on-chain.

## Packages

### Primitives (object-agnostic, no Miso dependencies)

| Package | Owns |
|---|---|
| [`lib/platform_link`](lib/platform_link) | `PlatformLink<Data>` — one typed external-platform link per `UID`; shared length backstops |
| [`lib/typed_set`](lib/typed_set) | One bounded `VecSet<T>` per key type per `UID` — init-on-add, dup/max checks, field reclamation |

### Extensions (attach to a `Party`, gated by `PartyAdminCap`)

| Package | Owns |
|---|---|
| [`party_platform_link`](party_platform_link) | Party wiring for `PlatformLink<Data>` — `set_link` / `clear_link` / views + phantom-typed events |
| [`party_social`](party_social) | Social handle payloads: X, Instagram, Threads, TikTok, YouTube, Discord, Telegram, Reddit, Twitch, Facebook |
| [`party_music`](party_music) | Music-platform artist payloads: Spotify, Bandcamp, SoundCloud, Apple Music, Deezer, Tidal, Amazon, Audiomack |
| [`party_pro_link`](party_pro_link) | Pro/industry payloads: website, booking/management/publisher/label pages, EPK; Patreon, Substack, Ko-fi |
| [`party_profile`](party_profile) | Profile card: `bio_short`, `bio_long`, `country`, `languages` (validated code types) |
| [`party_genre`](party_genre) | Genre-id set, proven at write time against the `genre` vocabulary |
| [`party_roles`](party_roles) | Artist-type set: Artist/Producer/DJ/Composer/Songwriter/Band/Label/Collective + `Custom` |
| [`party_tags`](party_tags) | Free-form tag set (moods, scenes, descriptors) |
| [`party_media`](party_media) | Imagery: one Walrus quilt blob id (avatar/header are quilt patches, a client convention) |
| [`party_cta`](party_cta) | Ordered external call-to-action links (`{ label, url }`, position is priority) |

Operational Party workflows are not profile extensions. Vault-authorized inbox
and accumulator withdrawals live in
[`misofm/vault-plugins/party_wallet`](https://github.com/misofm/vault-plugins/tree/main/party_wallet).

## Conventions

- **Events are change signals.** Dynamic-field mutations are not observable
  off-chain, so every write emits an event carrying `party_id`. Payloads are
  not re-included — an indexer re-reads the field — except small, stable ones
  (ids and short display strings: `party_media`'s quilt id and role/tag
  strings), which ride in.
- **Validation is split on purpose.** Primitives enforce set mechanics
  (duplicate / not-present / over-max — aborts come from `typed_set` or
  `platform_link` with their codes). Extensions enforce domain rules
  (non-empty, length, vocabulary proofs) before calling in. Format rules for
  handles and URLs are deliberately *not* on-chain — they change over time and
  belong to the app layer.
- **Stored URLs and handles are untrusted input.** Frontends must sanitize
  before rendering (e.g. reject `javascript:` URLs) and rebuild platform URLs
  from handles rather than trusting stored strings.
- **Dependencies are pinned.** Git dependencies use commit SHAs, never `main`;
  local path deps expect the sibling repos checked out side by side under
  `misonetwork/`.
- **Tests always include the wrong cap.** Every extension has an
  `expected_failure` test proving another party's `PartyAdminCap` aborts
  (`EUnauthorized` at `miso_party::party`).

## Build & test

Each package is independent. From a package directory:

```bash
sui move build
sui move test
```
