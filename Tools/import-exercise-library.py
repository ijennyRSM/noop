#!/usr/bin/env python3
"""Build NOOP's offline exercise library from free-exercise-db.

The input is the upstream dist/exercises.json file. The output deliberately
excludes images and instructional prose; NOOP bundles only normalized factual
metadata needed for search, logging, muscle distribution, and attribution.
"""

from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import defaultdict
from pathlib import Path

LIBRARY_VERSION = 1
SOURCE_NAME = "free-exercise-db"
SOURCE_URL = "https://github.com/yuhonas/free-exercise-db"
SOURCE_REVISION = "b0eed061e1c832b3ed815fbaa4b45b3cdc14df49"
SOURCE_LICENSE = "The Unlicense (public domain dedication)"
SOURCE_LICENSE_URL = "https://github.com/yuhonas/free-exercise-db/blob/main/LICENSE"

EQUIPMENT = {
    None: ["other"],
    "": ["other"],
    "body only": ["bodyweight"],
    "e-z curl bar": ["ez_bar"],
    "exercise ball": ["stability_ball"],
    "foam roll": ["foam_roller"],
    "kettlebells": ["kettlebell"],
    "medicine ball": ["medicine_ball"],
    "other": ["other"],
}

MUSCLES = {
    "abdominals": "abdominals",
    "abductors": "abductors",
    "adductors": "adductors",
    "biceps": "biceps",
    "calves": "calves",
    "chest": "chest",
    "forearms": "forearms",
    "glutes": "glutes",
    "hamstrings": "hamstrings",
    "lats": "lats",
    "lower back": "lower_back",
    "middle back": "upper_back",
    "neck": "traps",
    "quadriceps": "quadriceps",
    "traps": "traps",
    "triceps": "triceps",
}

ALIASES = {
    "barbell_squat": ["Back Squat", "Barbell Squat"],
    "romanian_deadlift_with_dumbbells": ["Dumbbell RDL", "Romanian DL"],
    "romanian_deadlift": ["RDL", "Romanian DL"],
    "stiff_legged_barbell_deadlift": ["Stiff-Leg Deadlift", "SLDL"],
    "barbell_deadlift": ["Deadlift", "Conventional Deadlift"],
    "barbell_bench_press_medium_grip": ["Barbell Bench Press", "Bench Press"],
    "dumbbell_bench_press": ["DB Bench Press"],
    "pullups": ["Pull-Up", "Pull Ups"],
    "chin_up": ["Chin-Up", "Chin Ups"],
    "wide_grip_lat_pulldown": ["Lat Pulldown"],
    "seated_cable_rows": ["Seated Cable Row", "Cable Row"],
    "standing_military_press": ["Overhead Press", "Military Press"],
    "side_lateral_raise": ["Lateral Raise", "Side Raise"],
    "face_pull": ["Cable Face Pull"],
    "barbell_hip_thrust": ["Hip Thrust"],
    "bulgarian_split_squat": ["Rear-Foot-Elevated Split Squat", "RFESS"],
}

CANONICAL_OVERRIDES = {
    "barbell_squat": "Barbell Back Squat",
    "seated_cable_rows": "Seated Cable Row",
    "standing_calf_raises": "Standing Calf Raise",
}

# Curated anchors must survive the balancing pass. They cover the common names used in product
# examples and guarantee that important aliases such as RDL remain searchable in every version.
MANDATORY_IDS = {
    "barbell_squat",
    "romanian_deadlift",
    "barbell_deadlift",
    "dumbbell_bench_press",
    "wide_grip_lat_pulldown",
    "seated_cable_rows",
    "standing_calf_raises",
    "pullups",
    "chin_up",
    "standing_military_press",
    "side_lateral_raise",
    "face_pull",
    "leg_press",
}

ALLOWED_CATEGORIES = {
    "strength",
    "powerlifting",
    "olympic weightlifting",
    "strongman",
    "plyometrics",
    "stretching",
}


