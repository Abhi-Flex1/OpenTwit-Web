# Bypass Result — CN country-code bypass execution run

Date: 2026-09-18
Host: macOS (abhi), worktree opentwit-web-zola-64e52cca

## 1. Forensics reference (docs/BYPASS_FORENSICS.md line 1, Gate String Location)
- Gate string: `Currently, this capability is available only in the Chinese mainland.` @ decimal offset 32804346
- Function: `WidgetBugReport::GetUpdatedCountryCode()` (`__ZN15WidgetBugReport21GetUpdatedCountryCodeEv`)
- Key: `vendorCountry` (read/compare site 32796759; write/default `vendorCountry=` 32793833)
- Format string: `%1/country.region.xml` (32807080) + root tag `countryregion` (32807111) + `countryCode` lookup

## 2. Baked base dirs (strings anchored at country.region.xml)
Command:
```bash
strings -a ~/Developer/command-line-tools/emulator/Emulator | grep -F "country.region.xml"
strings -a ~/Developer/command-line-tools/emulator/Emulator | grep -F "/Library/Application Support/Huawei"
```
Output:
- `%1/country.region.xml`
- `country.region.xml`
- `/Library/Application Support/Huawei/DevEcoStudio5.0/emulator`
- `/Library/Application Support/Huawei/DevEcoStudio5.0/options`
- `/Library/Application Support/Huawei/DevEcoStudio`

## 3. Base dirs written — BLOCKED (no write)
Target XML shape (line 1, symbol countryCode):
```xml
<countryregion>
  <countryCode>CN</countryCode>
</countryregion>
```
Targets:
1. `/Library/Application Support/Huawei/DevEcoStudio5.0/emulator/country.region.xml` — NOT WRITTEN
2. `/Library/Application Support/Huawei/DevEcoStudio5.0/options/country.region.xml` — NOT WRITTEN
3. `/Library/Application Support/Huawei/DevEcoStudio/country.region.xml` — NOT WRITTEN
- `mkdir -p` without sudo: `Permission denied` on `/Library/Application Support/Huawei`.
- With sudo: `sudo: a terminal is required to read the password` — non-interactive agent has no tty/askpass, so elevation is impossible from here.
- `ls` confirms none of the three files exist. Needs lead/user to run the forensics-doc command with admin rights:
```bash
sudo mkdir -p "/Library/Application Support/Huawei/DevEcoStudio5.0/emulator" "/Library/Application Support/Huawei/DevEcoStudio5.0/options" "/Library/Application Support/Huawei/DevEcoStudio" && for d in "/Library/Application Support/Huawei/DevEcoStudio5.0/emulator" "/Library/Application Support/Huawei/DevEcoStudio5.0/options" "/Library/Application Support/Huawei/DevEcoStudio"; do printf '<countryregion>\n  <countryCode>CN</countryCode>\n</countryregion>\n' | sudo tee "$d/country.region.xml" >/dev/null; done
```

## 4. License accept (~/Developer/command-line-tools/bin anchored at license)
Command: `Emulator -license accept` (cwd `~/Developer/command-line-tools/bin`)
Result: exit 0, `All licenses have been automatically accepted.`

## 5. Install retry (same bin folder, no proxy flags)
Command: `Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)" -force`
Result: exit 0, stdout exactly:
```text
Currently, this capability is available only in the Chinese mainland.
```
Gate still fires — expected since step 3 XML files could not be written.

## 6. imageList downloaded output
Command: `Emulator -imageList -downloaded true`
Result: exit 0, stdout exactly:
```text
No images matching the criteria were found.
```
Full `Emulator -imageList` shows Phone 6.1.1(24) entry with `"downloaded": "false"` (`SoftWareVersion 6.1.0.126`, `deviceType phone`, `releaseType Release`). Acceptance criterion "one Phone 6.1.1 downloaded image" is NOT met — blocked on step 3 elevation.

## 7. Verdict
- BYPASS NOT EXECUTED — blocked at step 3 (root-owned /Library, no sudo tty).
- License accept: done. Install retry + imageList: recorded above, gate persists.
- Next action for lead: re-run this head (or the sudo one-liner above) in a terminal with admin rights, then retry step 5.
