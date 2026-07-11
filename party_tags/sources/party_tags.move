// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Free-form tags for a party — moods, scenes, and descriptors (e.g. "ambient",
/// "deconstructed club", "leftfield pop").
///
/// The uncurated sibling to `party_genre`: genres reference a canonical, shared
/// vocabulary; tags are whatever the artist types. Stored as a `VecSet<String>`
/// on the party, gated by the `PartyAdminCap`. Tags are stored as given (exact
/// dedupe); normalization for search/display is a client concern.
module party_tags::party_tags;

use miso_party::party::{Party, PartyAdminCap};
use std::string::String;
use sui::dynamic_field as df;
use sui::event::emit;
use sui::vec_set::{Self, VecSet};

// === Errors ===

/// A tag must not be empty.
const EEmptyTag: u64 = 0;
/// A tag exceeds the maximum length.
const ETagTooLong: u64 = 1;
/// The party already carries this tag.
const EDuplicateTag: u64 = 2;
/// The party does not carry this tag.
const ETagNotPresent: u64 = 3;
/// Adding this tag would exceed the maximum.
const EMaxTagsExceeded: u64 = 4;

// === Constants ===

/// Maximum length of a tag in bytes.
const MAX_TAG_LENGTH: u64 = 50;
/// Maximum number of tags a party may carry.
const MAX_TAGS: u64 = 30;

// === Keys ===

/// Dynamic-field key for a party's tag set.
public struct TagsKey() has copy, drop, store;

// === Types ===

/// The set of tags carried by a party.
public struct PartyTags has store {
    tags: VecSet<String>,
}

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

// === Write API ===

/// Adds a tag to the party. Aborts if empty, too long, already present, or the
/// max is reached.
public fun add_tag(self: &mut Party, cap: &PartyAdminCap, tag: String) {
    assert!(!tag.is_empty(), EEmptyTag);
    assert!(tag.length() <= MAX_TAG_LENGTH, ETagTooLong);
    let party_id = self.id();
    let tags = tags_mut_or_init(self, cap);
    assert!(!tags.contains(&tag), EDuplicateTag);
    assert!(tags.length() < MAX_TAGS, EMaxTagsExceeded);
    tags.insert(tag);
    emit(TagAddedEvent { party_id, tag });
}

/// Removes a tag from the party. Aborts if not present.
public fun remove_tag(self: &mut Party, cap: &PartyAdminCap, tag: String) {
    let party_id = self.id();
    let uid = self.uid_mut(cap);
    assert!(df::exists(uid, TagsKey()), ETagNotPresent);
    let tags = borrow_tags_mut(uid);
    assert!(tags.contains(&tag), ETagNotPresent);
    tags.remove(&tag);
    emit(TagRemovedEvent { party_id, tag });
}

/// Removes the party's entire tag set. No-op if none is set.
public fun clear_tags(self: &mut Party, cap: &PartyAdminCap) {
    let uid = self.uid_mut(cap);
    if (df::exists(uid, TagsKey())) {
        let PartyTags { .. } = df::remove(uid, TagsKey());
    }
}

// === Views ===

/// Whether the party has a tag set.
public fun has_tags(self: &Party): bool {
    df::exists(self.uid(), TagsKey())
}

/// Whether the party carries the given tag.
public fun has_tag(self: &Party, tag: String): bool {
    if (!df::exists(self.uid(), TagsKey())) return false;
    borrow_tags(self.uid()).contains(&tag)
}

/// The party's tags.
public fun tags(self: &Party): vector<String> {
    if (!df::exists(self.uid(), TagsKey())) return vector[];
    *borrow_tags(self.uid()).keys()
}

// === Private ===

fun borrow_tags(uid: &UID): &VecSet<String> {
    &df::borrow<TagsKey, PartyTags>(uid, TagsKey()).tags
}

fun borrow_tags_mut(uid: &mut UID): &mut VecSet<String> {
    &mut df::borrow_mut<TagsKey, PartyTags>(uid, TagsKey()).tags
}

fun tags_mut_or_init(self: &mut Party, cap: &PartyAdminCap): &mut VecSet<String> {
    let uid = self.uid_mut(cap);
    if (!df::exists(uid, TagsKey())) {
        df::add(uid, TagsKey(), PartyTags { tags: vec_set::empty() });
    };
    borrow_tags_mut(uid)
}
