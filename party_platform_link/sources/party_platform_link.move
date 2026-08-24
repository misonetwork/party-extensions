// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Attaches `PlatformLink<Data>` records to a `Party` — one independent link per
/// platform type (`set_link<XData>`, `set_link<SpotifyData>`, …), each in its own
/// dynamic field keyed by `Data`. Adding one platform never rewrites another's,
/// and a new platform needs no change here.
///
/// This one module serves every platform (social, music, anything) because it is
/// generic over `Data`; the payload types live in their own small packages
/// (`party_social`, `party_music`, …). All writes are gated by the
/// `PartyAdminCap` via `uid_mut`; views are permissionless. Events are
/// phantom-typed per platform so an indexer can see which platform changed —
/// dynamic-field mutations are not otherwise observable. These events carry no
/// payload by convention: they are change signals, and the indexer re-reads the
/// field. (Small, stable payloads are the exception elsewhere — `party_media`'s
/// quilt id or a role or tag string.)
module party_platform_link::party_platform_link;

use miso_party::party::{Party, PartyAdminCap};
use platform_link::platform_link::{Self, PlatformLink};
use sui::event::emit;

// === Events ===

/// Emitted when a platform's link is set or replaced on a party.
public struct LinkSetEvent<phantom Data> has copy, drop {
    party_id: ID,
}

/// Emitted when a platform's link is cleared from a party.
public struct LinkClearedEvent<phantom Data> has copy, drop {
    party_id: ID,
}

// === Write API ===

/// Sets (or replaces) a platform's link on the party.
public fun set_link<Data: copy + drop + store>(
    self: &mut Party,
    cap: &PartyAdminCap,
    link: PlatformLink<Data>,
) {
    let party_id = object::id(self);
    platform_link::set(self.uid_mut(cap), link);
    emit(LinkSetEvent<Data> { party_id });
}

/// Clears a platform's link from the party. No-op if unset.
public fun clear_link<Data: copy + drop + store>(self: &mut Party, cap: &PartyAdminCap) {
    let party_id = object::id(self);
    // Cap-gate first: a wrong cap must abort even when no link is present, so
    // authorization never depends on state the caller can't be sure of.
    let uid = self.uid_mut(cap);
    if (platform_link::exists_<Data>(uid)) {
        platform_link::clear<Data>(uid);
        emit(LinkClearedEvent<Data> { party_id });
    }
}

// === Views ===

/// Whether the party has a link for this platform.
public fun has_link<Data: copy + drop + store>(self: &Party): bool {
    platform_link::exists_<Data>(self.uid())
}

/// The party's link for this platform, if set.
public fun link<Data: copy + drop + store>(self: &Party): Option<PlatformLink<Data>> {
    platform_link::get<Data>(self.uid())
}
