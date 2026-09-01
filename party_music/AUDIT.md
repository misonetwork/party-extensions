# Release Audit — `party_music`

**Repository:** `https://github.com/misonetwork/party-extensions`
**Audit target:** pending working-tree source based on `6bd663033267b7c2fddb7ed8b9ce85f980121e2f`
**Date:** 2026-09-02
**Toolchain:** `sui 1.78.1-722ac4fcf484`

## Verdict

Release-ready. No security or correctness findings remain.

## Implementation reviewed

`party_music` is a pure payload package, not a state-attaching extension. It
defines eight artist-platform payload types and validated constructors for
Spotify, Bandcamp, SoundCloud, Apple Music, Deezer, Tidal, Amazon Music, and
Audiomack. A shared private validator enforces nonempty identifiers no longer
than 256 bytes. The package has no Party, cap, storage, event, or automation
logic; `party_platform_link` attaches returned values to Party state.

## Exact manifest pins

| Dependency | Repository/subdirectory | Revision |
|---|---|---|
| `platform_link` | `https://github.com/misonetwork/party-extensions.git` / `lib/platform_link` | `684eaef752271865f1cbb1aafb819e5bba3c1d6c` |

The manifest has no local-path or floating dependencies.

## Verification

- Package tests: **5/5**, including **3** expected-failure paths for empty
  Spotify, empty Bandcamp, and the shared overlength validator.
- All eight constructors and all eight accessors execute on success.
- Production instruction coverage: **100.00%**.
- Shared-Party workflow: not applicable; this package is pure payload code.
- Repository aggregate: **77/77 tests on Testnet and 77/77 on Mainnet**, strict
  lint with warnings as errors; all 11 production modules are at **100.00%**.

## Published metadata

The retained `Published.toml` records prior immutable Testnet package
`0x491706bec2d57bbd3e1cda822d3228306f80360c0a965fc3b9293f0f24d33638`.
Its bytecode predates the pending validator refactor even though public behavior
and ABI are preserved. Fresh immutable publication uses the admin CLI with
`--allow-republish`; only after confirmed success may it replace the target
network block.
