# Boot Result — EMU Install + AVD (Ivo)

Date (UTC): 2026-09-18. Host: macOS arm64. Emulator: HarmonyOS Emulator 6.1.1.200. hdc: Ver 3.2.0d.
Work copy: `/Users/abhi/.droppy-code/worktrees/opentwit-web-ivo-73a4ace2`. All commands run in `~/Developer/command-line-tools/bin`.
Result: **BLOCKED — image install region-gated, no AVD, no device.** Nothing fabricated.

## 1. Bypass pre-check

- `docs/BYPASS_EXEC_RUN.md` does **not** exist in this worktree or in `/Users/abhi/Desktop/HarmonyOS Ports/OpenTwit-Web/docs/` (both list only AUDIT, BUILD_JDK_REPORT, BYPASS_FORENSICS, EMULATOR_* etc.). Proceeded with install regardless per brief.
- CN gate files absent: `/Library/Application Support/Huawei/DevEcoStudio5.0/emulator/country.region.xml`, `.../options/country.region.xml`, `.../DevEcoStudio/country.region.xml` — all `No such file or directory`.

## 2. Image list (symbol imageList)

- `./Emulator -imageList` confirms Phone entry exists: `deviceType: phone`, `osVersion: HarmonyOS 6.1.1(24)`, `SoftWareVersion: 6.1.0.126`, `releaseType: Release`, `downloaded: false`.

## 3. Install

- `./Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)" -force` →
  `Currently, this capability is available only in the Chinese mainland.`
- `./Emulator -imageList -downloaded true` (re-check) → `No images matching the criteria were found.` Downloaded image count: **0**.

## 4. AVD create

- `./Emulator -create -name OpenTwit_Phone_API24 ...` → `Invalid command: please attach the correct parameter after "create"!` (wrong syntax).
- Correct syntax `./Emulator -create OpenTwit_Phone_API24 -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)"` → `Cannot find image, please verify your SDK installation. Device create fail.`
- `./Emulator -list` → `[Empty]`; `./Emulator -list -details` → `[Empty]`. AVD `OpenTwit_Phone_API24` does **not** exist.

## 5. Start + 300 s hdc poll

- `Emulator -start OpenTwit_Phone_API24` (background) exits immediately:
  `"/Users/abhi/.Huawei/Emulator/deployed/" not exists or is not readable. "OpenTwit_Phone_API24" is not found. ... Unable to start the emulator`
- `hdc kill; hdc start` clean, then full 300 s poll (`30 x 10 s`): every `hdc list targets` → `[Empty]`.
- Device serial: `<none>` — acceptance item "hdc shows one serial" **NOT MET**.

## Acceptance

- [x] `docs/EMU_INSTALL_AVD_RUN.md` exists (this file).
- [ ] `Emulator -list` shows `OpenTwit_Phone_API24` — NOT MET (`[Empty]`, no image to create from).
- [ ] `hdc` shows one serial — NOT MET (`[Empty]` after 300 s).

## Unblock for lead

On a mainland-CN network (or logged-in DevEco Studio on one): `Emulator -license accept`, re-run the `-install` command above until `-imageList -downloaded true` lists the Phone 6.1.1(24) image, then `-create` + `-start` + re-poll.
