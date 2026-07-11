// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Profile imagery for a party: an avatar and a header/cover, each a Walrus
/// reference (`ori::WalrusData`).
///
/// Images are Walrus-hosted, so only the reference is stored — never bytes, and
/// never an external URL. Held as a single `Media` dynamic field on the party's
/// UID, gated by the `PartyAdminCap`; views are permissionless. This is the only
/// party extension that depends on `ori`, keeping that dependency isolated.
module party_media::party_media;

use miso_party::party::{Party, PartyAdminCap};
use ori::walrus_data::WalrusData;
use sui::dynamic_field as df;
use sui::event::emit;

// === Keys ===

/// Dynamic-field key for a party's media.
public struct MediaKey() has copy, drop, store;

// === Types ===

/// A party's profile imagery. Held as a dynamic-field value.
public struct Media has store, drop {
    avatar: Option<WalrusData>,
    header: Option<WalrusData>,
}

// === Events ===

/// Emitted when a party's avatar or header is set or cleared.
public struct MediaSetEvent has copy, drop {
    party_id: ID,
}

/// Emitted when a party's media is removed entirely.
public struct MediaClearedEvent has copy, drop {
    party_id: ID,
}

// === Write API ===

/// Sets (or replaces) the party's avatar.
public fun set_avatar(self: &mut Party, cap: &PartyAdminCap, avatar: WalrusData) {
    let party_id = self.id();
    media_mut_or_init(self, cap).avatar = option::some(avatar);
    emit(MediaSetEvent { party_id });
}

/// Sets (or replaces) the party's header/cover.
public fun set_header(self: &mut Party, cap: &PartyAdminCap, header: WalrusData) {
    let party_id = self.id();
    media_mut_or_init(self, cap).header = option::some(header);
    emit(MediaSetEvent { party_id });
}

/// Clears the party's avatar. No-op if no media is set.
public fun clear_avatar(self: &mut Party, cap: &PartyAdminCap) {
    let party_id = self.id();
    let uid = self.uid_mut(cap);
    if (df::exists(uid, MediaKey())) {
        df::borrow_mut<MediaKey, Media>(uid, MediaKey()).avatar = option::none();
        emit(MediaSetEvent { party_id });
    }
}

/// Clears the party's header. No-op if no media is set.
public fun clear_header(self: &mut Party, cap: &PartyAdminCap) {
    let party_id = self.id();
    let uid = self.uid_mut(cap);
    if (df::exists(uid, MediaKey())) {
        df::borrow_mut<MediaKey, Media>(uid, MediaKey()).header = option::none();
        emit(MediaSetEvent { party_id });
    }
}

/// Removes the party's media entirely. No-op if none is set.
public fun clear_media(self: &mut Party, cap: &PartyAdminCap) {
    let party_id = self.id();
    let uid = self.uid_mut(cap);
    if (df::exists(uid, MediaKey())) {
        let Media { .. } = df::remove(uid, MediaKey());
        emit(MediaClearedEvent { party_id });
    }
}

// === Views ===

/// Whether the party has any media set.
public fun has_media(self: &Party): bool {
    df::exists(self.uid(), MediaKey())
}

/// The party's avatar reference, if set.
public fun avatar(self: &Party): Option<WalrusData> {
    if (!df::exists(self.uid(), MediaKey())) return option::none();
    df::borrow<MediaKey, Media>(self.uid(), MediaKey()).avatar
}

/// The party's header/cover reference, if set.
public fun header(self: &Party): Option<WalrusData> {
    if (!df::exists(self.uid(), MediaKey())) return option::none();
    df::borrow<MediaKey, Media>(self.uid(), MediaKey()).header
}

// === Private ===

fun media_mut_or_init(self: &mut Party, cap: &PartyAdminCap): &mut Media {
    let uid = self.uid_mut(cap);
    if (!df::exists(uid, MediaKey())) {
        df::add(uid, MediaKey(), Media { avatar: option::none(), header: option::none() });
    };
    df::borrow_mut<MediaKey, Media>(uid, MediaKey())
}
