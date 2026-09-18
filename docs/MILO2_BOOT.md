# Boot Result — Milo 2 AVD (OpenTwit_Phone_API24)

Date (UTC): 2026-09-18. Host: macOS arm64. Emulator CLI: HarmonyOS Emulator 6.1.1.200. hdc: Ver 3.2.0d.
Work copy: `/Users/abhi/.droppy-code/worktrees/opentwit-web-milo-2-d382dac6`. All Emulator commands run in `~/Developer/command-line-tools/bin`.
Result: **BLOCKED — no image, no AVD, no device.** Nothing fabricated.

## 1. List (symbol list)

- `./Emulator -list` → `[Empty]` (exit 0). No AVDs exist before or after.
- `./Emulator -list -details` → `[Empty]`.
- `./Emulator -imageList -deviceType Phone -downloaded true` → `No images matching the criteria were found.` Downloaded image count: **0**. (Undownloaded list does include `HarmonyOS 6.1.1(24)` for Phone.)

## 2. Create (symbol create)

- `./Emulator -create OpenTwit_Phone_API24 -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)"` →
  `Failed to read image info.json, the image file may be incomplete.` + `Device create fail.`
- Root cause (verified): zero downloaded Phone images, so there is nothing to create from.

## 3. Start (symbol start, background)

- `nohup ./Emulator -start OpenTwit_Phone_API24` exits immediately:
  `"/Users/abhi/.Huawei/Emulator/deployed/" not exists or is not readable. "OpenTwit_Phone_API24" is not found. ... Unable to start the emulator`
- `./Emulator -list` after start → `[Empty]`.

## 4. hdc poll (symbol targets, 300 s)

- hdc at `~/Developer/command-line-tools/sdk/default/openharmony/toolchains/hdc` (run with cwd `~/Developer/command-line-tools/bin`); `hdc kill; hdc start` clean, then 30 x 10 s poll of `hdc list targets` (full 300 s): every poll → `[Empty]`.
- Device serial: `<none>`.

## Acceptance

- [x] `docs/MILO2_BOOT.md` exists (this file).
- [ ] `Emulator -list` shows `OpenTwit_Phone_API24` — NOT MET (`[Empty]`, no image to create from).
- [ ] `hdc` shows one serial — NOT MET (`[Empty]` after full 300 s poll).

## Unblock for lead

Same gate Hank 2 hit (`docs/HANK2_AVD_BOOT.md`): no downloaded emulator image and installs are region-gated (`Emulator -install` → `Currently, this capability is available only in the Chinese mainland`). On a mainland-CN network (or logged-in DevEco Studio on one): `Emulator -license accept`, re-run `./Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)"` until `-imageList -downloaded true` lists the Phone 6.1.1(24) image, then `-create OpenTwit_Phone_API24 ...` + `-start` + re-poll `hdc list targets`.
