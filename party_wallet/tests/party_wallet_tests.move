// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module party_wallet::party_wallet_tests;

use miso_party::party::{Self, Party, PartyAdminCap};
use party_wallet::party_wallet as wallet;
use std::unit_test::{assert_eq, destroy};
use sui::accumulator::AccumulatorRoot;
use sui::balance;
use sui::coin::{Self, Coin};
use sui::event;
use sui::sui::SUI;
use sui::test_scenario as ts;

const OPERATOR: address = @0xA;
/// `accumulator::create_for_testing` asserts the sender is the system address.
const SYSTEM: address = @0x0;

// Mirrors `party::EUnauthorized` (party.move:182) — a cap for a different party must
// never open this party's inbox.
const EUnauthorized: u64 = 0;
// Mirrors `hikida::ENoValueToRedeem` — accumulator semantics stay hikida's to enforce.
const ENoValueToRedeem: u64 = 1;

/// A second currency, to prove receiving one leaves the others alone.
public struct OTHER has drop {}

/// Stands in for `royalty_pool::stake::Stake<Share>`, which is `key + store`
/// (stake.move:24). Depending on royalty_pool here would drag in miso + hikida and a
/// full pool setup to prove a property that lives entirely in the type bound.
public struct StakeLike has key, store {
    id: UID,
    amount: u64,
}

// === Fixtures ===

fun new_party(scenario: &mut ts::Scenario, group: bool): ID {
    let ctx = scenario.ctx();
    let clock = sui::clock::create_for_testing(ctx);
    let kind = if (group) party::new_group_kind() else party::new_individual_kind();
    let (p, cap) = party::new(kind, b"Test Artist".to_string(), &clock, ctx);
    clock.destroy_for_testing();
    let party_id = object::id(&p);
    p.share(&cap);
    transfer::public_transfer(cap, OPERATOR);
    party_id
}

fun new_shared_party(scenario: &mut ts::Scenario): ID { new_party(scenario, false) }

/// A second party whose cap must not authorize against the first. Returned rather
/// than shared so the negative tests can wield the cap directly.
fun new_impostor(scenario: &mut ts::Scenario): (Party, PartyAdminCap) {
    let clock = sui::clock::create_for_testing(scenario.ctx());
    let (p, cap) = party::new(
        party::new_individual_kind(),
        b"Impostor".to_string(),
        &clock,
        scenario.ctx(),
    );
    clock.destroy_for_testing();
    (p, cap)
}

/// Mints and sends to `party_id` *as an address* — the transfer-to-object path a
/// payer uses knowing only the party's id.
fun send_coin<T>(scenario: &mut ts::Scenario, party_id: ID, amount: u64): ID {
    let c = coin::mint_for_testing<T>(amount, scenario.ctx());
    let coin_id = object::id(&c);
    transfer::public_transfer(c, party_id.to_address());
    coin_id
}

/// Credits the party's accumulator balance — the other funding route, with no
/// object to receive.
fun credit_accumulator<T>(party_id: ID, amount: u64) {
    balance::send_funds(balance::create_for_testing<T>(amount), party_id.to_address());
}

fun ticket<T: key + store>(id: ID): sui::transfer::Receiving<T> {
    ts::receiving_ticket_by_id<T>(id)
}

// === receive ===

#[test]
fun receive_returns_the_object_sent_to_the_party() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    let coin_id = send_coin<SUI>(&mut scenario, party_id, 500);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let c = wallet::receive(&mut p, &cap, ticket<Coin<SUI>>(coin_id));

        assert_eq!(c.value(), 500);
        assert_eq!(object::id(&c), coin_id);

        c.burn_for_testing();
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };
    scenario.end();
}

/// The case the publish flow actually needs: a non-`Coin` `key + store` object — a
/// stake — handed to a party and taken back out through the same generic door.
#[test]
fun receive_takes_a_stake_shaped_object_out() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    let stake = StakeLike { id: object::new(scenario.ctx()), amount: 5_000_000_000_000 };
    let stake_id = object::id(&stake);
    transfer::public_transfer(stake, party_id.to_address());

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let got = wallet::receive(&mut p, &cap, ticket<StakeLike>(stake_id));

        assert_eq!(object::id(&got), stake_id);
        assert_eq!(got.amount, 5_000_000_000_000);

        destroy(got);
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };
    scenario.end();
}

