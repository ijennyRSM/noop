#!/usr/bin/env python3
"""Validate Thai Apple String Catalog coverage and format safety.

Uses only the Python standard library so the same command works locally and in
GitHub Actions. Entries explicitly marked shouldTranslate=false are ignored.
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CATALOGS = [
    ROOT / "Strand" / "Resources" / "Localizable.xcstrings",
    ROOT / "Packages" / "StrandDesign" / "Sources" / "StrandDesign" / "Resources" / "Localizable.xcstrings",
    ROOT / "StrandiOSWidgets" / "Localizable.xcstrings",
    ROOT / "NOOPWatch" / "Localizable.xcstrings",
    ROOT / "NOOPWatchComplications" / "Localizable.xcstrings",
]
THAI_INFO_PLISTS = {
    ROOT / "StrandiOS" / "Resources" / "th.lproj" / "InfoPlist.strings": {
        "CFBundleDisplayName",
        "NSBluetoothAlwaysUsageDescription",
        "NSLocationWhenInUseUsageDescription",
        "NSHealthShareUsageDescription",
        "NSHealthUpdateUsageDescription",
        "NSMotionUsageDescription",
    },
    ROOT / "StrandiOSWidgets" / "th.lproj" / "InfoPlist.strings": {"CFBundleDisplayName"},
    ROOT / "NOOPWatch" / "th.lproj" / "InfoPlist.strings": {
        "CFBundleDisplayName",
        "NSHealthShareUsageDescription",
        "NSHealthUpdateUsageDescription",
    },
    ROOT / "NOOPWatchComplications" / "th.lproj" / "InfoPlist.strings": {"CFBundleDisplayName"},
}

# Covers printf placeholders emitted by Swift String Catalog extraction,
# including positional, precision, length-modified, object and literal-percent forms.
PLACEHOLDER_RE = re.compile(
    r"%%|%(?:(?:\d+)\$)?[-+0 #'I]*(?:\d+|\*)?(?:\.\d+|\.\*)?"
    r"(?:hh|h|ll|l|q|z|t|j)?[diuoxXfFeEgGaAcCsSp@]"
)
STRING_PAIR_RE = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$')

ALLOWED_IDENTICAL_WORDS = {
    "NOOP", "WHOOP", "Oura", "Polar", "Apple", "HealthKit", "Bluetooth", "iPhone",
    "iOS", "macOS", "watchOS", "HRV", "RHR", "HR", "BPM", "SpO", "GPS", "CSV",
    "AI", "BLE", "RMSSD", "ECG", "API", "SDK", "URL", "JSON", "SQL", "ZIP", "WHO",
    "bpm", "ms", "kcal", "km", "mi", "kg", "lb", "h", "min", "sec", "Claude",
    "OpenAI", "Anthropic", "Gemini", "Ollama", "Siri", "CrossFit", "Tanaka", "Health",
    "D", "DUR", "EST", "FW", "REM", "Z", "F", "MG", "http", "localhost",
    "m", "n", "s", "v",
}


def string_units(localization: object) -> list[dict]:
    units: list[dict] = []

    def walk(node: object) -> None:
        if not isinstance(node, dict):
            return
        unit = node.get("stringUnit")
        if isinstance(unit, dict):
            units.append(unit)
        for key, value in node.items():
            if key != "stringUnit":
                walk(value)

    walk(localization)
    return units


def signature(value: str) -> Counter[str]:
    # Positional markers change ordering, not the underlying argument type.
    # Treat `%2$@` as compatible with `%@` while still checking the complete
    # count and conversion/precision/length modifier of every placeholder.
    return Counter(re.sub(r"^%(?:\d+)\$", "%", item) for item in PLACEHOLDER_RE.findall(value))


def suspicious_identical(source: str, thai: str) -> bool:
    if source != thai:
        return False
    if re.fullmatch(r"[0-9a-fA-F]{16,}", source):
        return False
    scrubbed = PLACEHOLDER_RE.sub(" ", source)
    words = set(re.findall(r"[A-Za-z]+", scrubbed))
    return bool(words - ALLOWED_IDENTICAL_WORDS)


def parse_strings_file(path: Path) -> dict[str, str]:
    pairs: dict[str, str] = {}
    for line_number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if not line.strip() or line.lstrip().startswith(("//", "/*", "*")):
            continue
        match = STRING_PAIR_RE.match(line)
        if not match:
            raise ValueError(f"{path.relative_to(ROOT)}:{line_number}: malformed .strings line")
        pairs[match.group(1)] = match.group(2)
    return pairs


def main() -> int:
    failures: list[str] = []
    warnings: list[str] = []
    total_entries = 0
    total_translated = 0

    print("Thai localization validation")
    print("============================")

    for path in CATALOGS:
        relative = path.relative_to(ROOT)
        if not path.is_file():
            failures.append(f"missing catalog: {relative}")
            continue
        try:
            catalog = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            failures.append(f"invalid JSON: {relative}: {error}")
            continue

        if catalog.get("sourceLanguage") != "en":
            failures.append(f"{relative}: sourceLanguage must remain en")

        strings = catalog.get("strings")
        if not isinstance(strings, dict):
            failures.append(f"{relative}: strings must be a JSON object")
            continue

        checked = 0
        translated = 0
        mismatches = 0
        missing = 0
        for source, entry in strings.items():
            if not isinstance(entry, dict):
                failures.append(f"{relative}: malformed entry for {source!r}")
                continue
            if entry.get("shouldTranslate") is False:
                continue
            checked += 1
            thai = (entry.get("localizations") or {}).get("th")
            units = string_units(thai)
            if not units or any(unit.get("state") != "translated" or not isinstance(unit.get("value"), str) for unit in units):
                failures.append(f"{relative}: missing/incomplete th translation: {source!r}")
                missing += 1
                continue
            translated += 1
            english_units = string_units((entry.get("localizations") or {}).get("en"))
            source_values = [
                unit["value"] for unit in english_units if isinstance(unit.get("value"), str)
            ] or [source]
            for unit in units:
                value = unit["value"]
                thai_signature = signature(value)
                if not any(thai_signature == signature(source_value) for source_value in source_values):
                    failures.append(
                        f"{relative}: placeholder mismatch for {source!r}: "
                        f"source={[dict(signature(item)) for item in source_values]} "
                        f"th={dict(thai_signature)}"
                    )
                    mismatches += 1
                for brand in ("NOOP", "WHOOP"):
                    if any(brand in source_value for source_value in source_values) and brand not in value:
                        failures.append(f"{relative}: brand name {brand} was not preserved for {source!r}")
                if suspicious_identical(source_values[0], value):
                    warnings.append(f"{relative}: review identical English/Thai value: {source!r}")

        total_entries += checked
        total_translated += translated
        print(f"{relative}: {translated}/{checked} translated, missing={missing}, placeholder_mismatches={mismatches}")

    for path, required_keys in THAI_INFO_PLISTS.items():
        relative = path.relative_to(ROOT)
        if not path.is_file():
            failures.append(f"missing Thai InfoPlist localization: {relative}")
            continue
        try:
            pairs = parse_strings_file(path)
        except (OSError, UnicodeError, ValueError) as error:
            failures.append(str(error))
            continue
        missing_keys = sorted(required_keys - pairs.keys())
        if missing_keys:
            failures.append(f"{relative}: missing keys {missing_keys}")
        non_thai = sorted(
            key for key in required_keys
            if key != "CFBundleDisplayName" and key in pairs and not re.search(r"[\u0e00-\u0e7f]", pairs[key])
        )
        if non_thai:
            failures.append(f"{relative}: values contain no Thai text for {non_thai}")
        print(f"{relative}: {len(required_keys) - len(missing_keys)}/{len(required_keys)} required keys")

    print("----------------------------")
    print(f"Catalog summary: {total_translated}/{total_entries} Thai translations")
    if warnings:
        print(f"Review warnings: {len(warnings)}")
        for warning in warnings[:25]:
            print(f"  WARN {warning}")
        if len(warnings) > 25:
            print(f"  ... {len(warnings) - 25} more")
    if failures:
        print(f"FAIL: {len(failures)} problem(s)", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return 1
    print("OK: Thai catalogs are valid, complete, and format-compatible.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
