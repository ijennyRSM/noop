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

- [ ] Add semantic performance colour, typography, spacing, radius, chart and motion tokens.
- [ ] Add cards, rows, pills, buttons, sheets, states, charts and score components.
- [ ] Support VoiceOver, Dynamic Type, Reduce Motion and non-colour status.
- [ ] Validate compact Thai widths and placeholder parity.

## Navigation

- [ ] Floating dock: Home, Health, Progress, More.
- [ ] Separate circular Coach action aligned to dock.
- [ ] Home routes to the existing Today owner.
- [ ] Health exposes Charge, Rest, Effort, Health Monitor, Stress and Trends.
- [ ] Progress exposes Goal, Plan Book, Journey and Updates.
- [ ] More exposes Strength, Workouts, Data Sources, Privacy, Backup and Settings.
- [ ] Preserve selected-tab paths, reselect, deep links and Coach notifications.
- [ ] Respect Reduce Motion.

## Core screens

- [ ] Today no longer uses Liquid visual presentation.
- [ ] Today retains every section, plan/update entry and Arrange Today behaviour.
- [ ] Charge, Rest, Effort, Health Monitor, Stress and Trends share the design system.
- [ ] Workouts history/detail, zones and existing actions remain reachable.
- [ ] Loading, unavailable, permission-denied and error states are intentional.

## Strength

- [ ] Strength Home, Logger, Picker, templates, history and details share the design system.
- [ ] Logger preserves every set action, autosave and practical tap target.
- [ ] Body Map preserves original NOOP vector art and load service.
- [ ] Soreness and pain remain separate and consent-aware.

## Coach and progress

- [ ] Circular action opens the existing DX Coach.
- [ ] Chat, history, identity/provider and Semantic Memory retain existing engines.
- [ ] Goal, proposal, Plan Book, Journey and Updates retain every action.
- [ ] No plan is accepted automatically and no duplicate Coach/Today state exists.

## Settings and data

- [ ] Devices, Settings, privacy/consent, Data Sources, import/export and Backup V2 share the system.
- [ ] Disclosures remain visible and destructive actions remain confirmed.
- [ ] Side-by-side Full Beta bundle identity remains unchanged.

## Tests and artifacts

- [ ] Root mapping, Coach action, tab persistence and no-duplicate-Today tests.
- [ ] Plan, Logger, privacy and import/export presentation-route tests.
- [ ] Accessibility tests for key score components.
- [ ] Source Hygiene, i18n, packages, macOS, iOS Simulator, Android and validators pass.
- [ ] Capture the required real seeded Thai simulator screens.
- [ ] Visually inspect the complete screenshot artifact.
- [ ] Build and inspect one unsigned real-device IPA.
- [ ] Open a Draft PR into `integration/dx-thai-strength-full`.
- [ ] Record all real-device scenarios not yet tested.
