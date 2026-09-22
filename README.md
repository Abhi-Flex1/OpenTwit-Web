# OpenTwit-Web
Full Twitter/X web port for HarmonyOS — the real x.com web app inside a native HarmonyOS shell.

[![Release](https://img.shields.io/github/v/release/Abhi-Flex1/OpenTwit-Web?display_name=tag)](https://github.com/Abhi-Flex1/OpenTwit-Web/releases/latest)

Previous native-API mock (8 starter posts via fxtwitter/syndication) was **replaced**: this version loads `https://x.com` in the system `Web` component, so timeline, login, post, explore, notifications, DMs and profile all come from the real web app. Everything that is *chrome* is native HarmonyOS instead: per-tab headers with a native Home timeline switcher, Explore's search field, the account menu, compose FAB + sheet, a bottom bar that becomes a side rail, system colours (real light/dark), HarmonyOS Sans and Symbols throughout, offline retry, and a geolocation consent dialog.

## Features
- **Full web Twitter**: `https://x.com/home`, `/explore`, `/notifications`, `/messages`, `/settings/profile` — login via web cookies, no API key
- **Native shell**: linear progress + first-load spinner, bottom bar (Home/Explore/Notifications/Messages/Profile) with the filled HarmonyOS Symbols `house_fill`, `compass_circle_fill`, `bell_fill`, `envelope_fill`, `person_fill` — the same filled glyph in both states, with system blue for the selected tab, secondary grey otherwise, and a native unread badge on Notifications **and** Messages. It becomes a **side navigation rail** on wide layouts (tablet / unfolded foldable / 2in1), with a haptic tick on tab change
- **Live unread counts**: the shell reads the counts from the page's own navigation entries (x.com spends its accessible labels on them, and the shell keeps `document.title`'s `"(3) …"` as a fallback), shows them on the tab bar, clears the one for the tab you are on, and re-reads them on every in-page navigation, every 30 s, and whenever the app comes back to the foreground. A count the page has not published yet reads as "unknown" rather than zero, so a page load under a tab change cannot blank the badge — the shell keeps the last count and re-asks. Arabic-Indic digits are normalised, so the count survives an Arabic page
- **App-icon badge**: the same total goes to `notificationManager.setBadgeNumber`, so the launcher icon carries the count. HarmonyOS treats that badge as a notification surface — its permission dialog lists 角标 (badge) among the reminder modes — so the shell asks for notifications once, the first time there is something to show, and never again after a decline; the tab bar badges do not depend on it
- **Drafts that survive**: what you type in the native composer is written to ArkData preferences as you type and restored when the composer opens, so closing the sheet or killing the app does not lose it. It is cleared when the post actually goes through
- **Native headers, laid out like the stock app**: Home gets the account avatar plus a native "For you / Following" switcher that drives the page's real timeline tab; Explore puts a native `Search` field in the header (it also stays put on result pages); Notifications/Messages/Profile get a centred title over a subtitle (`@handle` on profiles) with at most one trailing gear — notification settings, settings, settings — and nothing else. Pages pushed from a tab keep a back arrow and a real page name, never a duplicated tab label
- **Native account menu**: the Home avatar opens a HarmonyOS menu for Profile, Bookmarks, Lists and Settings and privacy, so those pages are one tap away instead of buried in the web UI
- **Native compose**: floating compose button on the four content tabs opening a native bottom sheet (Cancel / New post / Post) that hosts `x.com/compose/post`; Post drives the page's own submit button and reports the outcome as a native toast. On Messages the same button starts a new direct message, as the stock app does
- **Native web-chrome removal**: X's own top nav, bottom nav, page headers and floating compose button are stripped by injected CSS/JS (`common/WebChrome.ets`) so the shell never double-renders chrome; the shell reads the page instead — `document.title` for the header, the Home timeline's own tab row for the switcher, `aria-selected` to keep it in step
- **Route-aware user agent**: the shell picks the UA each route needs (the desktop-class UA only for the e-mail sign-up flow, which x.com refuses on mobile web) instead of asking the user to toggle a desktop mode
- **Tab sync**: in-page web navigation updates the native tab index via URL mapping
- **Web hardening**: JavaScript + DOM storage on, `mixedMode(Compatible)`, `fileAccess(false)`, `CacheMode.Default`, `WebDarkMode.Auto`, zoom/overview on, autoplay gesture off, custom UA `OpenTwit-Web/1.0 HarmonyOS`
- **Resilience**: native offline card with Retry on `onErrorReceive`, automatic render-process recovery on `onRenderExited`
- **System language**: every shell string comes from `app.string.*` with `base` (English), `zh_CN` and `ar` qualifiers, and the layout mirrors for right-to-left from the system setting alone (ArkUI `Direction.Auto`) — a phone set to Arabic gets an Arabic shell *and* an Arabic x.com inside it. Adding another language is one more resource directory, no code change
- **HarmonyOS compliance**: layered app icon, system colour resources (real light/dark), `app.string.*` localisation (en + zh_CN + ar, RTL), native back navigation, geolocation consent dialog, system photo picker for uploads — see [docs/HARMONY_GUIDELINE_AUDIT.md](docs/HARMONY_GUIDELINE_AUDIT.md)
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

All captures below are real device frames (`uitest screenCap` / `snapshot_display`),
not mockups. Full-resolution files live in
[`screenshots/final/`](screenshots/final).

### Phone — 1320 x 2856, signed in (377 vp, bottom bar)

| | |
| --- | --- |
| <img src="screenshots/final/mobile/01-home-for-you.jpeg" width="320" alt="Home, For you"> **Home — For you.** Account avatar, native timeline switcher, filled tab bar with Home in system blue. | <img src="screenshots/final/mobile/03-home-following.jpeg" width="320" alt="Home, Following"> **Home — Following.** The same switcher driving x.com's real timeline tab; the underline follows `aria-selected`. |
| <img src="screenshots/final/mobile/02-account-menu.jpeg" width="320" alt="Account menu"> **Account menu.** Opened from the avatar: Profile, Bookmarks, Lists, Settings and privacy — HarmonyOS Symbols, native menu. | <img src="screenshots/final/mobile/04-explore.jpeg" width="320" alt="Explore"> **Explore.** Search lives *in* the header, not under a duplicated title. |
| <img src="screenshots/final/mobile/05-explore-results.jpeg" width="320" alt="Search results"> **Search results.** Back arrow plus the live query and a clear button, exactly where the stock app puts them. | <img src="screenshots/final/mobile/06-notifications.jpeg" width="320" alt="Notifications"> **Notifications.** Centred title, single gear, and the native unread badge on the tab bar. |
| <img src="screenshots/final/mobile/07-notification-settings.jpeg" width="320" alt="Notification settings"> **Notification settings.** A pushed page: back arrow, page name, no gear. | <img src="screenshots/final/mobile/08-messages.jpeg" width="320" alt="Messages"> **Messages.** Title + gear only; the pencil that used to sit here is gone (the FAB is the compose entry point). |
| <img src="screenshots/final/mobile/09-profile.jpeg" width="320" alt="Profile"> **Profile.** Display name over `@handle`, settings gear, no back arrow on the tab root. | <img src="screenshots/final/mobile/10-settings.jpeg" width="320" alt="Settings"> **Settings.** Reached from that gear. |
| <img src="screenshots/final/mobile/11-post-detail.jpeg" width="320" alt="Post detail"> **Post detail.** Native back plus a page name when a timeline item is opened. | <img src="screenshots/final/mobile/12-compose-sheet.jpeg" width="320" alt="Compose sheet"> **Compose sheet.** Cancel / New post / Post, counter, and the web composer hidden underneath. |

### Foldable — 2388 x 2480 unfolded (955 vp, side rail)

Same component tree, flipped by the 840 vp breakpoint: the bottom bar becomes a
rail and the web content keeps the full width. This AVD is **signed out** (its
session is device-local, see [audit doc §8.5](docs/HARMONY_GUIDELINE_AUDIT.md)),
so the pages it can load are x.com's own login walls — the point of these frames
is the shell.

| | |
| --- | --- |
| <img src="screenshots/final/foldable/01-home-rail.jpeg" width="460" alt="Foldable home"> **Rail + native header.** Filled symbols, Home active in system blue, avatar and switcher centred in the header. | <img src="screenshots/final/foldable/02-account-menu.jpeg" width="460" alt="Foldable account menu"> **Account menu** on the wide layout (signed out: Create account / Settings and privacy). |
| <img src="screenshots/final/foldable/03-home-following.jpeg" width="460" alt="Foldable Following"> **Timeline switch** works in the rail layout too. | <img src="screenshots/final/foldable/04-explore.jpeg" width="460" alt="Foldable Explore"> **Explore** on the wide layout — the header search spans the content column. |
| <img src="screenshots/final/foldable/09-compose-sheet.jpeg" width="460" alt="Foldable compose sheet"> **Compose sheet** — native sheet with the system keyboard. | <img src="screenshots/final/foldable/10-signed-install.jpeg" width="460" alt="Signed HAP running"> **The signed HAP, installed and running** (see below). |

Signed-out login walls on the same AVD, kept for completeness:
[Notifications](screenshots/final/foldable/06-notifications.jpeg),
[Messages](screenshots/final/foldable/07-messages.jpeg),
[Profile](screenshots/final/foldable/08-profile.jpeg).

### System language and unread badges — 2026-09-22

The same HAP, driven by the phone's own language setting and by what the page
reports, captured for a reviewer's two asks (system languages, live badges):

| | |
| --- | --- |
| <img src="screenshots/fixes-2026-09-22/01-arabic-rtl-home.jpeg" width="320" alt="Arabic, right to left"> **Arabic.** `الرئيسية / استكشاف / الإشعارات / الرسائل / الملف الشخصي`, the native Home switcher, the avatar and the compose FAB all mirrored for RTL — and x.com rendering Arabic inside it. | <img src="screenshots/fixes-2026-09-22/02-unread-badges-tabs.jpeg" width="320" alt="Unread badges"> **Unread badges.** `3` on Notifications and `2` on Messages at once; the launcher icon got the same total. |
| <img src="screenshots/fixes-2026-09-22/03-follows-system-language.jpeg" width="320" alt="Chinese, follows the system"> **Still follows the system.** Same build, phone left on zh-Hans: shell and page are Chinese again. | |
| <img src="screenshots/fixes-2026-09-22/04-icon-badge-after-permission.jpeg" width="320" alt="Icon badge"> **App-icon badge.** Once notifications are allowed — which is where HarmonyOS files the icon badge — the launcher icon carries the unread total. | <img src="screenshots/fixes-2026-09-22/05-draft-restored-after-kill.jpeg" width="320" alt="Draft restored"> **Draft restored.** Composer text survives the sheet closing and the app being force-stopped. |

## Project layout (remade)
- `AppScope/app.json5` — bundle `com.opentwit.web`
- `entry/src/main/ets/entryability/EntryAbility.ets` — loads `pages/MainTabs`
- `entry/src/main/ets/pages/MainTabs.ets` — single WebView + native chrome (the whole app)
- `entry/src/main/ets/common/WebConfig.ets` — routes, titles, UA, URL→tab mapping
- `entry/src/main/ets/common/Theme.ets` — font + theme tokens
- `entry/src/main/resources/{base,ar,dark,zh_CN}/element/*.json` — strings + start-window colour per qualifier; UI colours come from `sys.color.*`
- `AppScope/resources/base/media/{layered_image.json,background.png,foreground.png,app_icon.png}` — layered app icon, generated by `scripts/make-icons.py`
- `scripts/sign-hap.sh` — profile + HAP signing with the SDK's OpenHarmony test material, then verification (output lands in `dist/`, which is git-ignored; releases carry the artifact)
- `scripts/check-unread-counts.mjs` — runs the injected unread-count script against a stub DOM (`node scripts/check-unread-counts.mjs`); the script the shell sends to x.com is a string, so this is what keeps it honest
- `screenshots/final/{mobile,foldable}/` — the device evidence shown above, captured with `hdc ... uitest screenCap`
- `docs/HARMONY_GUIDELINE_AUDIT.md` — the audit log: findings, fixes, native-vs-web ownership table, device verification and the signing boundary
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
Hvigorw output is unsigned on purpose (`signingConfigs: []`). For a signed
HAP use `scripts/sign-hap.sh` (see [Signed build](#signed-build)); for an
AppGallery release, provision with your own AGC material via DevEco Studio
(File > Project Structure > Signing Configs) instead. Never commit
`.p12`/`.cer`/profiles — `.gitignore` already blocks them.

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
Verified again 2026-09-22 against a live signed-in account: every tab and
pushed page (see the phone gallery above), the native timeline switcher, the
account menu, the compose sheet, and
the signed HAP installing and launching on the foldable AVD. Method, per-finding
fixes and what is native vs. web-owned are in
[docs/HARMONY_GUIDELINE_AUDIT.md](docs/HARMONY_GUIDELINE_AUDIT.md) §8.

### App icons
`scripts/make-icons.py` regenerates the layered icon set
(`AppScope/resources/base/media/{background,foreground}.png`, `app_icon.png`
in both scopes) — run it after a palette change instead of editing PNGs by hand.

## License
Apache-2.0 — see LICENSE.
