# Latest Emulator Run — OpenTwit-Web (Phone)

Date: 2026-09-18 (UTC). Host: macOS arm64.

## AVD Name

`OpenTwit_Phone_API24` (Phone, requested osVersion `HarmonyOS 6.1.1` / catalog `HarmonyOS 6.1.1(24)`).

- `Emulator -list -details` → `[Empty]` (no AVDs exist).
- `Emulator -imageList -deviceType Phone` → latest entry `HarmonyOS 6.1.1(24)`, all entries `downloaded: false`; `-downloaded true` → no matches.
- Create attempt `Emulator -create OpenTwit_Phone_API24 -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)"` → `Cannot find image, please verify your SDK installation. Device create fail.` (no system image downloaded, so the AVD could not be created).
- `Emulator -start OpenTwit_Phone_API24` (from `scripts/launch-latest-emulator.sh`) → `"OpenTwit_Phone_API24" is not found. Please create the device(folder): "/Users/abhi/.Huawei/Emulator/deployed/OpenTwit_Phone_API24". Unable to start the emulator` (see `emulator-boot.log`).

## Device Serial

`hdc list targets` → `[Empty]` (no device appeared within `HDC_WAIT_SECS=300`).

- Serial: `<none>` — acceptance item "one device shown" NOT met; nothing fabricated.
- Script executed: `HDC_WAIT_SECS=300 bash scripts/launch-latest-emulator.sh` (full 300 s poll; exited with no device).

## Install Status

SKIPPED — no device and no built HAP (`entry/build/default/outputs/default/entry-default.hap` absent; no build run in this task).

- `hdc install <hap>` not attempted (script guard: device empty + hap missing).
- `hdc shell aa start -b com.example.opentwit -a EntryAbility` not attempted.

## Screenshot Paths

No screenshots captured (no device). Intended outputs (absent):

- `screenshots/latest.png` (via `hdc shell screencap -p /data/local/tmp/latest.png` + `hdc file recv`)
- Boot log: `emulator-boot.log` (contains the AVD-not-found error above)

## Files

- Script: `scripts/launch-latest-emulator.sh` (PATH export for `bin`+`toolchains`; `hdc kill`+`hdc start`; background `Emulator -start`; `hdc list targets` poll; `hdc install`+`aa start`+`screencap`)
- This report: `docs/LATEST_EMULATOR_RUN.md`

## Next step for lead

Unblocks require a downloaded Phone image (e.g. `Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)"`, region-gated per prior report), then re-run the script; then build the HAP (`hvigorw assembleHap`) before install.
