# Offline Exercise Library

NOOP bundles 420 normalized exercises. Runtime code never contacts an exercise API
and no exercise media is bundled.

## Source and license

| Source | Pinned revision | License | Included |
|---|---|---|---|
| [yuhonas/free-exercise-db](https://github.com/yuhonas/free-exercise-db) | `b0eed061e1c832b3ed815fbaa4b45b3cdc14df49` | [The Unlicense](https://github.com/yuhonas/free-exercise-db/blob/main/LICENSE), public-domain dedication | Canonical exercise names and factual category/equipment/muscle metadata |

NOOP excludes the upstream images, video links, and instructional prose. Source,
license, license URL, source URL, and local library version are stored on every
built-in exercise. The Unlicense does not require attribution, but this manifest is
preserved for provenance and reproducibility.

## Reproducible import

Download `dist/exercises.json` from the pinned revision and run:

```bash
python3 Tools/import-exercise-library.py \
  --source /path/to/exercises.json \
  --output Packages/WhoopStore/Sources/WhoopStore/Resources/exercise-library-v1.json \
  --count 420
```

The importer:

- accepts only strength, powerlifting, Olympic lifting, strongman, plyometric, and
  relevant mobility/stretching entries;
- creates stable normalized IDs;
- uses a balanced deterministic selection across primary muscle and equipment;
- normalizes source muscle/equipment terms into NOOP's taxonomy;
- adds a small reviewed alias set;
- normalizes muscle contribution roles to sum to 1.0;
- excludes entries with no supported primary muscle;
- writes no runtime URL dependency.

Run the WhoopStore tests after any update. They require at least 300 entries, unique
IDs, valid equipment and muscle IDs, unambiguous stored aliases per exercise, valid
contribution totals, and source/license metadata.

## Adding or updating data

1. Review the upstream revision and its exact license.
2. Update the pinned revision in the import script and this document.
3. Regenerate the JSON rather than editing hundreds of rows by hand.
4. Review canonical English names and ambiguous source regions manually.
5. Increment `LIBRARY_VERSION`.
6. Add aliases only when they are commonly accepted English terminology.
7. Run package, migration, search, localization, and app builds.

Custom exercises are not part of this resource. They are created locally with an
English name, aliases, equipment, movement pattern, load type, laterality, and
explicit user-selected muscles; AI never infers mapping from an arbitrary name.
