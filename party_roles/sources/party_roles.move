// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Artist-type roles for a party — what kind of act this is (artist, producer,
/// DJ, band, label, …). A party can hold several.
///
/// `ArtistRole` is a closed enum with a `Custom` escape hatch, mirroring
/// `composition_party_role`: canonical variants give the frontend a fixed,
/// typo-free set to render icons for, while `Custom(name)` covers anything else.
/// The set mechanics — storage, duplicate and capacity checks, field
/// reclamation — live in the shared `typed_set` primitive; this package keeps
/// the role type, name validation, the capacity, and the typed events.
/// Duplicate / not-present / over-max aborts come from `typed_set` with its own
/// error codes. Gated by the `PartyAdminCap`; views are permissionless.
module party_roles::party_roles;

use miso_party::party::{Party, PartyAdminCap};
use std::string::String;
use sui::event::emit;
use typed_set::typed_set as set;

public use fun role_name as ArtistRole.name;

// === Errors ===

/// A custom role name must not be empty.
const EEmptyCustomName: u64 = 0;
/// A custom role name exceeds the maximum length.
const ECustomNameTooLong: u64 = 1;

// === Constants ===

/// Maximum length of a custom role name in bytes.
const MAX_CUSTOM_NAME_LENGTH: u64 = 60;
/// Maximum number of roles a party may hold.
const MAX_ROLES: u64 = 12;

// === Keys ===

/// Dynamic-field key for a party's role set, stored as a `VecSet<ArtistRole>`
/// and managed through `typed_set`.
public struct RolesKey() has copy, drop, store;

// === Types ===

/// The kind of act a party represents. Closed enum + `Custom` escape hatch.
public enum ArtistRole has copy, drop, store {
    Artist,
    Producer,
    Dj,
    Composer,
    Songwriter,
    Band,
    Label,
    Collective,
    /// A user-defined role not covered by a canonical variant (validated).
    /// Prefer a canonical variant when one fits.
    Custom(String),
}

// === Events ===

/// Emitted when a role is added to a party.
public struct RoleAddedEvent has copy, drop {
    party_id: ID,
    role: String,
}

/// Emitted when a role is removed from a party.
public struct RoleRemovedEvent has copy, drop {
    party_id: ID,
    role: String,
}

/// Emitted when a party's entire role set is removed.
public struct RolesClearedEvent has copy, drop {
    party_id: ID,
}

// === Role constructors ===

public fun artist(): ArtistRole { ArtistRole::Artist }
public fun producer(): ArtistRole { ArtistRole::Producer }
public fun dj(): ArtistRole { ArtistRole::Dj }
public fun composer(): ArtistRole { ArtistRole::Composer }
public fun songwriter(): ArtistRole { ArtistRole::Songwriter }
public fun band(): ArtistRole { ArtistRole::Band }
public fun label(): ArtistRole { ArtistRole::Label }
public fun collective(): ArtistRole { ArtistRole::Collective }

/// Builds a custom role. Aborts if empty or too long.
public fun custom(name: String): ArtistRole {
    assert!(!name.is_empty(), EEmptyCustomName);
    assert!(name.length() <= MAX_CUSTOM_NAME_LENGTH, ECustomNameTooLong);
    ArtistRole::Custom(name)
}

/// The canonical name of a role (its own string for `Custom`).
public fun role_name(self: &ArtistRole): String {
    match (self) {
        ArtistRole::Artist => b"Artist".to_string(),
        ArtistRole::Producer => b"Producer".to_string(),
        ArtistRole::Dj => b"DJ".to_string(),
        ArtistRole::Composer => b"Composer".to_string(),
        ArtistRole::Songwriter => b"Songwriter".to_string(),
        ArtistRole::Band => b"Band".to_string(),
        ArtistRole::Label => b"Label".to_string(),
        ArtistRole::Collective => b"Collective".to_string(),
        ArtistRole::Custom(name) => *name,
    }
}

// === Write API ===

/// Adds a role to the party. Aborts in `typed_set` if already held or the max
/// is reached.
public fun add_role(self: &mut Party, cap: &PartyAdminCap, role: ArtistRole) {
    let party_id = object::id(self);
    let name = role.name();
    set::add(self.uid_mut(cap), RolesKey(), role, MAX_ROLES);
    emit(RoleAddedEvent { party_id, role: name });
}

/// Removes a role from the party. Aborts in `typed_set` if not held. The whole
/// field is dropped when the last role leaves.
public fun remove_role(self: &mut Party, cap: &PartyAdminCap, role: ArtistRole) {
    let party_id = object::id(self);
    let name = role.name();
    set::remove(self.uid_mut(cap), RolesKey(), role);
    emit(RoleRemovedEvent { party_id, role: name });
}

/// Removes the party's entire role set. No-op if none is set.
public fun clear_roles(self: &mut Party, cap: &PartyAdminCap) {
    let party_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (set::exists(uid, RolesKey())) {
        set::clear<RolesKey, ArtistRole>(uid, RolesKey());
        emit(RolesClearedEvent { party_id });
    }
}

// === Views ===

/// Whether the party holds any roles.
public fun has_roles(self: &Party): bool {
    set::exists(self.uid(), RolesKey())
}

/// Whether the party holds the given role.
public fun has_role(self: &Party, role: ArtistRole): bool {
    set::contains(self.uid(), RolesKey(), &role)
}

/// The party's roles.
public fun roles(self: &Party): vector<ArtistRole> {
    set::keys(self.uid(), RolesKey())
}
