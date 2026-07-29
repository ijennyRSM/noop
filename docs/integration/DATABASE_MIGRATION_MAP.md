# Database and Backup Migration Map

## Schema sequence

| Migration | Owner | Purpose |
| --- | --- | --- |
| `v1`–`v31-deep-capture-channels` | DX/upstream | Existing NOOP health, workout, import and raw-capture data |
| `v32-strength-training` | Donor | Exercise library, custom exercises, Strength sessions/sets/templates/favorites/recents, session/daily muscle loads and residual cache |
| `v33-strength-integration` | Integration | Soreness records, per-muscle soreness, separate pain/discomfort records and Strength-to-Plan linkage |

If refreshed DX main introduces a migration named v32 before implementation,
the donor migration retains its contents but receives the next unused monotonic
name. The migration name is recorded in this document and in backup metadata.

## v32 rules

- Seed built-in exercises by stable canonical ID and resource revision.
- Upsert seed facts without replacing custom user records.
- Enforce foreign keys and cascade session exercise/set/derived rows.
- Use transactions for session finalization, edit, delete and detected-workout
  relabel operations.
- Never use localized display text as an activity or exercise identifier.

## v33 rules

- `sorenessCheckIn`: timestamp, overall score, note and soft-delete marker.
- `sorenessMuscle`: check-in ID, canonical muscle ID, side and score.
- `painCheckIn`: timestamp, presence, affected area, optional severity/note and
  soft-delete marker. Pain is never copied into load columns.
- Add nullable plan proposal linkage to Strength sessions; legacy sessions
  remain valid.
- Migration is additive, idempotent and safe for clean DX, upgraded DX and
  donor v32 databases.

## Restore paths

| Input | Expected behavior |
| --- | --- |
| Clean install | Run all migrations and seed the library exactly once |
| Legacy DX `.noopbak` | Validate/restore its DB/settings, migrate to v33, preserve only Coach state present in the archive |
| Donor `.noopbak` | Restore v32 Strength rows, migrate to v33, rebuild derived caches |
| Unified Backup V2 | Preflight manifest/checksums, preview, stage all canonical state, replace atomically, rollback completely on failure |
| Invalid/corrupt backup | Reject before live replacement and show a user-visible error |

Historical donor backups do not contain donor Coach Profile or soreness
UserDefaults. The import UI must disclose this and offer a review/re-entry
step; it must not claim those unavailable values were migrated.

## Unified Backup V2 entries

- `manifest.json`: schema, app/build, source bundle/version, creation time,
  entry sizes and SHA-256 checksums.
- `noop-backup.sqlite`: canonical database after WAL checkpoint/integrity check.
- `settings.json`: non-secret whitelisted preferences.
- Versioned Coach memory, goals, plans and conversation JSON.
- Excluded: API/OAuth secrets, signing data, semantic vectors, Nomic/llama
  binaries, residual/semantic rebuild caches and transient unsafe logger state.

After restore, recalculate daily/residual Strength derivatives. Rebuild
semantic vectors only after explicit consent.

