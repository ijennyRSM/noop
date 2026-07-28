# Strength Training, Muscular Load, and AI Coach

NOOP Strength Training is local-first. The exercise library, search, workout drafts,
sets, templates, calculations, history, and body map work without a network
connection. Starting Strength Training keeps the existing live workout recorder
active, so heart rate, duration, calories, zones, and Cardiovascular Effort retain
their existing meaning.

## Using Strength Training

1. Open **Workouts**, tap **Start workout**, and choose **Strength Training**.
2. Add exercises using canonical English names. Search includes aliases and filters
   for muscle and equipment.
3. Log weight in kg, repetitions, optional RPE or RIR, set type, and completion.
   The current draft is saved to SQLite after each change and survives navigation,
   screen locking, backgrounding, and ordinary process restoration.
4. The rest timer starts when a set is completed. Sets and exercises can be copied,
   reordered, or removed.
5. Templates are local. A current workout can create a template; a template can be
   used, updated, or deleted.
6. End the workout normally. NOOP saves the existing cardiovascular workout and the
   structured strength session separately, then calculates Estimated Muscular Load
   and Total Training Load.

Completed sessions appear under **Workouts → Strength history** and remain editable.
Editing sets recalculates affected muscle loads. A detected workout offers three
paths: complete exercise details, a quick body-region/intensity summary, or skip.
Quick summaries are explicitly lower confidence and never invent exercises or
left/right asymmetry.

## Local database

GRDB migration `v32-strength-training` adds:

- `exerciseDefinition`, `exerciseAlias`, `exerciseMuscle`, `customExercise`
- `strengthSession`, `strengthSessionExercise`, `strengthSet`
- `workoutTemplate`, `workoutTemplateExercise`, `workoutTemplateSet`
- `strengthSessionMuscleLoad`, `dailyMuscleLoad`, `muscleResidualSnapshot`
- `exerciseFavorite`, `exerciseRecent`

Exercise history keeps a stable exercise ID and a snapshot of the English name.
Removing a custom exercise is a soft delete, so old sessions remain readable. A
whole-session transactional save prevents partial child rows and rejects negative
weight, invalid timestamps, duplicate set indexes, and invalid RPE/RIR values.

`StrengthDerivedCommit` writes the session, exercises and sets, session muscle
loads, rebuilt daily aggregate, residual cache, and any detected-workout relabel in
one transaction. Editing or deleting a session rebuilds its affected days. A failed
derived write rolls back every part instead of leaving stale or partial rows.

The standard `.noopbak` process checkpoints and copies the whole database, so custom
exercises, sessions, sets, templates, and derived loads are included automatically.
Bundled exercise facts can be reseeded by stable ID after restore.

## Estimated Muscular Load

This is an original, transparent heuristic—not a direct physiological measurement.
For every completed set:

```text
effective load × reps × effort factor × relative-intensity factor × set-type factor
```

- External exercises use entered kg.
- Bodyweight exercises use profile bodyweight multiplied by a documented
  exercise-specific effective-bodyweight coefficient. A conservative fallback is
  used, with lower confidence, when bodyweight is unavailable.
- RPE or RIR adjusts the effort factor. A neutral fallback is used when both are
  missing.
- Warm-up, working, drop, and failure sets have separate documented factors in
  `MuscularLoadEngine.Configuration`.
- Epley e1RM (`weight × (1 + reps / 30)`) is used only for 1–12 rep conventional
  externally loaded sets and is labelled as an estimate.
- Exercise contribution weights are normalized before stimulus is distributed to
  NOOP's stable muscle taxonomy. They are roles/weights, not measured EMG percentages.

Raw stimulus is normalized against the user's trailing 28-day local history. With at
least three references, the median is the personal reference and maps to 50/100;
each doubling changes the score by 22 points. A documented cold-start reference is
used until enough history exists and confidence is reduced. Output is clamped to
0–100 and cannot be NaN, infinite, or negative.

### Confidence

