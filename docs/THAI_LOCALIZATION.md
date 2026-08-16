# ภาษาไทยสำหรับ NOOP DX 10.1.0

สาขานี้เริ่มจาก tag `v10.1.0-dx` ของ `DX23876/noop` โดยตรงและเพิ่มเฉพาะ
ทรัพยากรภาษาไทย เครื่องมือตรวจสอบ และ workflow สำหรับสร้าง IPA ที่ยังไม่เซ็น
ไม่มีการนำ AI Full Beta, Strength Training, Body Map, database migration หรือ
งาน redesign จากสาขาทดลองเดิมมารวม

นี่เป็นงานดัดแปลงส่วนบุคคลและไม่ใช่รุ่นอย่างเป็นทางการจาก NOOP หรือ WHOOP
การใช้งานต้องเป็นไปตาม PolyForm Noncommercial License ของโครงการ

## ขอบเขตภาษาไทย

- แอป iPhone และ macOS: `Strand/Resources/Localizable.xcstrings`
- คอมโพเนนต์ร่วม: `Packages/StrandDesign/.../Localizable.xcstrings`
- Apple Watch: `NOOPWatch/Localizable.xcstrings`
- Watch complications: `NOOPWatchComplications/Localizable.xcstrings`
- ชื่อแอปและข้อความขอสิทธิ์ของ iPhone, macOS, Widgets และ Apple Watch
- ภาษาอังกฤษยังเป็น `developmentLanguage: en` และเป็นภาษาสำรอง

คำสำคัญที่ใช้สม่ำเสมอ ได้แก่ พลังฟื้นตัว (Charge), ภาระร่างกาย
(Effort/Strain), การฟื้นตัว, ประสิทธิภาพการนอน, เวลานอนที่ร่างกายต้องการ,
อัตราการเต้นหัวใจขณะพัก, อุณหภูมิผิวหนัง และออกซิเจนในเลือด (SpO₂)
ชื่อ NOOP, WHOOP และตัวย่อสากล เช่น HRV, RHR, SpO₂, GPS, AI และ BLE ไม่ถูกแปล

## ตรวจสอบคำแปล

```bash
python3 Tools/apply-thai-translations.py --check
python3 Tools/validate-thai-localization.py
python3 Tools/i18n_audit.py --platform ios
```

`apply-thai-translations.py` ตรวจว่าตารางคำแปลตรงกับ catalog และไม่ทำให้
placeholder เสีย ส่วน `validate-thai-localization.py` ตรวจ JSON, Thai coverage,
สถานะ translated, placeholder และข้อความ permission

เมื่อต้องเพิ่มคำแปล ให้แก้ไฟล์ต่อไปนี้ แล้วรัน `apply-thai-translations.py`:

- `Tools/translations/th.json`
- `Tools/translations/design-th.json`
- `Tools/translations/watch-th.json`
- `Tools/translations/watch-complications-th.json`

## สร้าง IPA บน GitHub

1. เปิด repository ของ fork บน GitHub
2. เลือกแท็บ **Actions**
3. เลือก workflow **Build DX Thai iOS Unsigned IPA**
4. กด **Run workflow** และเลือก branch ภาษาไทย
5. เมื่อจบแล้ว เปิด run นั้นและดาวน์โหลด artifact
   **NOOP-DX-Thai-Unsigned-IPA**

ชื่อไฟล์มีรูปแบบ:

```text
NOOP-DX-Thai-ios-unsigned-v10.1.0-<short-sha>.ipa
```

IPA นี้ยังไม่เซ็นและไม่มี certificate หรือ provisioning profile ผู้ใช้ต้องเซ็น
ด้วย AltStore, SideStore, Sideloadly หรือเครื่องมือส่วนตัวอื่นก่อนติดตั้ง
การเซ็นด้วย Apple ID ฟรีโดยทั่วไปมีอายุประมาณเจ็ดวัน

เพื่อให้ free-account sideload ง่ายขึ้น workflow จะนำ Watch และ PlugIns ออกจาก
สำเนาที่ใช้สร้าง IPA ดังนั้น Widgets, Live Activities และ Apple Watch อาจใช้ไม่ได้
HealthKit และ entitlement บางอย่างอาจถูกจำกัดโดยวิธีที่ใช้เซ็น

## อัปเดตจาก DX รุ่นถัดไป

อย่า merge สาขา AI Full Beta เข้ามา ให้อัปเดตแบบรักษาฐาน DX ที่สะอาด:

1. fetch tag หรือ branch ล่าสุดจาก remote `dx`
2. สร้างสาขาอัปเดตจาก DX รุ่นใหม่
3. นำเฉพาะไฟล์ `Tools/translations/*th.json`, InfoPlist localization,
   validator และ workflow มารวม
4. รัน `Tools/apply-thai-translations.py --check` เพื่อดู key ที่เพิ่ม/ลบ
5. แปล key ใหม่จากข้อความอังกฤษตามบริบท แล้วรัน validator และ build ใหม่

อย่าคัดลอก catalog เก่าทับทั้งไฟล์ เพราะจะทำให้ key ใหม่จาก DX หายไป
ให้รวมคำแปลแบบ key-by-key โดยยึด catalog อังกฤษของ DX รุ่นใหม่เป็นต้นฉบับเสมอ
