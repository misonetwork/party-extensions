// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Musical-genre tags for a party, piggybacking the Miso genre vocabulary.
///
/// Stores a set of `genre::Genre` object ids — the same canonical, name-derived
/// genres the shared vocabulary primitive mints, so a party's genres reference
/// exactly the ids releases (and anything else) use. Adding a genre takes a
/// `&Genre`, proving the id is a real vocabulary entry; removal is by id. Genre
/// is presentation, not protocol-verifiable state, so a party's genres are a
/// lightweight display tag list — no primary/secondary ranking, no anti-churn
/// locks. The set mechanics — storage, duplicate and capacity checks, field
/// reclamation — live in the shared `typed_set` primitive; this package keeps
/// the vocabulary proof, the capacity, and the typed events. Duplicate /
/// not-present / over-max aborts come from `typed_set` with its own error
/// codes. All writes are gated by the `PartyAdminCap`; views are
/// permissionless.
module party_genre::party_genre;

use genre::genre::Genre;
use miso_party::party::{Party, PartyAdminCap};
use sui::event::emit;
use typed_set::typed_set as set;

// === Constants ===

/// Maximum number of genres a party may carry.
const MAX_GENRES: u64 = 20;

// === Keys ===

/// Dynamic-field key for a party's genre set, stored as a `VecSet<ID>` and
/// managed through `typed_set`.
public struct GenresKey() has copy, drop, store;

// === Events ===

/// Emitted when a genre is added to a party.
public struct GenreAddedEvent has copy, drop {
    party_id: ID,
    genre_id: ID,
}

/// Emitted when a genre is removed from a party.
public struct GenreRemovedEvent has copy, drop {
    party_id: ID,
    genre_id: ID,
}

/// Emitted when a party's entire genre set is removed.
public struct GenresClearedEvent has copy, drop {
    party_id: ID,
}

// === Write API ===

/// Adds a genre to the party. Takes `&Genre` so only a real vocabulary entry
/// can be tagged. Aborts in `typed_set` if already present or the max is
/// reached.
public fun add_genre(self: &mut Party, cap: &PartyAdminCap, genre: &Genre) {
    let party_id = self.id();
    let genre_id = genre.id();
    set::add(self.uid_mut(cap), GenresKey(), genre_id, MAX_GENRES);
    emit(GenreAddedEvent { party_id, genre_id });
}

/// Removes a genre from the party. Aborts in `typed_set` if not present. The
/// whole field is dropped when the last genre leaves.
public fun remove_genre(self: &mut Party, cap: &PartyAdminCap, genre_id: ID) {
    let party_id = self.id();
    set::remove(self.uid_mut(cap), GenresKey(), genre_id);
    emit(GenreRemovedEvent { party_id, genre_id });
}

/// Removes the party's entire genre set. No-op if none is set.
public fun clear_genres(self: &mut Party, cap: &PartyAdminCap) {
    let party_id = self.id();
    let uid = self.uid_mut(cap);
    if (set::exists(uid, GenresKey())) {
        set::clear<GenresKey, ID>(uid, GenresKey());
        emit(GenresClearedEvent { party_id });
    }
}

// === Views ===

/// Whether the party carries any genres.
public fun has_genres(self: &Party): bool {
    set::exists(self.uid(), GenresKey())
}

/// Whether the party carries the given genre.
public fun has_genre(self: &Party, genre_id: ID): bool {
    set::contains(self.uid(), GenresKey(), &genre_id)
}

/// The party's genre ids.
public fun genres(self: &Party): vector<ID> {
    set::keys(self.uid(), GenresKey())
}
