# Security Check Report

Date: 2026-07-26
Scope: current working tree, intended release packages, export configuration,
Supabase migration/RPC boundary, and all Git history reachable from this clone.

Repository-positioning note: generated packages that were present under
`builds/` during this audit are now local-only ignored outputs and are no longer
tracked on the default branch. Future public binaries belong in GitHub Releases
or platform stores. The package-scan results below remain the historical record
for the files examined on this date.

## Executive result

No privileged credential, private key, signing material or reportable unresolved
product-security vulnerability was found. Git history did not require rewriting.
The ignored local Supabase client file contains a publishable key, not a secret,
and is absent from every package under `builds/`.

One conditional issue in the optional legacy Edge Function was found and fixed:
an offline challenge could previously be submitted after its signed expiry. The
submission function now rejects expired offline challenges before any database
write. Additional local-data and test-integrity hardening was also completed.

## Tools and commands

### Gitleaks 8.30.1

Git history:

```sh
gitleaks git . --redact --report-format json --report-path REPORT
```

Result: 2 commits and approximately 361 KB scanned; zero leaks.

Working tree:

```sh
gitleaks dir . --redact --report-format json --report-path REPORT \
  --max-target-megabytes 90
```

Result: five generic-key matches, all traced to the same intentionally public
Supabase publishable key in ignored `config/client.env` and ignored historical
`build/` PCK files. They are not privileged credentials and none is tracked.
Large ignored engine binaries were skipped by the generic pass.

Sanitized release packages were extracted and scanned separately:

```sh
gitleaks dir EXTRACTED_RELEASES --redact --report-format json \
  --report-path REPORT --max-target-megabytes 250
```

Result: approximately 20 MB of extractable content scanned; zero leaks. A
separate exact-value check confirmed zero copies of the local Supabase URL and
publishable key in all four locally generated packages.

### Credential filename and pattern review

The tracked tree and ignored-file inventory were checked for:

- Supabase service-role/secret keys;
- generic API tokens and passwords;
- PEM/OpenSSH/RSA/EC private-key headers;
- Android keystores;
- Apple certificates, provisioning profiles and archives;
- generic `.env` and credential files.

Only placeholder example files and security documentation references matched.
No signing credential or privileged configuration file is tracked.

### Repository security review

A repository-wide Codex Security review covered the Godot runtime, local JSON
storage, network and synchronization paths, Supabase SQL/RPCs, optional Edge
Functions, tests, CI configuration and release/export surfaces.

Result after remediation: zero unresolved reportable findings.

Reviewed non-reportable limitations:

- anonymous UUID identities remain vulnerable to Sybil abuse;
- plausible client metrics cannot prove that a human solved a server-issued
  puzzle;
- malformed private `user://` files can at worst affect the same local profile;
- executing an untrusted pull request inherently executes repository test/build
  code, so CI must not expose production secrets;
- Apple privacy declarations require a final publisher compliance review before
  App Store submission.

The final working-tree diff review additionally identified and remediated two CI
supply-chain weaknesses: every third-party Action is now pinned to an immutable
commit, and downloaded Godot engine/template archives are checked against the
official 4.7.1 SHA-512 values before extraction or execution.

### Dependencies and type checks

The project has no third-party Godot plugin, package-manager manifest or lockfile.
The Deno Edge Functions use Deno/Web platform APIs and local modules. Therefore
there was no supported dependency graph for OSV-style package scanning.

Executed checks:

```sh
deno test --allow-env backend/supabase/tests
deno check backend/supabase/functions/get-ranked-challenge/index.ts
deno check backend/supabase/functions/submit-score/index.ts
deno check backend/supabase/functions/get-leaderboard/index.ts
```

Result: 2 tests and all 3 type checks passed.

### Database authorization review

The linked Supabase project was queried with the read-only verification script:

```sh
supabase db query --linked \
  --file backend/supabase/tests/verify_data_api_scores.sql \
  --output table
```

Result:

- `scores` and `score_submission_guards` exist;
- both tables have enabled and forced RLS;
- `anon` has no table `SELECT`, `INSERT`, `UPDATE` or `DELETE`;
- no table policies or triggers exist, by design;
- all four expected indexes exist;
- only `submit_score` and `get_leaderboard` are client-executable;
- security-definer functions use an empty `search_path`.

Earlier anonymous live checks confirmed valid RPC submission/read, idempotency,
highest-score behavior, metric rejection, direct-table denial and the per-UUID
rate limit. Temporary QA rows were removed afterward.

The final cloud-only readback found zero suspected Codex/test/QA score rows and
zero orphan submission-guard rows. `supabase functions list` returned no
deployed Edge Functions, so the optional legacy/future function sources are not
represented as production-validated endpoints.

### Platform permission and artifact checks

- Android requests only `android.permission.INTERNET`.
- Android APK Signature Scheme v2/v3 verifies with the Godot debug certificate.
- macOS is ad-hoc signed; no Developer ID material is included.
- Windows and Linux packages are unsigned and contain no signing material.
- iOS has no committed package because Apple signing is required.

## Remediation completed

- Made the RPC the only supported leaderboard read/write boundary.
- Forced RLS and revoked all client table privileges and helper-function grants.
- Added server-side score calculation, metric bounds, idempotency and
  per-UUID throttling.
- Rejected expired offline challenges in the optional Edge Function.
- Added recovery/cleanup handling for temporary and backup JSON variants.
- Applied the 10 MB custom-audio limit to every runtime loader path.
- Randomized the live Godot test identity and tightened response assertions.
- Expanded `.gitignore` for environment, key, certificate, provisioning and
  generated-native-project files.
- Built public packages from a source copy that excluded local configuration,
  Git metadata, caches, logs and signing material.
- Pinned GitHub Actions to immutable commits and added official SHA-512
  verification for every downloaded Godot engine/template archive.

## Remaining release controls

Before a public store release, a human publisher must:

1. create release builds with private Android/Apple/Windows signing material
   stored outside the repository;
2. review and finalize Apple privacy declarations for anonymous installation ID
   and optional leaderboard display-name/score processing;
3. run installation and interaction QA on the actual target devices;
4. inspect the first GitHub Actions run after push;
5. rotate credentials immediately if a future scan finds a privileged leak.

No secret was removed from Git history in this review, so no key rotation or
history rewrite was necessary.
