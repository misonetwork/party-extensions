// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_media::party_media_tests;

use miso_party::party;
use party_media::party_media as media;
use std::unit_test::{assert_eq, destroy};
use sui::test_scenario::{Self as ts};

// Mirrors `party::EUnauthorized` (party.move) for the wrong-cap abort test.
const EUnauthorized: u64 = 0;
const OWNER: address = @0xA;

fun new_party(ctx: &mut TxContext): (party::Party, party::PartyAdminCap) {
    let clock = sui::clock::create_for_testing(ctx);
    let (p, cap) = party::new(party::new_individual_kind(), b"Test Artist".to_string(), &clock, ctx);
    clock.destroy_for_testing();
    (p, cap)
}

#[test]
fun set_read_and_clear() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);

    assert!(!media::has_media(&p));
    assert!(media::quilt(&p).is_none());

    media::set_media(&mut p, &cap, 0x1234u256);
    assert!(media::has_media(&p));
    assert_eq!(media::quilt(&p).destroy_some(), 0x1234u256);

    media::clear_media(&mut p, &cap);
    assert!(!media::has_media(&p));
    assert!(media::quilt(&p).is_none());

    media::clear_media(&mut p, &cap); // no-op when unset

    destroy(p);
    destroy(cap);
}

#[test]
fun set_media_replaces_quilt() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);

    media::set_media(&mut p, &cap, 0x1u256);
    media::set_media(&mut p, &cap, 0x2u256);

    assert_eq!(media::quilt(&p).destroy_some(), 0x2u256);

    destroy(p);
    destroy(cap);
}

#[test]
fun shared_party_media_workflow() {
    let mut scenario = ts::begin(OWNER);
    let (p, cap) = new_party(scenario.ctx());
    party::share(p, &cap);
    transfer::public_transfer(cap, OWNER);

    scenario.next_tx(OWNER);
    let mut p = scenario.take_shared<party::Party>();
    let cap = scenario.take_from_sender<party::PartyAdminCap>();
    media::set_media(&mut p, &cap, 0xCAFEu256);
    ts::return_shared(p);
    scenario.return_to_sender(cap);

    scenario.next_tx(@0xB);
    let p = scenario.take_shared<party::Party>();
    assert_eq!(media::quilt(&p).destroy_some(), 0xCAFEu256);
    ts::return_shared(p);
    scenario.end();
}

#[test, expected_failure(abort_code = 0, location = party_media::party_media)] // EZeroQuilt
fun rejects_zero_quilt() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    media::set_media(&mut p, &cap, 0u256);
    abort
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso_party::party)]
fun set_media_with_wrong_cap_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    let (other, other_cap) = new_party(ctx);

    // A cap for a different party must not authorize writes to `p`. The call
    // aborts; the cleanup below is unreachable but consumes the owned objects
    // the borrow-checker still sees as live (the aborting call takes them by
    // reference, so it cannot prove they are gone).
    media::set_media(&mut p, &other_cap, 0x1u256);

    destroy(p);
    destroy(cap);
    destroy(other);
    destroy(other_cap);
}
