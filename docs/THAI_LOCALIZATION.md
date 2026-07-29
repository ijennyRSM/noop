# Thai localization

NOOP AI Full Beta keeps English as the development and fallback language and adds Thai (`th`) through
Apple String Catalogs. The iPhone app, StrandDesign package, widgets, Watch app, Watch complications,
display name, and iOS permission descriptions each own their localization resources; targets do not
depend on another target's catalog.

The main health terms use concise Thai: Today = วันนี้, Recovery = การฟื้นตัว, Strain/Effort =
ภาระร่างกาย, Sleep = การนอน, Readiness = ความพร้อมของร่างกาย, Skin Temperature =
อุณหภูมิผิวหนัง, and Strength Training = การฝึกเวท. Brand names and standard abbreviations such as
NOOP, WHOOP, HRV, RHR, SpO₂, BLE, GPS, CSV, and AI remain unchanged.

Run the dependency-free validator from the repository root:

```bash
python3 Tools/validate-thai-localization.py
```

It validates JSON, requires `th`, checks every required Thai value, and compares Apple formatting
placeholders. The DX baseline key list in `Tools/i18n-dx-required-keys.json` prevents an integration from
silently dropping a DX-only string.

To build the sideload IPA in GitHub, open **Actions**, choose **Build NOOP AI Full Thai Strength**,
select **Run workflow**, choose `integration/dx-thai-strength-full`, and click **Run workflow**. When it
finishes, open the run, scroll to **Artifacts**, and download
`NOOP-AI-Full-Thai-Strength-Unsigned-IPA`.

The IPA is unsigned. Sign it with AltStore, SideStore, or Sideloadly before installation. A free Apple ID
signature normally expires after seven days. The sideload package deliberately removes Watch, widget,
and Live Activity extensions; HealthKit and other entitlement-dependent features can also be unavailable
when freely re-signed.

When updating from upstream:

1. Fetch `upstream/main` and merge it into a separate integration branch.
2. Never replace a whole `.xcstrings` file. Merge by key and preserve the English source value.
3. Run the validator. New source keys reported as missing need a natural Thai translation.
4. Review new SwiftUI screens and target-specific resources, then run the iOS build workflow.

This is a personal, non-commercial, unofficial localized fork. The original PolyForm Noncommercial
license and attribution files remain authoritative.
