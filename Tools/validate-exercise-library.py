#!/usr/bin/env python3
"""Validate NOOP's deterministic, offline exercise-library artifact."""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = (
    ROOT
    / "Packages"
    / "WhoopStore"
    / "Sources"
    / "WhoopStore"
    / "Resources"
    / "exercise-library-v1.json"
)

MUSCLES = {
    "chest", "lats", "upper_back", "lower_back", "traps", "front_delts",
    "side_delts", "rear_delts", "biceps", "triceps", "forearms",
    "abdominals", "obliques", "erector_spinae", "hip_flexors", "glutes",
    "quadriceps", "hamstrings", "adductors", "abductors", "calves", "tibialis",
}
LATERALITY = {"bilateral", "unilateral"}
LOAD_TYPES = {"external", "bodyweight"}
ROLES = {"primary", "secondary", "stabilizer"}


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def main() -> int:
    errors: list[str] = []
    try:
        document = json.loads(CATALOG.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"ERROR: cannot read {CATALOG}: {error}", file=sys.stderr)
        return 1

    exercises = document.get("exercises")
    if not isinstance(exercises, list):
        print("ERROR: exercises must be an array", file=sys.stderr)
        return 1
    if not 300 <= len(exercises) <= 500:
        fail(errors, f"exercise count {len(exercises)} is outside the required 300–500 range")
    if document.get("exerciseCount") != len(exercises):
        fail(errors, "exerciseCount does not match the exercises array")
    if not isinstance(document.get("libraryVersion"), int):
        fail(errors, "libraryVersion must be an integer")
    if not document.get("sourceRevision"):
        fail(errors, "sourceRevision is missing")

    seen_ids: set[str] = set()
    seen_names: set[str] = set()
    covered_muscles: set[str] = set()
    for index, exercise in enumerate(exercises):
        label = f"exercise[{index}]"
        exercise_id = exercise.get("id")
        name = exercise.get("canonicalName")
        if not isinstance(exercise_id, str) or not exercise_id.strip():
            fail(errors, f"{label}: missing stable id")
        elif exercise_id in seen_ids:
            fail(errors, f"{label}: duplicate id {exercise_id!r}")
        else:
            seen_ids.add(exercise_id)
        normalized_name = str(name).strip().casefold()
        if not normalized_name:
            fail(errors, f"{label}: missing canonicalName")
        elif normalized_name in seen_names:
            fail(errors, f"{label}: duplicate canonicalName {name!r}")
        else:
            seen_names.add(normalized_name)

        if not exercise.get("equipment"):
            fail(errors, f"{label}: equipment is empty")
        if exercise.get("laterality") not in LATERALITY:
            fail(errors, f"{label}: unsupported laterality")
        if exercise.get("loadType") not in LOAD_TYPES:
            fail(errors, f"{label}: unsupported loadType")
        if exercise.get("builtIn") is not True:
            fail(errors, f"{label}: bundled entries must be builtIn")
        if not exercise.get("source") or not exercise.get("sourceURL"):
            fail(errors, f"{label}: source attribution is incomplete")
        if not exercise.get("license") or not exercise.get("licenseURL"):
            fail(errors, f"{label}: license attribution is incomplete")
        if any(key in exercise for key in ("images", "video", "instructions")):
            fail(errors, f"{label}: media/instruction payload must not be bundled")

        contributions = exercise.get("muscles")
        if not isinstance(contributions, list) or not contributions:
            fail(errors, f"{label}: muscles must be a non-empty array")
            continue
        total = 0.0
        local_muscles: set[str] = set()
        for muscle in contributions:
            muscle_id = muscle.get("muscleId")
            role = muscle.get("role")
            weight = muscle.get("weight")
            if muscle_id not in MUSCLES:
                fail(errors, f"{label}: unknown muscle {muscle_id!r}")
            else:
                covered_muscles.add(muscle_id)
            if muscle_id in local_muscles:
                fail(errors, f"{label}: duplicate muscle {muscle_id!r}")
            local_muscles.add(muscle_id)
            if role not in ROLES:
                fail(errors, f"{label}: unsupported muscle role {role!r}")
            if not isinstance(weight, (int, float)) or not math.isfinite(weight) or weight <= 0:
                fail(errors, f"{label}: invalid muscle weight {weight!r}")
            else:
                total += float(weight)
        if not math.isclose(total, 1.0, abs_tol=0.001):
            fail(errors, f"{label}: muscle weights sum to {total:.6f}, expected 1.0")

    missing_muscles = sorted(MUSCLES - covered_muscles)
    if missing_muscles:
        fail(errors, f"taxonomy has no exercise coverage for: {', '.join(missing_muscles)}")

    if errors:
        print(f"Exercise library validation FAILED ({len(errors)} issue(s)):", file=sys.stderr)
        for message in errors[:100]:
            print(f"  - {message}", file=sys.stderr)
        if len(errors) > 100:
            print(f"  - … {len(errors) - 100} more", file=sys.stderr)
        return 1

    print(
        "Exercise library validation OK: "
        f"{len(exercises)} exercises, {len(seen_ids)} unique IDs, "
        f"{len(covered_muscles)}/{len(MUSCLES)} muscles covered, "
        f"source revision {document['sourceRevision']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
