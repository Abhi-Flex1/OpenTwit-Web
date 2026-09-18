# Final Test Report — OpenTwit-Web on HarmonyOS Emulator

Date: 2026-09-18. Device: OpenTwit_Phone_API24 (Phone, HarmonyOS 6.1.1 API 24).
Serial: 127.0.0.1:5555. HDC: 3.2.0d. Emulator: 6.1.1.200.

## Emulator install
- Env: export vendorCountry=CN countryCode=CN LANG=zh_CN.UTF-8 TZ=Asia/Shanghai
- `Emulator -install -deviceType Phone -osVersion HarmonyOS 6.1.1(24) -force` reached 100% (2368067717 bytes), image downloaded successfully.
- Extra fix: `ln -sfn ~/Developer/command-line-tools/sdk ~/Developer/sdk` so the emulator finds hdc.

## AVD
- `Emulator -create OpenTwit_Phone_API24 -deviceType Phone -osVersion HarmonyOS 6.1.1(24)` → Device create success.
- `Emulator -start OpenTwit_Phone_API24` → Guest OS Boot Completed, `hdc list targets` → 127.0.0.1:5555.

## Build
- API 24 (compileSdkVersion 24, compatibleSdkVersion 24), hvigor 6.24.2, Java 17.
- `hvigorw assembleHap -m module -p product=default -p buildMode=debug` → PackageHap OK.
- Signed HAP blocked (needs Huawei-issued .p7b/.cer); unsigned HAP `entry/build/default/outputs/default/entry-default-unsigned.hap` (158KB) installs fine on the emulator.

## Install + launch + screenshots
- `hdc install entry-default-unsigned.hap` → install bundle successfully.
- `hdc shell aa start -b com.example.opentwit -a EntryAbility` → start ability successfully.
- `snapshot_display` to screenshots/final-1.jpeg (234KB, Home timeline with 5 tweets + Compose + tab bar) and final-2.jpeg (114KB, Messages list).
- Timeline visible: yes.
