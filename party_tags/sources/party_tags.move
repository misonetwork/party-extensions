// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Free-form tags for a party — moods, scenes, and descriptors (e.g. "ambient",
/// "deconstructed club", "leftfield pop").
///
/// The uncurated sibling to `party_genre`: genres reference a canonical, shared
/// vocabulary; tags are whatever the artist types. The set mechanics — storage,
/// duplicate and capacity checks, field reclamation — live in the shared
/// `typed_set` primitive; this package keeps only what is tag-specific: length
/// validation, the capacity, and the typed events. Duplicate / not-present /
/// over-max aborts come from `typed_set` with its own error codes. Tags are
/// stored as given (exact dedupe); normalization for search/display is a client
/// concern. Gated by the `PartyAdminCap`; views are permissionless.
module party_tags::party_tags;

use miso_party::party::{Party, PartyAdminCap};
use std::string::String;
use sui::event::emit;
use typed_set::typed_set as set;

// === Errors ===

/// A tag must not be empty.
const EEmptyTag: u64 = 0;
/// A tag exceeds the maximum length.
const ETagTooLong: u64 = 1;

// === Constants ===

/// Maximum length of a tag in bytes.
const MAX_TAG_LENGTH: u64 = 50;
/// Maximum number of tags a party may carry.
const MAX_TAGS: u64 = 30;

// === Keys ===

/// Dynamic-field key for a party's tag set, stored as a `VecSet<String>` and
/// managed through `typed_set`.
public struct TagsKey() has copy, drop, store;

// === Events ===

/// Emitted when a tag is added to a party.
public struct TagAddedEvent has copy, drop {
    party_id: ID,
    tag: String,
}

/// Emitted when a tag is removed from a party.
public struct TagRemovedEvent has copy, drop {
    party_id: ID,
    tag: String,
}

/// Emitted when a party's entire tag set is removed.
public struct TagsClearedEvent has copy, drop {
    party_id: ID,
}

// === Write API ===

/// Adds a tag to the party. Aborts if empty or too long here, and in
/// `typed_set` if already present or the max is reached.
public fun add_tag(self: &mut Party, cap: &PartyAdminCap, tag: String) {
    assert!(!tag.is_empty(), EEmptyTag);
    assert!(tag.length() <= MAX_TAG_LENGTH, ETagTooLong);
    let party_id = object::id(self);
    set::add(self.uid_mut(cap), TagsKey(), tag, MAX_TAGS);
    emit(TagAddedEvent { party_id, tag });
}

/// Removes a tag from the party. Aborts in `typed_set` if not present. The
/// whole field is dropped when the last tag leaves, so `has_tags` tracks
/// "carries tags", not "has ever tagged".
public fun remove_tag(self: &mut Party, cap: &PartyAdminCap, tag: String) {
    let party_id = object::id(self);
    set::remove(self.uid_mut(cap), TagsKey(), tag);
    emit(TagRemovedEvent { party_id, tag });
}

/// Removes the party's entire tag set. No-op if none is set.
public fun clear_tags(self: &mut Party, cap: &PartyAdminCap) {
    let party_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (set::exists(uid, TagsKey())) {
        set::clear<TagsKey, String>(uid, TagsKey());
        emit(TagsClearedEvent { party_id });
    }
}

// === Views ===

/// Whether the party carries any tags.
public fun has_tags(self: &Party): bool {
    set::exists(self.uid(), TagsKey())
}

/// Whether the party carries the given tag.
public fun has_tag(self: &Party, tag: String): bool {
    set::contains(self.uid(), TagsKey(), &tag)
}

/// The party's tags.
public fun tags(self: &Party): vector<String> {
    set::keys(self.uid(), TagsKey())
}
