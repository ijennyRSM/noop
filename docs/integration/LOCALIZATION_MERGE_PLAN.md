# Thai Localization Merge Plan

## Recorded catalog inventory

| Source | Catalog keys | Thai entries |
| --- | ---: | ---: |
| DX main, all catalogs | 3,511 | 0 |
| Donor, all catalogs | 3,766 | 3,756 |
| Main app overlap | 3,274 | n/a |
| DX-only main-app keys | 57 | 0 |
| Donor-only main-app keys | 292 | mostly translated |

Counts are recomputed after the final source refresh and after string
extraction; these recorded values are the audit baseline, not a frozen target.

## Merge algorithm

1. Parse every catalog as JSON and retain DX as the structural source.
2. For identical keys, copy donor `th` variants only; preserve DX English,
   comments, substitutions and extraction state.
3. Add donor-only user-facing Strength keys with English source and Thai
   localization.
4. Translate DX-only Coach, identity/persona, Goal, Plan Book, Journey,
   history, semantic memory, privacy, updates and recovery/error UI.
5. Extract newly introduced integration UI and translate it before CI.
6. Keep canonical exercise names, slugs, activity IDs, database values and
   machine-readable formats in English. Add Thai aliases as separate search
   metadata where useful.

## Target boundaries

- Main app strings stay in `Strand/Resources`.
- StrandDesign package strings stay in its module resource bundle.
- Watch, complication and widget catalogs are merged separately even though
  unsigned Full Beta packaging omits extensions.
- Permission descriptions and `CFBundleDisplayName` receive localized values
  in the correct target bundle.

## Validation gates

- Every `.xcstrings` file parses as JSON.
- Every required user-visible key has `th`.
- English and Thai placeholders have compatible count, type and position.
- Every pre-merge DX key is still present.
- No duplicate canonical activity/exercise IDs.
- The audit flags untranslated English outside the documented abbreviation,
  brand, scientific-unit and canonical-identifier allowlist.
- Compact iPhone, Dynamic Type and Thai line-wrapping previews are captured.

