# Security Audit — `party_wallet`

**Revision:** working tree (source snapshot — no `.git` in repo) ·
**Date:** 2026-08-23 · **Toolchain:** sui 1.77.2-51d177ad7d65

**Pinned dependencies** (`Move.toml`): `miso_party` `0127a150` ·
`hikida` `e88c6fa8` (independently audited clean; source re-read here).

Audit of `party_wallet.move` (216 LOC) — the only withdrawal door on a
`Party`'s inbox, and therefore a financial surface: everything ever sent to a
party's address exits through this module. Verdict: **safe to publish — no
Critical/High/Medium findings.**

## What it does

A `Party`'s object id doubles as its address, so anyone can send value to a
party (transfer-to-object or funds accumulator) with no setup. This module is
the door back out:

- `receive` / `receive_multiple` (`party_wallet.move:83-102`) — take any
  `key + store` object addressed to the party via `Receiving<T>` tickets
  (`transfer::public_receive`).
- `receive_balance` / `receive_coin` (`:110-136`) — merge received
  `Coin<Currency>`s into one `Balance`/`Coin` (via `hikida`).
- `redeem_balance` / `redeem_coin` (`:145-167`) — withdraw a `value` from the
  party's address-balance accumulator (via `hikida` →
  `withdraw_funds_from_object` → `redeem_funds`).
- Views: `inbox_address`, `settled_funds` (commit-settled accumulator read).

Every function returns what it withdraws — nothing is forwarded — so callers
compose (receive shares, stake them; redeem revenue, deposit it) inside one
PTB.

Threat model: anyone withdrawing from a party they don't administer; ticket
substitution (receiving objects addressed elsewhere); generic-type escape of
another package's transfer rules; amount/event mismatches.

## Why it's safe

- **Single authorization choke point.** All six withdrawal functions funnel
  through `self.uid_mut(cap)` (`:89, 100, 118, 133, 151, 164`), which runs
  `party::authorize` — cap's `party_id` compared against the object's ID
  (`party.move:501-503`). There is no ungated path, and the `&mut UID` never
  leaves the call: it is used in place and dropped.
- **Recipient binding is framework-enforced.** `take` calls
  `transfer::public_receive(uid, ticket)` (`party_wallet.move:196`); the
  framework aborts unless the `Receiving<T>` ticket's recipient is that UID's
  address — a ticket for an object sent to *another* party cannot be redeemed
  here. `hikida::receive_balance_impl` does the same per coin
  (`hikida.move:43-53`, source re-read at the pinned rev).
- **Accumulator withdrawals are UID-gated.** `hikida::redeem_balance_impl`
  asserts `value > 0` and calls
  `redeem_funds(withdraw_funds_from_object(parent, value))`
  (`hikida.move:55-58`) — only funds at the party's *own* address are
  touchable, and an overdraw aborts in the framework.
- **The `store` bound is load-bearing and correct.** `receive<T: key +
  store>` can only extract types whose defining module opted into public
  transfer (`:82-90`); it cannot liberate `key`-only objects (e.g. a
  `Party`, `Recording`, or `RoyaltyPool`) from wherever they live. It *can*
  receive a `Stake<Share>` (`key + store`), another party's `PartyAdminCap`,
  etc. — intended: the party admin is the rightful custodian of whatever was
  sent to the party.
- **No value-inflation surface.** Batch functions reject empty vectors
  (`ENothingToReceive`); events carry the merged total measured from the
  returned balance itself (`:119, 134, 152, 165`), so events cannot overstate
  what moved. No arithmetic anywhere else.

## Findings

- **F1 (Informational): the party admin can extract *anything* sent to the
  party — by design, and worth restating for integrators.** Whoever holds
  `PartyAdminCap` has permanent, unrestricted withdrawal power over the
  party's inbox and accumulator. A party is therefore only as safe as its cap
  custody; "send to the party identity" means "send to whoever administers
  the identity, now and after any cap transfer."
- **F2 (Informational): `settled_funds` is commit-settled** (`:178-189`):
  it excludes funds credited earlier in the same transaction. Correct as a
  decision input ("how much can I redeem now"), wrong as an audit read —
  documented on the function itself.

## Edge cases (verified)

- Empty batch aborts (`ENothingToReceive`, all four batch entry points).
- Zero-value redeem aborts in `hikida` (`ENoValueToRedeem`) — tested
  (`redeem_zero_aborts_in_hikida`).
- Overdraw of the accumulator aborts in the framework.
- Receiving a zero-value coin merges fine (no zero-balance leak: the merged
  `Balance` is returned to the caller, who owns the obligation).

## Verification

- **25/25 unit tests** (`sui move test`, sui 1.77.2): wrong-cap negatives,
  receive/merge/redeem paths, event payloads, zero-value aborts.
- `hikida` (`e88c6fa8`) re-read in full (58 LOC): three public wrappers over
  `public_receive`/`withdraw_funds_from_object` with non-empty/non-zero
  asserts — no logic beyond what its audit reported.

## Load-bearing assumptions

- Framework: `public_receive` recipient binding;
  `withdraw_funds_from_object` UID gating; accumulator commit-settlement
  semantics. Framework rev per sibling lockfiles: `b9149cbf`.
- `miso_party::party` cap↔object binding (`authorize`), audited in this set
  (`party/AUDIT.md`).
