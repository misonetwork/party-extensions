# AGENTS.md — Working on Miso Party Extensions

Guidance for agents (and humans) building or documenting extensions in this
repository. Read [ROADMAP.md](ROADMAP.md) for design principles and phasing,
and [README.md](README.md) for the architecture and package overview.

## Repository shape

- `lib/*` — protocol-agnostic primitives (`platform_link`, `typed_set`). They
  depend only on the Sui framework: no `miso_party`, no Miso. If a mechanism
  knows what a party is, it does not belong in `lib/`.
- `party_*` — extensions. Each attaches one slice of a profile to a `Party`
  via dynamic fields, gated by `PartyAdminCap` through `party::uid_mut(cap)`.
- Every package is self-contained: `Move.toml`, `sources/`, `tests/`,
  `README.md`.

## Adding a new extension

1. **Check the ROADMAP first.** The extension should already be scoped to a
   phase with a defined slice. If it duplicates something derivable from
   protocol objects, stop — derived state is read, not stored.
2. **Use a primitive before writing mechanics.** A bounded set of anything →
   depend on `typed_set` and keep only your element type, domain validation,
   capacity constant, and typed events. A link to an external platform → a new
   `Data` payload type in the appropriate payload package (`party_social`,
   `party_music`, `party_pro_link`), wired by `party_platform_link` — zero new
   mechanism. Only write raw `df::add`/`borrow`/`remove` when no primitive
   fits (single-value fields like `party_media` and `party_profile`).
3. **Keep it slim.** One slice, one key, the smallest API that covers the
   feature. No speculative configurability, no helper functions with one call
   site, no unused public surface.
4. **Gate every write with the cap.** All writes take `&PartyAdminCap` and go
   through `party::uid_mut(cap)` — before any mutation or event emission.
   Views are permissionless.
5. **Bound everything stored.** Max lengths on strings, max counts on
   collections. Reuse `platform_link::max_identifier_length()` /
   `max_url_length()` rather than re-declaring the same numbers — unless the
   package deliberately stays free of the `platform_link` dependency (as
   `party_cta` does).
6. **Pin git dependencies to a commit SHA** — never `rev = "main"`.
7. **Emit an event per write**, carrying `party_id`. Events are change
   signals: payloads are not re-included, except small, stable ones (ids and
   short display strings — `party_media`'s quilt id or a role or tag string),
   which ride in.
8. **Tests:** happy path, each validation abort, and always a wrong-cap test
   (`expected_failure(abort_code = EUnauthorized, location = miso_party::party)`
   — mirror the constant locally). Set-mechanics aborts assert `typed_set`'s
   codes at `location = typed_set::typed_set`.
9. **Document** (below): package README, root README row, ROADMAP row.
10. **Verify:** `sui move build && sui move test` in the package, warning-free.

## Documenting an extension

Four artifacts, in this order:

### 1. Package `README.md` (required, in the package folder)

Use this exact section order. Omit a section only when it would be empty —
and say so inline (e.g. "none — set aborts come from `typed_set`") rather than
leaving the reader guessing.

```markdown
# <package_name>

<2–4 sentences: what slice of the profile this owns, why it exists as its own
package, and any load-bearing design decision (e.g. proven-at-write-time,
replace-in-place, client convention). Match the module header doc.>

## What it stores
<Dynamic-field key type(s), value type and shape, limits/capacities, and the
reclamation/replacement semantics. One short list or table.>

## API
### Writes (cap-gated)
| Function | Description | Aborts |
### Views
| Function | Returns |

## Events
| Event | When | Payload |

## Errors
| Code | Constant | Condition |
<Include aborts that surface from primitives, marked with their location.>

## Dependencies
<Direct deps and why. Note anything unusual (protocol deps, git pins).>

## Integrator notes
<What a client/indexer must know that is not in the code: URL rebuilding from
handles, untrusted-input sanitization, quilt patch identifier conventions,
re-read-on-event, commit-settled balances, etc.>
```

### 2. Root `README.md` row

Add the package to the correct table (Primitives vs. Extensions), one line:
what it owns, no mechanics. Keep alphabetical-ish grouping by role, not by
name.

### 3. `ROADMAP.md` row

Add or update the package's row in its phase table. If the roadmap described
the package aspirationally and reality differs, the roadmap loses — update it.

### 4. In-code docs (as you write the module)

- Module header doc comment: what the slice is, where the mechanics live,
  where aborts come from, who gates writes. This header is the source the
  package README condenses — keep them in sync.
- Doc comments on every public type, function, event, error constant, and
  storage constant. State abort conditions on the function that aborts.
- After any refactor, sweep comments that describe the old behavior.

## Style rules

- Plain, precise prose. No marketing voice, no emoji.
- Code identifiers stay in `backticks`; packages in bold only on first
  mention in a section if emphasis is truly needed.
- Tables over paragraphs for API/event/error surfaces.
- Numbers in docs (limits, codes) must match the code — when they disagree,
  the docs are wrong, always.
- Never document a function that does not exist; never leave a documented
  behavior unverified (`sui move test` green is the bar).
