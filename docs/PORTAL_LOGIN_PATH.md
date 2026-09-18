# Portal Login Path — Signed Emulator Image Download

Date: 2026-09-18 (UTC). Source: `docs/EMULATOR_SETUP_AND_TEST_REPORT.md` (§2, Summary).
Target image: Phone, `HarmonyOS 6.1.1(24)`, SoftWareVersion `6.1.0.126`
(from `Emulator -imageList`). Status: **BLOCKED on Huawei ID login — no zip downloaded yet.**
No proxy tools or proxy flags used anywhere on this path.

Reused failing commands from the report (verbatim, direct, no proxy flags):

- `curl -sSI https://devecostudio-drcn.deveco.dbankcloud.com` → `HTTP 403 Forbidden`
  (re-confirmed 2026-09-18; no public unauthenticated direct-download URL).
- `Emulator -install -deviceType Phone -osVersion "HarmonyOS 5.0.1(13)" -force`
  → `Currently, this capability is available only in the Chinese mainland.`
  (CLI image download is region-gated on this host.)

## Login Steps

Agent limitation (truthful): this head has no browser-automation tool and no
Huawei ID credentials, so the login + devtools capture below must be done by a
human. Steps:

1. Open `https://developer.huawei.com/consumer/en/deveco-studio/` (DevEco Studio
   download page) in a desktop browser.
2. Log in with a Huawei ID (accept the emulator license agreements if prompted —
   `Emulator -license` shows 2 unaccepted on this host).
3. Open DevTools → Network tab, filter for `dbankcloud.com` or `zip`.
4. Start the Phone `HarmonyOS 6.1.1(24)` (SoftWareVersion `6.1.0.126`) image
   download (via the page or DevEco Studio device manager).
5. Right-click the image-file request → Copy → Copy as cURL. Note the full
   signed URL plus the `Cookie` and `Authorization` request headers.

## Signed URL Pattern

- Image host (from `emulator/url.ini`, `[image_download_link]`):
  `https://devecostudio-drcn.deveco.dbankcloud.com`
- Authenticated pattern (query values issued per-session after login; placeholders,
  NOT a working URL — nothing fabricated):
  `https://devecostudio-drcn.deveco.dbankcloud.com/<image-path>/phone-6.1.0.126-api24.zip?AccessKeyId=<FROM_DEVTOOLS>&Expires=<FROM_DEVTOOLS>&Signature=<FROM_DEVTOOLS>`
- Catalog anchor: `deviceType=phone`, `osVersion=HarmonyOS 6.1.1(24)`,
  `SoftWareVersion=6.1.0.126`, `downloaded=false` (as of 2026-09-18).

## Curl Command

Failing unauthenticated probe (reused, no proxy flags):

```sh
curl -sSI https://devecostudio-drcn.deveco.dbankcloud.com
# → HTTP 403 Forbidden (expected without login)
```

Authenticated download template — paste `Cookie` + `Authorization` captured in
Login Steps, then run (direct, `curl -L`, no proxy flags):

```sh
curl -L \
  -H "Cookie: <PASTE_FROM_DEVTOOLS>" \
  -H "Authorization: <PASTE_FROM_DEVTOOLS>" \
  -o ~/Downloads/phone-6.1.0.126-api24.zip \
  "https://devecostudio-drcn.deveco.dbankcloud.com/<PASTE_SIGNED_PATH_AND_QUERY_FROM_DEVTOOLS>"
```

Do NOT add `-x`, `--proxy`, or any `*_proxy` env vars (policy: no proxy tools).

## Zip Path

- Intended: `~/Downloads/phone-6.1.0.126-api24.zip`
- Actual (2026-09-18): **not downloaded** — `ls ~/Downloads/` shows no zip
  files; blocked on human Huawei ID login + signed-URL capture above.
- Next head/lead: after running the Curl Command, verify with
  `ls -la ~/Downloads/*.zip` and record the real filename here.
