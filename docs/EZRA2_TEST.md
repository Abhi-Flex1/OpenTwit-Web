# Final Test — Ezra 2 (Install + Screenshot)

Date (UTC): 2026-09-18. Host: macOS arm64. hdc: Ver 3.2.0d
at `/Users/abhi/.ohos/sdk-remap/24/toolchains/hdc`.
Work copy: `/Users/abhi/.droppy-code/worktrees/opentwit-web-ezra-2-cbf350ad`.
Result: **BLOCKED — no device, install + screenshots not proven.** Nothing fabricated.

## 1. List targets (symbol targets)

- `hdc list targets` → `[Empty]` (exit 0), on first check and on every
  re-poll (3 x 30 s polls this run, all `[Empty]`).
- `hdc list targets -v` → `[Empty]`.
- `hdc checkserver` → `Client version:Ver: 3.2.0d, server version:Ver: 3.2.0d`.
- Serial: `<none>`.
- Note: a background `Emulator -install -deviceType Phone -osVersion
  "HarmonyOS 6.1.1(24)" -force` process (another head's run, locale-spoofed)
  was still alive during polling, but no device appeared; prior heads document
  the image download as region-gated (`docs/HANK2_AVD_BOOT.md`).

## 2. Install (symbol install)

- Signed HAP `entry/build/default/outputs/default/entry-default.hap`:
  **absent** (`ls` shows only `entry-default-unsigned.hap`, 161534 bytes,
  plus `mapping/`, `pack.info`).
- Per brief, fell back to the unsigned HAP:
- `hdc install entry/build/default/outputs/default/entry-default-unsigned.hap` →
  `[Fail]ExecuteCommand need connect-key? please confirm a device by help info`
  (no device to receive it).

## 3. Start (symbol start)

- `hdc shell aa start -b com.example.opentwit -a EntryAbility` →
  `[Fail]ExecuteCommand need connect-key? please confirm a device by help info`
  (bundle per `AppScope/app.json5`: `com.example.opentwit`).

## 4. Screenshots (symbol screencap)

- **None captured — no device, so `screencap` cannot run.** No `screenshots/`
  directory created; no placeholder image fabricated.
- Intended paths: `screenshots/final-1.png`, `screenshots/final-2.png`,
  `screenshots/final-3.png` — **not created**.
- Timeline visible: **no (unproven — app never launched)**.

## Acceptance

- [x] `docs/EZRA2_TEST.md` exists (this file).
- [ ] One screenshot file exists — NOT MET (no device).

## Unblock for lead

1. Finish image download + AVD create/start until `hdc list targets` shows
   one serial (see `docs/HANK2_AVD_BOOT.md` § Unblock).
2. Re-run `hdc install` on the unsigned HAP above (or build + sign the
   `entry-default.hap` first), then `aa start`, then
   `hdc shell screencap` to `screenshots/final-{1,2,3}.png`.
