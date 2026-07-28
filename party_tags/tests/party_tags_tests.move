// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_tags::party_tags_tests;

use miso_party::party;
use party_tags::party_tags as tags;
use std::unit_test::{assert_eq, destroy};

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

    tags::clear_tags(&mut p, &cap);
    assert!(!tags::has_tags(&p));

    destroy(p);
    destroy(cap);
}

#[test, expected_failure(abort_code = 0, location = party_tags::party_tags)] // EEmptyTag
fun rejects_empty() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    tags::add_tag(&mut p, &cap, b"".to_string());
    abort
}

#[test, expected_failure(abort_code = 2, location = party_tags::party_tags)] // EDuplicateTag
fun rejects_duplicate() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    tags::add_tag(&mut p, &cap, b"ambient".to_string());
    tags::add_tag(&mut p, &cap, b"ambient".to_string());
    abort
}

#[test, expected_failure(abort_code = 4, location = party_tags::party_tags)] // EMaxTagsExceeded
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
