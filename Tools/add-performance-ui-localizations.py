#!/usr/bin/env python3
"""Add deterministic catalog entries for the unified performance UI.

English stays the source/fallback language. The redesign is currently authored
in English and Thai; other supported locales deliberately receive the English
source text so that catalog coverage remains explicit until translators review
those strings.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_CATALOG = ROOT / "Strand" / "Resources" / "Localizable.xcstrings"
DESIGN_CATALOG = (
    ROOT
    / "Packages"
    / "StrandDesign"
    / "Sources"
    / "StrandDesign"
    / "Resources"
    / "Localizable.xcstrings"
)
LOCALES = ("de", "en", "es", "fr", "it", "pt-PT", "ru", "th", "zh-Hans", "zh-Hant")

APP_THAI = {
    "Home": "หน้าหลัก",
    "Opens details": "เปิดดูรายละเอียด",
    "Your recovery, rest, effort and vital signs": "การฟื้นตัว การพักผ่อน ภาระร่างกาย และสัญญาณชีพ",
    "Readiness and recovery drivers": "ความพร้อมและปัจจัยที่ส่งผลต่อการฟื้นตัว",
    "Sleep, need and consistency": "การนอน เวลานอนที่ต้องการ และความสม่ำเสมอ",
    "Cardiovascular load and zones": "ภาระต่อระบบหัวใจและโซนอัตราการเต้นหัวใจ",
    "Vitals, ranges and sources": "สัญญาณชีพ ช่วงค่าปกติ และแหล่งข้อมูล",
    "Monitor": "ติดตามสุขภาพ",
    "Current state and daily pattern": "สถานะปัจจุบันและรูปแบบตลอดวัน",
    "Compare seven-day and longer ranges": "เปรียบเทียบช่วง 7 วันและช่วงที่ยาวกว่า",
    "Activities, Effort and heart-rate zones": "กิจกรรม ภาระร่างกาย และโซนอัตราการเต้นหัวใจ",
    "Goals, plans and your journey": "เป้าหมาย แผน และเส้นทางของคุณ",
    "No active goal": "ยังไม่มีเป้าหมายที่กำลังดำเนินอยู่",
    "Choose what you want to work toward": "เลือกสิ่งที่คุณอยากพัฒนา",
    "Your plan is in motion": "แผนของคุณกำลังดำเนินอยู่",
    "Set a goal when you are ready. Nothing is accepted or scheduled automatically.": "ตั้งเป้าหมายเมื่อคุณพร้อม ระบบจะไม่ยอมรับหรือกำหนดตารางให้โดยอัตโนมัติ",
    "Review your journey and open Plan Book when you want to adjust what comes next.": "ทบทวนเส้นทางของคุณ และเปิดสมุดแผนเมื่อต้องการปรับขั้นตอนต่อไป",
    "A plan proposal is waiting for your decision.": "มีข้อเสนอแผนรอการตัดสินใจของคุณ",
    "Your progress": "ความคืบหน้าของคุณ",
    "Targets, milestones and evidence": "เป้าหมายย่อย หมุดหมาย และข้อมูลประกอบ",
    "Plan Book": "สมุดแผน",
    "Proposals, commitments and history": "ข้อเสนอ สิ่งที่วางแผนไว้ และประวัติ",
    "Changes and items that need attention": "การเปลี่ยนแปลงและรายการที่ต้องตรวจสอบ",
    "Loading your data…": "กำลังโหลดข้อมูลของคุณ…",
    "No data yet": "ยังไม่มีข้อมูล",
    "Connect a data source or import your history to begin.": "เชื่อมต่อแหล่งข้อมูลหรือนำเข้าประวัติเพื่อเริ่มต้น",
    "Data unavailable": "ไม่สามารถใช้ข้อมูลได้",
    "Your saved data is safe. Try refreshing this screen.": "ข้อมูลที่บันทึกไว้ยังปลอดภัย โปรดลองรีเฟรชหน้าจอนี้",
}

DESIGN_THAI = {
    "AI Coach": "โค้ช AI",
    "Opens your coach": "เปิดโค้ช AI",
}


def localized_entry(source: str, thai: str) -> dict:
    return {
        "localizations": {
            locale: {
                "stringUnit": {
                    "state": "translated",
                    "value": thai if locale == "th" else source,
                }
            }
            for locale in LOCALES
        }
    }


def update(path: Path, translations: dict[str, str]) -> int:
    catalog = json.loads(path.read_text(encoding="utf-8"))
    strings = catalog.setdefault("strings", {})
    changed = 0
    for source, thai in translations.items():
        expected = localized_entry(source, thai)
        if strings.get(source) != expected:
            strings[source] = expected
            changed += 1
    path.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return changed


def main() -> None:
    app_changed = update(APP_CATALOG, APP_THAI)
    design_changed = update(DESIGN_CATALOG, DESIGN_THAI)
    print(
        f"Performance UI localization: app={app_changed} "
        f"design={design_changed} entries updated"
    )


if __name__ == "__main__":
    main()
