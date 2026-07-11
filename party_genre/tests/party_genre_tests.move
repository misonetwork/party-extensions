// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_genre::party_genre_tests;

use genre::genre as g;
use genre::genre::{GenreRegistry, GenreRegistryCap, Genre};
use miso_party::party;
// Aliased so the bare `party_genre` name stays free for `location = …`.
use party_genre::party_genre as pg;
use std::unit_test::{assert_eq, destroy};
use sui::test_scenario::{Self as ts, Scenario};

const CURATOR: address = @0xC0;
const MAX_GENRES: u64 = 20;

// === Helpers ===

/// Creates a genre in the registry (cap-gated) and returns its derived id.
fun create_genre(scenario: &Scenario, name: vector<u8>): ID {
    let cap = scenario.take_from_sender<GenreRegistryCap>();
    let mut registry = scenario.take_shared<GenreRegistry>();
    let id = g::derive_genre_id(&registry, name.to_string());
    g::new(&cap, &mut registry, name.to_string());
    ts::return_shared(registry);
    scenario.return_to_sender(cap);
    id
}

fun new_party(ctx: &mut TxContext): (party::Party, party::PartyAdminCap) {
    party::new(party::new_individual_kind(), b"Test Artist".to_string(), ctx)
}

/// A fresh, unique id that is NOT a real genre (for negative cases).
fun fresh_id(ctx: &mut TxContext): ID {
    let uid = object::new(ctx);
    let id = uid.to_inner();
    uid.delete();
    id
}

// === Tests ===

#[test]
fun add_remove_and_query() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let id1 = create_genre(&scenario, b"HIP_HOP");
    scenario.next_tx(CURATOR);
    let id2 = create_genre(&scenario, b"AMBIENT");

    scenario.next_tx(CURATOR);
    let genre1 = scenario.take_immutable_by_id<Genre>(id1);
    let genre2 = scenario.take_immutable_by_id<Genre>(id2);
    let (mut p, cap) = new_party(scenario.ctx());

    assert!(!pg::has_genres(&p));
    pg::add_genre(&mut p, &cap, &genre1);
    pg::add_genre(&mut p, &cap, &genre2);

    assert!(pg::has_genres(&p));
    assert!(pg::has_genre(&p, id1));
    assert!(pg::has_genre(&p, id2));
    assert_eq!(pg::genres(&p).length(), 2);

    pg::remove_genre(&mut p, &cap, id1);
    assert!(!pg::has_genre(&p, id1));
    assert_eq!(pg::genres(&p).length(), 1);

    pg::clear_genres(&mut p, &cap);
    assert!(!pg::has_genres(&p));

    ts::return_immutable(genre1);
    ts::return_immutable(genre2);
    destroy(p);
    destroy(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 0, location = party_genre::party_genre)] // EDuplicateGenre
fun rejects_duplicate() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());
    scenario.next_tx(CURATOR);
    let id = create_genre(&scenario, b"HIP_HOP");

    scenario.next_tx(CURATOR);
    let genre = scenario.take_immutable_by_id<Genre>(id);
    let (mut p, cap) = new_party(scenario.ctx());
    pg::add_genre(&mut p, &cap, &genre);
    pg::add_genre(&mut p, &cap, &genre); // duplicate
    abort
}

#[test, expected_failure(abort_code = 1, location = party_genre::party_genre)] // EGenreNotPresent
fun remove_absent_aborts() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());
    scenario.next_tx(CURATOR);
    let id = create_genre(&scenario, b"HIP_HOP");

    scenario.next_tx(CURATOR);
    let genre = scenario.take_immutable_by_id<Genre>(id);
    let (mut p, cap) = new_party(scenario.ctx());
    pg::add_genre(&mut p, &cap, &genre);
    pg::remove_genre(&mut p, &cap, fresh_id(scenario.ctx())); // a real genre, but not tagged
    abort
}

#[test, expected_failure(abort_code = 2, location = party_genre::party_genre)] // EMaxGenresExceeded
fun rejects_over_max() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    // Mint MAX_GENRES + 1 distinct genres (single-letter names A, B, …).
    scenario.next_tx(CURATOR);
    let mut ids = vector[];
    {
        let cap = scenario.take_from_sender<GenreRegistryCap>();
        let mut registry = scenario.take_shared<GenreRegistry>();
        (MAX_GENRES + 1).do!(|i| {
            let name = std::string::utf8(vector[((65 + i) as u8)]);
            ids.push_back(g::derive_genre_id(&registry, name));
            g::new(&cap, &mut registry, name);
        });
        ts::return_shared(registry);
        scenario.return_to_sender(cap);
    };

    scenario.next_tx(CURATOR);
    let (mut p, cap) = new_party(scenario.ctx());
    ids.do_ref!(|id| {
        let genre = scenario.take_immutable_by_id<Genre>(*id);
        pg::add_genre(&mut p, &cap, &genre); // the (MAX_GENRES + 1)-th aborts
        ts::return_immutable(genre);
    });
    abort
}
