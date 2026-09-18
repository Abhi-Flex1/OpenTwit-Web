# Sudo Result — CN region files with admin + install retry

Date: 2026-09-18
Host: macOS (abhi), worktree opentwit-web-tova-d1dc7e3a

## 1. Forensics reference (docs/BYPASS_FORENSICS.md line 1, Gate String Location)
- Gate string: `Currently, this capability is available only in the Chinese mainland.` @ decimal offset 32804346
- Function: `WidgetBugReport::GetUpdatedCountryCode()` (`__ZN15WidgetBugReport21GetUpdatedCountryCodeEv`)
- Key: `vendorCountry` (read/compare 32796759; write/default `vendorCountry=` 32793833)

## 2. Base dirs (docs/BYPASS_EXEC_RUN.md line 1, Bypass Result — under Library Application Support Huawei)
1. `/Library/Application Support/Huawei/DevEcoStudio5.0/emulator`
2. `/Library/Application Support/Huawei/DevEcoStudio5.0/options`
3. `/Library/Application Support/Huawei/DevEcoStudio`
- Note: brief step 4 names `.../DevEcoStudio5.0/emulator/options`; binary strings show `.../DevEcoStudio5.0/options` (no `emulator/` infix). The admin script below writes both variants, so all readings are covered.

## 3. Write attempt (line 1, symbol countryCode, value CN)
Target XML shape, file `country.region.xml` line 1:
```xml
<countryregion>
  <countryCode>CN</countryCode>
</countryregion>
```
Method per brief: admin privilege via `osascript do shell script ... with administrator privileges` for mkdir plus tee (script staged at `/var/folders/bg/tc86dhpd5rj9z1s_0tqtnr2h0000gn/T/opencode/write_region.sh`, run via `osascript -e 'do shell script "/bin/sh <script>" with administrator privileges'`).
Result: BLOCKED — osascript admin prompt has no GUI approver in this session; command produced no output and hit the 120 s timeout (killed afterwards). `sudo -n true` → `sudo: a password is required` (exit 1). Direct `ls` confirms `/Library/Application Support/Huawei` does not exist.
File states after attempt:
1. `/Library/Application Support/Huawei/DevEcoStudio5.0/emulator/country.region.xml` — MISSING (not written)
2. `/Library/Application Support/Huawei/DevEcoStudio5.0/options/country.region.xml` — MISSING (not written)
3. `/Library/Application Support/Huawei/DevEcoStudio/country.region.xml` — MISSING (not written)
(Also staged `.../DevEcoStudio5.0/emulator/options/country.region.xml` in the same script for the brief's literal path — likewise not written, same blocker.)
Exact admin one-liner for lead/user terminal:
```bash
sh /var/folders/bg/tc86dhpd5rj9z1s_0tqtnr2h0000gn/T/opencode/write_region.sh
# or, with prompt in a terminal:
sudo mkdir -p "/Library/Application Support/Huawei/DevEcoStudio5.0/emulator" "/Library/Application Support/Huawei/DevEcoStudio5.0/options" "/Library/Application Support/Huawei/DevEcoStudio" && for d in "/Library/Application Support/Huawei/DevEcoStudio5.0/emulator" "/Library/Application Support/Huawei/DevEcoStudio5.0/options" "/Library/Application Support/Huawei/DevEcoStudio"; do printf '<countryregion>\n  <countryCode>CN</countryCode>\n</countryregion>\n' | sudo tee "$d/country.region.xml" >/dev/null; done
```

## 4. Install retry (folder ~/Developer/command-line-tools/bin)
Command: `Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)" -force`
Result: exit 0, stdout exactly:
```text
Currently, this capability is available only in the Chinese mainland.
```
Gate still fires — expected since the three XML files could not be written.

## 5. imageList downloaded output
Command: `Emulator -imageList -downloaded true`
Result: exit 0, stdout exactly:
```text
No images matching the criteria were found.
```
Full `Emulator -imageList` shows Phone 6.1.1(24) entry with `"downloaded": "false"` (`SoftWareVersion 6.1.0.126`). Acceptance "one image downloaded" NOT met — blocked on admin write.

## 6. Verdict
- SUDO RUN NOT COMPLETED — blocked at admin write (no tty/askpass, no GUI approver for osascript).
- Acceptance: three country.region.xml files with CN — NOT met (0/3 exist). imageList downloaded shows one image — NOT met (0 images).
- Next action for lead: run the section-3 one-liner in a terminal with admin rights, then retry section-4 install. Did not touch build-profile.json5, docs/EMU_RETRY_RUN.md, docs/HAP_RETRY_RUN.md.
