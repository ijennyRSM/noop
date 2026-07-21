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

# Guard against recurring literal machine-translation senses in health UI.
# These are deliberately source-contextual so an otherwise valid Thai word is
# rejected only when the English source proves a different product meaning.
CONTEXTUAL_TERM_RULES = [
    (re.compile(r"\b(?:sleep stages?|sleep staging|stage breakdown|light sleep)\b", re.I),
     re.compile(r"เวที|พังทลาย|แสดงละคร|จัดฉาก|จัดเตรียม|แสงสว่าง"), "sleep-stage terminology"),
    (re.compile(r"\bbuzz(?:es|ed|ing)?\b", re.I),
     re.compile(r"หึ่ง|พึมพำ|กระหึ่ม|ฉวัดเฉวียน"), "strap vibration terminology"),
    (re.compile(r"\bHRV?\b"), re.compile(r"ทรัพยากรบุคคล"), "heart-rate abbreviation"),
    (re.compile(r"\bbackfill(?:s|ed|ing)?\b", re.I), re.compile(r"ทดแทน"), "historical-data import"),
    (re.compile(r"\bCharge\b"),
     re.compile(r"ค่าใช้จ่าย|ประจุไฟฟ้า|การเรียกเก็บเงิน|พลังงานการนำกลับมาใช้ใหม่"),
     "Charge score terminology"),
    (re.compile(r"\bStrain\b", re.I),
     re.compile(r"บาดเจ็บ|น้ำหนักร่างกาย|น้ำหนักบรรทุก|โหลดร่างกาย"),
     "Strain score terminology"),
]


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


def placeholder_order_compatible(source: str, translation: str) -> bool:
    """Require the original argument order unless the translation uses positions."""
    source_tokens = [item for item in PLACEHOLDER_RE.findall(source) if item != "%%"]
    translated_tokens = [item for item in PLACEHOLDER_RE.findall(translation) if item != "%%"]
    source_arguments: dict[int, str] = {}
    for fallback_position, token in enumerate(source_tokens, 1):
        match = re.match(r"^%(?:(\d+)\$)?", token)
        position = int(match.group(1)) if match and match.group(1) else fallback_position
        source_arguments[position] = re.sub(r"^%(?:\d+)\$", "%", token)

    translated: list[tuple[int | None, str]] = []
    for token in translated_tokens:
        match = re.match(r"^%(?:(\d+)\$)?", token)
        position = int(match.group(1)) if match and match.group(1) else None
        translated.append((position, re.sub(r"^%(?:\d+)\$", "%", token)))

    if any(position is not None for position, _ in translated):
        return all(
            position is not None and source_arguments.get(position) == kind
            for position, kind in translated
        )
    source_call_order = [source_arguments[position] for position in sorted(source_arguments)]
    return source_call_order == [kind for _, kind in translated]


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
                compatible_sources = [
                    source_value for source_value in source_values
                    if thai_signature == signature(source_value)
                ]
                if not compatible_sources:
                    failures.append(
                        f"{relative}: placeholder mismatch for {source!r}: "
                        f"source={[dict(signature(item)) for item in source_values]} "
                        f"th={dict(thai_signature)}"
                    )
                    mismatches += 1
                elif not any(placeholder_order_compatible(source_value, value) for source_value in compatible_sources):
                    failures.append(
                        f"{relative}: placeholder order/type mismatch for {source!r}: {value!r}"
                    )
                    mismatches += 1
                for brand in ("NOOP", "WHOOP"):
                    if any(brand in source_value for source_value in source_values) and brand not in value:
                        failures.append(f"{relative}: brand name {brand} was not preserved for {source!r}")
                source_text = "\n".join(source_values)
                for source_pattern, thai_pattern, context in CONTEXTUAL_TERM_RULES:
                    if source_pattern.search(source_text) and thai_pattern.search(value):
                        failures.append(
                            f"{relative}: suspicious literal translation ({context}) for {source!r}: {value!r}"
                        )
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
