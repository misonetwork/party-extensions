// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// The one drop a party wants to headline — the "featured release" slot on a
/// profile.
///
/// A party's full discography is *derived* (an indexer lists every pressing
/// across the party's releases), but which one to feature is a **choice the
/// artist authors** — it exists nowhere on-chain until declared, so it can't
/// be derived and must be stored. This extension stores it.
///
/// Unlike the other party extensions, this one takes a protocol dependency
/// (`miso_pressing`) on purpose. `set_featured` requires the live `Pressing`
/// object, so the featured id is *proven* to be a real pressing at write
/// time — no garbage or dangling ids can be pinned. A `Pressing` is a shared,
/// `key`-only object that is never destroyed, so the stored `ID` cannot dangle.
/// ("Drop" is the profile-page vocabulary; on-chain the object is the release's
/// `Pressing` — one per release. Its live state: price, window, sold-out — is
/// read from the pressing and its listings by id at render time, never copied
/// here.)
///
/// One slot, replace-in-place: `set_featured` overwrites any existing pin.
/// Gated by the `PartyAdminCap`; views are permissionless.
module party_featured_pressing::party_featured_pressing;

use miso_party::party::{Party, PartyAdminCap};
use miso_pressing::pressing::Pressing;
use sui::dynamic_field as df;
use sui::event::emit;

// === Keys ===

/// Dynamic-field key for a party's featured-drop id.
public struct FeaturedKey() has copy, drop, store;

// === Events ===

/// Emitted when a party's featured drop is set or replaced. Carries the id —
/// small, stable pointers ride in the event so an indexer can skip re-reading
/// the field (dynamic-field mutations are not otherwise observable).
public struct FeaturedSetEvent has copy, drop {
    party_id: ID,
    /// The featured `Pressing`'s id (field name kept for indexer stability).
    drop_id: ID,
}

/// Emitted when a party's featured drop is cleared.
public struct FeaturedClearedEvent has copy, drop {
    party_id: ID,
}

// === Write API ===

/// Feature `pressing` on the party, replacing any existing pin. Takes the live
/// `Pressing` object so the stored id is guaranteed to be real; only its id
/// is kept.
public fun set_featured(
    self: &mut Party,
    cap: &PartyAdminCap,
    pressing: &Pressing,
) {
    let party_id = self.id();
    let drop_id = pressing.id();
    let uid = self.uid_mut(cap);
    if (df::exists(uid, FeaturedKey())) {
        *df::borrow_mut(uid, FeaturedKey()) = drop_id;
    } else {
        df::add(uid, FeaturedKey(), drop_id);
    };
    emit(FeaturedSetEvent { party_id, drop_id });
}

/// Removes the party's featured drop. No-op if none is set.
public fun clear_featured(self: &mut Party, cap: &PartyAdminCap) {
    let party_id = self.id();
    let uid = self.uid_mut(cap);
    if (df::exists(uid, FeaturedKey())) {
        let _: ID = df::remove(uid, FeaturedKey());
        emit(FeaturedClearedEvent { party_id });
    }
}

// === Views ===

/// Whether the party has a featured drop.
public fun has_featured(self: &Party): bool {
    df::exists(self.uid(), FeaturedKey())
}

/// The party's featured drop id (a `Pressing` id), or `none` if unset.
public fun featured(self: &Party): Option<ID> {
    if (!df::exists(self.uid(), FeaturedKey())) return option::none();
    option::some(*df::borrow<FeaturedKey, ID>(self.uid(), FeaturedKey()))
}
