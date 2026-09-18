# Boot Result — Hank 2 AVD (OpenTwit_Phone_API24)

Date (UTC): 2026-09-18. Host: macOS arm64. Emulator CLI: HarmonyOS Emulator (Tools 6.1.1.280, API 24). hdc: Ver 3.2.0d.
Work copy: `/Users/abhi/.droppy-code/worktrees/opentwit-web-hank-2-54d3cfef`. All Emulator commands run in `~/Developer/command-line-tools/bin`.
Result: **BLOCKED — no image, no AVD, no device.** Nothing fabricated.

## 1. List (symbol list)

- `./Emulator -list` → `[Empty]` (exit 0). No AVDs exist before or after.

## 2. Create

- `./Emulator -create OpenTwit_Phone_API24 -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)"` →
  `Cannot find image, please verify your SDK installation.` + `Device create fail.`
- Root cause (verified): `./Emulator -imageList -deviceType Phone -downloaded true` → `No images matching the criteria were found.` Downloaded image count: **0**.
- `./Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)"` → `Currently, this capability is available only in the Chinese mainland.` (region gate; same result documented in `docs/EMULATOR_NONCN_INSTALL.md` and `docs/EMU_INSTALL_AVD_RUN.md`).

## 3. Start (background)

- `nohup ./Emulator -start OpenTwit_Phone_API24` exits immediately:
  `"/Users/abhi/.Huawei/Emulator/deployed/" not exists or is not readable. "OpenTwit_Phone_API24" is not found. ... Unable to start the emulator`
- `./Emulator -list` after start → `[Empty]`.

## 4. hdc poll (symbol targets, 300 s)

- `hdc kill; hdc start` clean, then 30 x 10 s poll of `hdc list targets` (hdc at `~/Developer/command-line-tools/sdk/default/openharmony/toolchains/hdc`): every poll → `[Empty]`.
- Device serial: `<none>`.

## Acceptance

- [x] `docs/HANK2_AVD_BOOT.md` exists (this file).
- [ ] `Emulator -list` shows `OpenTwit_Phone_API24` — NOT MET (`[Empty]`, no image to create from).
- [ ] `hdc` shows one serial — NOT MET (`[Empty]` after full 300 s poll).

## Unblock for lead

On a mainland-CN network (or logged-in DevEco Studio on one): `Emulator -license accept`, re-run `./Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)"` until `-imageList -downloaded true` lists the Phone 6.1.1(24) image, then `-create OpenTwit_Phone_API24 ...` + `-start` + re-poll `hdc list targets`.
