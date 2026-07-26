# Security Policy

## Security Overview

Sudoku Game is an offline-first Godot application. Local play does not require
an account or network access. The optional leaderboard is an anonymous, casual
competition service backed by Supabase PostgreSQL and narrowly scoped Data API
RPC functions.

Security fixes are supported for the latest `1.0.x` release on the default
branch. Earlier development snapshots are not supported.

## Data Security

Game progress, settings, statistics, the random installation identifier,
leaderboard cache and upload queue are versioned JSON documents under Godot's
platform-specific `user://` directory. Writes use a temporary file and backup
rotation. Local JSON is not encrypted and relies on the operating system user
profile and application sandbox for confidentiality.

Supabase stores one public high-score record per anonymous installation UUID and
a private submission-guard row. The score and guard tables have row-level
security enabled and forced. Anonymous and authenticated client roles have no
direct table `SELECT`, `INSERT`, `UPDATE` or `DELETE` privilege. Public
leaderboard output contains display names, scores, timestamps and ranks; it does
not return installation UUIDs.

## Authentication / Authorization

The current client has no account system. It generates a random UUID for each
installation; this value is a pseudonymous local identifier, not authentication
and not proof of a unique person or device.

Clients can execute only `public.submit_score(...)` and
`public.get_leaderboard(...)`. The security-definer functions use an empty SQL
`search_path`, schema-qualified objects and typed parameters. Direct table
access and helper-function execution are revoked. The optional legacy Edge
Functions use server-side credentials and are not required by the supported
Data API leaderboard.

## API Security

The game may contain a Supabase project URL and publishable client key. A
publishable key is designed to be distributed and gains access only through
database grants and RLS. It must not be mistaken for a privileged credential.

Never put any of these values in the client, repository, logs, screenshots or
release artifacts:

- Supabase `service_role` or secret keys;
- database passwords or access tokens;
- Edge Function signing secrets;
- Android release keystores or passwords;
- Apple certificates, private keys, provisioning profiles or notarization
  credentials;
- Windows code-signing private keys.

Production API calls use HTTPS and bounded request timeouts. Database migrations
and negative authorization tests must be repeated for every Supabase project.

## Anti Cheat

The supported submit RPC, rather than the client, calculates the final score. It
validates the difficulty, plausible time range, mistakes, ranked hint use and
move count; deduplicates a submission UUID; limits each claimed player UUID to
ten accepted unique submissions per minute; and updates a record only when the
new score is higher. Direct client writes to the final score table are denied.

These checks provide basic abuse resistance, not proof of gameplay. A modified
client can generate new UUIDs, fabricate plausible metrics, wait out the
per-UUID limit or automate submissions. The anonymous leaderboard is suitable
for casual play and is not esports-grade. Stronger integrity requires
authenticated identities and a server-issued, single-use challenge whose
solution and expiry are verified before a private score write.

The optional legacy challenge functions are experimental. They validate signed
online challenges, and the submission path rejects expired offline challenges,
but they still do not eliminate Sybil identities or prove human play.

## Secret Management

`config/client.env` and backend environment files are ignored. Commit only
example files with placeholders. Keep signing material in the operating system
keychain, local Godot settings, store portals or protected CI secret storage.
CI for this repository builds only unsigned/debug artifacts and does not receive
production credentials. Third-party Actions are pinned to immutable commits,
and downloaded Godot binaries/templates are checked against official SHA-512
values before execution.

Before release, scan the current files, ignored configuration, generated
artifacts and Git history. If a privileged key is exposed:

1. revoke or rotate it immediately at the provider;
2. remove it from current files and artifacts;
3. assess and, when necessary, rewrite Git history;
4. invalidate and rebuild affected releases;
5. document the incident without repeating the secret.

## Vulnerability Reporting

Use the repository's **Security → Report a vulnerability** form when private
vulnerability reporting is available. Include the affected version or commit,
reproduction steps, expected impact and a minimal proof of concept. Remove
credentials, tokens and personal information from all evidence.

Do not publish exploitable details in a public issue before a fix is available.
If private reporting is unavailable, open a public issue containing only a
request for a private contact channel.

The project aims to acknowledge a report within seven days. Confirmation,
severity and remediation timing depend on reproducibility and impact. Reporters
will be notified when a fix is released and may be credited with consent.
Reports that only demonstrate the documented ability to modify an anonymous
client are normally treated as a known product limitation unless they also
bypass a server-enforced boundary such as RLS or the privileged submission path.
