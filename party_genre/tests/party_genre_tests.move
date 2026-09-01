// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_genre::party_genre_tests;

use genre::genre as g;
use genre::genre::{GenreRegistry, Genre};
use miso_party::party;
// Aliased so the bare `party_genre` name stays free for `location = …`.
use party_genre::party_genre as pg;
use std::unit_test::{assert_eq, destroy};
use sui::test_scenario::{Self as ts, Scenario};

const CREATOR: address = @0xC0;
const MAX_GENRES: u64 = 20;

// Mirrors `party::EUnauthorized` (party.move) for the wrong-cap abort test.
const EUnauthorized: u64 = 0;

// === Helpers ===

/// Creates a genre in the permissionless registry and returns its derived id.
fun create_genre(scenario: &Scenario, name: vector<u8>): ID {
    let mut registry = scenario.take_shared<GenreRegistry>();
    let id = g::derive_address(&registry, name.to_string()).to_id();
    g::new(&mut registry, name.to_string());
    ts::return_shared(registry);
    id
}

fun new_party(ctx: &mut TxContext): (party::Party, party::PartyAdminCap) {
    {
        let clock = sui::clock::create_for_testing(ctx);
        let (p, cap) = party::new(party::new_individual_kind(), b"Test Artist".to_string(), &clock, ctx);
        clock.destroy_for_testing();
        (p, cap)
    }
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
    let mut scenario = ts::begin(CREATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CREATOR);
    let id1 = create_genre(&scenario, b"HIP_HOP");
    scenario.next_tx(CREATOR);
    let id2 = create_genre(&scenario, b"AMBIENT");

    scenario.next_tx(CREATOR);
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

    // Removing the last genre reclaims the field — no empty set lingers.
    pg::remove_genre(&mut p, &cap, id2);
    assert!(!pg::has_genres(&p));

    pg::add_genre(&mut p, &cap, &genre1);
    pg::clear_genres(&mut p, &cap);
    assert!(!pg::has_genres(&p));
    pg::clear_genres(&mut p, &cap); // no-op when absent

    ts::return_immutable(genre1);
    ts::return_immutable(genre2);
    destroy(p);
    destroy(cap);
    scenario.end();
}

#[test]
fun shared_party_genre_workflow() {
    let mut scenario = ts::begin(CREATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CREATOR);
    let genre_id = create_genre(&scenario, b"HOUSE");

    scenario.next_tx(CREATOR);
    let (p, cap) = new_party(scenario.ctx());
    party::share(p, &cap);
    transfer::public_transfer(cap, CREATOR);

    scenario.next_tx(CREATOR);
    let genre = scenario.take_immutable_by_id<Genre>(genre_id);
    let mut p = scenario.take_shared<party::Party>();
    let cap = scenario.take_from_sender<party::PartyAdminCap>();
    pg::add_genre(&mut p, &cap, &genre);
    ts::return_immutable(genre);
    ts::return_shared(p);
    scenario.return_to_sender(cap);

    scenario.next_tx(@0xB);
    let p = scenario.take_shared<party::Party>();
    assert!(pg::has_genre(&p, genre_id));
    ts::return_shared(p);
    scenario.end();
}

#[test, expected_failure(abort_code = 0, location = typed_set::typed_set)] // EDuplicateItem
fun rejects_duplicate() {
    let mut scenario = ts::begin(CREATOR);
    g::init_for_testing(scenario.ctx());
    scenario.next_tx(CREATOR);
    let id = create_genre(&scenario, b"HIP_HOP");

    scenario.next_tx(CREATOR);
    let genre = scenario.take_immutable_by_id<Genre>(id);
    let (mut p, cap) = new_party(scenario.ctx());
    pg::add_genre(&mut p, &cap, &genre);
    pg::add_genre(&mut p, &cap, &genre); // duplicate
    abort
}

