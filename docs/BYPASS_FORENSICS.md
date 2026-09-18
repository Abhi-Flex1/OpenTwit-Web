# Emulator Binary Forensics — Region Gate Bypass

Date: 2026-09-18
Binary: `~/Developer/command-line-tools/emulator/Emulator` (DevEco Emulator 6.1.1.200, `sdk-pkg.json`)
Config: `~/Developer/command-line-tools/emulator/url.ini`

## 1. `url.ini` — `image_download_link` (lines 77–79)

```ini
[image_download_link]
cn=https://devecostudio-drcn.deveco.dbankcloud.com
en=https://devecostudio-drcn.deveco.dbankcloud.com
```

- Both `cn` and `en` values are **identical**: `https://devecostudio-drcn.deveco.dbankcloud.com`.
- No separate overseas mirror is configured here. The region gate is therefore **not** this URL — it is enforced in code before/at download time (see §2). Patching or overriding this key alone does not bypass the gate, but it is the file to patch if a mirror ever appears.

## 2. Gate String Location

Gate string (exact):

```text
Currently, this capability is available only in the Chinese mainland.
```

### Binary offsets (`grep -a -b -o`, decimal file offsets)

| String | Decimal file offset | Note |
|---|---|---|
| `Currently, this capability is available only in the Chinese mainland.` | `32804346` | the gate message (`strings -a -t d` agrees) |
| `vendorCountry=` | `32793833` | write/default site |
| `vendorCountry` | `32796759` | read/compare site |
| `vendorcountry=` | `32810995` | lowercase variant nearby |
| `country` | `32805022` | adjacent literal |
| `%1/country.region.xml` | `32807080` | format string: caller supplies base dir |
| `countryregion` (XML tag) | `32807111` | expected root tag |
| `image_download_link` | `32807577` | ini key read at download time |
| `country.region.xml` (bare) | `32815717` | second reference |
| `/Library/Application Support/Huawei/DevEcoStudio5.0/emulator` | `32815340` | base dir candidate |
| `/Library/Application Support/Huawei/DevEcoStudio5.0/options` | `32815401` | base dir candidate |
| `/Library/Application Support/Huawei/DevEcoStudio` | `32815538` | base dir candidate |
| `QString WidgetBugReport::GetUpdatedCountryCode()` | `32869592` | debug/mangled-name literal |
| `No <countryregion> found in XML.` | `32869668` | parse-failure path |
| `Can not get countryCode` | `32869745` | lookup-failure path |

### Gate function (from `nm`, Mach-O VM addresses)

```text
0000000100cd7e50 T __ZN15WidgetBugReport21GetUpdatedCountryCodeEv
0000000101d771c4 t __ZN15WidgetBugReport21GetUpdatedCountryCodeEv.cold.1
0000000101d771e0 t __ZN15WidgetBugReport21GetUpdatedCountryCodeEv.cold.2
```

- Demangled: `WidgetBugReport::GetUpdatedCountryCode()`.
- `strings` ordering places `GetUpdatedCountryCode` immediately next to `No <countryregion> found in XML.` and `Can not get countryCode`, i.e. the function parses `<base>/%1/country.region.xml`, looks for `<countryregion>` → `countryCode`, and falls through to the `Currently, this capability…` gate on failure/mismatch.
- `strings … | grep -i mainland|region|locale` otherwise returns only QEMU `memory_region*` / `redist regions` noise — there is **no IP-geolocation string** (`IP`, `geo`, `locale` check) in the `Emulator` binary. `grep -a` for `isMainland|getRegion` likewise finds **no such symbol** in the binary (only QEMU `memory_region_*` trace symbols). The gate is a **config-file country-code check**, not an IP check.

### How to reproduce

```bash
strings -a -t d ~/Developer/command-line-tools/emulator/Emulator \
  | grep -E "capability is available|vendorCountry|GetUpdatedCountryCode|country\.region\.xml|countryCode|image_download_link"

grep -a -b -o "Currently, this capability is available only in the Chinese mainland\." \
  ~/Developer/command-line-tools/emulator/Emulator

nm ~/Developer/command-line-tools/emulator/Emulator | grep GetUpdatedCountryCode
```