/// A band is a group party, and bands get paid — nothing here may be individual-only.
#[test]
fun receive_works_for_a_group_party() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_party(&mut scenario, true);

    scenario.next_tx(OPERATOR);
    let coin_id = send_coin<SUI>(&mut scenario, party_id, 77);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let c = wallet::receive(&mut p, &cap, ticket<Coin<SUI>>(coin_id));
        assert_eq!(c.value(), 77);
        c.burn_for_testing();
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };
    scenario.end();
}

#[test]
fun receive_emits_object_received_event() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    let coin_id = send_coin<SUI>(&mut scenario, party_id, 10);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let c = wallet::receive(&mut p, &cap, ticket<Coin<SUI>>(coin_id));

        let events = event::events_by_type<wallet::ObjectReceivedEvent>();
        assert_eq!(events.length(), 1);
        let (emitted_party, emitted_object) = wallet::object_received_event_fields(&events[0]);
        assert_eq!(emitted_party, party_id);
        assert_eq!(emitted_object, coin_id);

        c.burn_for_testing();
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };
    scenario.end();
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso_party::party)]
fun receive_rejects_another_partys_cap() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    let (other, other_cap) = new_impostor(&mut scenario);
    let coin_id = send_coin<SUI>(&mut scenario, party_id, 42);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let c = wallet::receive(&mut p, &other_cap, ticket<Coin<SUI>>(coin_id));
        c.burn_for_testing();
        ts::return_shared(p);
    };

    destroy(other);
    destroy(other_cap);
    scenario.end();
}

// === receive_multiple ===

#[test]
fun receive_multiple_returns_them_in_order() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    let a = send_coin<SUI>(&mut scenario, party_id, 11);
    let b = send_coin<SUI>(&mut scenario, party_id, 22);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let mut got = wallet::receive_multiple<Coin<SUI>>(
            &mut p,
            &cap,
            vector[ticket<Coin<SUI>>(a), ticket<Coin<SUI>>(b)],
        );

        assert_eq!(got.length(), 2);
        let second = got.pop_back();
        let first = got.pop_back();
        assert_eq!(first.value(), 11);
        assert_eq!(second.value(), 22);
        got.destroy_empty();

        // One event per object, not one per call.
        assert_eq!(event::events_by_type<wallet::ObjectReceivedEvent>().length(), 2);

        first.burn_for_testing();
        second.burn_for_testing();
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };
    scenario.end();
}

#[test]
fun receive_multiple_accepts_a_single_object() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    let a = send_coin<SUI>(&mut scenario, party_id, 9);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let mut got = wallet::receive_multiple<Coin<SUI>>(
            &mut p,
            &cap,
            vector[ticket<Coin<SUI>>(a)],
        );
        assert_eq!(got.length(), 1);
        let only = got.pop_back();
        assert_eq!(only.value(), 9);
        got.destroy_empty();
        only.burn_for_testing();
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };
    scenario.end();
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso_party::party)]
fun receive_multiple_rejects_another_partys_cap() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    let (other, other_cap) = new_impostor(&mut scenario);
    let a = send_coin<SUI>(&mut scenario, party_id, 1);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let got = wallet::receive_multiple<Coin<SUI>>(
            &mut p,
            &other_cap,
            vector[ticket<Coin<SUI>>(a)],
        );
        destroy(got);
        ts::return_shared(p);
    };

    destroy(other);
    destroy(other_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = wallet::ENothingToReceive)]
fun receive_multiple_with_nothing_aborts() {
    let mut scenario = ts::begin(OPERATOR);
    new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let got = wallet::receive_multiple<Coin<SUI>>(&mut p, &cap, vector[]);
        destroy(got);
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };
    scenario.end();
}

// === receive_balance ===

#[test]
fun receive_balance_merges_without_a_coin_detour() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    let a = send_coin<SUI>(&mut scenario, party_id, 400);
    let b = send_coin<SUI>(&mut scenario, party_id, 600);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let bal = wallet::receive_balance<SUI>(
            &mut p,
            &cap,
            vector[ticket<Coin<SUI>>(a), ticket<Coin<SUI>>(b)],
        );

        assert_eq!(bal.value(), 1000);

        // The event reports the merged total and how many coins produced it.
        let events = event::events_by_type<wallet::CoinsReceivedEvent<SUI>>();
        assert_eq!(events.length(), 1);
        let (emitted_party, amount, count) = wallet::coins_received_event_fields(&events[0]);
        assert_eq!(emitted_party, party_id);
        assert_eq!(amount, 1000);
        assert_eq!(count, 2);

        destroy(bal);
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };
    scenario.end();
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso_party::party)]
fun receive_balance_rejects_another_partys_cap() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    let (other, other_cap) = new_impostor(&mut scenario);
    let a = send_coin<SUI>(&mut scenario, party_id, 5);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let bal = wallet::receive_balance<SUI>(&mut p, &other_cap, vector[ticket<Coin<SUI>>(a)]);
        destroy(bal);
        ts::return_shared(p);
    };

    destroy(other);
    destroy(other_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = wallet::ENothingToReceive)]
