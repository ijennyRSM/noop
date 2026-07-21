# การแปล NOOP สำหรับ iOS เป็นภาษาไทย

สาขานี้เพิ่มภาษาไทยให้ NOOP โดยคงภาษาอังกฤษ (`en`) เป็นภาษาต้นฉบับและภาษาสำรอง การเปลี่ยนแปลงนี้เป็นงานดัดแปลงอิสระสำหรับการใช้งานส่วนตัวและไม่ใช่ NOOP รุ่นทางการ ไม่มีการแก้ protocol ของ WHOOP, การประมวลผล BLE, สูตรสุขภาพ, schema/migration ของฐานข้อมูล หรือรูปแบบนำเข้าและส่งออก

## ขอบเขตที่แปล

- แอป iPhone: หน้า Today, Recovery/Charge, Strain/Effort, Sleep/Rest, Workouts, Trends, Insights, Compare, Metric Explorer, Live heart rate, การเชื่อมต่อสายรัด, การซิงค์/backfill, การนำเข้า/ส่งออก, Apple Health, Profile, Settings, AI Coach, Breathe, Intervals, onboarding, terms/privacy, dialog, error, empty state, accessibility และข้อความแจ้งเตือนที่อยู่ใน String Catalog
- `StrandDesign`: ข้อความของ component ที่อยู่ใน Swift package ใช้ resource bundle ของ package ตามเดิม
- iOS Widget และ Live Activity: มี `StrandiOSWidgets/Localizable.xcstrings` ของ extension เอง ไม่พึ่ง catalog ของแอปหลัก
- Apple Watch และ Watch complication: ใช้ catalog ของ target แต่ละตัวตามเดิมและมีภาษาไทยครบ
- ข้อความ permission ของ iOS และ watchOS รวมถึงชื่อแอปภาษาไทย `NOOP ไทย` อยู่ใน `th.lproj/InfoPlist.strings` ของแต่ละ bundle

คำหลักที่ใช้สม่ำเสมอ ได้แก่ `การฟื้นตัว`, `ภาระร่างกาย`, `การนอน`, `ประสิทธิภาพการนอน`, `เวลานอนที่ร่างกายต้องการ`, `หนี้การนอน`, `ความพร้อมของร่างกาย`, `อัตราการเต้นหัวใจขณะพัก`, `อัตราการหายใจ`, `อุณหภูมิผิวหนัง` และ `ออกซิเจนในเลือด` ชื่อแบรนด์และตัวย่อสากล เช่น NOOP, WHOOP, HRV, RHR, SpO₂, GPS, CSV, AI และ BLE ไม่ถูกแปล

## ตรวจสอบ localization

รันจาก root ของ repository:

```bash
python3 Tools/validate-thai-localization.py
```

สคริปต์ใช้เฉพาะ Python standard library โดยตรวจ JSON, `sourceLanguage: en`, สถานะ `translated` ของภาษา `th`, จำนวนและชนิดของ format placeholder และ key ที่จำเป็นใน Thai `InfoPlist.strings` รายการที่ตั้ง `shouldTranslate: false` จะถูกข้ามโดยตั้งใจ

บน macOS ให้ตรวจ project และ build เพิ่มเติมด้วย:

```bash
xcodegen generate
xcodebuild \
  -scheme NOOPiOS \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/dd \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build
```

## สร้างและดาวน์โหลด IPA

1. เปิด repository ของ fork บน GitHub
2. เลือกแท็บ **Actions**
3. เลือก workflow **Build Thai iOS Unsigned IPA**
4. กด **Run workflow** เลือก branch ที่ต้องการ แล้วกด **Run workflow** อีกครั้ง
5. รอ job **Build unsigned Thai IPA** เสร็จ
6. เปิดหน้ารายละเอียด run แล้วดาวน์โหลด artifact **NOOP-Thai-Unsigned-IPA** ในส่วน **Artifacts**

ไฟล์ภายใน artifact มีรูปแบบ `NOOP-Thai-ios-unsigned-v<VERSION>-<SHORT_SHA>.ipa` และถูกเก็บไว้ 14 วัน workflow จะไม่สร้าง GitHub Release และไม่ใช้ certificate, provisioning profile, Apple ID หรือ repository secret

IPA นี้ยังไม่ได้เซ็น ต้องนำไปเซ็นและติดตั้งด้วย AltStore, SideStore หรือ Sideloadly การเซ็นด้วย Apple ID แบบฟรีโดยทั่วไปหมดอายุภายใน 7 วันและต้องเซ็นใหม่ ข้อจำกัด entitlement ของบัญชีฟรีอาจทำให้ HealthKit บางส่วนใช้งานไม่ได้

ขั้นตอน packaging จะนำ `Watch/` และ `PlugIns/` ออกจาก app bundle เพื่อให้ re-sign ด้วยบัญชีฟรีง่ายขึ้น ดังนั้น IPA แบบ sideload นี้ไม่มี Apple Watch app, widget และ Live Activity ฟังก์ชันเหล่านี้ยังอยู่ใน source และตรวจภาษาไทยได้ แต่ต้อง build/sign ด้วย entitlement ที่เหมาะสมจึงจะใช้งานได้

## อัปเดตจาก upstream

รักษา `upstream` ให้ชี้ไปที่ `ryanbr/noop` และนำการเปลี่ยนแปลงเข้า fork ก่อน จากนั้น merge หรือ rebase สาขาภาษาไทยอย่างระมัดระวัง:

```bash
git fetch upstream
git switch main
git merge --ff-only upstream/main
git push origin main
git switch feat/thai-localization-ios
git merge main
python3 Tools/validate-thai-localization.py
```

หากเกิด conflict ใน `.xcstrings` ให้เก็บ key ภาษาอังกฤษใหม่จาก upstream และรักษา `localizations.th` เดิมไว้ ห้ามเลือกทับทั้งไฟล์โดยไม่ตรวจ diff เพราะจะทำให้คำแปลภาษาไทยหาย หลังแก้ conflict ให้รัน validator และ `Tools/i18n_audit.py --platform ios` อีกครั้ง

เมื่อ upstream เพิ่มข้อความใหม่ ให้ build ด้วย Xcode/XcodeGen เพื่อให้ String Catalog ดึง key จาก `LocalizedStringKey`/`String(localized:)`, ตรวจข้อความด้วย `python3 Tools/i18n_audit.py --platform ios --full`, เติม `th` ใน catalog ของ target ที่เป็นเจ้าของข้อความ และรัน validator ก่อน commit อย่านำข้อความของ widget, watch หรือ Swift package ไปใส่เฉพาะ catalog ของแอปหลัก เพราะแต่ละ bundle โหลด resource ของตัวเอง

โครงการยังอยู่ภายใต้ PolyForm Noncommercial License และไฟล์ `LICENSE`, `NOTICE`, `ATTRIBUTION.md` และ `DISCLAIMER.md` ของต้นฉบับยังมีผลครบถ้วน ห้ามนำ fork นี้ไปนำเสนอว่าเป็น NOOP รุ่นทางการหรือใช้เพื่อการจำหน่ายเชิงพาณิชย์
