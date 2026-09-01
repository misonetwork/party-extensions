# Release Audit — `party_genre`

**Repository:** `https://github.com/misonetwork/party-extensions`
**Audit target:** pending working-tree source based on `6bd663033267b7c2fddb7ed8b9ce85f980121e2f`
**Date:** 2026-09-02
**Toolchain:** `sui 1.78.1-722ac4fcf484`

## Verdict

Release-ready. No security or correctness findings remain.

## Implementation reviewed

`party_genre` is a state-attaching extension. It stores up to 20 canonical
`Genre` object IDs through `typed_set`. Adding requires `&Genre`, proving the
vocabulary object exists; removal is by ID. All mutations require the matching
`PartyAdminCap`, final removal reclaims the field, and clear is idempotent.

## Exact manifest pins

| Dependency | Repository | Revision |
|---|---|---|
| `miso_party` | `https://github.com/misonetwork/party.git` | `ffb2915b9bb1802b4c160d3230c560e40bd2b063` |
| `typed_set` | `https://github.com/unconfirmedlabs/typed_set.git` | `b37474cbde166b7ddf8a3b615cd89f90182ace6f` |
| `genre` | `https://github.com/misonetwork/genre.git` | `069fee03d7cae357d5a805e28eeb24171f10c303` |

The manifest has no local-path or floating dependencies.

## Verification

- Package tests: **7/7**, including **5** expected-failure paths for duplicate,
  missing item, capacity, wrong cap, and authorization-before-capacity.
- Production instruction coverage: **100.00%**.
- End-to-end scenario covers the shared genre registry, immutable Genre,
  shared Party, transferred admin cap, cap-gated write, and later public read.
- Repository aggregate: **77/77 tests on Testnet and 77/77 on Mainnet**, strict
  lint with warnings as errors; all 11 production modules are at **100.00%**.

## Published metadata

The retained `Published.toml` records prior immutable Testnet package
`0xeaa9f5d615c93dcb23201f3c68ab2d58338fec53fc9cc2342264b119b76c3139`.
It is prior-generation metadata wherever pending inputs differ. Fresh immutable
publication uses the admin CLI with `--allow-republish`; only after confirmed
success may it replace the target network block.