fun receive_balance_with_nothing_aborts() {
    let mut scenario = ts::begin(OPERATOR);
    new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let bal = wallet::receive_balance<SUI>(&mut p, &cap, vector[]);
        destroy(bal);
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };
    scenario.end();
}

// === receive_coin ===

#[test]
fun receive_coin_merges_every_payment_into_one() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    // Three separate payments, exactly as three buyers would leave them.
    scenario.next_tx(OPERATOR);
    let a = send_coin<SUI>(&mut scenario, party_id, 100);
    let b = send_coin<SUI>(&mut scenario, party_id, 250);
    let c = send_coin<SUI>(&mut scenario, party_id, 650);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let merged = wallet::receive_coin<SUI>(
            &mut p,
            &cap,
            vector[ticket<Coin<SUI>>(a), ticket<Coin<SUI>>(b), ticket<Coin<SUI>>(c)],
            scenario.ctx(),
        );

        assert_eq!(merged.value(), 1000);

        merged.burn_for_testing();
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };
    scenario.end();
}

/// Each share currency is its own type. Receiving one must not disturb the rest — a
/// party holding twenty share currencies depends on it.
#[test]
fun receive_coin_leaves_other_currencies_untouched() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    let sui_coin = send_coin<SUI>(&mut scenario, party_id, 100);
    let other_coin = send_coin<OTHER>(&mut scenario, party_id, 999);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let got = wallet::receive_coin<SUI>(
            &mut p,
            &cap,
            vector[ticket<Coin<SUI>>(sui_coin)],
            scenario.ctx(),
        );
        assert_eq!(got.value(), 100);
        got.burn_for_testing();
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };

    // The OTHER coin is still there afterwards, untouched.
    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let got = wallet::receive_coin<OTHER>(
            &mut p,
            &cap,
            vector[ticket<Coin<OTHER>>(other_coin)],
            scenario.ctx(),
        );
        assert_eq!(got.value(), 999);
        got.burn_for_testing();
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };
    scenario.end();
}

#[test]
fun receive_coin_handles_a_zero_value_payment() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    let a = send_coin<SUI>(&mut scenario, party_id, 0);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let got = wallet::receive_coin<SUI>(
            &mut p,
            &cap,
            vector[ticket<Coin<SUI>>(a)],
            scenario.ctx(),
        );
        assert_eq!(got.value(), 0);
        got.burn_for_testing();
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };
    scenario.end();
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso_party::party)]
fun receive_coin_rejects_another_partys_cap() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    let (other, other_cap) = new_impostor(&mut scenario);
    let a = send_coin<SUI>(&mut scenario, party_id, 5);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let got = wallet::receive_coin<SUI>(
            &mut p,
            &other_cap,
            vector[ticket<Coin<SUI>>(a)],
            scenario.ctx(),
        );
        got.burn_for_testing();
        ts::return_shared(p);
    };

    destroy(other);
    destroy(other_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = wallet::ENothingToReceive)]
fun receive_coin_with_nothing_aborts() {
    let mut scenario = ts::begin(OPERATOR);
    new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let got = wallet::receive_coin<SUI>(&mut p, &cap, vector[], scenario.ctx());
        got.burn_for_testing();
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };
    scenario.end();
}

// === redeem ===
//
// IMPORTANT — what these tests do and do not prove.
//
// The Move unit-test VM stubs the accumulator natives: it tracks no balances. A party
// that was never credited can "withdraw" any amount and succeed, and
// `settled_funds_value` reads 0 no matter what `send_funds` was given. Verified
// directly rather than assumed.
//
// So everything below proves *this module's* wiring — the cap gate, the generic
// parameters, the event, the value flowing back to the caller — and proves nothing
// about accumulator accounting. Insufficient-balance and balance-decrement behaviour
// belong to the framework and can only be confirmed in a real transaction. First use
// on testnet is the check that matters; a green suite here is not it.

#[test]
fun redeem_balance_withdraws_accumulator_funds() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    credit_accumulator<SUI>(party_id, 1000);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let bal = wallet::redeem_balance<SUI>(&mut p, &cap, 400);
        assert_eq!(bal.value(), 400);

        let events = event::events_by_type<wallet::FundsRedeemedEvent<SUI>>();
        assert_eq!(events.length(), 1);
        let (emitted_party, amount) = wallet::funds_redeemed_event_fields(&events[0]);
        assert_eq!(emitted_party, party_id);
        assert_eq!(amount, 400);

        destroy(bal);
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };
    scenario.end();
}

