# Final Emulator Test — OpenTwit-Web (Rex)

Date: 2026-09-18 (UTC). Host: macOS arm64.
Work copy: `/Users/abhi/.droppy-code/worktrees/opentwit-web-rex-66224ca3`.
Result: **BLOCKED — boot + install not proven.** No HAP built, no device booted.
Nothing below is fabricated; every stage shows its real output.

## Environment (pre-steps, all verified)

- `source scripts/setup-jdk.sh` → `JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`
- `java -version` → `17.0.20.1` (OpenJDK 64-Bit Server VM, Homebrew)
- `hvigorw --version` → `6.24.2` (via `/Users/abhi/Developer/command-line-tools/bin/hvigorw`)
- `hdc --version` → `Ver: 3.2.0d` (at `sdk/default/openharmony/toolchains/hdc`)
- `Emulator -version` → `HarmonyOS Emulator :6.1.1.200`; SDK is HarmonyOS 6.1.1 Release (API 24)

## HAP Path

Expected: `entry/build/default/outputs/default/entry-default.hap`

Status: **NOT BUILT — file does not exist** (`ls` → `No such file or directory`).

Build command run from project root (after sourcing `scripts/setup-jdk.sh`):

```sh
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

Outcome: **BUILD FAILED** in ~781 ms with hvigor `00303038 Configuration Error —
Schema validate failed` at `build-profile.json5`. Verbatim validation errors:

- `app`: `compileSdkVersion` / `compatibleSdkVersion` are not valid property names
  (allowed: `signingConfigs`, `products`, `buildModeSet`, `multiProjects`, `capabilities`)
- `app.signingConfigs[0]`: missing required property `material`; `storeFile` is not
  a valid property (allowed: `name`, `material`, `type`)
- `app.products[0]` (`default`): missing required property `compatibleSdkVersion`

Root cause: the committed `build-profile.json5` uses the old (DevEco 5.0-era) schema;
the installed `hvigor-ohos-plugin 6.24.2` requires the new schema (signing material,
per-product `compatibleSdkVersion`, `buildModeSet`). Migrating it means choosing
signing material and SDK-version placement — a lead decision, so left untouched
(fixing it here would be guessing). See also `docs/BUILD_JDK_REPORT.md`.

## Device Serial

AVD: `OpenTwit_Phone_API24`. **Serial: `<none>` — no device.**

- `Emulator -list -details` → `[Empty]` (no AVDs exist).
- `Emulator -imageList -downloaded true` → `No images matching the criteria were found.`
  (all catalog entries `downloaded: false`; oldest catalog entry is HarmonyOS 5.0.1/API 13).
- Launch (from `~/Developer/command-line-tools/bin`, background per brief):
  `Emulator -start OpenTwit_Phone_API24` → exits immediately:
  `"/Users/abhi/.Huawei/Emulator/deployed/" not exists or is not readable.`
  `"OpenTwit_Phone_API24" is not found. ... Unable to start the emulator`
- `hdc list targets` → `[Empty]` on every poll (fresh 60 s poll this run, all `[Empty]`;
  a prior full 300 s poll run is documented in `docs/LATEST_EMULATOR_RUN.md` with the
  same result). The emulator process is already dead (AVD missing), so extending the
  poll cannot change the outcome; the image download that would unblock this
  (`Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)"`) is
  region-gated on this host per `docs/EMULATOR_SETUP_AND_TEST_REPORT.md`.

Acceptance item "hdc showed one device": **NOT MET**.

## Install Output

`hdc install` / launch were attempted against the real state and failed as expected
(no HAP file, no device). Verbatim:

```text
$ ls entry/build/default/outputs/default/entry-default.hap
ls: entry/build/default/outputs/default/entry-default.hap: No such file or directory
$ hdc install entry/build/default/outputs/default/entry-default.hap
[Fail]ExecuteCommand need connect-key? please confirm a device by help info
$ hdc shell aa start -b com.example.opentwit -a EntryAbility
[Fail]ExecuteCommand need connect-key? please confirm a device by help info
```

`aa start` was not retried after install since install never ran (nothing to install,
no device to receive it). Bundle name per `AppScope/app.json5`: `com.example.opentwit`.

## Screenshots

**None captured — no device, so `screencap` cannot run.** Verbatim:

```text
$ hdc shell screencap -p /data/local/tmp/latest-1.png
[Fail]ExecuteCommand need connect-key? please confirm a device by help info
```

Intended output `screenshots/latest-1.png` was **not created** (no `screenshots/`
directory created; no placeholder image fabricated).
Acceptance item "one screenshot file exists": **NOT MET**.

## What the lead must do to unblock

1. Migrate root `build-profile.json5` to the hvigor 6.24.2 schema (signing `material`,
   per-product `compatibleSdkVersion`, `buildModeSet`), then re-run the
   `hvigorw assembleHap ...` command above until
   `entry/build/default/outputs/default/entry-default.hap` exists.
2. On a network where image download works (or via logged-in DevEco Studio), download
   a Phone image and create the AVD:
   `Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)"` then
   `Emulator -create -name OpenTwit_Phone_API24 -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)"`.
3. Re-run `bash scripts/launch-latest-emulator.sh` (300 s device wait, `hdc install` +
   `aa start` + `screencap` to `screenshots/latest.png` once device + HAP exist).