#[test, expected_failure(abort_code = 1, location = typed_set::typed_set)] // EItemNotPresent
fun remove_absent_aborts() {
    let mut scenario = ts::begin(CREATOR);
    g::init_for_testing(scenario.ctx());
    scenario.next_tx(CREATOR);
    let id = create_genre(&scenario, b"HIP_HOP");

    scenario.next_tx(CREATOR);
    let genre = scenario.take_immutable_by_id<Genre>(id);
    let (mut p, cap) = new_party(scenario.ctx());
    pg::add_genre(&mut p, &cap, &genre);
    pg::remove_genre(&mut p, &cap, fresh_id(scenario.ctx())); // a real id, but not tagged
    abort
}

#[test, expected_failure(abort_code = 2, location = typed_set::typed_set)] // EMaxItemsExceeded
fun rejects_over_max() {
    let mut scenario = ts::begin(CREATOR);
    g::init_for_testing(scenario.ctx());

    // Mint MAX_GENRES + 1 distinct genres (single-letter names A, B, …).
    scenario.next_tx(CREATOR);
    let mut ids = vector[];
    {
        let mut registry = scenario.take_shared<GenreRegistry>();
        (MAX_GENRES + 1).do!(|i| {
            let name = std::string::utf8(vector[((65 + i) as u8)]);
            ids.push_back(g::derive_address(&registry, name).to_id());
            g::new(&mut registry, name);
        });
        ts::return_shared(registry);
    };

    scenario.next_tx(CREATOR);
    let (mut p, cap) = new_party(scenario.ctx());
    ids.do_ref!(|id| {
        let genre = scenario.take_immutable_by_id<Genre>(*id);
        pg::add_genre(&mut p, &cap, &genre); // the (MAX_GENRES + 1)-th aborts
        ts::return_immutable(genre);
    });
    abort
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso_party::party)]
fun add_genre_with_wrong_cap_aborts() {
    let mut scenario = ts::begin(CREATOR);
    g::init_for_testing(scenario.ctx());
    scenario.next_tx(CREATOR);
    let id = create_genre(&scenario, b"HIP_HOP");

    scenario.next_tx(CREATOR);
    let genre = scenario.take_immutable_by_id<Genre>(id);
    let (mut p, _cap) = new_party(scenario.ctx());
    let (_other, other_cap) = new_party(scenario.ctx());

    // A cap for a different party must not authorize writes to `p`.
    pg::add_genre(&mut p, &other_cap, &genre);
    abort
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso_party::party)]
fun add_genre_with_wrong_cap_on_full_set_aborts() {
    let mut scenario = ts::begin(CREATOR);
    g::init_for_testing(scenario.ctx());

    // Mint MAX_GENRES + 1 distinct genres (single-letter names A, B, …).
    scenario.next_tx(CREATOR);
    let mut ids = vector[];
    {
        let mut registry = scenario.take_shared<GenreRegistry>();
        (MAX_GENRES + 1).do!(|i| {
            let name = std::string::utf8(vector[((65 + i) as u8)]);
            ids.push_back(g::derive_address(&registry, name).to_id());
            g::new(&mut registry, name);
        });
        ts::return_shared(registry);
    };

    scenario.next_tx(CREATOR);
    let (mut p, cap) = new_party(scenario.ctx());
    let (_other, other_cap) = new_party(scenario.ctx());

    // Fill `p`'s genre set to MAX_GENRES so a capacity check, if it ran
    // before authorization, would also abort here — proving the cap-gate
    // really does run first, not just when there's room to add.
    MAX_GENRES.do!(|i| {
        let genre = scenario.take_immutable_by_id<Genre>(*ids.borrow(i));
        pg::add_genre(&mut p, &cap, &genre);
        ts::return_immutable(genre);
    });

    // A cap for a different party must abort on authorization, not capacity.
    let last = scenario.take_immutable_by_id<Genre>(*ids.borrow(MAX_GENRES));
    pg::add_genre(&mut p, &other_cap, &last);
    abort
}