- **Low:** classification/duration only, rep-only fallback, or insufficient detail.
- **Medium:** quick region/intensity summary or exercises with partial set details.
- **High:** multiple completed mapped sets with weights, effort detail, and enough
  personal history.

### Residual load

Residual load is a conservative exponential decay of prior per-muscle session load:

```text
residual = session load × 0.5^(hours elapsed / muscle half-life)
```

Repeated sessions accumulate before clamping. Sleep duration and Charge may adjust
the estimate only modestly. It never claims muscle damage, inflammation, injury
probability, or an exact recovery time.

`CurrentMuscleResidualService` recalculates decay against the current clock from
session-level muscle loads. Its 15-minute memory cache and database snapshot are
performance fallbacks, not the source of truth. Completing, editing, deleting, or
relabeling a workout, changing recovery/check-in inputs, and returning to the
foreground invalidate the cache.

An optional local soreness check-in can add at most 15% to an individual muscle's
estimated residual. It has full influence for 24 hours and tapers linearly to zero
at 72 hours. Missing soreness remains unavailable, not zero. Pain is stored and
described separately; it is never converted into load or used as a diagnosis.

### Total Training Load

Cardiovascular Effort is not changed or overwritten.
`CardiovascularEffortValue` carries an explicit `.noop100` or `.whoop21` scale and
source, so a stored NOOP value such as 10.5/100 cannot be normalized a second time.
Existing database values are always NOOP 0–100; WHOOP 0–21 conversion occurs only
at import/export boundaries. Hard-workout classification uses normalized Effort
`>= 70`.

The explicitly normalized value is
combined with Estimated Muscular Load using a weighted RMS plus a small peak guard:

```text
total = 0.90 × weightedRMS(cardio, muscle) + 0.10 × max(cardio, muscle)
```

If only one component exists, that component is returned. Both components remain
visible beside Total Training Load.

## Segmental body map

Today includes original SwiftUI front/back vector regions with modes for **Residual**
(default), **Today**, and **7 days**. Grey, green, yellow, orange, and red states also
have text labels and VoiceOver descriptions. Tapping a region shows load, working
sets, last trained time, contributing exercises, residual load, and confidence.

The 7-day view sums raw stimulus across seven local calendar days before
normalizing. Its personal reference is the median of four non-overlapping weeks in
the preceding 28 days; fewer than three usable weeks falls back to a documented
cold-start reference and low confidence. Training frequency is shown separately,
so normalized daily scores are never added until they saturate at 100.

The colors are estimates from logged training. They are not measurements of muscle
activation, tissue damage, inflammation, recovery percentage, or injury risk and are
not medical advice.

## AI Coach and privacy

`CoachSnapshot` separates local calculation from text formatting. With the existing
data-consent switch enabled, Coach receives compact recovery, shared main-sleep/nap
classification, calendar-based training load, up to six recent workouts with
available HR-zone summaries, latest-session muscle load, current residual, and
today/7-day muscle summaries. Current, recent, stale, and unavailable freshness is
explicit. The formatted context is capped at roughly 6,000 characters by removing
whole optional lines.

The optional Coach profile and soreness check-in are JSON stored in the app's local
settings. They add no account, telemetry, or upload path. Custom system prompts are
preserved; users can review and opt into the version-2 default, while users who
never customized the prompt migrate automatically.

Raw R-R, PPG red/IR, accelerometer, gyroscope, GPS, and stage-epoch streams are never
included. SpO₂ is included only when the database carries a calibrated percentage,
never from raw red/IR channels. The existing custom OpenAI-compatible local-server
option and BYOK consent model are unchanged.

## Tests

On macOS with Xcode/Swift installed:

```bash
swift test --package-path Packages/WhoopStore
swift test --package-path Packages/StrandAnalytics
xcodegen generate
xcodebuild -scheme Strand -configuration Debug test
xcodebuild -scheme NOOPiOS -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
```

The Windows development host cannot execute Xcode or Swift package tests; the GitHub
Actions workflows run the Apple builds.
