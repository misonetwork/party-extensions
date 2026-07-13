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
/// locks. All writes are gated by the `PartyAdminCap`; views are permissionless.
module party_genre::party_genre;

use genre::genre::Genre;
use miso_party::party::{Party, PartyAdminCap};
use sui::dynamic_field as df;
use sui::event::emit;
use sui::vec_set::{Self, VecSet};

// === Errors ===

/// The party already carries this genre.
const EDuplicateGenre: u64 = 0;
/// The party does not carry this genre.
const EGenreNotPresent: u64 = 1;
/// Adding this genre would exceed the maximum.
const EMaxGenresExceeded: u64 = 2;

// === Constants ===

/// Maximum number of genres a party may carry.
const MAX_GENRES: u64 = 20;

// === Keys ===

/// Dynamic-field key for a party's genre set.
public struct GenresKey() has copy, drop, store;

// === Types ===

/// The set of genre ids tagged on a party.
public struct PartyGenres has store {
    genres: VecSet<ID>,
}

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

/// Adds a genre to the party. Aborts if already present or the max is reached.
/// Takes `&Genre` so only a real vocabulary entry can be tagged.
public fun add_genre(self: &mut Party, cap: &PartyAdminCap, genre: &Genre) {
    let party_id = self.id();
    let genre_id = genre.id();
    let genres = genres_mut_or_init(self, cap);
    assert!(!genres.contains(&genre_id), EDuplicateGenre);
    assert!(genres.length() < MAX_GENRES, EMaxGenresExceeded);
    genres.insert(genre_id);
    emit(GenreAddedEvent { party_id, genre_id });
}

/// Removes a genre from the party. Aborts if not present.
public fun remove_genre(self: &mut Party, cap: &PartyAdminCap, genre_id: ID) {
    let party_id = self.id();
    let uid = self.uid_mut(cap);
    assert!(df::exists(uid, GenresKey()), EGenreNotPresent);
    let genres = borrow_genres_mut(uid);
    assert!(genres.contains(&genre_id), EGenreNotPresent);
    genres.remove(&genre_id);
    emit(GenreRemovedEvent { party_id, genre_id });
}

/// Removes the party's entire genre set. No-op if none is set.
public fun clear_genres(self: &mut Party, cap: &PartyAdminCap) {
    let party_id = self.id();
    let uid = self.uid_mut(cap);
    if (df::exists(uid, GenresKey())) {
        let PartyGenres { .. } = df::remove(uid, GenresKey());
        emit(GenresClearedEvent { party_id });
    }
}

// === Views ===

/// Whether the party has a genre set (which may be empty after removals).
public fun has_genres(self: &Party): bool {
    df::exists(self.uid(), GenresKey())
}

/// Whether the party carries the given genre.
public fun has_genre(self: &Party, genre_id: ID): bool {
    if (!df::exists(self.uid(), GenresKey())) return false;
    borrow_genres(self.uid()).contains(&genre_id)
}

/// The party's genre ids.
public fun genres(self: &Party): vector<ID> {
    if (!df::exists(self.uid(), GenresKey())) return vector[];
    *borrow_genres(self.uid()).keys()
}

// === Private ===

fun borrow_genres(uid: &UID): &VecSet<ID> {
    &df::borrow<GenresKey, PartyGenres>(uid, GenresKey()).genres
}

fun borrow_genres_mut(uid: &mut UID): &mut VecSet<ID> {
    &mut df::borrow_mut<GenresKey, PartyGenres>(uid, GenresKey()).genres
}

fun genres_mut_or_init(self: &mut Party, cap: &PartyAdminCap): &mut VecSet<ID> {
    let uid = self.uid_mut(cap);
    if (!df::exists(uid, GenresKey())) {
        df::add(uid, GenresKey(), PartyGenres { genres: vec_set::empty() });
    };
    borrow_genres_mut(uid)
}
