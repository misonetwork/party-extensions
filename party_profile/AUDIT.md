# Release Audit — `party_profile`

**Repository:** `https://github.com/misonetwork/party-extensions`
**Audit target:** pending working-tree source based on `6bd663033267b7c2fddb7ed8b9ce85f980121e2f`
**Date:** 2026-09-02
**Toolchain:** `sui 1.78.1-722ac4fcf484`

## Verdict

Release-ready. No security or correctness findings remain.

## Implementation reviewed

`party_profile` is a state-attaching extension. It stores one replace-whole
Profile dynamic field: required short bio (1–300 bytes), optional long bio
(1–8192 bytes), optional validated country code, and up to 10 distinct
validated language codes. Optional long-bio validation uses `Option::do_ref!`
with direct named numeric error constants; no caller-selected abort code remains.
Set and clear require the matching `PartyAdminCap`; views are permissionless.

## Exact manifest pins

| Dependency | Repository | Revision |
|---|---|---|
| `miso_party` | `https://github.com/misonetwork/party.git` | `ffb2915b9bb1802b4c160d3230c560e40bd2b063` |
| `country_code` | `https://github.com/unconfirmedlabs/country_code.git` | `b4c92cb7f772879335344d7b6499b5fa4eafef56` |
| `language_code` | `https://github.com/unconfirmedlabs/language_code.git` | `61542357f3d2ff989d120185046def7cf6c8bdcb` |

The manifest has no local-path or floating dependencies.

## Verification

- Package tests: **13/13**, including **8** expected-failure paths covering all
  seven local errors, long/short boundaries, duplicate/capacity language checks,
  and wrong-cap authorization.
- Production instruction coverage: **100.00%**.
- End-to-end scenario covers Party share, cap transfer, later profile write,
  and permissionless read from the shared Party.
- Strict fresh-copy builds without publication or lock metadata pass for both
  Testnet and Mainnet—the previous dynamic-abort-code failure is closed.
- Repository aggregate: **77/77 tests on Testnet and 77/77 on Mainnet**, strict
  lint with warnings as errors; all 11 production modules are at **100.00%**.

## Published metadata

The retained `Published.toml` records prior immutable Testnet package
`0xe01228bbcd4d9bcd4546ca47f50733efdd47c093eeab2a63b2c08092a455a48f`.
Its bytecode predates the pending validator correction. Fresh immutable
publication uses the admin CLI with `--allow-republish`; only after confirmed
success may it replace the target network block.
