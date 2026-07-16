// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_featured_drop::party_featured_drop_tests;

use miso_drop::drop;
use miso_party::party;
use party_featured_drop::party_featured_drop as fd;
use std::unit_test::{assert_eq, destroy};
use sui::sui::SUI;

fun new_party(ctx: &mut TxContext): (party::Party, party::PartyAdminCap) {
    {
        let clock = sui::clock::create_for_testing(ctx);
        let (p, cap) = party::new(party::new_individual_kind(), b"Test Artist".to_string(), &clock, ctx);
        clock.destroy_for_testing();
        (p, cap)
    }
}

fun new_drop(edition: u32, ctx: &mut TxContext): drop::Drop<SUI> {
    drop::new_for_testing<SUI>(
        object::id_from_address(@0xCAFE), // release id (fabricated for the test)
        edition,
        drop::new_fixed_price(1000),
        0, // start
        option::none(), // evergreen
        ctx,
    )
}

#[test]
fun set_read_replace_clear() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);

    // Unset by default.
    assert!(!fd::has_featured(&p));
    assert!(fd::featured(&p).is_none());

    // Feature a drop — stores its id.
    let d1 = new_drop(0, ctx);
    fd::set_featured(&mut p, &cap, &d1);
    assert!(fd::has_featured(&p));
    assert_eq!(fd::featured(&p).destroy_some(), drop::id(&d1));

    // Replace with a different drop — one slot, overwrites in place.
    let d2 = new_drop(1, ctx);
    fd::set_featured(&mut p, &cap, &d2);
    assert_eq!(fd::featured(&p).destroy_some(), drop::id(&d2));

    // Clear, then a second clear is a no-op.
    fd::clear_featured(&mut p, &cap);
    assert!(!fd::has_featured(&p));
    assert!(fd::featured(&p).is_none());
    fd::clear_featured(&mut p, &cap);

    drop::destroy_for_testing(d1);
    drop::destroy_for_testing(d2);
    destroy(p);
    destroy(cap);
}
