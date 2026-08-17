// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_profile::party_profile_tests;

use country_code::country_code as cc;
use language_code::language_code as lc;
use miso_party::party;
use party_profile::party_profile as profile;
use std::unit_test::{assert_eq, destroy};

// Mirrors `party::EUnauthorized` (party.move) for the wrong-cap abort test.
const EUnauthorized: u64 = 0;

/// A string of `len` 'A' bytes, for exercising the length bounds.
fun long_string(len: u64): std::string::String {
    let mut s = vector<u8>[];
    len.do!(|_| s.push_back(65));
    s.to_string()
}

fun new_party(ctx: &mut TxContext): (party::Party, party::PartyAdminCap) {
    {
        let clock = sui::clock::create_for_testing(ctx);
        let (p, cap) = party::new(party::new_individual_kind(), b"Test Artist".to_string(), &clock, ctx);
        clock.destroy_for_testing();
        (p, cap)
    }
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
fun replace_profile_in_place() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);

    // Only the required short bio; everything else empty/none.
    profile::set_profile(&mut p, &cap, b"first".to_string(), option::none(), option::none(), vector[]);
    assert_eq!(profile::profile(&p).bio_long(), option::none());

    // The whole card is re-set in one call; the field is replaced, not stacked.
    profile::set_profile(
        &mut p,
        &cap,
        b"second".to_string(),
        option::some(b"long".to_string()),
        option::some(cc::new(b"DE".to_string())),
        vector[lc::new(b"de".to_string())],
    );

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

/// The bound is inclusive, and it is on bytes rather than characters — 8 KB of
/// bio is stored intact.
#[test]
fun bio_long_at_max_length_is_accepted() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);

    let bio = long_string(8192);
    profile::set_profile(&mut p, &cap, b"bio".to_string(), option::some(bio), option::none(), vector[]);
    assert_eq!(profile::profile(&p).bio_long().destroy_some().as_bytes().length(), 8192);

    destroy(p);
    destroy(cap);
}

#[test, expected_failure(abort_code = profile::EBioLongTooLong)]
fun rejects_bio_long_over_max_length() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    // 8193 bytes — one past the bound.
    let bio = long_string(8193);
    profile::set_profile(&mut p, &cap, b"bio".to_string(), option::some(bio), option::none(), vector[]);
    abort
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

#[test, expected_failure(abort_code = 6, location = party_profile::party_profile)] // EDuplicateLanguage
fun rejects_duplicate_languages() {
    let ctx = &mut tx_context::dummy();
    let (mut p, cap) = new_party(ctx);
    let langs = vector[lc::new(b"en".to_string()), lc::new(b"ja".to_string()), lc::new(b"en".to_string())];
    profile::set_profile(&mut p, &cap, b"bio".to_string(), option::none(), option::none(), langs);
    abort
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso_party::party)]
fun set_profile_with_wrong_cap_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut p, _cap) = new_party(ctx);
    let (_other, other_cap) = new_party(ctx);

    // A cap for a different party must not authorize writes to `p`.
    profile::set_profile(&mut p, &other_cap, b"bio".to_string(), option::none(), option::none(), vector[]);
    abort
}
