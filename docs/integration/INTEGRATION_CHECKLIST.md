# Full Integration Checklist

## Safety and ownership

- [x] Fetch target, DX, donor and upstream
- [x] Record all four SHAs
- [x] Push immutable donor safety tag
- [x] Create integration branch directly from DX main
- [ ] Open a new Draft PR; keep PR #4 open and unchanged
- [x] Confirm donor `AICoach`, `CoachSnapshot` and profile UI were not copied

## Foundation

- [x] Apply `NOOP AI Full Beta` side-by-side identity
- [x] Preserve SemanticMemory/Nomic/llama bootstrap
- [x] Add canonical Gregorian day and duration utilities
- [x] Complete semantic Thai catalog merge and validators

## Strength and data

- [x] Add v32/v33 migrations and migration fixtures
- [x] Seed/validate 420 exercises and 22 muscles
- [x] Port logger, history, templates, favorites, recents and autosave
- [x] Port raw-first muscular/total/residual load engines
- [x] Store soreness and pain separately
- [x] Port authoritative anatomical body map

## DX integration

- [x] Add consent-gated read-only Strength tools
- [x] Add one-time donor profile review/migration
- [x] Add Strength proposal metadata and Plan Book linkage
- [x] Add Strength Today section through `TodayLayoutPrefs`
- [ ] Add privacy-aware semantic Strength sources
- [x] Add Unified Backup V2 and legacy imports

## Validation and release

- [ ] Source hygiene, localization and exercise validators pass
- [ ] Swift packages, SemanticMemory, macOS and iOS tests pass
- [ ] iOS Simulator and Android builds pass
- [ ] Generic-device unsigned Release build passes
- [ ] IPA contains one app, Nomic/llama, Exercise Library and Thai resources
- [ ] Thai multi-screen UI preview generated and inspected
- [ ] Manual scenarios A–E recorded with evidence
- [ ] Draft PR updated with final SHA, actual run URLs and limitations
- [ ] Mark PR Ready only after every required check passes
