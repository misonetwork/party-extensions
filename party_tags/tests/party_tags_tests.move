// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_tags::party_tags_tests;

use miso_party::party;
use party_tags::party_tags as tags;
use std::unit_test::{assert_eq, destroy};
use sui::test_scenario::{Self as ts};

// Mirrors `party::EUnauthorized` (party.move) for the wrong-cap abort test.
const EUnauthorized: u64 = 0;
const OWNER: address = @0xA;

fun new_party(ctx: &mut TxContext): (party::Party, party::PartyAdminCap) {
    {
        let clock = sui::clock::create_for_testing(ctx);
        let (p, cap) = party::new(party::new_individual_kind(), b"Test Artist".to_string(), &clock, ctx);
        clock.destroy_for_testing();
        (p, cap)
    }
}

#[test]
fun add_remove_and_query() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);

    assert!(!tags::has_tags(&p));
    tags::add_tag(&mut p, &cap, b"ambient".to_string());
    tags::add_tag(&mut p, &cap, b"deconstructed club".to_string());

    assert!(tags::has_tags(&p));
    assert!(tags::has_tag(&p, b"ambient".to_string()));
    assert!(!tags::has_tag(&p, b"techno".to_string()));
    assert_eq!(tags::tags(&p).length(), 2);

    tags::remove_tag(&mut p, &cap, b"ambient".to_string());
    assert!(!tags::has_tag(&p, b"ambient".to_string()));
    assert_eq!(tags::tags(&p).length(), 1);

    // Removing the last tag reclaims the field — no empty set lingers.
    tags::remove_tag(&mut p, &cap, b"deconstructed club".to_string());
    assert!(!tags::has_tags(&p));

    tags::add_tag(&mut p, &cap, b"leftfield pop".to_string());
    tags::clear_tags(&mut p, &cap);
    assert!(!tags::has_tags(&p));
    tags::clear_tags(&mut p, &cap); // no-op when absent

    destroy(p);
    destroy(cap);
}

#[test]
fun shared_party_tags_workflow() {
    let mut scenario = ts::begin(OWNER);
    let (p, cap) = new_party(scenario.ctx());
    party::share(p, &cap);
    transfer::public_transfer(cap, OWNER);

    scenario.next_tx(OWNER);
    let mut p = scenario.take_shared<party::Party>();
    let cap = scenario.take_from_sender<party::PartyAdminCap>();
    tags::add_tag(&mut p, &cap, b"ambient".to_string());
    ts::return_shared(p);
    scenario.return_to_sender(cap);

    scenario.next_tx(@0xB);
    let p = scenario.take_shared<party::Party>();
    assert!(tags::has_tag(&p, b"ambient".to_string()));
    ts::return_shared(p);
    scenario.end();
}

#[test, expected_failure(abort_code = 0, location = party_tags::party_tags)] // EEmptyTag
fun rejects_empty() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    tags::add_tag(&mut p, &cap, b"".to_string());
    abort
}

#[test, expected_failure(abort_code = 1, location = party_tags::party_tags)] // ETagTooLong
fun rejects_overlong_tag() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    let tag = vector::tabulate!(51, |_| 97u8).to_string();
    tags::add_tag(&mut p, &cap, tag);
    abort
}

#[test, expected_failure(abort_code = 0, location = typed_set::typed_set)] // EDuplicateItem
fun rejects_duplicate() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    tags::add_tag(&mut p, &cap, b"ambient".to_string());
    tags::add_tag(&mut p, &cap, b"ambient".to_string());
    abort
}

#[test, expected_failure(abort_code = 1, location = typed_set::typed_set)] // EItemNotPresent
fun remove_absent_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    tags::add_tag(&mut p, &cap, b"ambient".to_string());
    tags::remove_tag(&mut p, &cap, b"techno".to_string()); // not carried
    abort
}

#[test, expected_failure(abort_code = 2, location = typed_set::typed_set)] // EMaxItemsExceeded
fun rejects_over_max() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    // 31 distinct tags (two-char names) trips MAX_TAGS (30).
    31u64.do!(|i| {
        let tag = std::string::utf8(vector[b"t"[0], ((65 + i) as u8)]);
        tags::add_tag(&mut p, &cap, tag);
    });
    abort
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso_party::party)]
fun add_tag_with_wrong_cap_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut p, _cap) = new_party(ctx);
    let (_other, other_cap) = new_party(ctx);

    // A cap for a different party must not authorize writes to `p`.
    tags::add_tag(&mut p, &other_cap, b"ambient".to_string());
    abort
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso_party::party)]
fun add_tag_with_wrong_cap_on_full_set_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    let (_other, other_cap) = new_party(ctx);

    // Fill `p`'s tag set to MAX_TAGS (30) so a capacity check, if it ran
    // before authorization, would also abort here — proving the cap-gate
    // really does run first, not just when there's room to add.
    30u64.do!(|i| {
        let tag = std::string::utf8(vector[b"t"[0], ((65 + i) as u8)]);
        tags::add_tag(&mut p, &cap, tag);
    });

    // A cap for a different party must abort on authorization, not capacity.
    tags::add_tag(&mut p, &other_cap, b"ambient".to_string());
    abort
}
