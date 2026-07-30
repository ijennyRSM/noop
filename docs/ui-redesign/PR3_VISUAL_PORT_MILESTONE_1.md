# PR #3 Visual Port — Milestone 1

This milestone ports the accepted presentation from PR #3 onto the Full Beta backend at
`6c460d1e44091d1f410f9a6133cb1eab1a7870dd`. The visual donor is
`3b0ad22fa6add28d96aaa71940e65403aaad2d54`.

No repository, score formula, AI, consent, Strength, database, migration, backup, import/export,
Bluetooth, HealthKit, or canonical-date implementation was copied from PR #3.

## Measured Today geometry

Measurements are SwiftUI points from the donor implementation and its 393-point reference canvas.

| Element | PR #3 port measurement |
| --- | ---: |
| Horizontal screen inset | 16 pt |
| Header top offset | 12 pt |
| Day-selector outer frame | flexible × 40 pt |
| Day-selector inner pill | flexible × 34 pt |
| Header side cells | 76 pt |
| NOOP wordmark top gap | 4 pt after the 18 pt header stack gap |
| NOOP wordmark face | HelveticaNeue-CondensedBold, 16 pt |
| Score-ring diameter | 84 pt |
| Score-ring stroke | 8 pt |
| Score numeral | HelveticaNeue-CondensedBold, 28 pt, tabular |
| Percent glyph | HelveticaNeue-CondensedBold, 13 pt |
| Ring row spacing | 6 pt |
| Health/Stress card gap | 12 pt |
| Health/Stress card minimum height | 94 pt |
| Health/Stress card corner radius | 15 pt |
| My Day top spacing | 12 pt |
| My Day heading | HelveticaNeue-CondensedBold, 30 pt |
| My Day add control | 48 × 48 pt |
| Activity score tile | 127 × 60 pt |
| Navigation dock | flexible × 70 pt |
| Navigation corner radius | 28 pt |
| Coach action | 68 × 68 pt |
| Dock/Coach gap | 10 pt |

The complete ring is explicitly framed. The score numeral and the smaller percent glyph share a
first-text-baseline alignment. Effort has no percent glyph.

## Milestone scope

- Root navigation dock and separate DX Coach action
- Today top and scrolled composition
- Charge detail
- Rest detail
- Effort detail

Remaining screens are intentionally unchanged pending visual acceptance.

## Visual evidence

Run **Actions → PR3 Visual Port Milestone 1 → Run workflow**. The workflow builds the real SwiftUI
application for an iPhone simulator with seeded Thai data and uploads:

- `NOOP-PR3-Visual-Port-Milestone-1`
- `NOOP-PR3-vs-PR8-vs-New-Comparison`

The comparison artifact contains the authoritative PR #3 image, the rejected PR #8 capture, and the
new port in a three-column HTML viewer.
