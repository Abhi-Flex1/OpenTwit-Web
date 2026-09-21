# OpenTwit-Web
Full Twitter/X web port for HarmonyOS — the real x.com web app inside a native HarmonyOS shell.

Previous native-API mock (8 starter posts via fxtwitter/syndication) was **replaced**: this version loads `https://x.com` in the system `Web` component, so timeline, login, post, explore, notifications, DMs, profile all work with full web parity. Native feel comes from HarmonyOS chrome around it: Navigation title + progress, back/forward/reload, bottom `Tabs` with HarmonyOS Symbols, light/dark adaptation, offline retry, geolocation grant.

## Features
- **Full web Twitter**: `https://x.com/home`, `/explore`, `/notifications`, `/messages`, `/settings/profile` — login via web cookies, no API key
- **Native shell**: linear progress + first-load spinner, bottom bar (Home/Explore/Notifications/Messages/Profile) with the filled HarmonyOS Symbols `house_fill`, `compass_circle_fill`, `bell_fill`, `envelope_fill`, `person_fill` — the same filled glyph in both states, with system blue for the selected tab, secondary grey otherwise, and a native unread badge on Notifications. It becomes a **side navigation rail** on wide layouts (tablet / unfolded foldable / 2in1), with a haptic tick on tab change
- **Native headers, laid out like the stock app**: Home gets the account avatar plus a native "For you / Following" switcher that drives the page's real timeline tab; Explore puts a native `Search` field in the header (it also stays put on result pages); Notifications/Messages/Profile get a centred title over a subtitle (`@handle` on profiles) with at most one trailing gear — notification settings, settings, settings — and nothing else. Pages pushed from a tab keep a back arrow and a real page name, never a duplicated tab label
- **Native account menu**: the Home avatar opens a HarmonyOS menu for Profile, Bookmarks, Lists and Settings and privacy, so those pages are one tap away instead of buried in the web UI
- **Native compose**: floating compose button on the four content tabs opening a native bottom sheet (Cancel / New post / Post) that hosts `x.com/compose/post`; Post drives the page's own submit button and reports the outcome as a native toast. On Messages the same button starts a new direct message, as the stock app does
- **Native web-chrome removal**: X's own top nav, bottom nav, page headers and floating compose button are stripped by injected CSS/JS (`common/WebChrome.ets`) so the shell never double-renders chrome; the shell reads the page instead — `document.title` for the header, the Home timeline's own tab row for the switcher, `aria-selected` to keep it in step
- **Route-aware user agent**: the shell picks the UA each route needs (the desktop-class UA only for the e-mail sign-up flow, which x.com refuses on mobile web) instead of asking the user to toggle a desktop mode
- **Tab sync**: in-page web navigation updates the native tab index via URL mapping
- **Web hardening**: JavaScript + DOM storage on, `mixedMode(Compatible)`, `fileAccess(false)`, `CacheMode.Default`, `WebDarkMode.Auto`, zoom/overview on, autoplay gesture off, custom UA `OpenTwit-Web/1.0 HarmonyOS`
- **Resilience**: native offline card with Retry on `onErrorReceive`, automatic render-process recovery on `onRenderExited`
- **HarmonyOS compliance**: layered app icon, system colour resources (real light/dark), `app.string.*` localisation (en + zh_CN), native back navigation, geolocation consent dialog, system photo picker for uploads — see [docs/HARMONY_GUIDELINE_AUDIT.md](docs/HARMONY_GUIDELINE_AUDIT.md)
- Phone / tablet, Stage model only, API 24

## Signed build

`dist/OpenTwit-Web-1.0.0-signed.hap` is built by `scripts/sign-hap.sh`, which
signs the assembled HAP with the OpenHarmony test signing material that ships in
the SDK (`toolchains/lib`). It installs and runs on an emulator image that trusts
the OpenHarmony test root — verified on the foldable AVD. Retail HarmonyOS
devices want an AppGallery-issued certificate and profile for
`com.opentwit.web`, which only the account owner can request from AGC; swapping
that material in is the only change the script needs. Details and the exact
commands per step are in
[docs/HARMONY_GUIDELINE_AUDIT.md](docs/HARMONY_GUIDELINE_AUDIT.md) §8.6.

```bash
ohpm install && hvigorw assembleHap --no-daemon   # produces the unsigned HAP
./scripts/sign-hap.sh                             # -> dist/OpenTwit-Web-1.0.0-signed.hap
hdc install -r dist/OpenTwit-Web-1.0.0-signed.hap # uninstall any unsigned build first
```

## Screenshots

`screenshots/final/mobile/` — signed-in phone sweep (Home For you / Following,
account menu, Explore + results, Notifications, notification settings, Messages,
Profile, Settings). `screenshots/final/foldable/` — the same shell on the 955 vp
foldable AVD: side rail, native header, account menu, compose sheet, plus the
signed HAP running after install (that AVD is signed out; see the audit doc §8.5).

