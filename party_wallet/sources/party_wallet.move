// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// The door on a party's inbox.
///
/// A `Party` is a `key` object, so its object id doubles as an address and anyone
/// may send to it — no setup, no registration, and value can arrive before anyone
/// thinks to prepare for it. That is the point: a work's shares, its stake, or its
/// revenue can be addressed to an *artist identity* rather than to a wallet, so the
/// entitlement survives the holder rotating keys or losing an address.
///
/// Sending is permissionless; taking back out is not. Both withdrawal primitives
/// need `&mut UID`, and a party only yields one through `party::uid_mut`, which
/// authorizes the `PartyAdminCap` against that exact party. This module is the only
/// thing standing between those two facts — without it, everything sent to a Miso
/// party is stuck in an inbox with no door.
///
/// Value reaches a party's address by two distinct routes, and both are covered:
///
/// - **Transfer-to-object** — a whole object is sent to the party's id and is taken
///   out with a `Receiving` ticket. This carries `Coin`s, but also any `key + store`
///   object: a `Stake<Share>` handed over at publish, a `Blob`, a cap.
/// - **Accumulator** — funds credited directly to the party's address balance, with
///   no object to receive. These are withdrawn by value, not by ticket.
///
/// Every function returns what it withdraws rather than transferring it onward, so a
/// caller can receive shares and stake them, or redeem revenue and pay it out, inside
/// one transaction.
module party_wallet::party_wallet;

use hikida::hikida;
use miso_party::party::{Party, PartyAdminCap};
use sui::accumulator::AccumulatorRoot;
use sui::balance::Balance;
use sui::coin::Coin;
use sui::event::emit;
use sui::transfer::Receiving;

// Method syntax within this module only: `Party` is defined elsewhere, so the alias
// cannot be `public` and does not carry to callers.
use fun inbox_address as Party.inbox_address;

// === Errors ===

/// No objects were passed to a batch receive. Receiving nothing is always a caller
/// mistake, and failing loudly beats returning an empty vector that reads as success.
///
/// This module validates the *shape* of its own calls; accumulator semantics — a
/// zero withdrawal, a withdrawal the balance cannot cover — stay `hikida`'s to
/// enforce, so the two never disagree about the same condition.
const ENothingToReceive: u64 = 0;

// === Events ===

/// Emitted once per object taken out of a party's inbox.
public struct ObjectReceivedEvent has copy, drop {
    party_id: ID,
    object_id: ID,
}

/// Emitted when coins are received from a party's inbox, carrying the merged total
/// rather than one event per coin — the total is what an indexer wants.
public struct CoinsReceivedEvent<phantom Currency> has copy, drop {
    party_id: ID,
    amount: u64,
    coins: u64,
}

/// Emitted when funds are withdrawn from a party's accumulator balance.
public struct FundsRedeemedEvent<phantom Currency> has copy, drop {
    party_id: ID,
    amount: u64,
}

// === Transfer-to-object ===

/// Receives a single object addressed to the party and returns it.
///
/// This is the general door: anything `key + store` fits, including a
/// `royalty_pool::stake::Stake<Share>` transferred to the party at publish time.
/// The `store` bound is load-bearing — `public_receive` refuses types whose module
/// withheld it, so this cannot be used to escape another package's transfer rules.
public fun receive<T: key + store>(
    self: &mut Party,
    cap: &PartyAdminCap,
    object_to_receive: Receiving<T>,
): T {
    let party_id = self.id();
    take(self.uid_mut(cap), party_id, object_to_receive)
}

/// Receives several objects of the same type in one call, in the order given.
public fun receive_multiple<T: key + store>(
    self: &mut Party,
    cap: &PartyAdminCap,
    objects_to_receive: vector<Receiving<T>>,
): vector<T> {
    assert!(!objects_to_receive.is_empty(), ENothingToReceive);
    let party_id = self.id();
    let uid = self.uid_mut(cap);
    objects_to_receive.map!(|object_to_receive| take(uid, party_id, object_to_receive))
}

