# File Ownership Map

DX remains the owner whenever a donor path overlaps an AI, navigation, privacy,
plan, memory or Today surface.

| Donor area | Classification | Integration action |
| --- | --- | --- |
| `Packages/WhoopStore/.../StrengthModels.swift` | PORT AS-IS | Preserve stable Codable/DB identifiers |
| `Packages/WhoopStore/.../StrengthStore.swift` | PORT WITH ADAPTER | Keep queries; connect mutations to DX refresh and plan adherence |
| `exercise-library-v1.json` and license docs | PORT AS-IS | Preserve source/revision/license metadata |
| `CanonicalDay.swift` and tests | PORT AS-IS | Make it the stored-day-key contract |
| Strength/weekly load engines | PORT WITH ADAPTER | Keep math; connect DX repository, confidence and invalidation |
| `CurrentMuscleResidualService.swift` | PORT WITH ADAPTER | Replace donor UserDefaults check-in source with integration store |
| Strength logger/history screens | PORT WITH ADAPTER | Embed in DX navigation/theme and keep DX state ownership |
| Anatomical body-map views | PORT WITH ADAPTER | Preserve vector geometry; connect authoritative integration services |
| Thai catalog entries | PORT WITH ADAPTER | Semantic key merge into DX catalogs; never overwrite a DX catalog wholesale |
| Localization/exercise validators | PORT WITH ADAPTER | Add DX-key preservation and Full target discovery |
| Donor `AICoach.swift` | DO NOT PORT | DX provider/request/tool lifecycle remains authoritative |
| Donor `CoachSnapshot.swift` | DO NOT PORT | Replace with compact DX Strength tool responses |
| Donor `CoachProfileSheet.swift` | REIMPLEMENT ON DX | Migrate reviewable fields into DX Goal/Memory/Settings |
| Donor `LocalCoachProfile.swift` | DOCUMENTATION ONLY | Read legacy payload for migration; do not retain a second profile |
| Donor `LiquidTodayView.swift` | DO NOT PORT | Recreate the Strength card inside DX Today/TodayLayoutPrefs |
| Donor performance-dashboard commits | REIMPLEMENT ON DX | Use reusable StrandDesign presentation components without replacing DX behavior |
| Existing DX `AICoach`, Coach stores and tools | DX OWNED | Extend through new cases/services only |
| Existing DX SemanticMemory and Nomic runtime | DX OWNED | Preserve package, bootstrap, indexing and delete/rebuild controls |
| Existing DX `RootTabView`, `LiquidTodayView`, `TodayLayoutPrefs` | DX OWNED | Add routes/sections without parallel navigation or state |
| Existing DX backup core | DX OWNED | Extend to a versioned V2 archive while retaining legacy import |

## Shared-file merge policy

- `project.yml`: start from DX and add Full Beta identifiers and Strength
  sources/resources.
- `Database.swift`: start from DX v31 and append donor v32 plus integration v33.
- `Repository.swift`: retain DX behavior and add narrowly scoped Strength
  adapters/day-key calls.
- `Localizable.xcstrings`: merge JSON entries by key, preserving every DX key.
- `AICoach.swift`, `CoachTools.swift`, `ToolConsent.swift`: edit DX versions
  only; donor equivalents are reference material.
- Today/navigation files: edit DX versions only.

