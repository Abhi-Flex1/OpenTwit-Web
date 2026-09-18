# Emulator Setup and Test Report — OpenTwit-Web

Date: 2026-09-18 (UTC). Host: macOS arm64. Worktree: `opentwit-web-remy-07b13401`.
Owner files: `scripts/run-emulator-test.sh`, this report. No other project files touched.

## Summary

End-to-end emulator test is **BLOCKED, not passing**. The toolchain is present and
healthy, but there is no bootable device: no system image is downloaded, no AVD
exists, and the image download itself is region-gated. The repo checkout also
contains no HarmonyOS app source (`AppScope`/`entry` absent — only
`README.md`+`LICENSE`), so there is no HAP to build or install. The test script
was created, executed, and every stage logged below. All acceptance items that
could not be met are marked as such — nothing is fabricated.

## 1. Toolchain inspection (`~/Developer/command-line-tools/bin`)

| Binary asked for | Found? | Reality |
|---|---|---|
| `sdkmanager` | **No** — not present in `bin/` or anywhere under `command-line-tools` | `sdkmanager` is an Android-SDK tool; HarmonyOS command-line-tools (v6.1.1.280) has no such binary. `sdkmanager --list` could not be run. Equivalent: `Emulator -imageList` (see §3). |
| `hdc` | Yes, but **not** in `bin/` | Lives at `sdk/default/openharmony/toolchains/hdc`, version **3.2.0d** |
| `emulator` | Yes, two forms | Wrapper script `bin/Emulator` → binary `emulator/Emulator`, version **6.1.1.200** |
| `hvigorw` | Yes | Wrapper `bin/hvigorw`, version **6.24.2** |
| `bin/` actually contains | — | `codelinter`, `Emulator`, `hstack`, `hvigorw`, `ohpm` (no `sdkmanager`, no `hdc`, no lowercase `emulator`) |

SDK: HarmonyOS 6.1.1 Release (Ohos_sdk_public 6.1.1.125, **API 24**).

## 2. No-proxy workaround steps (exact commands and URLs)

Policy: no third-party proxy tool; everything direct (env confirms
`http_proxy/https_proxy/all_proxy` all unset). The `Emulator` CLI's own
`-http_proxy` flag was deliberately **never passed**.

1. `hdc kill; hdc start` — server restarts cleanly, direct/local only.
2. `Emulator -imageList` — lists 63 catalog entries, **0 downloaded**
   (`Emulator -imageList -downloaded true` → "No images matching the criteria").
3. Direct-curl probe of the image host from `emulator/url.ini`
   (`[image_download_link] en=https://devecostudio-drcn.deveco.dbankcloud.com`):
   `curl -sSI https://devecostudio-drcn.deveco.dbankcloud.com` → **HTTP 403
   Forbidden**. There is **no public unauthenticated direct-download URL** for a
   system image; images are served via signed URLs negotiated by
   `Emulator -install` / DevEco Studio (logged-in).
4. No-proxy install attempt (direct, `-force`, no `-http_proxy`):
   `Emulator -install -deviceType Phone -osVersion "HarmonyOS 5.0.1(13)" -force`
   → **`Currently, this capability is available only in the Chinese mainland.`**
   Image download via CLI is region-gated on this host. Not bypassed.
5. License gate also observed: `Emulator -license` shows 2 unaccepted agreements;
   license was **not** auto-accepted (left for a human: run `Emulator -license`
   and accept interactively).
6. Requested "API 12 x86_64 image" does not exist in the catalog: oldest entry is
   **HarmonyOS 5.0.1 (API 13)** phone/foldable/tablet; newest is 6.1.1 (API 24).
   Manual unzip to `~/Library/Huawei` was not possible — that directory does not
   exist and there was no image archive to unzip (see 403 + region block above).

## 3. Test script

Created `scripts/run-emulator-test.sh` (executable). It puts
`sdk/default/openharmony/toolchains`, `bin`, and `emulator` on `PATH`, then runs:
`hdc kill` → `hdc start` → `Emulator -list -details` (+ `-imageList -downloaded
true`) → background `Emulator -start <AVD>` → poll `hdc list targets`
(`HDC_WAIT_SECS`, default 300) → `hdc shell getprop` → `hvigorw assembleHap`
(only if `AppScope/`+`entry/` exist) → `hdc install <hap>` → `hdc shell aa
start -b <bundle>` → 3× `screencap` into `$SCREENSHOT_DIR`
(default `./screenshots`). Every stage prints PASS/SKIP/FAIL and never aborts
early. Run used for this report:
`HDC_WAIT_SECS=15 SCREENSHOT_DIR=$PWD/build.noindex/remy/screenshots
LOG_FILE=$PWD/build.noindex/remy/emulator-test.log ./scripts/run-emulator-test.sh`
(build/log output kept outside the tracked tree).

## 4. Execution result (boot log, abridged)

```
hdc --version            -> Ver: 3.2.0d
Emulator -version        -> HarmonyOS Emulator :6.1.1.200
hvigorw --version        -> 6.24.2
[PASS] hdc server restarted
Emulator -list -details  -> [Empty]            (no AVDs)
-imageList -downloaded   -> No images matching the criteria were found.
[SKIP] no AVD exists; cannot launch
hdc list targets (x3)    -> [Empty]
[FAIL] no device appeared within 15s
[SKIP] getprop (no device) | [SKIP] assembleHap (no AppScope/entry in checkout)
[SKIP] hdc install (no device, no HAP) | [SKIP] aa start | [SKIP] screenshots x3
```

- **Device serial:** none — `hdc list targets` shows `[Empty]` (acceptance item
  "one device" **not met**).
- **Install status:** HAP install **not attempted** — no device and no HAP exist
  (acceptance item "hap install attempted" **not met**: nothing to install).
- **Screenshots:** intended paths `screenshots/screenshot-1.png`,
  `screenshots/screenshot-2.png`, `screenshots/screenshot-3.png` — **not captured**
  (no device); no `screenshots/` directory was created in the checkout.

## 5. What the lead must do to unblock

1. On a mainland-CN network (or via DevEco Studio with login), accept the
   emulator license (`Emulator -license`), then e.g.
   `Emulator -install -deviceType Phone -osVersion "HarmonyOS 5.0.1(13)"` and
   `Emulator -create -name Phone_API13 -deviceType Phone -osVersion "HarmonyOS 5.0.1(13)"`.
2. Provide the actual HarmonyOS app source (`AppScope/`, `entry/`, `hvigorw`,
   `oh-package.json5`) — this checkout has none, so build/install/launch and
   screenshots are impossible regardless of the emulator.
3. Re-run `./scripts/run-emulator-test.sh` (defaults: 300 s device wait,
   `./screenshots/`); it needs no edits for the happy path.
