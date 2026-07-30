# PR #3 Full-App State Ownership

The visual port must not introduce a parallel state or data stack.

| Domain | Authoritative owner | UI may do | UI must not do |
|---|---|---|---|
| Today/health/workouts | `Repository` and existing analytics | format and arrange returned values | recalculate or cache competing scores |
| Root routing | `RootTabView`, `NavRouter`, existing `NavigationPath`s | present current destinations | create a second route graph |
| Coach | `AICoachEngine`, transcript/memory/provider stores | render messages, tool state, proposals | bypass consent or provider requests |
| Goals | `CoachGoalStore` | display and call existing mutations | invent progress/adherence |
| Plans | `CoachPlanStore` | expose accept/modify/decline/swap/start/skip | auto-accept or complete |
| Journey | existing goal/plan derivation | render real milestones/events | create unsupported milestones |
| Updates | `UpdateStore` | read/mark/clear/route/restore | create another inbox |
| Strength draft/logger | `StrengthTrainingViewModel` + `WhoopStore` | bind inputs and existing actions | duplicate autosave/session persistence |
| Exercise Library | `WhoopStore` seeded definitions | display/search localized aliases | change canonical IDs |
| Strength derived load | `MuscularLoadEngine`, weekly/residual services | show values/confidence/freshness | recalculate presentation-only loads |
| Body Map | `MuscleBodyMapModel` over authoritative services | select side/mode/muscle | replace anatomy/load mapping |
| Soreness/pain | existing check-in/profile stores and consent | edit/delete/skip through current API | merge pain into soreness/load |
| Database/migrations | GRDB/WhoopStore migrations | none | change schema for styling |
| Backup/restore | Unified Backup V2 + staging/rollback flow | present state and confirmations | change archive or transaction behavior |
| Import/export | repository/import/export services | route, validate, present result | change formats |
| Bluetooth/device | repository/BLE coordinator | show status and invoke existing commands | change frames, sync, ownership |
| HealthKit | HealthKit bridge/repository | request permission/import | change query/write semantics |
| Privacy/consent | `ToolConsent`, AppStorage consent keys | show/toggle via existing bindings | infer or silently enable consent |
| Semantic Memory | existing semantic memory service/settings | show state/rebuild/delete through API | expose vectors or bypass master consent |
| Canonical dates | existing Gregorian utilities | localized display only | parse stored keys with `Calendar.current` |
| Thai localization | String Catalogs and existing bundle rules | use localizable keys | replace source strings with Thai literals |

## Presentation state permitted

Local view state is limited to visual concerns such as selected segment,
expanded section, search query already owned by a view model, sheet visibility,
scroll position, and accessibility focus. Any new persistence key requires a
functional reason and review; visual styling alone must not create one.

## High-risk mutation audit

Before a redesigned action is accepted, verify that it still calls the same
owner:

- finish/edit/delete Strength session;
- workout edit/delete/reclassify;
- plan accept/modify/decline/swap/start/skip;
- privacy and sensitive-purpose toggles;
- semantic-memory deletion/rebuild;
- backup restore/import confirmation and rollback;
- device pair/remove/sync;
- destructive settings and data deletion.