def slug(value: str) -> str:
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()
    return re.sub(r"_+", "_", re.sub(r"[^a-z0-9]+", "_", value.lower())).strip("_")


def canonical_name(name: str) -> str:
    replacements = {
        "Dumbbell": "Dumbbell",
        "Kettlebell": "Kettlebell",
        "Barbell": "Barbell",
        "E-Z": "EZ",
    }
    result = re.sub(r"\s+", " ", name.replace("_", " ")).strip()
    for old, new in replacements.items():
        result = result.replace(old, new)
    return result


def equipment_ids(raw: str | None) -> list[str]:
    if raw in EQUIPMENT:
        return EQUIPMENT[raw]
    return [slug(raw or "other")]


def deltoid_for(name: str) -> str:
    lower = name.lower()
    if any(token in lower for token in ("rear", "reverse fly", "face pull")):
        return "rear_delts"
    if any(token in lower for token in ("lateral", "side raise", "upright row")):
        return "side_delts"
    return "front_delts"


def muscle_id(raw: str, name: str) -> str | None:
    lower = name.lower()
    if raw == "shoulders":
        return deltoid_for(name)
    if raw == "abdominals" and any(
        token in lower for token in ("oblique", "side bend", "russian twist", "wood chop")
    ):
        return "obliques"
    if raw in ("quadriceps", "abdominals") and any(
        token in lower for token in ("hip flexor", "psoas", "knee raise", "leg raise")
    ):
        return "hip_flexors"
    if raw == "calves" and "tibialis" in lower:
        return "tibialis"
    if raw == "lower back" and any(
        token in lower for token in ("back extension", "hyperextension", "good morning")
    ):
        return "erector_spinae"
    return MUSCLES.get(raw)


def movement_pattern(name: str, force: str | None, mechanic: str | None) -> str:
    n = name.lower()
    checks = [
        ("squat", ("squat", "leg press")),
        ("hinge", ("deadlift", "good morning", "hip thrust", "pull through")),
        ("lunge", ("lunge", "split squat", "step-up", "step up")),
        ("horizontal_push", ("bench press", "push-up", "push up", "chest press", "fly")),
        ("vertical_push", ("shoulder press", "military press", "overhead press", "push press")),
        ("vertical_pull", ("pull-up", "pullup", "chin-up", "chin up", "pulldown")),
        ("horizontal_pull", ("row", "face pull")),
        ("carry", ("carry", "farmer", "yoke walk")),
        ("rotation", ("rotation", "wood chop", "twist")),
        ("locomotion", ("jump", "sprint", "run", "walk")),
        ("calf_raise", ("calf raise",)),
        ("arm_flexion", ("curl",)),
        ("arm_extension", ("triceps", "extension", "dip")),
        ("core", ("crunch", "plank", "sit-up", "sit up", "ab ")),
        ("mobility", ("stretch", "foam roll")),
    ]
    for pattern, tokens in checks:
        if any(token in n for token in tokens):
            return pattern
    if mechanic == "isolation":
        return "isolation"
    return force or "other"


def laterality(name: str) -> str:
    n = name.lower()
    if any(token in n for token in ("single-arm", "single arm", "one-arm", "one arm",
                                    "single-leg", "single leg", "unilateral", "alternate")):
        return "unilateral"
    return "bilateral"


def bodyweight_coefficient(name: str) -> float | None:
    n = name.lower()
    if any(token in n for token in ("pull-up", "pullup", "chin-up", "dip")):
        return 0.90
    if any(token in n for token in ("push-up", "push up")):
        return 0.65
    if any(token in n for token in ("squat", "lunge", "step-up", "step up")):
        return 0.75
    if any(token in n for token in ("plank", "crunch", "sit-up", "sit up")):
        return 0.35
    return 0.50


