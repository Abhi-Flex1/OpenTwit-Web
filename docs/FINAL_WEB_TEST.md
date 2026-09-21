# Final Web Test — OpenTwit-Web (full web port)

Date: 2026-09-20. Host: macOS arm64. CLI tools 6.1.1.280, API 24.

## Environment
- `.zprofile`: CLI `bin` + `tool/node/bin` + `openjdk@17/bin` on PATH, `DEVECO_SDK_HOME`, `JAVA_HOME` — done
- JDK 17.0.20.1 via brew — done
- Emulator image: `HarmonyOS 6.1.1(24)` phone `downloaded:true` via locale trick (`LANG/LC_ALL=zh_CN.UTF-8`, `TZ=Asia/Shanghai`), no proxy — 2.37 GB to `~/Library/Huawei/Sdk/system-image/`
- AVD `OpenTwitPhone` (nova 15 Pro/Ultra, 6.84" 1320x2856, arm64, apiVersion 24): `Device create success`, `isRunning:true`, `hdc list targets` → `127.0.0.1:5555`

## Build
- `ohpm install` + `hvigorw assembleApp` → `BUILD SUCCESSFUL`
- `entry-default-unsigned.hap` (91K), `OpenTwit-Web-default-unsigned.app`
- Fixes applied: `~/.ohos/sdk-remap/24 -> openharmony` SDK layout, `LOCATION usedScene`, `SymbolGlyph fontColor([...])`, main-frame-only `onErrorReceive` (subresource errors on x.com no longer flip to error page)

## Install + launch
- `hdc install entry-default-unsigned.hap` → `install bundle successfully`
- `aa start -b com.opentwit.web -a EntryAbility` → `start ability successfully`
- `ps` → `com.opentwit.web` + `com.opentwit.web:render` running

## Screenshots
- `screenshots/emulator-native-shell.jpg` — native shell + error page before main-frame fix (tabs/icons verified)
- `screenshots/emulator-web-x.jpg` — **full x.com web loaded**: X logo, title `X。尽是新鲜事 / X`, login CTA, footer `© 2026 X Corp.`, native bottom tabs in sync. Chinese locale because emulator image is CN (bypass side effect); switchable in X settings.

## Verdict
Full web Twitter port confirmed on HarmonyOS 6.1.1 API 24 emulator. No mock data, no API key — all features via web cookies.

## Native redesign (post-sign-in feedback)
Removed all browser chrome: no back/forward chevrons, no Reload button, no URL bar, no web page title. Shell is now pure HarmonyOS design language — `Navigation` Mini title per tab (`Home`/`Explore`/…), 2px linear progress, full-bleed Web, bottom bar with Symbols. Proof: `screenshots/emulator-native-home.jpg` (signed-in timeline, native Home title, native tabs, zero browser controls).

## Tab visibility fix
Bug: `Tabs` hides inactive `TabContent`, so the single WebView (child of tab 0) was invisible on Explore/Notifications/Messages/Profile — only placeholders showed. Fix: dropped `Tabs` entirely; the shared WebView now lives directly in the `Column`, always visible, driven by a custom native bottom bar (hairline divider + 5 equal targets, active tab bold/blue). Tapping the active tab smooth-scrolls to top like the stock app. Verified via `uitest uiInput click`: `screenshots/emulator-native-explore.jpg` shows live Explore (search, Today's News, trends) with the Explore tab highlighted.

## Native header + Profile update (verified on emulator)
- Profile tab now opens the signed-in user's own profile (`/handle`, discovered
  from X's nav and cached in preferences, native title shows `@handle`).
  Logged-out sessions fall back to X login (verified: login page under
  native "Profile" title). Edit-profile moved to the header menu action only.
- Native headers per HarmonyOS design: Mini title per tab, per-tab menus
  (Home search, Notifications settings, Messages compose, Profile edit),
  native Search field on Explore, thin progress bar, Symbol bottom bar.
- X's duplicate top chrome (TopNavBar container, search row, logo/icons) is
  hidden on tab roots via MutationObserver script; web tab strips
  (For you/Following, Explore/Trending/...) and subpage headers (back button)
  are preserved. Verified per tab:
  - Home: timeline starts immediately, no web top row
    (`screenshots/emulator-native-home.jpg`)
  - Explore: native Search + full content, no web duplicate
    (`screenshots/emulator-native-explore.jpg`)
  - Notifications/Messages/Profile: correct routing with native titles in sync
    (`screenshots/emulator-native-notifications.jpg`,
    `screenshots/emulator-native-messages.jpg`,
    `screenshots/emulator-native-profile.jpg`)
