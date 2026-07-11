// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_roles::party_roles_tests;

use miso_party::party;
use party_roles::party_roles as roles;
use std::unit_test::{assert_eq, destroy};

fun new_party(ctx: &mut TxContext): (party::Party, party::PartyAdminCap) {
    party::new(party::new_individual_kind(), b"Test Artist".to_string(), ctx)
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

#[test, expected_failure(abort_code = 2, location = party_roles::party_roles)] // EDuplicateRole
fun rejects_duplicate() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    roles::add_role(&mut p, &cap, roles::artist());
    roles::add_role(&mut p, &cap, roles::artist());
    abort
}

#[test, expected_failure(abort_code = 3, location = party_roles::party_roles)] // ERoleNotPresent
fun remove_absent_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    roles::add_role(&mut p, &cap, roles::artist());
    roles::remove_role(&mut p, &cap, roles::dj()); // not held
    abort
}

#[test, expected_failure(abort_code = 4, location = party_roles::party_roles)] // EMaxRolesExceeded
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
