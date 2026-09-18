# OpenTwit-Web — Repo & Environment Audit

Date (UTC): 2026-09-18
Auditor: Hank (read-only audit + this report file only)
Project folder (source checkout): `/Users/abhi/Desktop/HarmonyOS Ports/OpenTwit-Web`
Work copy audited: `/Users/abhi/.droppy-code/worktrees/opentwit-web-hank-5dce8333`

## 1. Repo state

### README.md (full file, 2 lines)
```
# OpenTwit-Web
Twitter/X Web adaptation for HarmonyOS
```

### LICENSE (first line + identification)
- Line 1: `Apache License`
- Full file: standard Apache License, Version 2.0, January 2004 (201 lines, ends with `limitations under the License.`).
- No copyright-year/owner line filled in (boilerplate `Copyright [yyyy] [name of copyright owner]` still present at line 189).

### `git log --oneline -20` (work copy)
```
195327d Droppy Code: a Hydra head's starting point
b3483ab Initial commit
```

### `git status` (work copy)
```
Not currently on any branch.
nothing to commit, working tree clean
```

### `ls -la` project folder (work copy)
```
total 40
drwxr-xr-x@ 5 abhi  staff    160 Sep 18 15:40 .
drwxr-xr-x@ 8 abhi  staff    256 Sep 18 15:41 ..
-rw-r--r--@ 1 abhi  staff     99 Sep 18 15:40 .git
-rw-r--r--@ 1 abhi  staff  11357 Sep 18 15:40 LICENSE
-rw-r--r--@ 1 abhi  staff     54 Sep 18 15:40 README.md
```
Notes:
- Only tracked files: `README.md`, `LICENSE` (plus `.git` pointer file — this copy is a git worktree).
- `docs/` did not exist before this audit; `docs/AUDIT.md` (this file) is the only new file.
- Original checkout `ls -la "/Users/abhi/Desktop/HarmonyOS Ports/OpenTwit-Web"` shows the same 2 files plus its own `.git` (14 entries inside `.git`, i.e. a full repo dir vs the worktree pointer file).

## 2. Toolchain presence

### `ls -la ~/Developer/command-line-tools`
```
total 384
drwx------@ 13 abhi  staff     416 Sep 18 15:36 .
drwxr-xr-x   9 abhi  staff     288 Sep 18 15:36 ..
drwx------@  7 abhi  staff     224 May 23 00:17 bin
drwx------@  6 abhi  staff     192 May 23 00:16 codelinter
drwx------@ 33 abhi  staff    1056 Sep 18 15:36 emulator
drwx------@  4 abhi  staff     128 May 23 00:16 hstack
drwx------@  5 abhi  staff     160 Sep 18 15:35 hvigor
drw-------@  1 abhi  staff   77481 May 23 00:10 LICENSE.txt
-rw-------@  1 abhi  staff  110759 May 23 00:10 NOTICE.txt
drwx------@  7 abhi  staff     224 Sep 18 15:35 ohpm
drwx------@  3 abhi  staff      96 May 23 00:12 sdk
drwx------@  3 abhi  staff      96 May 23 00:10 tool
-rw-------@  1 abhi  staff     336 May 23 00:17 version.txt
```

### `ls -la ~/Developer/command-line-tools/bin`
```
total 40
drwx------@  7 abhi  staff  224 May 23 00:17 .
drwx------@ 13 abhi  staff  416 Sep 18 15:36 ..
-r-xr-----@  1 abhi  staff  758 May 23 00:16 codelinter
-r-xr-----@  1 abhi  staff  272 May 23 00:10 Emulator
-r-xr-----@  1 abhi  staff  516 May 23 00:12 ohpm
-r-xr-----@  1 abhi  staff  528 May 23 00:16 hstack
-r-xr-----@  1 abhi  staff  737 May 23 00:17 hvigorw
```

### `~/.zprofile` (`ls -la` + contents)
```
-rw-r--r--@ 1 abhi  staff  154 Sep 17 18:52 /Users/abhi/.zprofile
```
```
export PATH="$HOME/Developer:$HOME/Developer/flutter/bin:$PATH"
eval "$(/opt/homebrew/bin/brew shellenv zsh)"
export PATH=/Users/abhi/.opencode/bin:$PATH
```
Note: HarmonyOS `command-line-tools/bin` is NOT on PATH in `.zprofile` (hence bare `ohpm` / `hvigorw` resolve as "command not found"; full-path invocation works).

