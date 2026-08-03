// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_music::party_music_tests;

use party_music::party_music as music;
use std::unit_test::assert_eq;

#[test]
fun added_platform_constructors() {
    assert_eq!(music::deezer(b"1".to_string()).data().artist_id(), b"1".to_string());
    assert_eq!(music::tidal(b"2".to_string()).data().artist_id(), b"2".to_string());
    assert_eq!(music::amazon_music(b"3".to_string()).data().artist_id(), b"3".to_string());
    assert_eq!(music::audiomack(b"miso".to_string()).data().username(), b"miso".to_string());
}

#[test]
fun constructors_wrap_ids() {
    assert_eq!(music::spotify(b"1abc".to_string()).data().artist_id(), b"1abc".to_string());
    assert_eq!(music::bandcamp(b"miso".to_string()).data().subdomain(), b"miso".to_string());
    assert_eq!(music::soundcloud(b"miso".to_string()).data().username(), b"miso".to_string());
    assert_eq!(music::apple_music(b"12345".to_string()).data().artist_id(), b"12345".to_string());
}

#[test, expected_failure(abort_code = 0, location = party_music::party_music)] // EEmptyId
fun rejects_empty_spotify_id() {
    let _ = music::spotify(b"".to_string());
    abort
}

#[test, expected_failure(abort_code = 0, location = party_music::party_music)] // EEmptyId
fun rejects_empty_bandcamp_subdomain() {
    let _ = music::bandcamp(b"".to_string());
    abort
}

#[test, expected_failure(abort_code = 1, location = party_music::party_music)] // EIdTooLong
fun rejects_overlong_id() {
    // 257 bytes — one over the shared backstop (platform_link::max_identifier_length(), 256).
    let long = vector::tabulate!(257, |_| 97u8).to_string();
    let _ = music::spotify(long);
    abort
}
