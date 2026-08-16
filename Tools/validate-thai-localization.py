#!/usr/bin/env python3
"""Validate Thai Apple localization coverage and formatting safety."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CATALOGS = (
    ROOT / "Strand/Resources/Localizable.xcstrings",
    ROOT / "Packages/StrandDesign/Sources/StrandDesign/Resources/Localizable.xcstrings",
    ROOT / "NOOPWatch/Localizable.xcstrings",
    ROOT / "NOOPWatchComplications/Localizable.xcstrings",
)
INFO_PLISTS = {
    ROOT / "StrandiOS/Resources/th.lproj/InfoPlist.strings": {
        "CFBundleDisplayName",
        "NSBluetoothAlwaysUsageDescription",
        "NSLocationWhenInUseUsageDescription",
        "NSHealthShareUsageDescription",
        "NSHealthUpdateUsageDescription",
        "NSMotionUsageDescription",
    },
    ROOT / "NOOPWatch/th.lproj/InfoPlist.strings": {
        "CFBundleDisplayName",
        "NSHealthShareUsageDescription",
        "NSHealthUpdateUsageDescription",
    },
    ROOT / "StrandiOSWidgets/th.lproj/InfoPlist.strings": {"CFBundleDisplayName"},
    ROOT / "NOOPWatchComplications/th.lproj/InfoPlist.strings": {"CFBundleDisplayName"},
}
FORMAT = re.compile(r"%(?:(?:\d+)\$)?(@|(?:hh|h|ll|l|q|z|t|j)?[diuoxXfFeEgGaAcCsSp]|%)")
PLIST_KEY = re.compile(r'^\s*"([^"]+)"\s*=')


def signature(value: str) -> list[str]:
    return sorted(FORMAT.findall(value))


def units(localization: dict) -> list[dict]:
    found: list[dict] = []

    def walk(value: object) -> None:
        if isinstance(value, dict):
            unit = value.get("stringUnit")
            if isinstance(unit, dict):
                found.append(unit)
            for child in value.values():
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)

    walk(localization)
    return found


def english_value(key: str, entry: dict) -> str:
    english = ((entry.get("localizations") or {}).get("en") or {})
    english_units = units(english)
    if english_units:
        return english_units[0].get("value", key)
    return key


def validate_catalog(path: Path) -> tuple[int, list[str]]:
    errors: list[str] = []
    try:
        catalog = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return 0, [f"{path.relative_to(ROOT)}: malformed JSON: {error}"]
    if catalog.get("sourceLanguage") != "en":
        errors.append(f"{path.relative_to(ROOT)}: sourceLanguage must remain en")
    translated = 0
    for key, entry in catalog.get("strings", {}).items():
        if not key or entry.get("shouldTranslate") is False:
            continue
        thai = ((entry.get("localizations") or {}).get("th") or {})
        thai_units = units(thai)
        if not thai_units:
            errors.append(f"{path.relative_to(ROOT)}: missing th for {key!r}")
            continue
        if any(unit.get("state") != "translated" or not unit.get("value") for unit in thai_units):
            errors.append(f"{path.relative_to(ROOT)}: incomplete th for {key!r}")
            continue
        source = english_value(key, entry)
        for unit in thai_units:
            value = unit.get("value", "")
            if signature(source) != signature(value):
                errors.append(
                    f"{path.relative_to(ROOT)}: placeholders differ for {key!r}: "
                    f"{signature(source)!r} != {signature(value)!r}"
                )
        translated += 1
    print(f"{path.relative_to(ROOT)}: {translated} Thai entries")
    return translated, errors


def validate_info_plist(path: Path, required: set[str]) -> list[str]:
    if not path.exists():
        return [f"{path.relative_to(ROOT)}: missing"]
    keys = {
        match.group(1)
        for line in path.read_text(encoding="utf-8").splitlines()
        if (match := PLIST_KEY.match(line))
    }
    missing = required - keys
    if missing:
        return [f"{path.relative_to(ROOT)}: missing keys {sorted(missing)!r}"]
    print(f"{path.relative_to(ROOT)}: permission/display strings present")
    return []


def main() -> int:
    total = 0
    errors: list[str] = []
    for catalog in CATALOGS:
        count, found = validate_catalog(catalog)
        total += count
        errors.extend(found)
    for path, required in INFO_PLISTS.items():
        errors.extend(validate_info_plist(path, required))
    if errors:
        for error in errors:
            print("ERROR: " + error, file=sys.stderr)
        print(f"Thai localization validation failed with {len(errors)} error(s).")
        return 1
    print(f"Thai localization validation passed: {total} translated entries; English fallback retained.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
