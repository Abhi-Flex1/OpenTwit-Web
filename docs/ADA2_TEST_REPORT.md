# App Test — Ada 2 Install & Run Report

Date (UTC): 2026-09-18
Worktree: /Users/abhi/.droppy-code/worktrees/opentwit-web-ada-2-8b2ed688
HDC: ~/Developer/command-line-tools/sdk/default/openharmony/toolchains/hdc

## 1. targets — serial

Command: `hdc list targets`
Output: `[Empty]`
Serial: `<none>` — no device/emulator online.

## 2. install — HAP install

Command: `hdc install entry/build/default/outputs/default/entry-default.hap`
HAP file: MISSING — `entry/build/default/outputs/default/entry-default.hap` does not exist (no prior build produced it; build blocked per docs/HAP_BUILD_TEST_RUN.md).
Output: `[Fail]ExecuteCommand need connect-key? please confirm a device by help info`
Result: FAIL (no target + no HAP).

## 3. start — app launch

Command: `hdc shell aa start -b com.example.opentwit -a EntryAbility`
Output: `[Fail]ExecuteCommand need connect-key? please confirm a device by help info`
Result: NOT STARTED (no device).

## 4. screencap — screenshots

Command: `hdc shell screencap -p /data/local/tmp/latest-1.png`
Output: `[Fail]ExecuteCommand need connect-key? please confirm a device by help info`
Intended screenshot paths (NOT created — no device):
- `screenshots/latest-1.png`
- `screenshots/latest-2.png`
- `screenshots/latest-3.png`
Result: no screenshot files exist.

## 5. Timeline visible: no

The Twitter UI / timeline could not be verified — app never installed or launched (no HAP, no device).

## Acceptance

- `docs/ADA2_TEST_REPORT.md` exists: YES (this file).
- One screenshot file exists: NO — blocked, nothing fabricated.
- Overall: BLOCKED. Unblocks: (1) fix build-profile schema so `entry-default.hap` builds, (2) provide an online device/AVD with downloaded system image so `hdc list targets` shows a serial.
