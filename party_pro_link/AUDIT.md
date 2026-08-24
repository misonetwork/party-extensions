# Security Audit — `party_pro_link`

**Revision:** not a git repository (working tree as of audit date) · **Date:** 2026-08-23 ·
**Toolchain:** sui 1.77.2

Audit of `party_pro_link`, the professional/industry payload package for
`platform_link`: six URL-based types (website, booking, management,
publisher, label, EPK) and three handle-based types (Patreon, Substack,
Ko-fi). Verdict: **safe — no findings; one integrator-facing note.**

## What it does

Pure payload definitions + validated constructors
(`party_pro_link.move:65-127`). URL-based payloads store a full `url` ≤
`max_url_length()` (2000); handle-based ones store an identifier ≤
`max_identifier_length()` (256). Like the other payload packages, this one
touches no object and gates nothing — writes happen through
`party_platform_link::set_link` under the `PartyAdminCap`.

Threat model: malformed payloads reaching storage; phishing URLs rendered as
trusted links.

## Checks performed (all hold)

- **Uniform validation.** Every constructor asserts non-empty + the shared
  length backstop (`:62-127`); limits come from `platform_link` functions,
  so no drift.
- **Module-private construction** — no unvalidated payload can be built
  outside these constructors.
- **Type-level isolation** between the nine platforms via phantom-typed
  keys downstream.

## Findings

None.

### Notes (integrator-facing, not code findings)

- **Stored URLs are arbitrary by design** (`:8-10` — "the URL *is* the
  identity"). A party admin can store any URL on their OWN party, including
  lookalike/phishing destinations. Frontends MUST render these as untrusted
  external links (no auto-redirect, clear external-link affordance). This is
  self-sovereign data; the chain's job — bounds and authorization — is done.
  **Disposition (2026-08-24):** accepted — self-sovereign data on one's own
  party; untrusted-rendering is a documented frontend obligation.

## Edge cases (verified)

- Empty url/handle — aborts (`EEmptyValue`).
- Over-long url (>2000) / handle (>256) — aborts (`EUrlTooLong` /
  `EHandleTooLong`).
- URL-valued payload vs handle-valued payload confusion — impossible: distinct
  types, distinct constructors, distinct df keys downstream.

## Verification

Tests in `tests/party_pro_link_tests.move` (4 `expected_failure` — validation
aborts).
