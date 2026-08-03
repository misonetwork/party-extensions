// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A party's editable profile card — the free-form identity fields a profile
/// page renders.
///
/// Stored as a single `Profile` dynamic field on the party's UID, gated by the
/// `PartyAdminCap`; views are permissionless. Deliberately holds only cohesive
/// identity fields — typed or collection-shaped concerns (roles, tags, genres,
/// media, links) each live in their own extension. `country` and `languages` use
/// validated code primitives (`country_code`, `language_code`), so a stored value
/// is always a real code. The party's `name` is NOT duplicated here — it lives on
/// the core `Party` (`party::set_name`) — and the join date comes from the party's
/// creation event (the indexer has it for free).
module party_profile::party_profile;

use country_code::country_code::CountryCode;
use language_code::language_code::LanguageCode;
use miso_party::party::{Party, PartyAdminCap};
use std::string::String;
use sui::dynamic_field as df;
use sui::event::emit;
use sui::vec_set;

// === Errors ===

/// Short bio must not be empty.
const EEmptyBioShort: u64 = 0;
/// Short bio exceeds the maximum length.
const EBioShortTooLong: u64 = 1;
/// Long bio must not be empty when provided.
const EEmptyBioLong: u64 = 2;
/// Long bio exceeds the maximum length.
const EBioLongTooLong: u64 = 3;
/// Too many language tags.
const ETooManyLanguages: u64 = 4;
/// No profile is set on this party.
const ENoProfile: u64 = 5;
/// A language tag appears more than once.
const EDuplicateLanguage: u64 = 6;

// === Constants ===

/// Maximum length of the short bio in bytes.
const MAX_BIO_SHORT_LENGTH: u64 = 300;
/// Maximum length of the long bio in bytes.
const MAX_BIO_LONG_LENGTH: u64 = 5000;
/// Maximum number of language tags.
const MAX_LANGUAGES: u64 = 10;

// === Keys ===

/// Dynamic-field key for a party's profile.
public struct ProfileKey() has copy, drop, store;

// === Types ===

/// A party's profile card. Held as a dynamic-field value, not a standalone
/// object.
public struct Profile has store, drop {
    bio_short: String,
    bio_long: Option<String>,
    country: Option<CountryCode>,
    languages: vector<LanguageCode>,
}

// === Events ===

/// Emitted when a party's profile is set or updated.
public struct ProfileSetEvent has copy, drop {
    party_id: ID,
}

/// Emitted when a party's profile is cleared.
public struct ProfileClearedEvent has copy, drop {
    party_id: ID,
}

// === Write API ===

/// Sets (creates or replaces) the party's whole profile. The single write
/// entry point: a profile is a cohesive card, edited as a whole and saved in
/// one call.
public fun set_profile(
    self: &mut Party,
    cap: &PartyAdminCap,
    bio_short: String,
    bio_long: Option<String>,
    country: Option<CountryCode>,
    languages: vector<LanguageCode>,
) {
    validate_bio_short(&bio_short);
    validate_optional(&bio_long, MAX_BIO_LONG_LENGTH, EEmptyBioLong, EBioLongTooLong);
    validate_languages(&languages);

    let party_id = self.id();
    let profile = Profile { bio_short, bio_long, country, languages };
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ProfileKey())) {
        *df::borrow_mut(uid, ProfileKey()) = profile;
    } else {
        df::add(uid, ProfileKey(), profile);
    };
    emit(ProfileSetEvent { party_id });
}

/// Removes the party's profile. No-op if none is set.
public fun clear_profile(self: &mut Party, cap: &PartyAdminCap) {
    let party_id = self.id();
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ProfileKey())) {
        let Profile { .. } = df::remove(uid, ProfileKey());
        emit(ProfileClearedEvent { party_id });
    }
}

// === Views ===

/// Whether the party has a profile.
public fun has_profile(self: &Party): bool {
    df::exists(self.uid(), ProfileKey())
}

/// Borrows the party's profile. Aborts if none is set.
public fun profile(self: &Party): &Profile {
    assert!(df::exists(self.uid(), ProfileKey()), ENoProfile);
    df::borrow(self.uid(), ProfileKey())
}

public fun bio_short(self: &Profile): String { self.bio_short }
public fun bio_long(self: &Profile): Option<String> { self.bio_long }
public fun country(self: &Profile): Option<CountryCode> { self.country }
public fun languages(self: &Profile): vector<LanguageCode> { self.languages }

// === Private ===

fun validate_bio_short(bio_short: &String) {
    assert!(!bio_short.is_empty(), EEmptyBioShort);
    assert!(bio_short.length() <= MAX_BIO_SHORT_LENGTH, EBioShortTooLong);
}

fun validate_optional(opt: &Option<String>, max: u64, empty_err: u64, long_err: u64) {
    if (opt.is_some()) {
        let s = opt.borrow();
        assert!(!s.is_empty(), empty_err);
        assert!(s.length() <= max, long_err);
    }
}

// Each `LanguageCode` is already a valid ISO 639-1 code by construction, so
// only the count and duplicates are checked here.
fun validate_languages(languages: &vector<LanguageCode>) {
    assert!(languages.length() <= MAX_LANGUAGES, ETooManyLanguages);
    let mut seen = vec_set::empty<LanguageCode>();
    languages.do_ref!(|l| {
        assert!(!seen.contains(l), EDuplicateLanguage);
        seen.insert(*l);
    });
}
