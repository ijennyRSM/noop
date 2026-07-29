# Unified performance UI acceptance checklist

Base: `6c460d1e44091d1f410f9a6133cb1eab1a7870dd`

## Reference and safety

- [x] Inspect every file in the authoritative ZIP.
- [x] Validate all 23 SHA-256 entries.
- [x] Inspect images 00–18; use image 00 as authoritative navigation.
- [x] Keep reference files outside the repository and application bundle.
- [x] Start `feat/whoop-full-ui-redesign` directly from the stable Full Beta SHA.
- [ ] Confirm protected backend paths have no behavioural diff before delivery.

## Shared design system

- [x] Add semantic performance colour, typography, spacing, radius, chart and motion tokens.
- [x] Add cards, rows, pills, buttons, sheets, states, charts and score components.
- [x] Support VoiceOver, Dynamic Type, Reduce Motion and non-colour status.
- [x] Validate catalog placeholder parity; compact Thai screenshot review is pending.

## Navigation

- [x] Floating dock: Home, Health, Progress, More.
- [x] Separate circular Coach action aligned to dock.
- [x] Home routes to the existing Today owner.
- [x] Health exposes Charge, Rest, Effort, Health Monitor, Stress and Trends.
- [x] Progress exposes Goal, Plan Book, Journey and Updates.
- [x] More exposes Strength, Workouts, Data Sources, Privacy, Backup and Settings.
- [x] Preserve selected-tab paths, reselect, deep links and Coach notifications.
- [x] Respect Reduce Motion.

## Core screens

- [x] Today no longer uses Liquid visual presentation.
- [x] Today retains every section, plan/update entry and Arrange Today behaviour.
- [x] Charge, Rest, Effort, Health Monitor, Stress and Trends share the design system.
- [x] Workouts history/detail, zones and existing actions remain reachable.
- [x] Loading, unavailable and error components use the shared semantic system.

## Strength

- [x] Strength Home, Logger, Picker, templates, history and details share the design system.
- [x] Logger preserves every set action, autosave and practical tap target.
- [x] Body Map preserves original NOOP vector art and load service.
- [x] Soreness and pain data paths remain separate and consent-aware.

## Coach and progress

- [x] Circular action opens the existing DX Coach.
- [x] Chat, history, identity/provider and Semantic Memory retain existing engines.
- [x] Goal, proposal, Plan Book, Journey and Updates retain every action.
- [x] No plan is accepted automatically and no duplicate Coach/Today state exists.

## Settings and data

- [x] Devices, Settings, privacy/consent, Data Sources, import/export and Backup V2 share the system.
- [x] Disclosures remain visible and destructive actions remain confirmed.
- [x] Side-by-side Full Beta bundle identity remains unchanged.

## Tests and artifacts

- [x] Root mapping and tab persistence tests added; compiler/test run pending.
- [ ] Plan, Logger, privacy and import/export presentation-route tests.
- [ ] Accessibility tests for key score components.
- [ ] Source Hygiene, i18n, packages, macOS, iOS Simulator, Android and validators pass.
- [ ] Capture the required real seeded Thai simulator screens.
- [ ] Visually inspect the complete screenshot artifact.
- [ ] Build and inspect one unsigned real-device IPA.
- [x] Open a Draft PR into `integration/dx-thai-strength-full`.
- [ ] Record all real-device scenarios not yet tested.
