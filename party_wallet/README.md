# party_wallet

The door on a party's inbox. A `Party` is a `key` object, so its object id
doubles as an address and anyone may send to it — shares, stake, or revenue
can be addressed to an *artist identity* rather than a wallet, surviving key
rotation. Sending is permissionless; taking back out is not: every withdrawal
is gated by the `PartyAdminCap` through `party::uid_mut(cap)`. This module is
the only thing standing between those two facts.

Two inbound routes, both covered: **transfer-to-object** (whole objects sent
to the party's id, taken out with a `Receiving` ticket) and the
**accumulator** (funds credited straight to the party's address balance,
withdrawn by amount). Every function returns what it withdrew rather than
transferring onward, so a caller can receive shares and stake them, or redeem
revenue and pay it out, inside one transaction.

## What it stores

Nothing. The wallet holds no dynamic-field state — value lives in the party's
inbox (objects addressed to it) and its accumulator balance, both native to
the chain.

## API

All writes require `&PartyAdminCap` for the exact party; a wrong cap aborts
with `EUnauthorized` at `miso_party::party`.

### Transfer-to-object

| Function | Description | Aborts |
|---|---|---|
| `receive<T: key + store>(party, cap, Receiving<T>)` | Receive one object addressed to the party, return it | wrong cap; `store` bound refuses types whose module withheld it |
| `receive_multiple<T: key + store>(party, cap, vector<Receiving<T>>)` | Receive several objects of one type, in order | `ENothingToReceive` (0) on an empty vector |
| `receive_balance<Currency>(party, cap, vector<Receiving<Coin<Currency>>>)` | Receive coins of one currency, merged into a single `Balance` | `ENothingToReceive` (0) on an empty vector |
| `receive_coin<Currency>(party, cap, vector<Receiving<Coin<Currency>>>, ctx)` | Same, merged into a single `Coin` | `ENothingToReceive` (0) on an empty vector |

### Accumulator

| Function | Description | Aborts |
|---|---|---|
| `redeem_balance<Currency>(party, cap, value)` | Withdraw `value` from the party's accumulator balance, as a `Balance` | wrong cap; accumulator semantics (zero withdrawal, insufficient balance) enforced inside `hikida` |
| `redeem_coin<Currency>(party, cap, value, ctx)` | Same, as a `Coin` | same |

### Views

| Function | Returns |
|---|---|
| `inbox_address(party)` | The address to send to — the party's object id as an address; what a manifest records as a share or revenue recipient |
| `settled_funds<Currency>(root, party)` | The party's accumulator balance in `Currency`, as settled at the start of the current consensus commit |

## Events

| Event | When | Payload |
|---|---|---|
| `ObjectReceivedEvent` | Each object taken out of the inbox (`receive`, `receive_multiple`) | `party_id`, `object_id` |
| `CoinsReceivedEvent<Currency>` | Coins received via `receive_balance` / `receive_coin` | `party_id`, `amount` (merged total), `coins` (count) |
| `FundsRedeemedEvent<Currency>` | Accumulator withdrawal via `redeem_balance` / `redeem_coin` | `party_id`, `amount` |

## Errors

| Code | Constant | Condition |
|---|---|---|
| 0 | `ENothingToReceive` | Batch receive called with an empty vector — receiving nothing is always a caller mistake |

Accumulator failures (zero withdrawal, balance cannot cover) abort inside
`hikida` with its codes, so the two never disagree about the same condition.

## Dependencies

- `miso_party` (local) — the `Party` / `PartyAdminCap` authorization core.
- `hikida` (git, pinned by SHA) — coin/balance receive-merge and accumulator
  withdrawal mechanics.

## Integrator notes

- **Composability is the point.** All withdraw functions return values, not
  transfers — compose them in one PTB (receive a `Stake<Share>`, stake it;
  redeem revenue, split it).
- **`settled_funds` is commit-settled**: it excludes funds credited earlier in
  the same transaction. Read it to decide, not to audit.
- **Junk is harmless.** Anyone can transfer objects to the party's address by
  design; the admin chooses what to receive, and unclaimed objects just sit.
- Indexers track inbox flows via the three events above; per-coin detail is
  intentionally collapsed into merged totals.