### `~/Developer/command-line-tools/version.txt`
```
# ======================
# Command Line Tools(mac-arm64)
# Version: 6.1.1.280
# ======================

hvigor       : 6.24.2
codelinter   : 6.0.240
hstack       : 5.1.0
ohpm         : 6.1.2.268
releaseType  : release
HarmonyOS SDK: HarmonyOS 6.1.1 Release (include Ohos_sdk_public 6.1.1.125 (API Version 24 Release))
apiVersion   : 24
```

### SDK layout
- `ls ~/Developer/command-line-tools/sdk/default` → `hms  openharmony  sdk-pkg.json`
- `ls ~/Developer/command-line-tools/sdk/default/openharmony` → `ets  js  native  previewer  toolchains`
- Emulator dir present (`~/Developer/command-line-tools/emulator` contains `Emulator` binary + `libQt5*`, `platforms`, `emulator.json`, etc.).

### Tool versions probed
- `~/Developer/command-line-tools/bin/ohpm --version` → `6.1.2.268` (bare `ohpm` → `command not found`, PATH gap only)
- `~/Developer/command-line-tools/bin/hvigorw --version` → `6.24.2` (bare `hvigorw` → `command not found`, PATH gap only)
- `~/Developer/command-line-tools/bin/hstack --version` → `5.1.0`
- `which hdc` → `hdc not found` (not on PATH; hdc normally ships under `sdk/default/openharmony/toolchains` — not verified on PATH here)

## 3. OS / arch / runtimes

### `uname -m`
```
arm64
```

### `sw_vers`
```
ProductName:		macOS
ProductVersion:		27.0
BuildVersion:		26A428
```

### `node -v`
```
v26.8.2
```

### `java -version`
```
The operation couldn't be completed. Unable to locate a Java Runtime.
Please visit http://www.java.com for information on installing Java.
```
Note: no Java runtime found. HarmonyOS builds via hvigor typically need a JDK (DevEco Studio bundles one; CLI-only setups must provide `JAVA_HOME` themselves).

## 4. Missing pieces for a HarmonyOS Stage-model ArkTS port

Repo currently contains NO app code — only `README.md` + `LICENSE`. Everything below is missing:

1. **Stage-model app skeleton**: `AppScope/` (`app.json5`, resources), entry UIAbility `src/main/ets/` (`EntryAbility.ets`, `pages/`, `components/`), `module.json5` (abilities, permissions e.g. `ohos.permission.INTERNET`), `main_pages.json`, `resources/` (strings, media, themes).
2. **Build config**: `hvigorfile.ts` + `hvigor-config.json5`, `oh-package.json5` (+ lock), `build-profile.json5`, `obfuscation-rules.txt` as applicable; `hvigorw` wrapper committed or documented to use the CLI tools path.
3. **Web-view strategy decision** (this repo is a "Twitter/X Web adaptation"): no `Web` component code, no decided URL allowlist, no JS-bridge / cookie / user-agent / navigation-delegate policy, no offline/error/loading states.
4. **Signing**: no `build-profile` signing config, no keystore/materials (correctly absent from git; must be documented as local-only).
5. **Target definition**: no `minCompatibleVersion` / `targetAPIVersion` (toolchain SDK is API 24 / HarmonyOS 6.1.1 — unconfirmed as the intended target), no device matrix (phone/2-in-1), no portrait/landscape policy.
6. **Env gaps on this machine**: `command-line-tools/bin` not on PATH (ohpm/hvigorw/hstack only reachable by full path); no Java runtime (`java -version` fails — blocks hvigor builds); `hdc` not on PATH (device install/debug path unverified); DevEco Studio presence/version unconfirmed; emulator images installed state unconfirmed (binary present, images not listed).
7. **Repo hygiene**: README is a 2-line stub (no setup, build, run, or contribution instructions); LICENSE copyright owner/year blank; no `.gitignore` for `oh_modules/`, `build/`, signing artifacts; no CI/lint config (codelinter binary exists in toolchain but no repo ruleset).

Suggested next heads (not done here): scaffold Stage-model skeleton pinned to API 24, document PATH + JDK + hdc setup, add minimal Web-ability loading X with error/loading handling.
