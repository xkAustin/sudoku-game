# Security Guide

See the complete repository policy in [`SECURITY.md`](../../SECURITY.md).

- Local JSON is stored under `user://`, is not encrypted, and relies on the OS
  user boundary.
- Both Supabase tables enable and force RLS; clients cannot access tables
  directly.
- `submit_score` calculates the final score in the database, and
  `get_leaderboard` does not return UUIDs.
- A publishable key may be distributed, but all access remains constrained by
  grants and RLS.
- Never put `service_role`, passwords, tokens, keystores, certificates,
  profiles, or private keys in the client, Git, logs, or delivery packages.
- An anonymous leaderboard cannot prevent new UUIDs, modified clients, or
  fabricated plausible metrics and is not suitable for serious competition.
- CI pins third-party Actions to immutable commits and verifies Godot 4.7.1
  archives with the official SHA-512 list before execution.
- Submit vulnerabilities through GitHub private vulnerability reporting before
  publishing exploit details.

After a disclosure, rotate immediately, clean current files and artifacts,
assess Git history, and rebuild affected releases.
