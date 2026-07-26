# Repository working guide

This file applies to the entire repository.

## Project boundaries

- Continue the existing Godot 4.7 architecture; do not replace the service,
  autoload, persistence or Supabase boundaries without an explicit requirement.
- Keep `core/sudoku/` independent of UI code.
- Preserve offline play when Supabase is absent or unavailable.
- Treat the Data API RPCs in migration 006 as the supported leaderboard path.
  The Edge Functions are optional legacy/future challenge infrastructure.

## Required validation

Run before committing code:

```sh
./tests/run_all.sh
godot --headless --path . \
  --log-file /tmp/sudoku-ui-smoke.log \
  --script tests/ui_smoke_runner.gd
```

Run `SUDOKU_STRESS=1 ./tests/run_all.sh` after generator, solver, difficulty or
session-rule changes. Live Supabase checks are optional and require an ignored
test-project configuration; clean their generated UUID rows afterward.

## Secrets and generated files

- Never commit `config/client.env`, `.env`, service-role/secret keys, database
  passwords, signing keys, certificates or provisioning profiles.
- A client build may contain only a Supabase publishable key.
- Keep local output under ignored `build/`. Commit only deliberately packaged,
  documented artifacts under `builds/`.
- Do not claim target-device QA or production signing unless it was actually
  completed on that platform.

## Documentation

When commands, requirements or delivery status change, update the root guides
and the matching `docs/zh-CN/` and `docs/en-US/` pages. Keep commands and paths
identical between languages and record environmental limitations explicitly.
