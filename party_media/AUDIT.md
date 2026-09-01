# Release Audit — `party_media`

**Repository:** `https://github.com/misonetwork/party-extensions`
**Audit target:** pending working-tree source based on `6bd663033267b7c2fddb7ed8b9ce85f980121e2f`
**Date:** 2026-09-02
**Toolchain:** `sui 1.78.1-722ac4fcf484`

## Verdict

Release-ready. No security or correctness findings remain.

## Implementation reviewed

`party_media` is a state-attaching extension. It stores one nonzero Walrus
quilt ID (`u256`) as a Party dynamic field. Set/replace and idempotent clear
require the matching `PartyAdminCap`; reads are permissionless. Patch roles are
an off-chain convention, and no media bytes or funds are stored.

## Exact manifest pins

| Dependency | Repository | Revision |
|---|---|---|
| `miso_party` | `https://github.com/misonetwork/party.git` | `ffb2915b9bb1802b4c160d3230c560e40bd2b063` |

The manifest has no local-path or floating dependencies.

## Verification

- Package tests: **5/5**, including **2** expected-failure paths for zero ID
  and wrong-cap authorization.
- Production instruction coverage: **100.00%**.
- End-to-end scenario covers Party share, cap transfer, later cap-gated media
  write, and permissionless read from the shared Party.
- Repository aggregate: **77/77 tests on Testnet and 77/77 on Mainnet**, strict
  lint with warnings as errors; all 11 production modules are at **100.00%**.

## Published metadata

The retained `Published.toml` records prior immutable Testnet package
`0x149794c510c84fa40042a9d064efac710ba89fa9607fe6342dc7091120b8f6a7`.
It is prior-generation metadata wherever pending inputs differ. Fresh immutable
publication uses the admin CLI with `--allow-republish`; only after confirmed
success may it replace the target network block.
