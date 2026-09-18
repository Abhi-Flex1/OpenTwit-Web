# HAP Build Test Run

# Test Result: FAIL (blocked, no HAP produced)

Date (UTC): 2026-09-18
Worktree: /Users/abhi/.droppy-code/worktrees/opentwit-web-lux-16b1957b

## 1. JDK (scripts/setup-jdk.sh line 1, symbol JAVA_HOME)
- Sourced `scripts/setup-jdk.sh`.
- `JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`
- `java -version`: openjdk 17.0.20.1 (Homebrew, 64-Bit Server VM, mixed mode)

## 2. ohpm install (project root, symbol install)
- Command: `ohpm install`
- Output: `install completed in 0s 22ms`

## 3. hvigorw assembleHap (mode module, product default, buildMode debug, flag no-daemon)
- Command: `hvigorw --no-daemon assembleHap --mode module -p product=default -p buildMode=debug`
- Result: BUILD FAILED in ~737 ms. Error `00303038 Configuration Error: Schema validate failed`
  at `build-profile.json5`. hvigor (6.24.2) rejects the current profile:
  `app.compileSdkVersion` / `app.compatibleSdkVersion` are not allowed keys,
  `app.signingConfigs[0]` requires `material` (has `storeFile`), and
  `app.products[0]` requires `compatibleSdkVersion`.
- Expected HAP path: `entry/build/default/outputs/default/entry-default.hap`
- Actual: file does NOT exist (build never reached packaging).
- Not fixed: `build-profile.json5` and `entry/build-profile.json5` were not
  touched per task constraints.

## 4. Device install / launch / screenshot (symbols install, com.example.opentwit)
- `hdc list targets`: `[Empty]` (no device online).
- `Emulator -list`: `[Empty]` (no AVDs). `Emulator -imageList -downloaded true`:
  no images. So `hdc install`, `hdc shell aa start -b com.example.opentwit
  -a EntryAbility`, and `hdc screencap` were not attempted; there is no target.
- Screenshot path: `screenshots/latest-1.png` — NOT created (no device, no HAP).

## Files
- HAP file: MISSING (`entry/build/default/outputs/default/entry-default.hap`)
- Screenshot: MISSING (`screenshots/latest-1.png`)
- This doc: `docs/HAP_BUILD_TEST_RUN.md` (this file)

## What the lead must do to unblock
1. Fix `build-profile.json5` to the hvigor 6.24.2 schema (move
   `compatibleSdkVersion` into `products[0]`, drop `compileSdkVersion` from
   `app`, give `signingConfigs[0]` a `material` block), or pin an hvigor
   version matching the current profile. `entry/build-profile.json5` target
   uses `releaseType Release` while the task asks for a debug build.
2. Provide an emulator AVD + downloaded system image (or a USB device) so
   `hdc install` / `aa start` / `screencap` can run.
3. Re-run steps 3-4 above, then update this file with the real install output
   and screenshot path.
