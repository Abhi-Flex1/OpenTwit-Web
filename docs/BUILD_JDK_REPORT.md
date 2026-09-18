# Build JDK Report — OpenTwit-Web

Date: 2026-09-18 (UTC). Host: macOS arm64.

## JDK Path

- `java -version` before setup: no Java runtime installed.
- Installed via `brew install openjdk@17` (17.0.20.1).
- `JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`
- Pinned for the project in `scripts/setup-jdk.sh`:
  - line 1: `export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`
  - line 2: `export PATH="/Users/abhi/Developer/command-line-tools/bin:/Users/abhi/Developer/command-line-tools/sdk/default/openharmony/toolchains:$JAVA_HOME/bin:$PATH"`
- Verified: after `source scripts/setup-jdk.sh`, `java -version` → 17.0.20.1 and `hvigorw --version` → 6.24.2.
- Supporting env setup (outside the project, needed for any HarmonyOS build): `~/.npmrc` now contains `@ohos:registry=https://repo.harmonyos.com/npm/` so `@ohos` packages resolve to the Huawei registry instead of npmjs (without it, hvigor fails with "No npmrc file is matched in the current user folder").

## Build Command

From the project root, after sourcing the JDK setup:

```sh
source scripts/setup-jdk.sh
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

(`-p buildMode=debug` is the debug value; run from the project root because that is where the app-level `build-profile.json5`/`hvigorfile.ts` live — hvigor run from `entry/` alone has no app profile.)

## HAP Path

Expected output (per module `entry`, product `default`):

- `entry/build/default/outputs/default/entry-default.hap`

Status: **NOT BUILT — no `.hap` file exists.** The build fails during dependency resolution, before compilation:

```text
ERR_PNPM_NO_MATCHING_VERSION  No matching version found for
@ohos/hvigor-ohos-plugin@5.0.2 while fetching it from
https://repo.harmonyos.com/npm/
```

Root cause: the project pins `@ohos/hvigor-ohos-plugin@5.0.2` (`oh-package.json5`, `hvigor/hvigor-config.json5` with `hvigorVersion 5.0.2`), but version 5.0.2 was removed/never published in the Huawei registry (81 published versions, oldest 5.x is 5.2.2; verified via the registry packument).

## What the lead must do to unblock

1. Bump the plugin pin to a published version (e.g. 5.2.2+, or align with the installed toolchain's bundled 6.24.2) in `oh-package.json5` and `hvigor/hvigor-config.json5`. Deliberately left untouched: `build-profile.json5` files per task constraints.
2. Note likely next blockers after the pin is fixed: installed SDK is HarmonyOS 6.1.1 (API 24) only while the project targets `compileSdkVersion 5.0.0(12)`, and `signingConfigs` is empty — both live in the `build-profile.json5` files this task forbids touching, so they need a lead decision.
3. Re-run the Build Command above; on success the HAP appears at the HAP Path listed here.
