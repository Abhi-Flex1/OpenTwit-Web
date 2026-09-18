# Emulator Alternative Path (no system-image download)

Run OpenTwit via the local Previewer or a USB real device. Nothing here
downloads a system image. Helper script: `scripts/preview-or-cloud-run.sh`.

## Previewer Command

SDK lives outside the repo at `$HOME/Developer/command-line-tools`
(no `sdk/` directory inside the project; the on-disk layout is
`sdk/default/openharmony/previewer`). Confirmed listing:

- `sdk/default/openharmony/previewer/` contains `common/`, `liteWearable/`
- Previewer binary: `sdk/default/openharmony/previewer/common/bin/Previewer`
- hdc: `sdk/default/openharmony/toolchains/hdc` (Ver: 3.2.0d)
- CLI tools: `Version: 6.1.1.280`, `HarmonyOS 6.1.1 Release (API Version 24)`

Launch the entry ability (`EntryAbility`, bundle `com.example.opentwit`
per `entry/src/main/module.json5`) with:

```sh
./scripts/preview-or-cloud-run.sh --launch
# dry-run default prints versions + device status and exits 0 (no GUI started)
# explicit launch runs: Previewer -j entry/build/default/outputs/default/entry-default.hap
```

## USB Device Result

Recorded 2026-09-18 (macOS, no device plugged in):

- `hdc list targets` -> `[Empty]` (exit 0, no USB devices online)
- `ls ~/Library/Huawei` -> No such file or directory (no Huawei USB helper state)
- Consequence: the script's stage-4 fallback (`hdc install <hap>` +
  `hdc shell aa start -b com.example.opentwit -a EntryAbility`) correctly
  skips; plug in a device with USB debugging, re-run, and it installs/starts.

## How To Run Without Image

1. `./scripts/preview-or-cloud-run.sh` — verifies Previewer present, prints
   versions, checks `hdc list targets`. Needs no image, no device.
2. Build the HAP in DevEco or via hvigor, then
   `./scripts/preview-or-cloud-run.sh --launch` to open it in the Previewer.
3. Real-device path: connect USB device, `hdc list targets` shows a serial,
   re-run the script (or `hdc install <hap>`) — no emulator image involved.
4. Never touched: `build-profile.json5`, `oh-package.json5`, `entryability/*.ets`.
