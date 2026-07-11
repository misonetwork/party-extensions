// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Social-platform payloads for the `platform_link` primitive. Each network gets
/// its own `…Data` type — a thin wrapper around the account's handle — so a party
/// can carry one independent `PlatformLink<…Data>` per network (they never
/// collide, and adding a network is a new type here, nothing elsewhere).
///
/// Only the native handle is stored; the public profile URL is rebuilt
/// client-side (e.g. `x.com/{handle}`, `discord.gg/{handle}`), so a platform
/// reshaping its URLs needs no on-chain change. Validation is intentionally
/// minimal — non-empty only — because handle format rules change over time and
/// belong in the app layer.
module party_social::party_social;

use platform_link::platform_link::{Self, PlatformLink};
use std::string::String;

public use fun x_handle as XData.handle;
public use fun instagram_handle as InstagramData.handle;
public use fun threads_handle as ThreadsData.handle;
public use fun tiktok_handle as TikTokData.handle;
public use fun youtube_handle as YouTubeData.handle;
public use fun discord_handle as DiscordData.handle;
public use fun telegram_handle as TelegramData.handle;
public use fun reddit_handle as RedditData.handle;
public use fun twitch_handle as TwitchData.handle;
public use fun facebook_handle as FacebookData.handle;

// === Errors ===

/// The handle was empty.
const EEmptyHandle: u64 = 0;

// === Types ===

/// An X (formerly Twitter) handle, without the leading `@`.
public struct XData has copy, drop, store { handle: String }
/// An Instagram handle.
public struct InstagramData has copy, drop, store { handle: String }
/// A Threads handle, without the leading `@`.
public struct ThreadsData has copy, drop, store { handle: String }
/// A TikTok handle, without the leading `@`.
public struct TikTokData has copy, drop, store { handle: String }
/// A YouTube handle or channel identifier.
public struct YouTubeData has copy, drop, store { handle: String }
/// A Discord server-invite code (the `{code}` in `discord.gg/{code}`).
public struct DiscordData has copy, drop, store { handle: String }
/// A Telegram username or channel (the `{name}` in `t.me/{name}`).
public struct TelegramData has copy, drop, store { handle: String }
/// A Reddit username (the `{name}` in `reddit.com/user/{name}`).
public struct RedditData has copy, drop, store { handle: String }
/// A Twitch channel name.
public struct TwitchData has copy, drop, store { handle: String }
/// A Facebook page username or id.
public struct FacebookData has copy, drop, store { handle: String }

// === Constructors ===

/// Builds an X link from a handle. Aborts if empty.
public fun x(handle: String): PlatformLink<XData> {
    assert!(!handle.is_empty(), EEmptyHandle);
    platform_link::new(XData { handle })
}

/// Builds an Instagram link from a handle. Aborts if empty.
public fun instagram(handle: String): PlatformLink<InstagramData> {
    assert!(!handle.is_empty(), EEmptyHandle);
    platform_link::new(InstagramData { handle })
}

/// Builds a Threads link from a handle. Aborts if empty.
public fun threads(handle: String): PlatformLink<ThreadsData> {
    assert!(!handle.is_empty(), EEmptyHandle);
    platform_link::new(ThreadsData { handle })
}

/// Builds a TikTok link from a handle. Aborts if empty.
public fun tiktok(handle: String): PlatformLink<TikTokData> {
    assert!(!handle.is_empty(), EEmptyHandle);
    platform_link::new(TikTokData { handle })
}

/// Builds a YouTube link from a handle or channel identifier. Aborts if empty.
public fun youtube(handle: String): PlatformLink<YouTubeData> {
    assert!(!handle.is_empty(), EEmptyHandle);
    platform_link::new(YouTubeData { handle })
}

/// Builds a Discord link from a server-invite code. Aborts if empty.
public fun discord(handle: String): PlatformLink<DiscordData> {
    assert!(!handle.is_empty(), EEmptyHandle);
    platform_link::new(DiscordData { handle })
}

/// Builds a Telegram link from a username or channel. Aborts if empty.
public fun telegram(handle: String): PlatformLink<TelegramData> {
    assert!(!handle.is_empty(), EEmptyHandle);
    platform_link::new(TelegramData { handle })
}

/// Builds a Reddit link from a username. Aborts if empty.
public fun reddit(handle: String): PlatformLink<RedditData> {
    assert!(!handle.is_empty(), EEmptyHandle);
    platform_link::new(RedditData { handle })
}

/// Builds a Twitch link from a channel name. Aborts if empty.
public fun twitch(handle: String): PlatformLink<TwitchData> {
    assert!(!handle.is_empty(), EEmptyHandle);
    platform_link::new(TwitchData { handle })
}

/// Builds a Facebook link from a page username or id. Aborts if empty.
public fun facebook(handle: String): PlatformLink<FacebookData> {
    assert!(!handle.is_empty(), EEmptyHandle);
    platform_link::new(FacebookData { handle })
}

// === Accessors ===

public fun x_handle(self: &XData): String { self.handle }
public fun instagram_handle(self: &InstagramData): String { self.handle }
public fun threads_handle(self: &ThreadsData): String { self.handle }
public fun tiktok_handle(self: &TikTokData): String { self.handle }
public fun youtube_handle(self: &YouTubeData): String { self.handle }
public fun discord_handle(self: &DiscordData): String { self.handle }
public fun telegram_handle(self: &TelegramData): String { self.handle }
public fun reddit_handle(self: &RedditData): String { self.handle }
public fun twitch_handle(self: &TwitchData): String { self.handle }
public fun facebook_handle(self: &FacebookData): String { self.handle }
