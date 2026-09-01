# Release Audit — `party_tags`

**Repository:** `https://github.com/misonetwork/party-extensions`
**Audit target:** pending working-tree source based on `6bd663033267b7c2fddb7ed8b9ce85f980121e2f`
**Date:** 2026-09-02
**Toolchain:** `sui 1.78.1-722ac4fcf484`

## Verdict

Release-ready. No security or correctness findings remain.

## Implementation reviewed

`party_tags` is a state-attaching extension. It stores up to 30 exact-match
free-form strings through `typed_set`, with each tag constrained to 1–50 bytes.
All mutations require the matching `PartyAdminCap`; final removal reclaims the
field, clear is idempotent, and views are permissionless. Normalization and
rendering safety remain client concerns.

## Exact manifest pins

| Dependency | Repository | Revision |
|---|---|---|
| `miso_party` | `https://github.com/misonetwork/party.git` | `ffb2915b9bb1802b4c160d3230c560e40bd2b063` |
| `typed_set` | `https://github.com/unconfirmedlabs/typed_set.git` | `b37474cbde166b7ddf8a3b615cd89f90182ace6f` |

The manifest has no local-path or floating dependencies.

## Verification

- Package tests: **9/9**, including **7** expected-failure paths covering both
  tag validators, duplicate, missing item, capacity, wrong cap, and
  authorization-before-capacity.
- Production instruction coverage: **100.00%**.
- End-to-end scenario covers Party share, cap transfer, later tag write, and
  permissionless read from the shared Party.
- Repository aggregate: **77/77 tests on Testnet and 77/77 on Mainnet**, strict
  lint with warnings as errors; all 11 production modules are at **100.00%**.

## Published metadata

The retained `Published.toml` records prior immutable Testnet package
`0x1807589b09b4048aca2b52fd7dbd19bd90c3a1b00b2e7af928346aae295721c9`.
It is prior-generation metadata wherever pending inputs differ. Fresh immutable
publication uses the admin CLI with `--allow-republish`; only after confirmed
success may it replace the target network block.
