// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_cta::party_cta_tests;

use miso_party::party;
use party_cta::party_cta as cta;
use std::unit_test::{assert_eq, destroy};

fun new_party(ctx: &mut TxContext): (party::Party, party::PartyAdminCap) {
    party::new(party::new_individual_kind(), b"Test Artist".to_string(), ctx)
}

#[test]
fun set_read_replace_clear() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);

    assert!(!cta::has_ctas(&p));
    assert!(cta::ctas(&p).is_empty());

    cta::set_ctas(&mut p, &cap, vector[
        cta::new_cta(b"Tickets".to_string(), b"https://dice.fm/artist".to_string()),
        cta::new_cta(b"Merch".to_string(), b"https://shop.example/artist".to_string()),
    ]);

    assert!(cta::has_ctas(&p));
    let list = cta::ctas(&p);
    assert_eq!(list.length(), 2);
    // Position is priority — order is preserved.
    assert_eq!(list[0].label(), b"Tickets".to_string());
    assert_eq!(list[0].url(), b"https://dice.fm/artist".to_string());
    assert_eq!(list[1].label(), b"Merch".to_string());

    // Replace the whole list.
    cta::set_ctas(&mut p, &cap, vector[
        cta::new_cta(b"Newsletter".to_string(), b"https://substack.com/artist".to_string()),
    ]);
    assert_eq!(cta::ctas(&p).length(), 1);
    assert_eq!(cta::ctas(&p)[0].label(), b"Newsletter".to_string());

    cta::clear_ctas(&mut p, &cap);
    assert!(!cta::has_ctas(&p));
    cta::clear_ctas(&mut p, &cap); // no-op

    destroy(p);
    destroy(cap);
}

#[test, expected_failure(abort_code = 0, location = party_cta::party_cta)] // EEmptyLabel
fun rejects_empty_label() {
    let _ = cta::new_cta(b"".to_string(), b"https://x.com".to_string());
    abort
}

#[test, expected_failure(abort_code = 2, location = party_cta::party_cta)] // EEmptyUrl
fun rejects_empty_url() {
    let _ = cta::new_cta(b"Listen".to_string(), b"".to_string());
    abort
}

#[test, expected_failure(abort_code = 4, location = party_cta::party_cta)] // ETooManyCtas
fun rejects_over_max() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    let mut list = vector[];
    21u64.do!(|_| list.push_back(cta::new_cta(b"L".to_string(), b"https://x.com".to_string())));
    cta::set_ctas(&mut p, &cap, list);
    abort
}
