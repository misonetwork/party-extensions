# Release Audit — `party_pro_link`

**Repository:** `https://github.com/misonetwork/party-extensions`
**Audit target:** pending working-tree source based on `6bd663033267b7c2fddb7ed8b9ce85f980121e2f`
**Date:** 2026-09-02
**Toolchain:** `sui 1.78.1-722ac4fcf484`

## Verdict

Release-ready. No security or correctness findings remain.

## Implementation reviewed

`party_pro_link` is a pure payload package, not a state-attaching extension. It
defines six URL payloads and three handle/subdomain payloads. Shared private
validators enforce nonempty values, URL length at most 2000 bytes, and handle
length at most 256 bytes. The package has no Party, cap, storage, event, or
automation logic; `party_platform_link` attaches its returned values.

## Exact manifest pins

| Dependency | Repository/subdirectory | Revision |
|---|---|---|
| `platform_link` | `https://github.com/misonetwork/party-extensions.git` / `lib/platform_link` | `684eaef752271865f1cbb1aafb819e5bba3c1d6c` |

The manifest has no local-path or floating dependencies.

## Verification

- Package tests: **6/6**, including **4** expected-failure paths covering
  empty URL, empty handle, overlength URL, and overlength handle.
- All nine constructors and their nine accessors execute successfully, including
  `management_page` and `publisher_page`.
- Production instruction coverage: **100.00%**.
- Shared-Party workflow: not applicable; this package is pure payload code.
- Repository aggregate: **77/77 tests on Testnet and 77/77 on Mainnet**, strict
  lint with warnings as errors; all 11 production modules are at **100.00%**.

## Published metadata

The retained `Published.toml` records prior immutable Testnet package
`0x0be57adad52ba72d9697526fb5d9330ebd3e44868f869836fc981b8df23e8519`.
Its bytecode predates the pending validator refactor even though public behavior
and ABI are preserved. Fresh immutable publication uses the admin CLI with
`--allow-republish`; only after confirmed success may it replace the target
network block.
