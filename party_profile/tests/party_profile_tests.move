// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_profile::party_profile_tests;

use country_code::country_code as cc;
use language_code::language_code as lc;
use miso_party::party;
use party_profile::party_profile as profile;
use std::unit_test::{assert_eq, destroy};

fun new_party(ctx: &mut TxContext): (party::Party, party::PartyAdminCap) {
    party::new(party::new_individual_kind(), b"Test Artist".to_string(), ctx)
}

#[test]
fun set_and_read_full_profile() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);

    assert!(!profile::has_profile(&p));
    profile::set_profile(
        &mut p,
        &cap,
        b"Short bio.".to_string(),
        option::some(b"A much longer biography.".to_string()),
        option::some(cc::new(b"JP".to_string())),
        vector[lc::new(b"en".to_string()), lc::new(b"ja".to_string())],
    );

    assert!(profile::has_profile(&p));
    let card = profile::profile(&p);
    assert_eq!(card.bio_short(), b"Short bio.".to_string());
    assert_eq!(card.bio_long(), option::some(b"A much longer biography.".to_string()));
    assert_eq!(card.country().destroy_some().code(), b"JP".to_string());
    assert_eq!(card.languages().length(), 2);

    destroy(p);
    destroy(cap);
}

#[test]
fun minimal_profile_and_field_setters() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);

    // Only the required short bio; everything else empty/none.
    profile::set_profile(&mut p, &cap, b"first".to_string(), option::none(), option::none(), vector[]);
    assert_eq!(profile::profile(&p).bio_long(), option::none());

    profile::set_bio_short(&mut p, &cap, b"second".to_string());
    profile::set_bio_long(&mut p, &cap, option::some(b"long".to_string()));
    profile::set_country(&mut p, &cap, option::some(cc::new(b"DE".to_string())));
    profile::set_languages(&mut p, &cap, vector[lc::new(b"de".to_string())]);

    let card = profile::profile(&p);
    assert_eq!(card.bio_short(), b"second".to_string());
    assert_eq!(card.bio_long(), option::some(b"long".to_string()));
    assert_eq!(card.country().destroy_some().code(), b"DE".to_string());
    assert_eq!(card.languages().length(), 1);

    destroy(p);
    destroy(cap);
}

#[test]
fun clear_profile_removes_it() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    profile::set_profile(&mut p, &cap, b"bio".to_string(), option::none(), option::none(), vector[]);
    profile::clear_profile(&mut p, &cap);
    assert!(!profile::has_profile(&p));
    profile::clear_profile(&mut p, &cap); // no-op
    destroy(p);
    destroy(cap);
}

#[test, expected_failure(abort_code = 0, location = party_profile::party_profile)] // EEmptyBioShort
fun rejects_empty_bio_short() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    profile::set_profile(&mut p, &cap, b"".to_string(), option::none(), option::none(), vector[]);
    abort
}

#[test, expected_failure(abort_code = 4, location = party_profile::party_profile)] // ETooManyLanguages
fun rejects_too_many_languages() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    let langs = vector[
        lc::new(b"en".to_string()), lc::new(b"ja".to_string()), lc::new(b"de".to_string()),
        lc::new(b"fr".to_string()), lc::new(b"es".to_string()), lc::new(b"it".to_string()),
        lc::new(b"pt".to_string()), lc::new(b"ru".to_string()), lc::new(b"zh".to_string()),
        lc::new(b"ko".to_string()), lc::new(b"ar".to_string()),
    ];
    profile::set_profile(&mut p, &cap, b"bio".to_string(), option::none(), option::none(), langs);
    abort
}

#[test, expected_failure(abort_code = 5, location = party_profile::party_profile)] // ENoProfile
fun set_field_without_profile_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    profile::set_bio_short(&mut p, &cap, b"x".to_string());
    abort
}
