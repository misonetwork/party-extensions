// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// The one drop a party wants to headline — the "featured release" slot on a
/// profile.
///
/// A party's full discography is *derived* (an indexer lists every drop the
/// party minted), but which one to feature is a **choice the artist authors** —
/// it exists nowhere on-chain until declared, so it can't be derived and must be
/// stored. This extension stores it.
///
/// Unlike the other party extensions, this one takes a protocol dependency
/// (`miso_drop`) on purpose. `set_featured` requires the live
/// `Drop<Currency>` object, so the featured id is *proven* to be a real
/// drop at write time — no garbage or dangling ids can be pinned. A
/// `Drop` is a shared, `key`-only, currency-generic object, so it can't be
/// held on the party; we store only its `ID`. The drop's live state (price,
/// edition, sold-out, its release) is read from the object by id at render time
/// and never copied here.
///
/// One slot, replace-in-place: `set_featured` overwrites any existing pin. Gated
/// by the `PartyAdminCap`; views are permissionless.
module party_featured_drop::party_featured_drop;

use miso_drop::drop::Drop;
use miso_party::party::{Party, PartyAdminCap};
use sui::dynamic_field as df;
use sui::event::emit;

// === Keys ===

/// Dynamic-field key for a party's featured-drop id.
public struct FeaturedKey() has copy, drop, store;

// === Events ===

/// Emitted when a party's featured drop is set or replaced.
public struct FeaturedSetEvent has copy, drop {
    party_id: ID,
    drop_id: ID,
}

/// Emitted when a party's featured drop is cleared.
public struct FeaturedClearedEvent has copy, drop {
    party_id: ID,
}

// === Write API ===

/// Feature `drop` on the party, replacing any existing pin. Takes the live
/// `Drop` object so the stored id is guaranteed to be a real drop; only
/// its id is kept.
public fun set_featured<Currency>(
    self: &mut Party,
    cap: &PartyAdminCap,
    drop: &Drop<Currency>,
) {
    let party_id = self.id();
    let drop_id = drop.id();
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

/// The party's featured drop id, or `none` if unset.
public fun featured(self: &Party): Option<ID> {
    if (!df::exists(self.uid(), FeaturedKey())) return option::none();
    option::some(*df::borrow<FeaturedKey, ID>(self.uid(), FeaturedKey()))
}
