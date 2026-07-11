// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Artist-type roles for a party — what kind of act this is (artist, producer,
/// DJ, band, label, …). A party can hold several.
///
/// `ArtistRole` is a closed enum with a `Custom` escape hatch, mirroring
/// `composition_party_role`: canonical variants give the frontend a fixed,
/// typo-free set to render icons for, while `Custom(name)` covers anything else.
/// Roles are stored as a `VecSet<ArtistRole>` on the party, gated by the
/// `PartyAdminCap`; views are permissionless.
module party_roles::party_roles;

use miso_party::party::{Party, PartyAdminCap};
use std::string::String;
use sui::dynamic_field as df;
use sui::event::emit;
use sui::vec_set::{Self, VecSet};

public use fun role_name as ArtistRole.name;

// === Errors ===

/// A custom role name must not be empty.
const EEmptyCustomName: u64 = 0;
/// A custom role name exceeds the maximum length.
const ECustomNameTooLong: u64 = 1;
/// The party already holds this role.
const EDuplicateRole: u64 = 2;
/// The party does not hold this role.
const ERoleNotPresent: u64 = 3;
/// Adding this role would exceed the maximum.
const EMaxRolesExceeded: u64 = 4;

// === Constants ===

/// Maximum length of a custom role name in bytes.
const MAX_CUSTOM_NAME_LENGTH: u64 = 60;
/// Maximum number of roles a party may hold.
const MAX_ROLES: u64 = 12;

// === Keys ===

/// Dynamic-field key for a party's role set.
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

/// The set of roles held by a party.
public struct PartyRoles has store {
    roles: VecSet<ArtistRole>,
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

/// Adds a role to the party. Aborts if already held or the max is reached.
public fun add_role(self: &mut Party, cap: &PartyAdminCap, role: ArtistRole) {
    let party_id = self.id();
    let name = role.name();
    let roles = roles_mut_or_init(self, cap);
    assert!(!roles.contains(&role), EDuplicateRole);
    assert!(roles.length() < MAX_ROLES, EMaxRolesExceeded);
    roles.insert(role);
    emit(RoleAddedEvent { party_id, role: name });
}

/// Removes a role from the party. Aborts if not held.
public fun remove_role(self: &mut Party, cap: &PartyAdminCap, role: ArtistRole) {
    let party_id = self.id();
    let name = role.name();
    let uid = self.uid_mut(cap);
    assert!(df::exists(uid, RolesKey()), ERoleNotPresent);
    let roles = borrow_roles_mut(uid);
    assert!(roles.contains(&role), ERoleNotPresent);
    roles.remove(&role);
    emit(RoleRemovedEvent { party_id, role: name });
}

/// Removes the party's entire role set. No-op if none is set.
public fun clear_roles(self: &mut Party, cap: &PartyAdminCap) {
    let uid = self.uid_mut(cap);
    if (df::exists(uid, RolesKey())) {
        let PartyRoles { .. } = df::remove(uid, RolesKey());
    }
}

// === Views ===

/// Whether the party has a role set.
public fun has_roles(self: &Party): bool {
    df::exists(self.uid(), RolesKey())
}

/// Whether the party holds the given role.
public fun has_role(self: &Party, role: ArtistRole): bool {
    if (!df::exists(self.uid(), RolesKey())) return false;
    borrow_roles(self.uid()).contains(&role)
}

/// The party's roles.
public fun roles(self: &Party): vector<ArtistRole> {
    if (!df::exists(self.uid(), RolesKey())) return vector[];
    *borrow_roles(self.uid()).keys()
}

// === Private ===

fun borrow_roles(uid: &UID): &VecSet<ArtistRole> {
    &df::borrow<RolesKey, PartyRoles>(uid, RolesKey()).roles
}

fun borrow_roles_mut(uid: &mut UID): &mut VecSet<ArtistRole> {
    &mut df::borrow_mut<RolesKey, PartyRoles>(uid, RolesKey()).roles
}

fun roles_mut_or_init(self: &mut Party, cap: &PartyAdminCap): &mut VecSet<ArtistRole> {
    let uid = self.uid_mut(cap);
    if (!df::exists(uid, RolesKey())) {
        df::add(uid, RolesKey(), PartyRoles { roles: vec_set::empty() });
    };
    borrow_roles_mut(uid)
}
