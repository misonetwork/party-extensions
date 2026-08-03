// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Profile imagery for a party, stored as a single Walrus quilt.
///
/// All of a party's images (avatar, header/cover, …) live together in one Walrus
/// quilt — batching them under a single storage reservation is markedly cheaper
/// than one blob each, which matters when the platform sponsors storage. Only the
/// quilt's blob id is held on-chain, as a `Media` dynamic field on the party's
/// UID, gated by the `PartyAdminCap`; views are permissionless.
///
/// The chain is deliberately role-agnostic: which patch is the avatar vs the
/// header is a client convention (quilt patch *identifiers*, e.g. "avatar" /
/// "header"), derived off-chain — never stored here. Updating any image means
/// re-storing the quilt and calling `set_media` with the new id.
module party_media::party_media;

use miso_party::party::{Party, PartyAdminCap};
use sui::dynamic_field as df;
use sui::event::emit;

// === Keys ===

/// Dynamic-field key for a party's media.
public struct MediaKey() has copy, drop, store;

// === Errors ===

/// The quilt id was zero. Zero is never a real Walrus blob id — almost
/// certainly a caller bug, and indistinguishable from "unset" downstream.
const EZeroQuilt: u64 = 0;

// === Types ===

/// A party's imagery. Held as a dynamic-field value.
public struct Media has store, drop {
    /// Walrus quilt blob id holding all of the party's images. Individual images
    /// are quilt patches addressed by identifier ("avatar", "header", …); those
    /// roles are a client convention, derived off-chain, not stored here.
    quilt: u256,
}

// === Events ===

/// Emitted when a party's media quilt is set or replaced. Carries the new
/// quilt id — small, stable pointers ride in the event so an indexer can skip
/// re-reading the field (dynamic-field mutations are not otherwise observable).
public struct MediaSetEvent has copy, drop {
    party_id: ID,
    quilt: u256,
}

/// Emitted when a party's media is removed.
public struct MediaClearedEvent has copy, drop {
    party_id: ID,
}

// === Write API ===

/// Sets (or replaces) the party's media quilt. Aborts on a zero id.
public fun set_media(self: &mut Party, cap: &PartyAdminCap, quilt: u256) {
    assert!(quilt != 0, EZeroQuilt);
    let party_id = self.id();
    let uid = self.uid_mut(cap);
    if (df::exists(uid, MediaKey())) {
        df::borrow_mut<MediaKey, Media>(uid, MediaKey()).quilt = quilt;
    } else {
        df::add(uid, MediaKey(), Media { quilt });
    };
    emit(MediaSetEvent { party_id, quilt });
}

/// Removes the party's media. No-op if none is set.
public fun clear_media(self: &mut Party, cap: &PartyAdminCap) {
    let party_id = self.id();
    let uid = self.uid_mut(cap);
    if (df::exists(uid, MediaKey())) {
        let Media { .. } = df::remove(uid, MediaKey());
        emit(MediaClearedEvent { party_id });
    }
}

// === Views ===

/// Whether the party has media set.
public fun has_media(self: &Party): bool {
    df::exists(self.uid(), MediaKey())
}

/// The party's media quilt id, if set.
public fun quilt(self: &Party): Option<u256> {
    if (!df::exists(self.uid(), MediaKey())) return option::none();
    option::some(df::borrow<MediaKey, Media>(self.uid(), MediaKey()).quilt)
}
