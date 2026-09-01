# Release Audit — `party_cta`

**Repository:** `https://github.com/misonetwork/party-extensions`
**Audit target:** pending working-tree source based on `6bd663033267b7c2fddb7ed8b9ce85f980121e2f`
**Date:** 2026-09-02
**Toolchain:** `sui 1.78.1-722ac4fcf484`

## Verdict

Release-ready. No security or correctness findings remain.

## Implementation reviewed

`party_cta` is a state-attaching extension. It stores one ordered,
replace-whole `vector<Cta>` dynamic field on a Party. Labels are 1–60 bytes,
URLs are 1–2000 bytes, and the list is capped at 20. `set_ctas` and
`clear_ctas` require the matching `PartyAdminCap`; views are permissionless.
The module emits change events and contains no funds or automation entrypoints.

## Exact manifest pins

| Dependency | Repository | Revision |
|---|---|---|
| `miso_party` | `https://github.com/misonetwork/party.git` | `ffb2915b9bb1802b4c160d3230c560e40bd2b063` |

The manifest has no local-path or floating dependencies.

## Verification

- Package tests: **8/8**, including **6** expected-failure paths covering all
  four CTA validators, list capacity, and wrong-cap authorization.
- Production instruction coverage: **100.00%**.
- End-to-end scenario: Party creation and share, cap transfer, later cap-gated
  write to the shared Party, and permissionless read in another transaction.
- Repository aggregate: **77/77 tests on Testnet and 77/77 on Mainnet**, strict
  lint with warnings as errors; all 11 production modules are at **100.00%**.
- Fresh unpublished copies build strictly for both networks.

## Published metadata

The retained `Published.toml` records prior immutable Testnet package
`0xf385934b1291d262048712c09f6ed1745487f4795e2d87be9c7520a72c0fbde3`.
It predates pending source wherever inputs differ. Fresh immutable publication
uses the admin CLI with `--allow-republish`; only a confirmed successful
transaction may replace the target network block.
