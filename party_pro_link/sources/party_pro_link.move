// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Professional / industry payloads for the `platform_link` primitive: an
/// artist's own website, booking/management/publisher/label pages, EPK, and
/// creator-support platforms (Patreon, Substack, Ko-fi).
///
/// Two shapes here. A website / booking page / EPK has **no reconstructable
/// handle** — the URL *is* the identity — so those store a full `url`. The
/// creator platforms have a handle like the social/music payloads and store just
/// that, with the URL rebuilt client-side. All non-empty-validated only.
module party_pro_link::party_pro_link;

use platform_link::platform_link::{Self, PlatformLink};
use std::string::String;

public use fun website_url as WebsiteData.url;
public use fun booking_url as BookingPageData.url;
public use fun management_url as ManagementPageData.url;
public use fun publisher_url as PublisherPageData.url;
public use fun label_url as LabelPageData.url;
public use fun epk_url as EpkData.url;
public use fun patreon_handle as PatreonData.handle;
public use fun substack_subdomain as SubstackData.subdomain;
public use fun kofi_handle as KofiData.handle;

// === Errors ===

/// The value was empty.
const EEmptyValue: u64 = 0;
/// The url exceeded the maximum length.
const EUrlTooLong: u64 = 1;
/// The handle exceeded the maximum length.
const EHandleTooLong: u64 = 2;

// === Constants ===

/// Maximum url length in bytes (matches `party_cta`). A storage backstop.
const MAX_URL_LENGTH: u64 = 2000;
/// Maximum handle length in bytes. A generous storage backstop, not format
/// validation.
const MAX_HANDLE_LENGTH: u64 = 256;

// === Types (URL-based — the URL is the identity) ===

/// The artist's official website URL.
public struct WebsiteData has copy, drop, store { url: String }
/// A booking-agent page URL.
public struct BookingPageData has copy, drop, store { url: String }
/// A management-company page URL.
public struct ManagementPageData has copy, drop, store { url: String }
/// A publisher page URL.
public struct PublisherPageData has copy, drop, store { url: String }
/// A label page URL.
public struct LabelPageData has copy, drop, store { url: String }
/// An electronic press kit (EPK) URL.
public struct EpkData has copy, drop, store { url: String }

// === Types (handle-based — creator support) ===

/// A Patreon handle (the `{name}` in `patreon.com/{name}`).
public struct PatreonData has copy, drop, store { handle: String }
/// A Substack subdomain (the `{name}` in `{name}.substack.com`).
public struct SubstackData has copy, drop, store { subdomain: String }
/// A Ko-fi handle (the `{name}` in `ko-fi.com/{name}`).
public struct KofiData has copy, drop, store { handle: String }

// === Constructors (URL-based) ===

/// Builds a website link from a full URL. Aborts if empty.
public fun website(url: String): PlatformLink<WebsiteData> {
    assert!(!url.is_empty(), EEmptyValue);
    assert!(url.length() <= MAX_URL_LENGTH, EUrlTooLong);
    platform_link::new(WebsiteData { url })
}

/// Builds a booking-page link from a full URL. Aborts if empty.
public fun booking_page(url: String): PlatformLink<BookingPageData> {
    assert!(!url.is_empty(), EEmptyValue);
    assert!(url.length() <= MAX_URL_LENGTH, EUrlTooLong);
    platform_link::new(BookingPageData { url })
}

/// Builds a management-page link from a full URL. Aborts if empty.
public fun management_page(url: String): PlatformLink<ManagementPageData> {
    assert!(!url.is_empty(), EEmptyValue);
    assert!(url.length() <= MAX_URL_LENGTH, EUrlTooLong);
    platform_link::new(ManagementPageData { url })
}

/// Builds a publisher-page link from a full URL. Aborts if empty.
public fun publisher_page(url: String): PlatformLink<PublisherPageData> {
    assert!(!url.is_empty(), EEmptyValue);
    assert!(url.length() <= MAX_URL_LENGTH, EUrlTooLong);
    platform_link::new(PublisherPageData { url })
}

/// Builds a label-page link from a full URL. Aborts if empty.
public fun label_page(url: String): PlatformLink<LabelPageData> {
    assert!(!url.is_empty(), EEmptyValue);
    assert!(url.length() <= MAX_URL_LENGTH, EUrlTooLong);
    platform_link::new(LabelPageData { url })
}

/// Builds an EPK link from a full URL. Aborts if empty.
public fun epk(url: String): PlatformLink<EpkData> {
    assert!(!url.is_empty(), EEmptyValue);
    assert!(url.length() <= MAX_URL_LENGTH, EUrlTooLong);
    platform_link::new(EpkData { url })
}

// === Constructors (handle-based) ===

/// Builds a Patreon link from a handle. Aborts if empty.
public fun patreon(handle: String): PlatformLink<PatreonData> {
    assert!(!handle.is_empty(), EEmptyValue);
    assert!(handle.length() <= MAX_HANDLE_LENGTH, EHandleTooLong);
    platform_link::new(PatreonData { handle })
}

/// Builds a Substack link from a subdomain. Aborts if empty.
public fun substack(subdomain: String): PlatformLink<SubstackData> {
    assert!(!subdomain.is_empty(), EEmptyValue);
    assert!(subdomain.length() <= MAX_HANDLE_LENGTH, EHandleTooLong);
    platform_link::new(SubstackData { subdomain })
}

/// Builds a Ko-fi link from a handle. Aborts if empty.
public fun kofi(handle: String): PlatformLink<KofiData> {
    assert!(!handle.is_empty(), EEmptyValue);
    assert!(handle.length() <= MAX_HANDLE_LENGTH, EHandleTooLong);
    platform_link::new(KofiData { handle })
}

// === Accessors ===

public fun website_url(self: &WebsiteData): String { self.url }
public fun booking_url(self: &BookingPageData): String { self.url }
public fun management_url(self: &ManagementPageData): String { self.url }
public fun publisher_url(self: &PublisherPageData): String { self.url }
public fun label_url(self: &LabelPageData): String { self.url }
public fun epk_url(self: &EpkData): String { self.url }
public fun patreon_handle(self: &PatreonData): String { self.handle }
public fun substack_subdomain(self: &SubstackData): String { self.subdomain }
public fun kofi_handle(self: &KofiData): String { self.handle }
