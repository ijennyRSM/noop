# NOOP AI Full integration implementation

## Ownership

The integration branch starts from DX `main`. DX remains authoritative for `AICoachEngine`, tools,
memory, goals, plans, journey, consent, RootTabView, Today state, SemanticMemory, Nomic, and llama.
Strength code is adapted into those owners rather than installing the donor CoachSnapshot or profile UI
in parallel.

## Dates and durations

Stored day keys are Gregorian `yyyy-MM-dd` identifiers. `CanonicalDay` uses
`Calendar(identifier: .gregorian)`, `en_US_POSIX`, the device time zone, and strict parsing. Never parse a
stored key with `Calendar.current`: a Thai device may use the Buddhist calendar. User-facing dates and
scheduling may still use the user's localized calendar.

Daily freshness is based on local Gregorian calendar dates, not elapsed hours: same date = current,
previous date = recent, two or more dates old = stale, and missing/invalid = unavailable. Seven- and
twenty-eight-day windows include today; prior-thirty-day baselines exclude the current partial day.

`CoachDurationFormatter` retains numerical storage units and renders whole-minute context: `64` minutes
becomes `1 h 4 min`, `286.7` becomes `4 h 47 min`, and signed differences preserve their sign.

## Strength and privacy contracts

Migration `v32-strength-training` owns the exercise library and Strength session/load tables.
`v33-strength-integration` adds separate soreness, per-muscle soreness, pain check-in, and
strength-plan-link tables. Pain is structurally separate and never enters load or residual formulas.

`CurrentMuscleResidualService` recomputes from session-level muscle loads, caches for 15 minutes, and is
invalidated after mutations and foregrounding. Soreness has full influence for 24 hours, tapers to zero at
72 hours, and can increase residual by at most 15%. Missing soreness is unavailable, not zero.

Strength Coach tools require the master data-consent switch and the Strength purpose. Pain fields also
require the independent pain-sensitive purpose, which no preset enables. Tool output contains only
derived summaries, confidence, Gregorian dates, and readable durations—never raw HR/RR/PPG/IMU/GPS rows
or device identifiers.

Accepting a Strength proposal does not create a workout. A plan becomes completed only after a
user-started Strength session finalizes and its session ID is linked.

## Unified Backup V2

Production `.noopbak` exports contain:

- `manifest.json` with schema, source, app version, timestamp, and SHA-256 checksums;
- `noop-backup.sqlite`;
- optional whitelisted `settings.json`;
- `coach-state.json` with versioned whitelisted memory, goals, plan, and conversation state.

API keys, provider tokens, device identifiers, semantic vectors, Nomic/llama binaries, signing data, and
derived caches are excluded. Restore extracts to staging, validates the manifest/checksums and SQLite
integrity, then swaps data. A Coach-state failure rolls the database, settings, documents, and whitelisted
defaults back. Legacy DX and donor SQLite backups remain importable; historical donor archives never
contained `ai.localCoachProfile.v1` or soreness UserDefaults, so those values cannot be invented during
restore.

## Build and preview

The manual **Build NOOP AI Full Thai Strength** workflow bootstraps the pinned Nomic assets before
XcodeGen, validates Thai and the 420-exercise library, builds `NOOPiOS` Release for a generic physical
iPhone with signing disabled, verifies required resources, removes embedded Watch/extensions, and uploads
one unsigned IPA. Its optional simulator job captures seeded Thai Today, Strength home, logger, body map,
Coach, Goal/Plan, and Privacy screens.

## Manual scenario status

The following require installation on an iPhone and must not be inferred from compilation:

- A: fresh DX database migrates through v32/v33 and logs/finalizes a Strength session;
- B: donor database migrates without duplicate rows and offers profile review;
- C: soreness changes residual while pain remains separate under every consent combination;
- D: accepting/starting/finalizing a Strength plan links exactly one session;
- E: Backup V2 export, preview, restore, and rollback on a deliberately damaged archive.

CI and build results are recorded in the pull request separately from these manual scenarios.
