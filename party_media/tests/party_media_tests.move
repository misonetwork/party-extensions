// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_media::party_media_tests;

use miso_party::party;
use ori::walrus_data;
use party_media::party_media as media;
use std::unit_test::{assert_eq, destroy};

fun new_party(ctx: &mut TxContext): (party::Party, party::PartyAdminCap) {
    party::new(party::new_individual_kind(), b"Test Artist".to_string(), ctx)
}

#[test]
fun set_read_and_clear() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);

    assert!(!media::has_media(&p));
    assert!(media::avatar(&p).is_none());

    media::set_avatar(&mut p, &cap, walrus_data::new_blob(0x1234u256));
    media::set_header(&mut p, &cap, walrus_data::new_blob(0x5678u256));

    assert!(media::has_media(&p));
    assert_eq!(media::avatar(&p).destroy_some().blob_id(), 0x1234u256);
    assert_eq!(media::header(&p).destroy_some().blob_id(), 0x5678u256);

    // Clearing avatar leaves header intact.
    media::clear_avatar(&mut p, &cap);
    assert!(media::avatar(&p).is_none());
    assert!(media::header(&p).is_some());

    media::clear_media(&mut p, &cap);
    assert!(!media::has_media(&p));
    media::clear_media(&mut p, &cap); // no-op

    destroy(p);
    destroy(cap);
}

#[test]
fun set_avatar_replaces() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    media::set_avatar(&mut p, &cap, walrus_data::new_blob(0x1u256));
    media::set_avatar(&mut p, &cap, walrus_data::new_blob(0x2u256));
    assert_eq!(media::avatar(&p).destroy_some().blob_id(), 0x2u256);
    destroy(p);
    destroy(cap);
}
