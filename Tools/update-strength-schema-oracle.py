#!/usr/bin/env python3
"""Pin the iOS-only strength schema in both cross-platform oracle copies."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ORACLES = [
    ROOT / "Packages/WhoopStore/Tests/WhoopStoreTests/Resources/schema_oracle.json",
    ROOT / "android/app/src/test/resources/schema_oracle.json",
]


def column(name: str, affinity: str, *, nullable: bool = False,
           default: str | None = None) -> dict:
    return {
        "name": name,
        "affinity": affinity,
        "notNull": not nullable,
        "default": default,
    }


def index(name: str, *columns: str) -> dict:
    return {"name": name, "unique": False, "columns": list(columns)}


def table(columns: list[dict], primary_key: list[str],
          indices: list[dict] | None = None) -> dict:
    return {
        "platform": "ios_only",
        "columns": columns,
        "primaryKey": primary_key,
        "indices": sorted(indices or [], key=lambda item: item["name"]),
    }


TEXT_PK = lambda name="id": column(name, "TEXT", nullable=True)
INT_PK = lambda name="rowId": column(name, "INTEGER", nullable=True)
STRENGTH_TABLES = {
    "exerciseDefinition": table([
        TEXT_PK(), column("canonicalName", "TEXT"), column("equipmentJSON", "TEXT"),
        column("movementPattern", "TEXT"), column("laterality", "TEXT"),
        column("loadType", "TEXT"), column("effectiveBodyweightCoefficient", "REAL", nullable=True),
        column("source", "TEXT"), column("sourceURL", "TEXT"), column("license", "TEXT"),
        column("licenseURL", "TEXT"), column("libraryVersion", "INTEGER"),
        column("updatedAt", "INTEGER"),
    ], ["id"]),
    "exerciseAlias": table([
        INT_PK(), column("exerciseId", "TEXT"), column("alias", "TEXT"),
        column("normalizedAlias", "TEXT"),
    ], ["rowId"], [index("idx_exerciseAlias_normalized", "normalizedAlias")]),
    "exerciseMuscle": table([
        INT_PK(), column("exerciseId", "TEXT"), column("muscleId", "TEXT"),
        column("role", "TEXT"), column("contribution", "REAL"),
    ], ["rowId"], [index("idx_exerciseMuscle_muscle", "muscleId", "exerciseId")]),
    "customExercise": table([
        TEXT_PK(), column("canonicalName", "TEXT"), column("aliasesJSON", "TEXT"),
        column("equipmentJSON", "TEXT"), column("movementPattern", "TEXT"),
        column("laterality", "TEXT"), column("loadType", "TEXT"),
        column("musclesJSON", "TEXT"),
        column("effectiveBodyweightCoefficient", "REAL", nullable=True),
        column("createdAt", "INTEGER"), column("updatedAt", "INTEGER"),
        column("deletedAt", "INTEGER", nullable=True),
    ], ["id"], [index("idx_customExercise_name", "canonicalName")]),
    "strengthSession": table([
        TEXT_PK(), column("deviceId", "TEXT"),
        column("workoutStartTs", "INTEGER", nullable=True), column("startedAt", "INTEGER"),
        column("endedAt", "INTEGER", nullable=True), column("title", "TEXT"),
        column("status", "TEXT"), column("source", "TEXT"),
        column("sessionRPE", "REAL", nullable=True), column("notes", "TEXT", nullable=True),
        column("quickRegion", "TEXT", nullable=True),
        column("quickIntensity", "TEXT", nullable=True), column("confidence", "TEXT"),
        column("cardiovascularEffort", "REAL", nullable=True),
        column("muscularLoad", "REAL", nullable=True),
        column("totalTrainingLoad", "REAL", nullable=True),
        column("createdAt", "INTEGER"), column("updatedAt", "INTEGER"),
    ], ["id"], [
        index("idx_strengthSession_device_started", "deviceId", "startedAt"),
        index("idx_strengthSession_status", "status", "updatedAt"),
    ]),
    "strengthSessionExercise": table([
        TEXT_PK(), column("sessionId", "TEXT"), column("exerciseId", "TEXT"),
        column("snapshotName", "TEXT"), column("orderIndex", "INTEGER"),
        column("notes", "TEXT", nullable=True), column("createdAt", "INTEGER"),
        column("updatedAt", "INTEGER"),
    ], ["id"], [
        index("idx_strengthSessionExercise_exercise", "exerciseId"),
        index("idx_strengthSessionExercise_session", "sessionId", "orderIndex"),
    ]),
    "strengthSet": table([
        TEXT_PK(), column("sessionExerciseId", "TEXT"), column("setIndex", "INTEGER"),
        column("setType", "TEXT"), column("weightKg", "REAL", nullable=True),
        column("reps", "INTEGER", nullable=True), column("rpe", "REAL", nullable=True),
        column("rir", "REAL", nullable=True), column("side", "TEXT"),
        column("completed", "NUMERIC", default="0"),
        column("reachedFailure", "NUMERIC", default="0"),
        column("notes", "TEXT", nullable=True), column("createdAt", "INTEGER"),
        column("updatedAt", "INTEGER"),
    ], ["id"], [index("idx_strengthSet_exercise", "sessionExerciseId", "setIndex")]),
    "workoutTemplate": table([
        TEXT_PK(), column("name", "TEXT"), column("notes", "TEXT", nullable=True),
        column("createdAt", "INTEGER"), column("updatedAt", "INTEGER"),
    ], ["id"]),
    "workoutTemplateExercise": table([
        TEXT_PK(), column("templateId", "TEXT"), column("exerciseId", "TEXT"),
        column("snapshotName", "TEXT"), column("orderIndex", "INTEGER"),
        column("notes", "TEXT", nullable=True),
    ], ["id"]),
    "workoutTemplateSet": table([
        TEXT_PK(), column("templateExerciseId", "TEXT"), column("setIndex", "INTEGER"),
        column("setType", "TEXT"), column("targetWeightKg", "REAL", nullable=True),
        column("targetReps", "INTEGER", nullable=True),
        column("targetRPE", "REAL", nullable=True),
        column("targetRIR", "REAL", nullable=True),
    ], ["id"]),
    "dailyMuscleLoad": table([
        column("deviceId", "TEXT"), column("day", "TEXT"), column("muscleId", "TEXT"),
        column("side", "TEXT"), column("rawStimulus", "REAL"),
        column("normalizedLoad", "REAL"), column("workingSets", "INTEGER"),
        column("confidence", "TEXT"), column("updatedAt", "INTEGER"),
    ], ["deviceId", "day", "muscleId", "side"], [
        index("idx_dailyMuscleLoad_device_muscle_day", "deviceId", "muscleId", "day"),
    ]),
    "strengthSessionMuscleLoad": table([
        column("sessionId", "TEXT"), column("deviceId", "TEXT"), column("day", "TEXT"),
        column("trainedAt", "INTEGER"), column("muscleId", "TEXT"),
        column("side", "TEXT"), column("rawStimulus", "REAL"),
        column("normalizedLoad", "REAL"), column("workingSets", "INTEGER"),
        column("confidence", "TEXT"),
    ], ["sessionId", "muscleId", "side"], [
        index("idx_strengthSessionMuscleLoad_device_day",
              "deviceId", "day", "muscleId", "side"),
    ]),
    "muscleResidualSnapshot": table([
        column("deviceId", "TEXT"), column("capturedAt", "INTEGER"),
        column("muscleId", "TEXT"), column("side", "TEXT"),
        column("residualLoad", "REAL"), column("confidence", "TEXT"),
        column("lastTrainedAt", "INTEGER", nullable=True),
    ], ["deviceId", "capturedAt", "muscleId", "side"], [
        index("idx_muscleResidual_latest",
              "deviceId", "muscleId", "side", "capturedAt"),
    ]),
    "exerciseFavorite": table([
        TEXT_PK("exerciseId"), column("createdAt", "INTEGER"),
    ], ["exerciseId"]),
    "exerciseRecent": table([
        TEXT_PK("exerciseId"), column("lastUsedAt", "INTEGER"),
        column("useCount", "INTEGER", default="1"),
    ], ["exerciseId"]),
}


def main() -> None:
    documents = [json.loads(path.read_text(encoding="utf-8")) for path in ORACLES]
    if documents[0] != documents[1]:
        raise SystemExit("schema oracle copies differ before update")
    document = documents[0]
    migrations = document["grdbMigrations"]
    if "v32-strength-training" not in migrations:
        migrations.append("v32-strength-training")
    document["tables"].update(STRENGTH_TABLES)
    encoded = json.dumps(document, indent=2, ensure_ascii=True) + "\n"
    for path in ORACLES:
        path.write_text(encoded, encoding="utf-8")
    print(f"Pinned {len(STRENGTH_TABLES)} iOS-only strength tables in both schema oracles")


if __name__ == "__main__":
    main()
