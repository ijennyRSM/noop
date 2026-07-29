#!/usr/bin/env python3
"""Validate Thai String Catalog coverage and format safety without dependencies."""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CATALOGS = (
    ROOT / "Strand/Resources/Localizable.xcstrings",
    ROOT / "Packages/StrandDesign/Sources/StrandDesign/Resources/Localizable.xcstrings",
    ROOT / "StrandiOSWidgets/Localizable.xcstrings",
    ROOT / "NOOPWatch/Localizable.xcstrings",
    ROOT / "NOOPWatchComplications/Localizable.xcstrings",
)
BASELINE = ROOT / "Tools/i18n-dx-required-keys.json"
PLACEHOLDER = re.compile(
    r"%%|%(?:(?:\d+)\$)?[-+0 #'I]*(?:\d+|\*)?(?:\.\d+|\.\*)?"
    r"(?:hh|h|ll|l|q|z|t|j)?[diuoxXfFeEgGaAcCsSp@]"
)
PAIR = re.compile(
    r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$'
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
    ROOT / "StrandiOSWidgets/th.lproj/InfoPlist.strings": {
        "CFBundleDisplayName"
    },
    ROOT / "NOOPWatch/th.lproj/InfoPlist.strings": {
        "CFBundleDisplayName",
        "NSHealthShareUsageDescription",
        "NSHealthUpdateUsageDescription",
    },
    ROOT / "NOOPWatchComplications/th.lproj/InfoPlist.strings": {
        "CFBundleDisplayName"
    },
}


def units(node: object) -> list[str]:
    result: list[str] = []
    if not isinstance(node, dict):
        return result
    unit = node.get("stringUnit")
    if isinstance(unit, dict) and isinstance(unit.get("value"), str):
        result.append(unit["value"])
    for key, value in node.items():
        if key != "stringUnit":
            result.extend(units(value))
    return result


def signature(value: str) -> Counter[str]:
    return Counter(
        re.sub(r"^%(?:\d+)\$", "%", token)
        for token in PLACEHOLDER.findall(value)
    )


def parse_strings(path: Path) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for number, line in enumerate(
        path.read_text(encoding="utf-8-sig").splitlines(),
        1,
    ):
        if not line.strip() or line.lstrip().startswith(("//", "/*", "*")):
            continue
        match = PAIR.match(line)
        if not match:
            raise ValueError(f"{path.relative_to(ROOT)}:{number}: malformed")
        parsed[match.group(1)] = match.group(2)
    return parsed


def main() -> int:
    failures: list[str] = []
    checked = translated = 0
    baseline = {}
    if BASELINE.is_file():
        baseline = json.loads(BASELINE.read_text(encoding="utf-8"))

    print("Thai localization validation")
    print("============================")
    for path in CATALOGS:
        relative = path.relative_to(ROOT).as_posix()
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
            failures.append(f"{relative}: strings must be an object")
            continue

        missing_dx = sorted(set(baseline.get(relative, ())) - set(strings))
        if missing_dx:
            failures.append(
                f"{relative}: deleted {len(missing_dx)} DX keys: "
                + ", ".join(repr(key) for key in missing_dx[:10])
            )

        catalog_checked = catalog_translated = 0
        for source, entry in strings.items():
            if not isinstance(entry, dict):
                failures.append(f"{relative}: malformed entry {source!r}")
                continue
            if entry.get("shouldTranslate") is False:
                continue
            checked += 1
            catalog_checked += 1
            thai = (entry.get("localizations") or {}).get("th")
            thai_values = units(thai)
            if not thai_values:
                failures.append(f"{relative}: missing Thai: {source!r}")
                continue
            states: list[str] = []

            def collect_states(node: object) -> None:
                if not isinstance(node, dict):
                    return
                unit = node.get("stringUnit")
                if isinstance(unit, dict):
                    states.append(str(unit.get("state", "")))
                for key, value in node.items():
                    if key != "stringUnit":
                        collect_states(value)

            collect_states(thai)
            if states and any(state != "translated" for state in states):
                failures.append(f"{relative}: incomplete Thai: {source!r}")
                continue
            english_values = units(
                (entry.get("localizations") or {}).get("en")
            ) or [source]
            english_signatures = {tuple(sorted(signature(v).items()))
                                  for v in english_values}
            for value in thai_values:
                if tuple(sorted(signature(value).items())) not in english_signatures:
                    failures.append(
                        f"{relative}: placeholder mismatch {source!r}: "
                        f"{dict(signature(value))}"
                    )
            translated += 1
            catalog_translated += 1
        print(f"{relative}: {catalog_translated}/{catalog_checked}")

    for path, required in INFO_PLISTS.items():
        relative = path.relative_to(ROOT)
        if not path.is_file():
            failures.append(f"missing Thai InfoPlist: {relative}")
            continue
        try:
            values = parse_strings(path)
        except (OSError, UnicodeError, ValueError) as error:
            failures.append(str(error))
            continue
        absent = sorted(required - values.keys())
        if absent:
            failures.append(f"{relative}: missing keys {absent}")
        for key in required - {"CFBundleDisplayName"}:
            if key in values and not re.search(r"[\u0e00-\u0e7f]", values[key]):
                failures.append(f"{relative}: no Thai text for {key}")

    print("----------------------------")
    print(f"Catalog summary: {translated}/{checked}")
    if failures:
        print(f"FAIL: {len(failures)} problem(s)", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return 1
    print("OK: Thai catalogs are complete and format-compatible.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
