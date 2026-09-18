# Install Result — verify bypass + Phone 6.1.1 install

Date: 2026-09-18
Host: macOS (abhi), worktree opentwit-web-gus-dba0ee92

## 1. Expected paths (docs/BYPASS_SUDO_RUN.md line 1, Sudo Result)
1. `/Library/Application Support/Huawei/DevEcoStudio5.0/emulator/country.region.xml`
2. `/Library/Application Support/Huawei/DevEcoStudio5.0/options/country.region.xml`
3. `/Library/Application Support/Huawei/DevEcoStudio/country.region.xml`

## 2. ls output (line 1, symbol countryCode — confirm value CN)
```
-rw-r--r--  1 root  admin  65 Sep 18 16:26 /Library/Application Support/Huawei/DevEcoStudio5.0/emulator/country.region.xml
-rw-r--r--  1 root  admin  65 Sep 18 16:26 /Library/Application Support/Huawei/DevEcoStudio5.0/options/country.region.xml
-rw-r--r--  1 root  admin  65 Sep 18 16:26 /Library/Application Support/Huawei/DevEcoStudio/country.region.xml
```
File content (all three identical):
```xml
<countryregion>
  <countryCode>CN</countryCode>
</countryregion>
```
Verdict: BYPASS VERIFIED — 3/3 files exist, value CN. (Note: literal brief variant `.../DevEcoStudio5.0/emulator/options/country.region.xml` does NOT exist — `ls` → No such file or directory.)

## 3. License accept (folder ~/Developer/command-line-tools/bin, line 1, symbol license)
Command: `./Emulator -license accept`
Result: exit 0, stdout ends with `All licenses have been automatically accepted.`

## 4. Install output
Command: `./Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)" -force`
Result: exit 0, stdout exactly:
```text
Currently, this capability is available only in the Chinese mainland.
```
Gate still fires despite 3/3 CN files present.

## 5. imageList output
Command: `./Emulator -imageList -downloaded true`
Result: exit 0, stdout exactly:
```text
No images matching the criteria were found.
```
Full `Emulator -imageList` shows phone 6.1.1(24) entry (`SoftWareVersion 6.1.0.126`) with `"downloaded": "false"`.

## 6. Verdict
- Acceptance "docs/GUS_INSTALL_RUN.md exists" — MET (this file).
- Acceptance "imageList shows one Phone 6.1.1 downloaded true" — NOT met (0 images downloaded; install blocked by region gate).
- Next: gate bypass needs more than the three XML files (possible 4th literal path `.../emulator/options/country.region.xml`, or another vendorCountry source). Did not touch build-profile.json5, entry/build-profile.json5, docs/HANK2_AVD_BOOT.md, docs/ADA2_TEST_REPORT.md.
