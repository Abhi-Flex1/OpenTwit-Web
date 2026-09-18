# Redownload Result (Iris 2)

## 1. Clean
- Ran: `rm -rf /Users/abhi/Library/Huawei/Sdk/system-image/HarmonyOS-6.1.1/phone_all_arm`
- Result: corrupt dir cleared (was empty/stale, removed OK).

## 2. Env
- Ran in `~/Developer/command-line-tools/bin`:
  `export vendorCountry=CN countryCode=CN LANG=zh_CN.UTF-8 TZ=Asia/Shanghai`

## 3. Install (Phone, HarmonyOS 6.1.1(24), force)
- Ran: `./Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)" -force`
- Expected bytes: 2368067717
- Install tail:
```
99.7% (2361819136/2368067717 bytes)
99.7% (2362122997/2368067717 bytes)
99.8% (2363457536/2368067717 bytes)
99.9% (2364734136/2368067717 bytes)
99.9% (2365755392/2368067717 bytes)
100.0% (2367143936/2368067717 bytes)
100.0% (2367796628/2368067717 bytes)
100.0% (2368067717/2368067717 bytes)
The image is downloaded successfully.
```

## 4. Zip size
- Download total: 2368067717 bytes (100.0% reached).
- Installer zip is consumed/extracted after install; no *.zip remains under
  `/Users/abhi/Library/Huawei/Sdk/system-image/HarmonyOS-6.1.1/`.
- Extracted dir `phone_all_arm/` total bytes: 4752031934 (~4.4G du), files:
  Image (29M), ramdisk.img (3.2M), sys_prod.img (800M), system.img (3.4G),
  userdata.img (100M), vendor.img (100M), plus features.ini/info.json/sdk-pkg.json/image_signature/.

## 5. imageList (downloaded=true)
- Ran: `./Emulator -imageList -downloaded true` (same env, exit 0)
```
[
    {
        "SoftWareVersion": "6.1.0.126",
        "deviceType": "phone",
        "downloaded": "true",
        "osVersion": "HarmonyOS 6.1.1(24)",
        "releaseType": "Release",
        "upgradable": "false"
    },
    {
        "SoftWareVersion": "6.1.0.126",
        "deviceType": "foldable",
        "downloaded": "true",
        "osVersion": "HarmonyOS 6.1.1(24)",
        "releaseType": "Release",
        "upgradable": "false"
    },
    {
        "SoftWareVersion": "6.1.0.126",
        "deviceType": "triplefold",
        "downloaded": "true",
        "osVersion": "HarmonyOS 6.1.1(24)",
        "releaseType": "Release",
        "upgradable": "false"
    },
    {
        "SoftWareVersion": "6.1.0.126",
        "deviceType": "widefold",
        "downloaded": "true",
        "osVersion": "HarmonyOS 6.1.1(24)",
        "releaseType": "Release",
        "upgradable": "false"
    }
]
```

Acceptance: Phone 6.1.1 downloaded=true present.