## Project layout (remade)
- `AppScope/app.json5` — bundle `com.opentwit.web`
- `entry/src/main/ets/entryability/EntryAbility.ets` — loads `pages/MainTabs`
- `entry/src/main/ets/pages/MainTabs.ets` — single WebView + native chrome (the whole app)
- `entry/src/main/ets/common/WebConfig.ets` — routes, titles, UA, URL→tab mapping
- `entry/src/main/ets/common/Theme.ets` — font + theme tokens
- `entry/src/main/resources/{base,dark,zh_CN}/element/*.json` — strings + start-window colour per qualifier; UI colours come from `sys.color.*`
- `AppScope/resources/base/media/{layered_image.json,background.png,foreground.png,app_icon.png}` — layered app icon, generated by `scripts/make-icons.py`
- Old `services/` (`WebTimeline`, `UserApi`, …), `viewmodels/`, `components/TweetCard|Composer|LiveTweetList`, `pages/Home|Explore|Notify|Messages|Profile|Login|Detail|UserProfile`, `common/TokenStore|WebFallback|HarmonyCard` removed — dead native-mock stack

## Prerequisites
- HarmonyOS Command Line Tools 6.1.1 (hvigor 6.24.2, ohpm 6.1.2, SDK 6.1.1 API 24) in `~/Developer/command-line-tools`
- JDK 17 (`brew install openjdk@17`), Node 18 bundled in `command-line-tools/tool/node/bin`
- `~/.npmrc` containing `@ohos:registry=https://repo.harmonyos.com/npm/`
- `local.properties`: `sdk.dir=/Users/abhi/.ohos/sdk-remap` (symlink to `~/Developer/command-line-tools/sdk/default` + `24 -> openharmony` fix for hvigor SDK layout)

## PATH (.zprofile)
`~/Developer/command-line-tools` on PATH (as requested):
```bash
export PATH="$HOME/Developer/command-line-tools/bin:$HOME/Developer/command-line-tools/tool/node/bin:/opt/homebrew/opt/openjdk@17/bin:$PATH"
export PATH="$HOME/Developer/command-line-tools/sdk/default/openharmony/toolchains:$PATH"   # hdc
export DEVECO_SDK_HOME="$HOME/Developer/command-line-tools/sdk"
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
```
Also (emulator hdc fix): `ln -s ~/Developer/command-line-tools/sdk ~/Developer/sdk`.

## Build (unsigned debug HAP)
```bash
export PATH="$HOME/Developer/command-line-tools/bin:/opt/homebrew/opt/openjdk@17/bin:$HOME/Developer/command-line-tools/tool/node/bin:$PATH"
export DEVECO_SDK_HOME="$HOME/Developer/command-line-tools/sdk"
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
ohpm install
hvigorw assembleApp
# outputs:
#   entry/build/default/outputs/default/entry-default-unsigned.hap
#   build/outputs/default/OpenTwit-Web-default-unsigned.app
```
Debug builds are unsigned on purpose (`signingConfigs: []`). For signed release, provision via DevEco Studio (File > Project Structure > Signing Configs); never commit `.p12`/`.cer`/profiles.

## Emulator (phone, HarmonyOS 6.1.1 API 24)
Image download via `Emulator -install` is geo-gated to the Chinese mainland since DevEco 6.1.0 Beta1. No proxy needed — locale/timezone exports are enough (the `export ...` trick from `Abhi-Flex1/OpenTwit@e87a9ee` README):
```bash
export PATH="$HOME/Developer/command-line-tools/bin:$PATH"
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export TZ=Asia/Shanghai
Emulator -license accept
Emulator -imageList -deviceType Phone            # works globally
Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)" -force
# ~2.2 GB ARM64 image -> ~/Library/Huawei/Sdk/system-image/HarmonyOS-6.1.1/phone_all_arm/
Emulator -create OpenTwitPhone -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)"
# wide-layout AVD used for the tablet/foldable check (955 vp unfolded):
Emulator -create OpenTwitWide2 -deviceType Foldable -osVersion "HarmonyOS 6.1.1(24)" \
  -screen "2388 2480 400 8.0" "2388 2480 400 8.0"
ln -s ~/Developer/command-line-tools/sdk ~/Developer/sdk   # CLI-tools layout fix so Emulator UI finds hdc
Emulator -start OpenTwitPhone   # run it in a shell that STAYS OPEN: a detached
                                # "nohup ... &" child is killed with its session
# new terminal once boot finishes (hdc shows 127.0.0.1:5555):
hdc list targets
hdc -t 127.0.0.1:5555 install entry/build/default/outputs/default/entry-default-unsigned.hap
hdc -t 127.0.0.1:5555 shell aa start -b com.opentwit.web -a EntryAbility
```
Why 6.1 not 7: HarmonyOS 7 (API 26) announced at HDC 2026 is developer-beta only; latest stable Release suite is 6.1.1 (API 24), no HarmonyOS 7 image listed by stable 6.1.1 CLI tools. App uses only stable Stage-model APIs so it carries over unchanged.

Verified 2026-09-21 on both AVDs (phone 377 vp + foldable 955 vp): install,
launch, tab switching and tab sync, system Back (web history → Home tab →
leave app), offline retry, light/dark theme, launcher icon, `zh_CN`
localisation, bottom bar on phone and navigation rail on the wide device.
Method, per-finding fixes and the screenshot names are in
[docs/HARMONY_GUIDELINE_AUDIT.md](docs/HARMONY_GUIDELINE_AUDIT.md).

### App icons
`scripts/make-icons.py` regenerates the layered icon set
(`AppScope/resources/base/media/{background,foreground}.png`, `app_icon.png`
in both scopes) — run it after a palette change instead of editing PNGs by hand.

## License
Apache-2.0 — see LICENSE.
