// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_featured_pressing::party_featured_pressing_tests;

use miso_party::party;
use miso_pressing::pressing;
use party_featured_pressing::party_featured_pressing as fp;
use std::unit_test::{assert_eq, destroy};
use sui::sui::SUI;

fun new_party(ctx: &mut TxContext): (party::Party, party::PartyAdminCap) {
    party::new(party::new_individual_kind(), b"Test Artist".to_string(), ctx)
}

fun new_pressing(edition: u32, ctx: &mut TxContext): pressing::Pressing<SUI> {
    pressing::new_for_testing<SUI>(
        object::id_from_address(@0xCAFE), // release id (fabricated for the test)
        edition,
        pressing::new_fixed_price(1000),
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
    assert!(!fp::has_featured(&p));
    assert!(fp::featured(&p).is_none());

    // Feature a pressing — stores its id.
    let pr1 = new_pressing(0, ctx);
    fp::set_featured(&mut p, &cap, &pr1);
    assert!(fp::has_featured(&p));
    assert_eq!(fp::featured(&p).destroy_some(), pressing::id(&pr1));

    // Replace with a different pressing — one slot, overwrites in place.
    let pr2 = new_pressing(1, ctx);
    fp::set_featured(&mut p, &cap, &pr2);
    assert_eq!(fp::featured(&p).destroy_some(), pressing::id(&pr2));

    // Clear, then a second clear is a no-op.
    fp::clear_featured(&mut p, &cap);
    assert!(!fp::has_featured(&p));
    assert!(fp::featured(&p).is_none());
    fp::clear_featured(&mut p, &cap);

    pressing::destroy_for_testing(pr1);
    pressing::destroy_for_testing(pr2);
    destroy(p);
    destroy(cap);
}
