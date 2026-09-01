# Release Audit — `platform_link`

**Repository:** `https://github.com/misonetwork/party-extensions`
**Audit target:** pending working-tree source based on `6bd663033267b7c2fddb7ed8b9ce85f980121e2f`
**Date:** 2026-09-02
**Toolchain:** `sui 1.78.1-722ac4fcf484`

## Verdict

Release-ready. No security or correctness findings remain.

## Implementation reviewed

`platform_link` is a protocol-agnostic primitive. It wraps a payload as
`PlatformLink<Data>` and stores at most one value per `Data` type under any
caller-supplied `UID`, using the phantom-typed `PlatformLinkKey<Data>`. It
implements set/replace, optional read, borrow, remove, and idempotent clear. It
contains no Party, capability, event, Vault, Action, plugin, or fund logic;
authorization belongs to its caller. Identifier and URL backstops are exactly
256 and 2000 bytes.

## Dependency provenance

The manifest has no explicit dependency. `Move.lock` resolves the Sui
framework for both Testnet and Mainnet at exact revision
`2a0becb2fcc6989e492981104af67f62f2c9511a`. There are no local-path, branch,
or floating Git dependencies.

## Verification

- Package tests: **5/5**, including **2** expected-failure paths (`borrow` and
  `remove` when absent).
- Production instruction coverage: **100.00%**.
- Shared-Party workflow: not applicable; this primitive accepts a `UID` and
  owns no host object.
- Repository aggregate: **77/77 tests on Testnet and 77/77 on Mainnet**, strict
  lint with warnings as errors; all 11 production modules are at **100.00%**.
- Fresh copies without `Published.toml` or `Move.lock` build strictly for both
  networks.

## Published metadata

The retained `Published.toml` records prior immutable Testnet package
`0x24f10661c815b9d6b8e6a94d7b1b38d53df848735863430d458af5d5481b27c5`.
It is historical deployment metadata and does not attest to pending source.
Fresh immutable publication uses the admin CLI with `--allow-republish`; only
after confirmed success may it replace the target network block.