def normalize_exercise(item: dict) -> dict | None:
    name = canonical_name(item["name"])
    identifier = slug(item.get("id") or name)
    name = CANONICAL_OVERRIDES.get(identifier, name)
    primary = [muscle_id(m, name) for m in item.get("primaryMuscles", [])]
    secondary = [muscle_id(m, name) for m in item.get("secondaryMuscles", [])]
    primary = list(dict.fromkeys(m for m in primary if m))
    secondary = list(dict.fromkeys(m for m in secondary if m and m not in primary))
    if not primary:
        return None

    contributions = []
    for muscle in primary:
        contributions.append({"muscleId": muscle, "role": "primary", "weight": 1.0})
    for muscle in secondary:
        contributions.append({"muscleId": muscle, "role": "secondary", "weight": 0.45})
    total = sum(part["weight"] for part in contributions)
    for part in contributions:
        part["weight"] = round(part["weight"] / total, 5)

    equipment = equipment_ids(item.get("equipment"))
    is_bodyweight = equipment == ["bodyweight"]
    aliases = list(dict.fromkeys(ALIASES.get(identifier, [])))
    return {
        "id": identifier,
        "canonicalName": name,
        "aliases": aliases,
        "equipment": equipment,
        "movementPattern": movement_pattern(name, item.get("force"), item.get("mechanic")),
        "laterality": laterality(name),
        "loadType": "bodyweight" if is_bodyweight else "external",
        "muscles": contributions,
        "effectiveBodyweightCoefficient": bodyweight_coefficient(name) if is_bodyweight else None,
        "source": SOURCE_NAME,
        "sourceURL": SOURCE_URL,
        "license": SOURCE_LICENSE,
        "licenseURL": SOURCE_LICENSE_URL,
        "libraryVersion": LIBRARY_VERSION,
        "builtIn": True,
    }


def select_balanced(exercises: list[dict], count: int) -> list[dict]:
    """Round-robin by primary muscle/equipment before filling alphabetically."""
    mandatory = sorted(
        (exercise for exercise in exercises if exercise["id"] in MANDATORY_IDS),
        key=lambda exercise: exercise["canonicalName"].lower(),
    )
    missing = MANDATORY_IDS - {exercise["id"] for exercise in mandatory}
    if missing:
        raise SystemExit(f"mandatory curated exercises missing from source: {sorted(missing)}")
    buckets: dict[tuple[str, str], list[dict]] = defaultdict(list)
    mandatory_ids = {exercise["id"] for exercise in mandatory}
    for ex in exercises:
        if ex["id"] in mandatory_ids:
            continue
        key = (ex["muscles"][0]["muscleId"], ex["equipment"][0])
        buckets[key].append(ex)
    for values in buckets.values():
        values.sort(key=lambda ex: (ex["canonicalName"].lower(), ex["id"]))
    chosen: list[dict] = list(mandatory)
    keys = sorted(buckets)
    while len(chosen) < count and keys:
        next_keys = []
        for key in keys:
            if buckets[key] and len(chosen) < count:
                chosen.append(buckets[key].pop(0))
            if buckets[key]:
                next_keys.append(key)
        keys = next_keys
    return sorted(chosen, key=lambda ex: ex["canonicalName"].lower())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--count", type=int, default=420)
    args = parser.parse_args()

    raw = json.loads(args.source.read_text(encoding="utf-8"))
    normalized = []
    seen = set()
    for item in raw:
        if item.get("category") not in ALLOWED_CATEGORIES:
            continue
        ex = normalize_exercise(item)
        if ex is None or ex["id"] in seen:
            continue
        seen.add(ex["id"])
        normalized.append(ex)
    if len(normalized) < args.count:
        raise SystemExit(f"only {len(normalized)} valid exercises for requested {args.count}")
    selected = select_balanced(normalized, args.count)
    document = {
        "schemaVersion": 1,
        "libraryVersion": LIBRARY_VERSION,
        "source": SOURCE_NAME,
        "sourceRevision": SOURCE_REVISION,
        "license": SOURCE_LICENSE,
        "licenseURL": SOURCE_LICENSE_URL,
        "exerciseCount": len(selected),
        "exercises": selected,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n",
                           encoding="utf-8")
    print(f"Wrote {len(selected)} exercises to {args.output}")


if __name__ == "__main__":
    main()
