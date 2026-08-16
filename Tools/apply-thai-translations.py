#!/usr/bin/env python3
"""Apply the reviewed Thai translation tables to every Apple String Catalog.

The English catalog remains authoritative.  This script refuses unknown keys,
missing Thai values, and incompatible printf placeholders.  It is safe to run
after upstream catalog updates: ``--check`` reports drift without changing a
file, while the default mode rewrites only the ``th`` localization units.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
TABLES = (
    ("Strand/Resources/Localizable.xcstrings", "Tools/translations/th.json"),
    (
        "Packages/StrandDesign/Sources/StrandDesign/Resources/Localizable.xcstrings",
        "Tools/translations/design-th.json",
    ),
    ("NOOPWatch/Localizable.xcstrings", "Tools/translations/watch-th.json"),
    (
        "NOOPWatchComplications/Localizable.xcstrings",
        "Tools/translations/watch-complications-th.json",
    ),
)
FORMAT = re.compile(r"%(?:(?:\d+)\$)?(@|(?:hh|h|ll|l|q|z|t|j)?[diuoxXfFeEgGaAcCsSp]|%)")


def signature(value: str) -> list[str]:
    # Thai may place a value earlier in the sentence using positional printf
    # arguments (for example ``%3$@``).  Type/count parity is the safety rule;
    # ordering is valid when positions are explicit.
    return sorted(FORMAT.findall(value))


def english_value(key: str, entry: dict) -> str:
    unit = (((entry.get("localizations") or {}).get("en") or {}).get("stringUnit") or {})
    return unit.get("value", key)


def process(catalog_path: str, table_path: str, *, check: bool) -> tuple[int, list[str]]:
    catalog_file = ROOT / catalog_path
    table_file = ROOT / table_path
    catalog = json.loads(catalog_file.read_text(encoding="utf-8"))
    table = json.loads(table_file.read_text(encoding="utf-8"))
    strings = catalog.get("strings", {})
    problems: list[str] = []
    changed = 0

    unknown = sorted(set(table) - set(strings))
    for key in unknown:
        problems.append(f"{catalog_path}: translation key is absent from catalog: {key!r}")

    expected = {
        key
        for key, entry in strings.items()
        if key and entry.get("shouldTranslate") is not False
    }
    for key in sorted(expected - set(table)):
        problems.append(f"{catalog_path}: missing Thai translation: {key!r}")

    for key in sorted(expected & set(table)):
        entry = strings[key]
        source = english_value(key, entry)
        translated = table[key]
        if signature(source) != signature(translated):
            problems.append(
                f"{catalog_path}: placeholders differ for {key!r}: "
                f"{signature(source)!r} != {signature(translated)!r}"
            )
            continue
        wanted = {"stringUnit": {"state": "translated", "value": translated}}
        localizations = entry.setdefault("localizations", {})
        if localizations.get("th") != wanted:
            changed += 1
            if not check:
                localizations["th"] = wanted

    if not check and changed and not problems:
        catalog_file.write_text(
            json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    return changed, problems


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    total = 0
    problems: list[str] = []
    for catalog_path, table_path in TABLES:
        changed, found = process(catalog_path, table_path, check=args.check)
        total += changed
        problems.extend(found)
        action = "need updates" if args.check else "updated"
        print(f"{catalog_path}: {changed} Thai unit(s) {action}")
    for problem in problems:
        print("ERROR: " + problem)
    if problems:
        return 1
    print(f"Thai catalog summary: {total} unit(s) {'differ' if args.check else 'written'}; no errors")
    return 1 if args.check and total else 0


if __name__ == "__main__":
    raise SystemExit(main())
