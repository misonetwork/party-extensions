// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_featured_pressing::party_featured_pressing_tests;

use miso_party::party;
use miso_pressing::pressing;
use party_featured_pressing::party_featured_pressing as fd;
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

fun new_pressing(ctx: &mut TxContext): pressing::Pressing {
    pressing::new_for_testing(
        object::id_from_address(@0xCAFE), // release id (fabricated for the test)
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

    // Feature a pressing — stores its id.
    let p1 = new_pressing(ctx);
    fd::set_featured(&mut p, &cap, &p1);
    assert!(fd::has_featured(&p));
    assert_eq!(fd::featured(&p).destroy_some(), pressing::id(&p1));

    // Replace with a different pressing — one slot, overwrites in place.
    let p2 = new_pressing(ctx);
    fd::set_featured(&mut p, &cap, &p2);
    assert_eq!(fd::featured(&p).destroy_some(), pressing::id(&p2));

    // Clear, then a second clear is a no-op.
    fd::clear_featured(&mut p, &cap);
    assert!(!fd::has_featured(&p));
    assert!(fd::featured(&p).is_none());
    fd::clear_featured(&mut p, &cap);

    pressing::destroy_for_testing(p1);
    pressing::destroy_for_testing(p2);
    destroy(p);
    destroy(cap);
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso_party::party)]
fun set_featured_with_wrong_cap_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut p, _cap) = new_party(ctx);
    let (_other, other_cap) = new_party(ctx);

    // A cap for a different party must not authorize writes to `p`.
    let pr = new_pressing(ctx);
    fd::set_featured(&mut p, &other_cap, &pr);
    abort
}