/// Repeated withdrawals across transactions each return their requested amount. Note
/// this does NOT prove the balance decrements — see the section header.
#[test]
fun redeem_balance_twice_across_transactions() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    credit_accumulator<SUI>(party_id, 1000);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let first = wallet::redeem_balance<SUI>(&mut p, &cap, 600);
        assert_eq!(first.value(), 600);
        destroy(first);
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let rest = wallet::redeem_balance<SUI>(&mut p, &cap, 400);
        assert_eq!(rest.value(), 400);
        destroy(rest);
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };
    scenario.end();
}

#[test]
fun redeem_coin_withdraws_accumulator_funds() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    credit_accumulator<SUI>(party_id, 750);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let c = wallet::redeem_coin<SUI>(&mut p, &cap, 750, scenario.ctx());
        assert_eq!(c.value(), 750);
        c.burn_for_testing();
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };
    scenario.end();
}

/// The accumulator is gated by the `enable_object_funds_withdraw` protocol flag, but
/// the gate this module adds is its own: `uid_mut` authorizes before hikida is ever
/// reached, so a foreign cap fails on redeem exactly as it does on receive.
#[test, expected_failure(abort_code = EUnauthorized, location = miso_party::party)]
fun redeem_balance_rejects_another_partys_cap() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    let (other, other_cap) = new_impostor(&mut scenario);
    credit_accumulator<SUI>(party_id, 100);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let bal = wallet::redeem_balance<SUI>(&mut p, &other_cap, 1);
        destroy(bal);
        ts::return_shared(p);
    };

    destroy(other);
    destroy(other_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso_party::party)]
fun redeem_coin_rejects_another_partys_cap() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    let (other, other_cap) = new_impostor(&mut scenario);
    credit_accumulator<SUI>(party_id, 100);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let c = wallet::redeem_coin<SUI>(&mut p, &other_cap, 1, scenario.ctx());
        c.burn_for_testing();
        ts::return_shared(p);
    };

    destroy(other);
    destroy(other_cap);
    scenario.end();
}

/// A zero withdrawal is accumulator semantics, so hikida owns the rejection — this
/// pins that boundary so it cannot silently migrate into this module.
#[test, expected_failure(abort_code = ENoValueToRedeem, location = hikida::hikida)]
fun redeem_zero_aborts_in_hikida() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    credit_accumulator<SUI>(party_id, 100);

    scenario.next_tx(OPERATOR);
    {
        let mut p = scenario.take_shared<Party>();
        let cap = scenario.take_from_sender<PartyAdminCap>();
        let bal = wallet::redeem_balance<SUI>(&mut p, &cap, 0);
        destroy(bal);
        scenario.return_to_sender(cap);
        ts::return_shared(p);
    };
    scenario.end();
}

// Deliberately absent: an over-withdrawal test. `withdraw_from_object` does not check
// the amount (its own comment says so), deferring to the native at redemption — and
// the test VM's native does not check either. Asserting the current pass-through would
// pin a VM artifact that must not become a guarantee. This is a testnet check.

// === Views ===

#[test]
fun inbox_address_is_the_party_id_as_an_address() {
    let mut scenario = ts::begin(OPERATOR);
    let party_id = new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    {
        let p = scenario.take_shared<Party>();
        assert_eq!(wallet::inbox_address(&p), party_id.to_address());
        ts::return_shared(p);
    };
    scenario.end();
}

/// An unfunded party reads zero — true both here and on-chain, so it is a real
/// invariant rather than a VM artifact. The *funded* reading cannot be exercised: the
/// test VM's `send_funds` writes no accumulator state for `settled_funds_value` to
/// find. That path is testnet-only.
#[test]
fun settled_funds_is_zero_for_an_unfunded_party() {
    let mut scenario = ts::begin(SYSTEM);
    sui::accumulator::create_for_testing(scenario.ctx());

    scenario.next_tx(OPERATOR);
    new_shared_party(&mut scenario);

    scenario.next_tx(OPERATOR);
    {
        let p = scenario.take_shared<Party>();
        let root = scenario.take_shared<AccumulatorRoot>();
        assert_eq!(wallet::settled_funds<SUI>(&root, &p), 0);
        ts::return_shared(root);
        ts::return_shared(p);
    };
    scenario.end();
}
