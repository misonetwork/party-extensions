// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_roles::party_roles_tests;

use miso_party::party;
use party_roles::party_roles as roles;
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
fun add_remove_and_query() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);

    assert!(!roles::has_roles(&p));
    roles::add_role(&mut p, &cap, roles::artist());
    roles::add_role(&mut p, &cap, roles::producer());
    roles::add_role(&mut p, &cap, roles::custom(b"Visual Artist".to_string()));

    assert!(roles::has_roles(&p));
    assert!(roles::has_role(&p, roles::artist()));
    assert!(roles::has_role(&p, roles::producer()));
    assert!(!roles::has_role(&p, roles::dj()));
    assert_eq!(roles::roles(&p).length(), 3);
    // The canonical name maps to a stable token; DJ is uppercased.
    assert_eq!(roles::dj().name(), b"DJ".to_string());
    assert_eq!(roles::custom(b"Visual Artist".to_string()).name(), b"Visual Artist".to_string());

    roles::remove_role(&mut p, &cap, roles::producer());
    assert!(!roles::has_role(&p, roles::producer()));
    assert_eq!(roles::roles(&p).length(), 2);

    // Removing the last roles reclaims the field — no empty set lingers.
    roles::remove_role(&mut p, &cap, roles::artist());
    roles::remove_role(&mut p, &cap, roles::custom(b"Visual Artist".to_string()));
    assert!(!roles::has_roles(&p));

    roles::add_role(&mut p, &cap, roles::band());
    roles::clear_roles(&mut p, &cap);
    assert!(!roles::has_roles(&p));

    destroy(p);
    destroy(cap);
}

#[test, expected_failure(abort_code = 0, location = party_roles::party_roles)] // EEmptyCustomName
fun rejects_empty_custom() {
    let _ = roles::custom(b"".to_string());
    abort
}

#[test, expected_failure(abort_code = 0, location = typed_set::typed_set)] // EDuplicateItem
fun rejects_duplicate() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    roles::add_role(&mut p, &cap, roles::artist());
    roles::add_role(&mut p, &cap, roles::artist());
    abort
}

#[test, expected_failure(abort_code = 1, location = typed_set::typed_set)] // EItemNotPresent
fun remove_absent_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    roles::add_role(&mut p, &cap, roles::artist());
    roles::remove_role(&mut p, &cap, roles::dj()); // not held
    abort
}

#[test, expected_failure(abort_code = 2, location = typed_set::typed_set)] // EMaxItemsExceeded
fun rejects_over_max() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    // 8 canonical roles + customs until the 13th trips MAX_ROLES (12).
    roles::add_role(&mut p, &cap, roles::artist());
    roles::add_role(&mut p, &cap, roles::producer());
    roles::add_role(&mut p, &cap, roles::dj());
    roles::add_role(&mut p, &cap, roles::composer());
    roles::add_role(&mut p, &cap, roles::songwriter());
    roles::add_role(&mut p, &cap, roles::band());
    roles::add_role(&mut p, &cap, roles::label());
    roles::add_role(&mut p, &cap, roles::collective());
    5u64.do!(|i| roles::add_role(&mut p, &cap, roles::custom(std::string::utf8(vector[((65 + i) as u8)]))));
    abort
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso_party::party)]
fun add_role_with_wrong_cap_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut p, _cap) = new_party(ctx);
    let (_other, other_cap) = new_party(ctx);

    // A cap for a different party must not authorize writes to `p`.
    roles::add_role(&mut p, &other_cap, roles::artist());
    abort
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso_party::party)]
fun add_role_with_wrong_cap_on_full_set_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    let (_other, other_cap) = new_party(ctx);

    // Fill `p`'s role set to MAX_ROLES (12): the 8 canonical roles + 4
    // customs. A capacity check, if it ran before authorization, would also
    // abort here — proving the cap-gate really does run first, not just
    // when there's room to add.
    roles::add_role(&mut p, &cap, roles::artist());
    roles::add_role(&mut p, &cap, roles::producer());
    roles::add_role(&mut p, &cap, roles::dj());
    roles::add_role(&mut p, &cap, roles::composer());
    roles::add_role(&mut p, &cap, roles::songwriter());
    roles::add_role(&mut p, &cap, roles::band());
    roles::add_role(&mut p, &cap, roles::label());
    roles::add_role(&mut p, &cap, roles::collective());
    4u64.do!(|i| roles::add_role(&mut p, &cap, roles::custom(std::string::utf8(vector[((65 + i) as u8)]))));

    // A cap for a different party must abort on authorization, not capacity.
    roles::add_role(&mut p, &other_cap, roles::custom(std::string::utf8(vector[((65 + 4u64) as u8)])));
    abort
}
