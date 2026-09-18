# Export Matrix (Remy 2)

Symbol: Export Matrix

## 1. Export Trick source

- Looked for `docs/OTTO2_OTHER_REPO_EXPORT.md` line 1, symbol Export Trick.
- Result: file NOT present in worktree (`docs/` lists 17 entries, no OTTO2 file) nor in main checkout `/Users/abhi/Desktop/HarmonyOS Ports/OpenTwit-Web/docs`.
- Fallback used per brief: `export vendorCountry=CN`.

## 2. Exports tried

Single export set, applied inline before install:

```sh
export vendorCountry=CN countryCode=CN LANG=zh_CN.UTF-8 TZ=Asia/Shanghai
```

Verified via `env | grep -E "vendorCountry|countryCode|LANG|TZ"`:

```
LANG=zh_CN.UTF-8
vendorCountry=CN
countryCode=CN
TZ=Asia/Shanghai
```

No other export combinations tried (source file absent, brief specifies this set).

## 3. Install command (anchored at symbol install)

Working dir: `~/Developer/command-line-tools/bin` (`/Users/abhi/Developer/command-line-tools/bin`)

```sh
./Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)" -force
```

Full command with exports:

```sh
export vendorCountry=CN countryCode=CN LANG=zh_CN.UTF-8 TZ=Asia/Shanghai && ./Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)" -force
```

## 4. Install output (truncated progress log)

- Target path: `/Users/abhi/Library/Huawei/Sdk/system-image/HarmonyOS-6.1.1/phone_all_arm/`
- Total size: 2368067717 bytes (~2.37 GB)
- Behavior: no region gate / auth error; download started immediately and progressed steadily.
- Start: `0.0% (15820/2368067717 bytes)`
- End at tool timeout (180 s): `58.7% (1390909176/2368067717 bytes)` (~1.39 GB downloaded)
- Termination: shell tool killed the command after exceeding 180000 ms timeout; download was still in progress, NOT complete, NOT failed. No failure message observed.
- Raw progress stream saved at tool-output `tool_0b511a4c0001AtfV8ruMMwPVIG` (7717 bytes logical, progress-line heavy).

## 5. imageList output (anchored at symbol downloaded)

Command:

```sh
./Emulator -imageList -downloaded true
```

Output:

```
No images matching the criteria were found.
EXIT:0
```

Interpretation: `downloaded true` shows zero completed images, consistent with install still in progress (58.7% at timeout). Acceptance second clause met via recorded full failure/incomplete outputs.

## 6. Acceptance

- [x] `docs/REMY2_EXPORT_MATRIX.md` exists.
- [ ] imageList shows one downloaded true — NOT YET (none downloaded; install incomplete).
- [x] Full failure/incomplete outputs recorded — YES (install progress + imageList output above).
