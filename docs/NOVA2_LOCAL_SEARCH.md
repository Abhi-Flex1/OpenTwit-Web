# Local Export

Nova 2 local search for gemini export command (2026-09-18).

## 1. Checkout paths (mdfind, name OpenTwit, kind)
- `mdfind "kMDItemDisplayName == '*OpenTwit*' || kMDItemFSName == '*OpenTwit*'"` hit:
  - `/Users/abhi/Desktop/HarmonyOS Ports/OpenTwit-Web`
- `mdfind -name OpenTwit` hit:
  - `/Users/abhi/Desktop/HarmonyOS Ports/OpenTwit-Web`
- No Abhi-Flex1 OpenTwit checkout found outside the current project; only the one checkout above exists.
- Current worktree: `/Users/abhi/.droppy-code/worktrees/opentwit-web-nova-2-13bc0398`

## 2. History hits (grep Emulator in ~/.zsh_history + ~/.bash_history + ~/.ohos/logs, anchored at export)
- `~/.bash_history`: does not exist.
- `~/.ohos/logs/`: does not exist (`~/.ohos/` contains only `config/`, `sdk-remap/`).
- `grep -h "Emulator" ~/.zsh_history | grep -i "export"`: no hits.
- `grep -h -i "export" ~/.zsh_history` sole hit (country-region bootstrap, also the Emulator-adjacent export candidate):
  - `sudo mkdir -p "/Library/Application Support/Huawei/DevEcoStudio5.0/emulator" ... && ... printf '<countryregion>\n  <countryCode>CN</countryCode>\n</countryregion>\n' | sudo tee "$d/country.region.xml" >/dev/null; done`
- `grep -h -i "emulator" ~/.zsh_history` hits (no export prefix, for context):
  - `flutter emulators`
  - `Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)" -force, Emulator -create OpenTwit_Phone_API24 -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)"`
- `~/.zprofile` export candidate lines (active shell exports, no gemini export found):
  - `export PATH="$HOME/Developer:$HOME/Developer/flutter/bin:$PATH"`
  - `export PATH=/Users/abhi/.opencode/bin:$PATH`
  - `export PATH=$HOME/Developer/command-line-tools/bin:$PATH`
  - `export PATH=$HOME/Developer/command-line-tools/sdk/default/openharmony/toolchains:$PATH`
  - `export HDC_SERVER_PORT=7035`
- No `export GEMINI*` / `export GOOGLE_*` / gemini export command found in `~/.zsh_history` or `~/.zprofile`.

## 3. Env keys (grep -R vendorCountry + countryCode + DevEco + OHOS in ~/Developer/command-line-tools/emulator, anchored at env)
- Target dir exists: `/Users/abhi/Developer/command-line-tools/emulator`
- `grep -R -i -E "vendorCountry|countryCode|DevEco|OHOS"` hits:
  - `url.ini: cn=https://devecostudio-drcn.deveco.dbankcloud.com` (DevEco key)
  - `url.ini: en=https://devecostudio-drcn.deveco.dbankcloud.com` (DevEco key)
  - `url.ini: ...?code=CN&branchid=0...` (country code params, `code=CN`)
  - Binary match: `Emulator` (contains vendorCountry/countryCode strings, binary)
  - Binary match: `emulator-crash-service`
  - Binary match: `libQt5Network.5.dylib`, `libQt5Core.5.dylib`
- `country.region.xml` env effect (written by history command above):
  - `/Library/Application Support/Huawei/DevEcoStudio5.0/emulator/country.region.xml`: `<countryCode>CN</countryCode>`
  - `/Library/Application Support/Huawei/DevEcoStudio5.0/options/country.region.xml`: `<countryCode>CN</countryCode>`
- Live `env | grep -i gemini|google|ohos|deveco|vendor|country|emulator`: no hits.

## Export candidate line
- `export HDC_SERVER_PORT=7035`