/// Receives coins of one currency from the inbox, merged into a single `Balance`.
///
/// Payments accumulate as separate coin objects — ten buyers means ten coins — so
/// merging on the way out is almost always what the caller wants. Returning a
/// `Balance` suits callers feeding a pool or accumulator without a detour through
/// `Coin`; use `receive_coin` when a `Coin` is what you need.
public fun receive_balance<Currency>(
    self: &mut Party,
    cap: &PartyAdminCap,
    coins: vector<Receiving<Coin<Currency>>>,
): Balance<Currency> {
    assert!(!coins.is_empty(), ENothingToReceive);
    let party_id = self.id();
    let count = coins.length();
    let balance = hikida::receive_balance(self.uid_mut(cap), coins);
    emit(CoinsReceivedEvent<Currency> { party_id, amount: balance.value(), coins: count });
    balance
}

/// Receives coins of one currency from the inbox, merged into a single `Coin`.
public fun receive_coin<Currency>(
    self: &mut Party,
    cap: &PartyAdminCap,
    coins: vector<Receiving<Coin<Currency>>>,
    ctx: &mut TxContext,
): Coin<Currency> {
    assert!(!coins.is_empty(), ENothingToReceive);
    let party_id = self.id();
    let count = coins.length();
    let coin = hikida::receive_coin(self.uid_mut(cap), coins, ctx);
    emit(CoinsReceivedEvent<Currency> { party_id, amount: coin.value(), coins: count });
    coin
}

// === Accumulator ===

/// Withdraws `value` from the party's accumulator balance, as a `Balance`.
///
/// Distinct from the receive path: accumulator funds are credited straight to the
/// party's address with no object to receive, so they are taken by amount rather
/// than by ticket. Aborts inside `hikida` if the balance cannot cover `value`.
public fun redeem_balance<Currency>(
    self: &mut Party,
    cap: &PartyAdminCap,
    value: u64,
): Balance<Currency> {
    let party_id = self.id();
    let balance = hikida::redeem_balance<Currency>(self.uid_mut(cap), value);
    emit(FundsRedeemedEvent<Currency> { party_id, amount: balance.value() });
    balance
}

/// Withdraws `value` from the party's accumulator balance, as a `Coin`.
public fun redeem_coin<Currency>(
    self: &mut Party,
    cap: &PartyAdminCap,
    value: u64,
    ctx: &mut TxContext,
): Coin<Currency> {
    let party_id = self.id();
    let coin = hikida::redeem_coin<Currency>(self.uid_mut(cap), value, ctx);
    emit(FundsRedeemedEvent<Currency> { party_id, amount: coin.value() });
    coin
}

// === Views ===

/// The address to send to. A party's object id doubles as its address, and this is
/// the value a manifest records as a share or revenue recipient — naming it keeps
/// callers from open-coding the conversion and wondering whether it is the right one.
public fun inbox_address(self: &Party): address {
    self.id().to_address()
}

/// The party's accumulator balance in `Currency`, as settled at the start of the
/// current consensus commit.
///
/// The companion to `redeem_*`: those take an amount, and this is how a caller knows
/// what amount is available. Being commit-settled, it excludes funds credited earlier
/// in the same transaction — read it to decide, not to audit.
///
/// Only the zero case is unit-testable: the test VM stubs the accumulator natives and
/// records nothing for a funded read to find. Confirm the funded reading on-chain.
public fun settled_funds<Currency>(root: &AccumulatorRoot, self: &Party): u64 {
    sui::balance::settled_funds_value<Currency>(root, self.inbox_address())
}

// === Internal ===

/// Receives one object and announces it. Shared so the single and batch paths cannot
/// drift in what they emit.
fun take<T: key + store>(uid: &mut UID, party_id: ID, object_to_receive: Receiving<T>): T {
    let received = transfer::public_receive(uid, object_to_receive);
    emit(ObjectReceivedEvent { party_id, object_id: object::id(&received) });
    received
}

// === Test Only ===

#[test_only]
public fun object_received_event_fields(e: &ObjectReceivedEvent): (ID, ID) {
    (e.party_id, e.object_id)
}

#[test_only]
public fun coins_received_event_fields<Currency>(e: &CoinsReceivedEvent<Currency>): (ID, u64, u64) {
    (e.party_id, e.amount, e.coins)
}

#[test_only]
public fun funds_redeemed_event_fields<Currency>(e: &FundsRedeemedEvent<Currency>): (ID, u64) {
    (e.party_id, e.amount)
}
