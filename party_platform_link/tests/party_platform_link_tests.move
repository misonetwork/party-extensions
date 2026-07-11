// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_platform_link::party_platform_link_tests;

use miso_party::party;
use party_platform_link::party_platform_link as links;
use party_social::party_social::{Self as social, XData, InstagramData};
use std::unit_test::{assert_eq, destroy};

fun new_party(ctx: &mut TxContext): (party::Party, party::PartyAdminCap) {
    party::new(party::new_individual_kind(), b"Test Artist".to_string(), ctx)
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
