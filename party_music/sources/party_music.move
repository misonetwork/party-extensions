// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Music-platform payloads for the `platform_link` primitive — a party's links to
/// its own artist/profile pages on streaming and music sites.
///
/// These are *artist-level* identifiers (an artist's Spotify id, a Bandcamp
/// subdomain), distinct from the release-level (album/track) payloads the
/// protocol's DSP-link extension uses. Only the native id is stored; the public
/// URL is rebuilt client-side, so a platform reshaping its URLs needs no on-chain
/// change. Validation is intentionally minimal — non-empty only.
module party_music::party_music;

use platform_link::platform_link::{Self, PlatformLink};
use std::string::String;

public use fun spotify_artist_id as SpotifyData.artist_id;
public use fun bandcamp_subdomain as BandcampData.subdomain;
public use fun soundcloud_username as SoundCloudData.username;
public use fun apple_music_artist_id as AppleMusicData.artist_id;
public use fun deezer_artist_id as DeezerData.artist_id;
public use fun tidal_artist_id as TidalData.artist_id;
public use fun amazon_music_artist_id as AmazonMusicData.artist_id;
public use fun audiomack_username as AudiomackData.username;

// === Errors ===

/// The identifier was empty.
const EEmptyId: u64 = 0;
/// The id exceeded the maximum length.
const EIdTooLong: u64 = 1;

// === Constants ===

/// Maximum id/username length in bytes. A generous storage backstop, not format
/// validation — real platform ids are far shorter.
const MAX_ID_LENGTH: u64 = 256;

// === Types ===

/// A Spotify artist id (the id in `open.spotify.com/artist/{id}`).
public struct SpotifyData has copy, drop, store { artist_id: String }
/// A Bandcamp subdomain (the `{name}` in `{name}.bandcamp.com`).
public struct BandcampData has copy, drop, store { subdomain: String }
/// A SoundCloud username (the `{name}` in `soundcloud.com/{name}`).
public struct SoundCloudData has copy, drop, store { username: String }
/// An Apple Music artist id (the numeric id in `music.apple.com/artist/{id}`).
public struct AppleMusicData has copy, drop, store { artist_id: String }
/// A Deezer artist id (the id in `deezer.com/artist/{id}`).
public struct DeezerData has copy, drop, store { artist_id: String }
/// A Tidal artist id (the id in `tidal.com/artist/{id}`).
public struct TidalData has copy, drop, store { artist_id: String }
/// An Amazon Music artist id (the id in `music.amazon.com/artists/{id}`).
public struct AmazonMusicData has copy, drop, store { artist_id: String }
/// An Audiomack username (the `{name}` in `audiomack.com/{name}`).
public struct AudiomackData has copy, drop, store { username: String }

// === Constructors ===

/// Builds a Spotify artist link. Aborts if empty.
public fun spotify(artist_id: String): PlatformLink<SpotifyData> {
    assert!(!artist_id.is_empty(), EEmptyId);
    assert!(artist_id.length() <= MAX_ID_LENGTH, EIdTooLong);
    platform_link::new(SpotifyData { artist_id })
}

/// Builds a Bandcamp link from an artist subdomain. Aborts if empty.
public fun bandcamp(subdomain: String): PlatformLink<BandcampData> {
    assert!(!subdomain.is_empty(), EEmptyId);
    assert!(subdomain.length() <= MAX_ID_LENGTH, EIdTooLong);
    platform_link::new(BandcampData { subdomain })
}

/// Builds a SoundCloud link from a username. Aborts if empty.
public fun soundcloud(username: String): PlatformLink<SoundCloudData> {
    assert!(!username.is_empty(), EEmptyId);
    assert!(username.length() <= MAX_ID_LENGTH, EIdTooLong);
    platform_link::new(SoundCloudData { username })
}

/// Builds an Apple Music artist link. Aborts if empty.
public fun apple_music(artist_id: String): PlatformLink<AppleMusicData> {
    assert!(!artist_id.is_empty(), EEmptyId);
    assert!(artist_id.length() <= MAX_ID_LENGTH, EIdTooLong);
    platform_link::new(AppleMusicData { artist_id })
}

/// Builds a Deezer artist link. Aborts if empty.
public fun deezer(artist_id: String): PlatformLink<DeezerData> {
    assert!(!artist_id.is_empty(), EEmptyId);
    assert!(artist_id.length() <= MAX_ID_LENGTH, EIdTooLong);
    platform_link::new(DeezerData { artist_id })
}

/// Builds a Tidal artist link. Aborts if empty.
public fun tidal(artist_id: String): PlatformLink<TidalData> {
    assert!(!artist_id.is_empty(), EEmptyId);
    assert!(artist_id.length() <= MAX_ID_LENGTH, EIdTooLong);
    platform_link::new(TidalData { artist_id })
}

/// Builds an Amazon Music artist link. Aborts if empty.
public fun amazon_music(artist_id: String): PlatformLink<AmazonMusicData> {
    assert!(!artist_id.is_empty(), EEmptyId);
    assert!(artist_id.length() <= MAX_ID_LENGTH, EIdTooLong);
    platform_link::new(AmazonMusicData { artist_id })
}

/// Builds an Audiomack link from a username. Aborts if empty.
public fun audiomack(username: String): PlatformLink<AudiomackData> {
    assert!(!username.is_empty(), EEmptyId);
    assert!(username.length() <= MAX_ID_LENGTH, EIdTooLong);
    platform_link::new(AudiomackData { username })
}

// === Accessors ===

public fun spotify_artist_id(self: &SpotifyData): String { self.artist_id }
public fun bandcamp_subdomain(self: &BandcampData): String { self.subdomain }
public fun soundcloud_username(self: &SoundCloudData): String { self.username }
public fun apple_music_artist_id(self: &AppleMusicData): String { self.artist_id }
public fun deezer_artist_id(self: &DeezerData): String { self.artist_id }
public fun tidal_artist_id(self: &TidalData): String { self.artist_id }
public fun amazon_music_artist_id(self: &AmazonMusicData): String { self.artist_id }
public fun audiomack_username(self: &AudiomackData): String { self.username }
