// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_platform_link::party_platform_link_tests;

use miso_party::party;
use party_platform_link::party_platform_link as links;
use party_social::party_social::{Self as social, XData, InstagramData};
use std::unit_test::{assert_eq, destroy};

// Mirrors `party::EUnauthorized` (party.move) for the wrong-cap abort test.
const EUnauthorized: u64 = 0;

fun new_party(ctx: &mut TxContext): (party::Party, party::PartyAdminCap) {
    {
        let clock = sui::clock::create_for_testing(ctx);
        let (p, cap) = party::new(party::new_individual_kind(), b"Test Artist".to_string(), &clock, ctx);
        clock.destroy_for_testing();
        (p, cap)
    }
}

#[test]
fun set_read_and_clear_link() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);

    assert!(!links::has_link<XData>(&p));
    links::set_link(&mut p, &cap, social::x(b"miso".to_string()));

    assert!(links::has_link<XData>(&p));
    let got = links::link<XData>(&p).destroy_some();
    assert_eq!(got.data().handle(), b"miso".to_string());

    links::clear_link<XData>(&mut p, &cap);
    assert!(!links::has_link<XData>(&p));
    links::clear_link<XData>(&mut p, &cap); // no-op

    destroy(p);
    destroy(cap);
}

#[test]
fun platforms_are_independent() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);

    links::set_link(&mut p, &cap, social::x(b"miso".to_string()));
    links::set_link(&mut p, &cap, social::instagram(b"miso.network".to_string()));

    // Clearing one platform leaves the other untouched.
    links::clear_link<XData>(&mut p, &cap);
    assert!(!links::has_link<XData>(&p));
    assert!(links::has_link<InstagramData>(&p));
    assert_eq!(
        links::link<InstagramData>(&p).destroy_some().data().handle(),
        b"miso.network".to_string(),
    );

    destroy(p);
    destroy(cap);
}

#[test]
fun set_link_replaces_existing() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);

    links::set_link(&mut p, &cap, social::x(b"old".to_string()));
    links::set_link(&mut p, &cap, social::x(b"new".to_string()));
    assert_eq!(links::link<XData>(&p).destroy_some().data().handle(), b"new".to_string());

    destroy(p);
    destroy(cap);
}

// `clear_link` must reject a wrong cap even when no link is present — the cap is
// verified before the existence check, so authorization never depends on state.
#[test, expected_failure(abort_code = EUnauthorized, location = miso_party::party)]
fun clear_link_with_wrong_cap_aborts_when_absent() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    let (other, other_cap) = new_party(ctx);

    // `p` has no XData link; a foreign cap must still abort rather than no-op.
    links::clear_link<XData>(&mut p, &other_cap);

    destroy(p);
    destroy(cap);
    destroy(other);
    destroy(other_cap);
}
