# Emulator Non-CN Install — OpenTwit-Web

Date: 2026-09-18 (UTC). Host: macOS arm64. Worktree: `opentwit-web-iris-4eedd7cf`.
Goal: emulator image install that works without CN network and without any third-party proxy.
Result: **BLOCKED — no working non-CN install path exists.** CLI install is region-gated;
Device Manager shares the same backend/gate, so it cannot succeed here either.
No proxy flags were ever passed; `http_proxy`/`https_proxy`/`all_proxy` all unset.

Reused exact failing commands from `docs/EMULATOR_SETUP_AND_TEST_REPORT.md` §2 (Summary + §1–§2).

## Commands Run

All in `~/Developer/command-line-tools/bin`, direct, no `-http_proxy`:

1. `./Emulator -imageList` → 63 catalog entries, 0 downloaded.
2. `./Emulator -imageList -downloaded true` → `No images matching the criteria were found.`
3. `./Emulator -license` (interactive) → `There are 2 license agreements that need to be reviewed.`
   `Do you want to continue? (y/N):` … ends with `Please read carefully and confirm
   whether agree to the above agreement? (y/N):`
4. `./Emulator -license accept` → `All licenses have been automatically accepted.`
5. `./Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1" -force` → 
   `Currently, this capability is available only in the Chinese mainland.`
6. `./Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)" -force` →
   `Currently, this capability is available only in the Chinese mainland.` (same with lowercase `phone`)
7. Re-ran `./Emulator -imageList -downloaded true` → `No images matching the criteria were found.`

Reference reads:

- `~/Developer/command-line-tools/emulator/url.ini` → `[image_download_link]`
  `cn=https://devecostudio-drcn.deveco.dbankcloud.com`,
  `en=https://devecostudio-drcn.deveco.dbankcloud.com`
- `~/Developer/command-line-tools/version.txt` → Command Line Tools (mac-arm64) 6.1.1.280,
  `apiVersion: 24`, SDK HarmonyOS 6.1.1 Release (Ohos_sdk_public 6.1.1.125, API 24).

DevEco Studio path (step 6 of brief): checked `/Applications/` — no DevEco Studio installed;
`~/Library/Huawei/` does not exist. Official source confirmed as
`https://developer.huawei.com/consumer/en/deveco-studio/` (Mac ARM ~1 GB, login-gated
download). The ~1 GB IDE was **not** downloaded: its Device Manager negotiates signed
image URLs from the same `devecostudio-drcn.deveco.dbankcloud.com` backend that already
returned HTTP 403 unauthenticated and `only in the Chinese mainland` via CLI on this host,
so it cannot succeed without CN network or login — same gate, not a workaround.

## Image Picked

Latest Phone entry with osVersion HarmonyOS 6.1.1 API 24 (from the 63-entry catalog):

- `deviceType: phone`, `osVersion: HarmonyOS 6.1.1(24)`, `SoftWareVersion: 6.1.0.126`,
  `releaseType: Release`, `downloaded: false`

## License Result

- `./Emulator -license accept` → `All licenses have been automatically accepted.` (both agreements).
- Interactive `./Emulator -license` confirms 2 agreements pending review before acceptance.

## Download Proof

- `./Emulator -imageList -downloaded true` output after all install attempts:
  `No images matching the criteria were found.`
- Downloaded image count: **0**. Acceptance item "one downloaded image listed" is **NOT met** —
  nothing is fabricated. Unblock requires a mainland-CN network (or logged-in DevEco Studio
  on one), then re-run the install command above.