## 3. Config Keys

`grep -R -n -i -E "isMainland|getRegion|\bIP\b|mainland|region" ~/Developer/command-line-tools/emulator/` result summary:

- `isMainland` / `getRegion`: **zero hits** in text configs and zero symbols in the binary. Not a plist/env key — negative result, do not chase.
- What **does** exist (actionable keys/paths):
  - `vendorCountry=` / `vendorCountry` / `vendorcountry=` (binary literals; persisted config value compared against gate).
  - `%1/country.region.xml` + `<countryregion>` + `countryCode` + `Can not get countryCode` — the XML lookup chain in `GetUpdatedCountryCode()`.
  - `image_download_link` (`url.ini`) — download endpoint (cn == en, see §1).
  - `widget.settings.language.chinese|english`, `widget.settings.imagelanguage.*`, `widget.settings.skin.*` — UI prefs, not the gate.
  - `countryName`, `countryCode3c/3n`, `itu_t_t35_country_code` — ffmpeg/SSL baggage, not the gate.
  - `emulator.json` — device profiles only (no region keys). `sdk-pkg.json` — version only.
  - Base dirs baked in binary: `/Library/Application Support/Huawei/DevEcoStudio5.0/emulator`, `…/options`, `/Library/Application Support/Huawei/DevEcoStudio` — `%1` in `%1/country.region.xml` resolves against one of these.
  - IP/geo: only Huawei privacy-agreement boilerplate mentions collection of `IP address`; **no runtime IP check string** in the binary.

## 4. Bypass Hypothesis

Primary hypothesis: `GetUpdatedCountryCode()` reads `<base>/country.region.xml`, extracts `<countryregion><countryCode>`, and the image-download path shows the `Chinese mainland` gate unless the code is CN. No network/IP signal is consulted.

### Patch target (exact file, no binary patch needed)

Create the XML the function is already looking for. Candidate paths in priority order (from binary string order):

1. `/Library/Application Support/Huawei/DevEcoStudio5.0/emulator/country.region.xml`
2. `/Library/Application Support/Huawei/DevEcoStudio5.0/options/country.region.xml`
3. `/Library/Application Support/Huawei/DevEcoStudio/country.region.xml`

Expected shape (from adjacent literals `countryregion` + `countryCode`):

```xml
<countryregion>
  <countryCode>CN</countryCode>
</countryregion>
```

If a `vendorCountry=CN` entry exists in the emulator prefs under one of the base dirs above, set it to `CN` as well.

### One concrete bypass command

```bash
sudo mkdir -p "/Library/Application Support/Huawei/DevEcoStudio5.0/emulator" \
  "/Library/Application Support/Huawei/DevEcoStudio5.0/options" \
  "/Library/Application Support/Huawei/DevEcoStudio" && \
for d in "/Library/Application Support/Huawei/DevEcoStudio5.0/emulator" \
         "/Library/Application Support/Huawei/DevEcoStudio5.0/options" \
         "/Library/Application Support/Huawei/DevEcoStudio"; do
  printf '<countryregion>\n  <countryCode>CN</countryCode>\n</countryregion>\n' \
    | sudo tee "$d/country.region.xml" >/dev/null
done && \
cat "/Library/Application Support/Huawei/DevEcoStudio5.0/emulator/country.region.xml" && \
strings -a -t d ~/Developer/command-line-tools/emulator/Emulator | grep -E "Can not get countryCode|country\.region"
```

Fallback (binary-level, only if XML alone fails): NOP/force-true the branch in `WidgetBugReport::GetUpdatedCountryCode()` (`0x100cd7e50`) or patch the gate string's caller — requires `lldb`/Hopper disassembly of that function; try the XML file first since the binary already contains the `No <countryregion> found` / `Can not get countryCode` fallbacks proving a file-missing path exists.

Env/locale spoofing (`LANG=zh_CN.UTF-8`, `LC_ALL=zh_CN.UTF-8`) is **not** expected to work alone — no `LANG`/`LC_*`/NSLocale gate strings adjacent to the gate; covered in `docs/LOCALE_SPOOF_RUN.md` (not touched here).
