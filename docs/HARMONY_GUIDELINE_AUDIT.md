# HarmonyOS Guideline Audit + Emulator Test — OpenTwit-Web

Date: 2026-09-21. Host: macOS arm64 (16 GB).
Goal: install the latest HarmonyOS emulator, run OpenTwit-Web on it, audit the
app against HarmonyOS design/development guidance, fix what does not comply,
and re-verify on the device.

Everything below was produced on this machine in this run; nothing is inferred
from, or replayed out of, an earlier report.

## 1. Toolchain and emulator actually used

| Item | Value |
| --- | --- |
| Command Line Tools | 6.1.1.280 (hvigor 6.24.2, ohpm 6.1.2.268, codelinter 6.0.240, hstack 5.1.0) |
| SDK | HarmonyOS 6.1.1 Release, Ohos_sdk_public 6.1.1.125, API 24 |
| JDK | OpenJDK 17.0.20.1 (Homebrew) |
| hdc | Ver 3.2.0d |
| Emulator image | HarmonyOS 6.1.1(24) phone, SoftWareVersion 6.1.0.126, arm64, 2,368,067,717 bytes |
| Running OS | emulator 6.1.0.126(SP1DEVC00E120R4P11) |
| HAP | entry/build/default/outputs/default/entry-default-unsigned.hap |

HarmonyOS 6.1.1 (API 24) is the newest **stable Release** image the 6.1.1 CLI
tools list (Emulator -imageList); the catalogue tops out at
6.1.0.126 / HarmonyOS 6.1.1(24). HarmonyOS 7 / API 26 is developer-beta only
and has no emulator image in this catalogue, so "latest API" == API 24 here.

### Image download (mainland-China gate)

Emulator -install answers "Currently, this capability is available only in the
Chinese mainland." unless the locale is spoofed. The locale/timezone export
trick recorded in Abhi-Flex1/OpenTwit@e87a9ee (and repeated in this repo's
README) works — no proxy, no VPN:

~~~bash
export LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 TZ=Asia/Shanghai
export vendorCountry=CN countryCode=CN
Emulator -license accept
Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)" -force
# -> 100.0% (2368067717/2368067717 bytes) "The image is downloaded successfully."
~~~

The same run also marked foldable, triplefold and widefold images as
downloaded: true, which allowed a second AVD for wide-layout testing.

### AVDs

| AVD | deviceType | screen | density | width in vp |
| --- | --- | --- | --- | --- |
| OpenTwitPhone | phone | 1320 x 2856 | 560 | 377 vp (bottom-bar layout) |
| OpenTwitWide2 | foldable | 2388 x 2480 | 400 | 955 vp (side-rail layout) |

Two host details matter and cost time when missed:

* ln -s ~/Developer/command-line-tools/sdk ~/Developer/sdk — the Emulator UI
  looks for hdc there.
* The Emulator must be started from a shell that stays alive. A detached
  "nohup Emulator -start <name> &" child is killed when the launching session
  exits, which is what produced the earlier "emulator dies seconds after boot"
  symptom (Emulator.log shows "Client heartbeat lost, exit").

## 2. How the audit was run

| Source | Command | Result |
| --- | --- | --- |
| Compiler / ArkTS | hvigorw assembleApp | 5 deprecation + 1 resource warnings before, 0 after |
| Official linter | codelinter -f json entry/src/main/ets | 0 findings |
| Device UI | hdc -t <t> shell uitest dumpLayout / screenCap | real bounds + image per state |
| Device input | hdc -t <t> shell uitest uiInput click / keyEvent | taps and system Back in device pixels |

Screenshots: screenshots/baseline-*.jpeg (before) and screenshots/fixed-*.jpeg
(after). Every claim below points at one of them.

## 3. Findings and fixes

### 3.1 Launcher icon was a blank placeholder — fixed

AppScope/resources/base/media/app_icon.png and
entry/src/main/resources/base/media/app_icon.png were both **1x1 transparent
PNGs**. The launcher rendered a featureless green rounded square
(screenshots/baseline-07-after-back.jpeg).

HarmonyOS expects a **layered** app icon (layered_image.json + background +
foreground) plus a square icon for the ability / start window.

Fix: scripts/make-icons.py (Pillow, run offline) generates background.png,
foreground.png, layered_image.json, a 216px app_icon.png for both scopes and a
512px store fallback; AppScope/app.json5 now points icon at
$media:layered_image.

Evidence: screenshots/fixed-00-launcher-icon.jpeg.

### 3.2 Dark mode did not exist — fixed

entry/src/main/resources/dark/element/color.json was a byte-for-byte copy of
the base file, so the dark qualifier changed nothing; the shell stayed white in
dark mode regardless of the system setting.

Fix: the shell no longer ships a hand-made palette. It uses the system colour
resources ($r('sys.color.ohos_id_color_background'), ..._sub_background,
..._text_primary, ..._text_secondary, ..._list_separator, ..._emphasize), so
light/dark, high-contrast and future theme changes come from the OS. Only
start_window_background stays an app resource, with genuinely different light
(#FFFFFF) and dark (#000000) values.

Evidence: screenshots/fixed-11-dark-mode.jpeg (dark chrome + X dark theme via
WebDarkMode.Auto) against screenshots/fixed-01-home.jpeg (light).

### 3.3 System Back dropped the user out of the app — fixed

Before: pressing Back on any page (including deep inside x.com) closed the app
immediately — one Back from the logged-out home screen landed on the launcher
(screenshots/baseline-07-after-back.jpeg).

Fix: the page implements onBackPress(): web history first, then the Home tab,
and only then return false so the system may leave the app.

Evidence: Explore -> Back stays in the app and lands back on Home
(screenshots/fixed-13-back-from-explore.jpeg); a further Back from the Home
root leaves the app, which reveals the previous task
(screenshots/fixed-14-back2.jpeg).

### 3.4 Tab highlight jumped to Profile on any /i/... page — fixed

routeIndexForUrl() mapped /i/* and every /settings/* path to the Profile tab.
Logged out, x.com/explore redirects to /i/flow/login, so tapping Explore
highlighted **Profile** (screenshots/fixed-03-explore.jpeg).

Fix: only /settings/profile (the editor opened from the Profile tab) maps to
tab 4; login flows, tweet detail, lists and other /i/... pages return -1 and
leave the highlight alone.

Evidence: screenshots/fixed-12-explore-dark.jpeg — the Explore tab stays active
while X serves its login flow.

### 3.5 Wide layouts were squeezed into a 240 vp pane — fixed

On a 955 vp-wide device the shell rendered everything inside a narrow left
column (screenshots/fixed-16-widefold-rail.jpeg). uitest dumpLayout showed why:
Navigation defaults to NavigationMode.Split on wide windows, so it reserved
NavBar [0,98][600,2480] for itself and put our rail **and** WebView inside that
pane.

Fix: .mode(NavigationMode.Stack) — the shell owns the wide layout — plus a
breakpoint listener ((width>=840vp)) that turns the bottom bar into a
navigation rail. Both variants are the same component tree inside a Flex whose
direction flips (ColumnReverse <-> Row), so crossing the breakpoint never
re-creates, and therefore never reloads, the WebView.

Evidence: screenshots/fixed-17-widefold-rail-stack.jpeg — left rail with the
active item highlighted, X's two-column desktop web layout filling the rest.

### 3.6 Deprecated APIs — fixed (compiler-warning driven)

| Warning | Replacement used |
| --- | --- |
| getContext(this) deprecated (x2) | this.getUIContext().getHostContext() |
| Web.userAgent() deprecated | controller.setCustomUserAgent() in onControllerAttached |
| onUrlLoadIntercept deprecated | onLoadIntercept (event.data.getRequestUrl()) |
| @Entry struct in a non-page file | removed with the dead Theme.ets provider |
| app_name conflict | single definition in AppScope |
| targetSdkVersion not set | targetSdkVersion: 24 in build-profile.json5 |

hvigorw assembleApp now reports only the expected "no signingConfig" notice for
an unsigned debug build.

### 3.7 Header menu icons rendered as empty circles — fixed

NavigationMenuItem.icon takes an image resource. The per-tab actions passed
$r('sys.symbol.magnifyingglass') there, so the header showed a blank grey circle
(screenshots/baseline-01-launch.jpeg).

Fix: symbolIcon: new SymbolGlyphModifier($r('sys.symbol....')).

Evidence: screenshots/fixed-02-home-menu.jpeg (magnifier),
screenshots/fixed-04-notifications.jpeg (gear).

### 3.8 Hard-coded English strings — fixed

Tab labels, titles, menus, the error card and the retry button were string
literals. All of them now come from app.string.* with an English default and a
zh_CN translation, so the shell follows the system language.

Evidence: screenshots/fixed-01-home.jpeg (首页 / 探索 / 通知 / 私信 / 我 on the
Chinese emulator image).

### 3.9 Geolocation was granted silently — fixed

onGeolocationShow called invoke(origin, true, false) unconditionally: any page
on x.com could read the device location with no user decision and without the
OS permission ever being requested.

Fix: a native showAlertDialog (Allow / Don't allow) first; "Allow" then goes
through abilityAccessCtrl.requestPermissionsFromUser(['ohos.permission.LOCATION'])
and only a granted result is forwarded to the page. Denial is the default on
every failure path.

### 3.10 File upload did nothing — fixed

The README claimed file upload was enabled, but no onShowFileSelector handler
existed, so X's "Choose file" was a no-op. Fix: onShowFileSelector opens the
system photo picker (photoAccessHelper.PhotoViewPicker, image + video) with the
selection mode taken from FileSelectorMode, and returns the picked URIs through
result.handleFileList().

### 3.11 Web hardening — tightened

fileAccess(true) (JS access to local files) and MixedMode.All were on for a site
that needs neither. Now fileAccess(false) and MixedMode.Compatible; DOM storage,
JavaScript, zoom, overview, media playback and dark mode are unchanged.

### 3.12 Render-process crash showed an error card — fixed

onRenderExited set the error state even though the system restarts the render
process. It now logs, clears the error and calls controller.refresh(), falling
back to the error card only if the refresh itself throws.

### 3.13 Error card, bottom bar and dead resources — fixed

* The error card used Text('!'); it now uses
  SymbolGlyph($r('sys.symbol.wifi_slash')) with a capsule Retry/重试 button
  (screenshots/fixed-09-error-state.jpeg), and Retry recovers the page
  (screenshots/fixed-10-after-retry.jpeg).
* Bottom-bar items carry accessibilityText / accessibilityDescription with the
  localised tab name and meet the 48 vp minimum touch-target height.
* Dead resources removed: AppScope/resources/base/element/display.json (unused
  breakpoint strings) and the old hw_* palette.

### 3.14 Repository hygiene — fixed

.hvigor/ and entry/build/ were versioned: 142 of 262 tracked files were build
output. They are now untracked and covered by a new .gitignore (build/,
.hvigor/, oh_modules/, signing material, .DS_Store).

## 4. Verification status

Runtime-verified on the emulator (device pixels, real screenshots):

* install + launch of the unsigned debug HAP ("install bundle successfully",
  "start ability successfully")
* Home / Explore / Notifications tab switching with in-page tab sync
* system Back: web history -> Home tab -> leave app
* retry from the offline card, and recovery of the Web page
* light **and** dark theme, including WebDarkMode.Auto on the page
* launcher icon, zh_CN localisation, header menu icons
* wide layout: navigation rail + full-width web on a 955 vp foldable AVD

Compile-verified only (they need an X login or an OS permission prompt, and no
account credentials were used in this run):

* file upload through the system picker (onShowFileSelector)
* the geolocation consent dialog + requestPermissionsFromUser path
* signed-in timeline, DMs, composer and profile editing (X web cookies)

Not touched: signingConfigs stays empty on purpose (unsigned debug HAP); no
.p12/.cer/.p7b material was created or committed.

## 5. Reproduce

~~~bash
# 1. tools + SDK on PATH (see README "PATH (.zprofile)")
source ~/.zprofile

# 2. build
cd "/Users/abhi/Desktop/HarmonyOS Ports/OpenTwit-Web"
ohpm install && hvigorw assembleApp --no-daemon

# 3. emulator (image already installed on this host)
Emulator -start OpenTwitPhone          # keep this shell alive
# wide-layout check: Emulator -start OpenTwitWide2  (955 vp)

# 4. install + run + evidence
hdc list targets                       # -> 127.0.0.1:5555
hdc -t 127.0.0.1:5555 install -r entry/build/default/outputs/default/entry-default-unsigned.hap
hdc -t 127.0.0.1:5555 shell aa start -b com.opentwit.web -a EntryAbility
hdc -t 127.0.0.1:5555 shell uitest dumpLayout -p /data/local/tmp/layout.json
hdc -t 127.0.0.1:5555 shell uitest screenCap -p /data/local/tmp/shot.jpeg
~~~

## 6. Native-shell pass (same day, second phase)

Goal: make the web content behave like native content by moving every piece of
app chrome into the shell, so the user never sees "a website in a box".

| Chrome element | Before | After |
| --- | --- | --- |
| Title bar | one line, tab name only | custom native title: tab name or @handle **plus** the current `x.com` path as subtitle (`fixed-01` vs `native-01`) |
| Header actions | at most one icon | per-tab native menus — Search, Notification settings, New message, Edit profile **or** Create account, Desktop site, Refresh |
| Compose | X's own in-page composer/FAB only | native FAB + native bottom sheet with a Cancel / New post / Post header (`native-04-compose-sheet.jpeg`) |
| First paint | 2 vp progress bar only | native `LoadingProgress` overlay with a 15 s safety timeout, then the progress bar |
| Navigation | bottom bar | bottom bar on phones, side rail from 840 vp, short haptic tick on tab change |
| Web chrome | X top nav hidden | X top nav, bottom nav **and** floating compose button hidden; the shell supplies the equivalents |
| Back | web history → Home → exit | sheet → web history → Home → exit (`native-05-after-sheet-back.jpeg`) |
| Failure | error card only | error card + native Refresh menu action + automatic render-process recovery |

New/changed files: `common/WebChrome.ets` (all injected scripts moved out of the
page, plus the new CSS that removes X's floating compose button),
`pages/MainTabs.ets` (title builder, menus, FAB, compose sheet, first-load
state, haptics), `common/WebConfig.ets` (desktop UA + sign-up route),
`module.json5` (`ohos.permission.VIBRATE`), `resources/{base,zh_CN}` (new
strings). `hvigorw assembleApp` stays warning-free and `codelinter` stays at
0 findings.

Two deliberate product decisions came out of this pass:

* The compose FAB is shown on the four content tabs whether or not the user is
  signed in — X's own app does the same, and a hidden entry point is worse than
  a login wall.
* "Desktop site" is a persisted user preference, because x.com's desktop path is
  the only web path that exposes parts of the product the mobile web path hides
  (see below).

## 7. Creating an account with a temporary mailbox — blocked by X, not by us

Requested: use a temp-mail address to create an account, then test the
signed-in experience. Attempted for real; X refuses.

1. Temporary mailbox created via the tempmail.lol API:
   `berni699@jn.auroracovia.com` (token held in memory only, nothing persisted
   in the repo).
2. Inside the app's WebView, the login form accepted the address and X answered
   with **"下载 app 完成电子邮件注册 / 仅限在应用中以电子邮件注册"** — "Download
   the app to complete email sign-up. Email sign-up is only available in the
   app." (`screenshots/signup-01.jpeg`).
3. Switching to the desktop user agent and loading `x.com/i/flow/signup`
   renders X's desktop sign-in card with **no sign-up entry at all**
   (`screenshots/signup-02-desktop.jpeg`), and submitting the address hands the
   flow over to a Google account page (`x.com/v3/signin/identifier`,
   `screenshots/signup-03.jpeg`) whose "创建账号" creates a **Google** account,
   not an X account.

Conclusion: X has removed email/password sign-up from the web. New accounts
require the X mobile app or the phone-number path ("Continue with phone"), both
of which need a phone number that this run does not have. Nothing was fabricated:
no account exists, and no signed-in state was faked.

What remains untested for the same reason (needs a real session): the compose
sheet's Post action against a populated composer, the signed-in timeline/DM/
notification menus, and own-profile discovery (`ownHandle`). The shell code for
all of them is in place and compiles clean; the compose sheet itself, its native
header and its back handling are verified above in the signed-out state.

To finish the signed-in pass, one of these is needed:

* log in with an existing X account on the emulator (the shell drives the flow,
  but the password has to be entered by the account owner), or
* a phone number for X's "Continue with phone" sign-up, or
* an account created beforehand on another device, then logged in here.

## 8. Native-UI completion pass (same day, third phase)

Goal: every piece of app chrome is native HarmonyOS, the web supplies content
only, and the result follows the HarmonyOS guidelines. Two of the three
previously-untested signed-in paths (timeline, DMs, own-profile discovery) were
verified for real this time: the phone AVD signed in with the account owner's
session, so the screenshots in this section are of a live account.

### 8.1 Who owns which surface

| Surface | Owner now | Notes |
| --- | --- | --- |
| Title bar, back, page titles | shell | one native header per tab, driven by `document.title` + the routed path |
| Home "For you / Following" | shell | native switcher; taps click the page's real (hidden) tab, `aria-selected` keeps the underline honest |
| Explore search | shell | native `Search` in the header, stays on result pages |
| Tab bar / rail | shell | five filled HarmonyOS Symbols, system blue vs secondary grey, native unread badge |
| Account menu | shell | Profile / Bookmarks / Lists / Settings and privacy, bound to the avatar |
| Compose (post) | shell | native FAB + bottom sheet; Messages deliberately has no floating FAB |
| Progress, first paint, offline, retry | shell | native `Progress`, `LoadingProgress`, error card |
| Pull to refresh | shell | native `Refresh` around the `Web` child |
| Tab-root top rows (logo, tabs, search) | shell | removed from the page by injected CSS/JS |
| Timelines, threads, profiles, notification list, settings forms | x.com web | content, data-dense, and not chrome — the shell does not redraw them |
| Messages inbox, conversation, composer | shell | `components/NativeMessages.ets` owns the visible surface; the WebView stays underneath for session/unread state |
| Login flows, media/GIF/poll/thread composer internals | x.com web | the composer falls back to the page for the parts the shell does not implement |

### 8.2 Fixes in this pass

1. **Duplicate header icons removed.** `Navigation.menus()` drew a second set of
   actions on top of the custom title bar — the pencil on Messages (already a
   FAB), the pencil on Profile (already an Edit profile button in the page), and
   the dead Desktop site / Refresh entries. `menus()` is gone; each header now
   carries at most one action, only where the stock app has one.
2. **Home switcher restored as native UI.** x.com's own For you/Following row is
   hidden by the chrome pass, which left the user with no way to reach the
   Following timeline. The shell now draws it and drives the page's real tab
   (`screenshots/final/mobile/01-home-for-you.jpeg`,
   `03-home-following.jpeg`).
3. **Explore search moved into the header** instead of sitting under a title
   (`screenshots/final/mobile/04-explore.jpeg`,
   `05-explore-results.jpeg`), which also removed the duplicated "Explore" title
   + field stack.
4. **Profile header follows the stock app**: display name over `@handle`, with
   the settings gear, and no back arrow on the Profile root
   (`screenshots/final/mobile/09-profile.jpeg`, `10-settings.jpeg`).
5. **`databaseAccess(true)`** on the `Web` component: ArkWeb gates its database
   APIs behind this flag and defaults them off, which a full web app should not
   rely on.
6. **Messages route corrected** — see 8.4.

### 8.3 HarmonyOS guideline checks applied

| Guideline | How it is met |
| --- | --- |
| System colours only | every native colour is `$r('sys.color.ohos_id_color_*')`; no hand-made palette, so light/dark/high-contrast follow the OS |
| One typeface | `HarmonyOS Sans` pinned on the shell and injected into the page; no webfont |
| System icons | HarmonyOS Symbols (`SymbolGlyph`) everywhere, including the menu (`symbolStartIcon`) |
| Touch targets | 48 vp minimum for the bar items, header actions and avatar; the compose FAB is 56 vp |
| Title bar text scaling | header title/subtitle and both switcher labels are single-line with ellipsis, so a large system font cannot overflow the bar |
| Localisation | all shell strings come from `app.string.*` with `base` + `zh_CN` qualifiers (`首页 / 探索 / 通知 / 私信 / 我` on the Chinese image) |
| Haptics | short vibration on tab change and on Home timeline switch |
| Back behaviour | native conversation first, then sheet, web history, Home tab, and only then leave the app |
| Wide/continuity | same component tree, `Flex` direction flips at 840 vp: bottom bar becomes a rail, the `Web` is never re-created |
| Accessibility | every icon-only control carries `accessibilityText` / `accessibilityDescription` |
| Safe areas | the bar paints into the bottom safe area; Navigation owns the status-bar inset |

Tooling: `hvigorw assembleApp` is warning-free apart from the expected
`No signingConfig found` notice (now resolved, see 8.6) and `codelinter -f json
entry/src/main/ets` reports `[]` (0 findings; the CLI prints a note that its
bundled ruleset targets OpenHarmony projects, so treat it as one signal, not
proof).

### 8.4 Messages: native ArkUI surface

The visible Messages experience no longer delegates to XChat. `NativeMessages`
owns the padded conversation list, search/filter row, conversation detail, text
composer and emoji panel. The shared WebView continues loading the web route
underneath so login cookies and unread counts remain available to the shell, but
it is covered by the native surface on this tab. The floating compose FAB is
suppressed on Messages so it cannot overlap the send control. The native model
is fed by the signed-in inbox payload; no conversations or messages are seeded.
Message text is drawn inside a bounded rounded `Row` surface rather than a
filled `Text` or span, which keeps wrapped messages continuous and avoids the
emulator's black-background paint path. Text sends use the real DM endpoint,
while mute uses the session-backed route confirmed in the current x.com client.
Archive, attachments, voice, calls, and video calls are not exposed by the
native surface until their real paths exist.

### 8.5 Verification on devices

Phone AVD (1320x2856, signed in as the account owner; the current CLI target is
`127.0.0.1:5555`):
`screenshots/final/mobile/` — home (For you), account menu, home (Following),
explore, explore results, notifications, notification settings, messages,
profile, settings, post detail, compose sheet. All twelve are embedded in the
README's screenshot gallery.

Foldable AVD (2388x2480, 955 vp, **signed out**): `screenshots/final/foldable/`
— rail + native header, account menu (Create account / Settings and privacy),
Following switch, explore, compose sheet, plus `10-signed-install.jpeg` which is
the **signed** HAP running after install. The login-wall captures
(`06-notifications`, `07-messages`, `08-profile`) are linked from the README for
completeness; two early captures (`00-state`, `05-explore-results`) were dropped
because they were duplicates of another frame and a black frame respectively.

The foldable's own session could not be re-established: the web cookie jar lives
outside the app sandbox, `hdc file send` and `shell cp` into the sandbox are
denied, the guest cannot reach the host over HTTP, and moving the phone's
userdata into the foldable instance stalled its boot. Its screenshots are
therefore of the shell, which is what the foldable layout is meant to show.

### 8.6 Signing and release

`scripts/sign-hap.sh` performs the whole flow with the SDK's bundled test
material (`toolchains/lib/OpenHarmony.p12`, `OpenHarmonyProfileRelease.pem`,
`UnsgnedReleasedProfileTemplate.json`, `hap-sign-tool.jar`):

1. builds the app signing chain from the CA-issued leaf embedded in the profile
   template plus the `cacert` / root entries in the keystore (the keystore's own
   copy of that leaf is self-signed; the public keys are identical, verified
   with `openssl x509 -pubkey`),
2. re-dates the template's expired validity window and sets
   `bundle-name: com.opentwit.web`,
3. signs the profile (`sign-profile`, `SHA256withECDSA`, local mode),
4. signs the HAP (`sign-app`, `-inForm zip -compatibleVersion 12`),
5. verifies with `verify-app` ("Verify success").

Result: `dist/OpenTwit-Web-1.0.0-signed.hap` (SHA-256 in the `.sha256` file).
Since 1.1.0 the script derives that name from `AppScope/app.json5` and writes the
checksum itself, so the artifact always carries the app's own version.
It was installed **for real** on the foldable AVD — after uninstalling the
unsigned build, because a bundle cannot switch signing identities — and it
starts and runs (`screenshots/final/foldable/10-signed-install.jpeg`).

Honest boundary: this is the OpenHarmony **test** identity, not an
AppGallery-issued one. Emulator images that trust the OpenHarmony test root
accept it; a retail HarmonyOS device normally will not. Publishing to
AppGallery requires an AGC certificate and profile for `com.opentwit.web`,
which only the account owner can issue.

## 9. Reviewer feedback pass — system language and live badges (2026-09-22)

Source: a reviewer's message thread about the build. Two asks, both answered on
the phone AVD (1320 x 2856, HarmonyOS 6.1.1 / API 24):

1. *"Does it support system languages when you set by default … not everyone
   speaks English … This user asked whether it supports Arabic?"*
2. *"You can get live notifications with a badge support on menu screen … as
   well as messages"*

### 9.1 System language: Arabic added, RTL follows from the system

Finding: the shell shipped `base` (English) and `zh_CN` only. Every other system
language — Arabic included — fell through to English, so a phone set to Arabic
got an Arabic x.com inside an English tab bar.

Fix: a third resource qualifier, `entry/src/main/resources/ar/element/string.json`,
translates all 38 shell strings (tab labels, Home switcher, account menu, compose
sheet, error card, permission prompts). Nothing else was needed for right-to-left
layout: ArkUI's `direction` attribute defaults to `Direction.Auto`, which mirrors
the tree when the app's language reads right to left, and every container the
shell uses (`Flex`, `Row`, `Column`, `Text`, `Badge`, `Navigation`) is on the
platform's mirrored list. The injected stylesheet already carried
`HarmonyOS Sans Naskh Arabic UI` in its font stack.

The web half was already multilingual: x.com resolves its own locale from the
app's language, which the captures below show — Chinese on the zh_CN image,
Arabic on the Arabic run, same build, no app-side switch.

| Evidence | What it shows |
| --- | --- |
| `screenshots/fixes-2026-09-22/01-arabic-rtl-home.jpeg` | Arabic run: `الرئيسية / استكشاف / الإشعارات / الرسائل / الملف الشخصي` in the tab bar, `لك / المتابَعة` in the native Home switcher, avatar and compose FAB mirrored to the right/left, and x.com itself rendering Arabic RTL |
| `screenshots/fixes-2026-09-22/03-follows-system-language.jpeg` | Same build, same HAP, phone left on zh-Hans: the shell and the page are Chinese again, i.e. the language is system-driven, not baked in |

Method: `param set persist.global.language ar` is refused for a non-root shell
(`errNum 1001`), so the Arabic run used a temporary `i18n.System.setAppPreferredLanguage('ar')`
line in `EntryAbility`, which is the same per-app preference the OS exposes in
Settings, then forced a cold start. That line is **not** in the shipped code —
it was removed, the HAP rebuilt, the bundle uninstalled to clear the per-app
preference, and the result is the zh-Hans capture above.

### 9.2 Live unread badges on the tab bar, and on the launcher icon

Finding: the old badge read the notification count out of `document.title` only,
showed nothing at all for Messages, and only ever updated after a page
navigation — so it was neither "live" nor complete.

Fix, in three parts:

1. `common/WebChrome.ets` gains `UNREAD_COUNTS_SCRIPT`. It reads the counts off
   the page's **own** navigation entries rather than guessing at the DOM: every
   x.com nav item carries the number in its accessible label, using the
   templates x.com itself ships (`"Notifications (%d unread notifications)"`,
   `"Direct Messages (%d unread conversations)"`), and tabs that draw a numeric
   badge have the same number in a text node. Entries are matched by `href`
   (`/notifications`, `/messages`, `/i/chat`) so a renamed test id cannot break
   the read; `document.title`'s `"(3) …"` prefix stays as the notification
   fallback. Counts are normalised from Arabic-Indic digits (`٣`) to ASCII
   before parsing, so the badge survives an Arabic page.
2. `pages/MainTabs.ets` shows the result on **both** tab-bar items (and the side
   rail), clearing the one for the tab you are on, and refreshes it on every
   in-page navigation, every 30 s, and whenever the page is shown again
   (`onPageShow`).
3. The same total is handed to `notificationManager.setBadgeNumber`, so the
   launcher icon carries the count too.

| Evidence | What it shows |
| --- | --- |
| `screenshots/fixes-2026-09-22/02-unread-badges-tabs.jpeg` | `3` on Notifications and `2` on Messages at the same time, on the native bar |
| device log, phone AVD | `launcher badge -> 5` / `launcher badge accepted: 5` — the badge API accepted the count |
| device log, background → foreground | counts changed to 4+3 while the app was backgrounded; the next refresh (`launcher badge -> 7`) landed **0.4 s** after the app was resumed and 5.7 s after the previous refresh, i.e. it came from `onPageShow`, not from the 30 s tick |
| device log, page reload | counts went back to zero and the badge was cleared (`launcher badge -> 0`) |

Honest boundaries:

* The badge capture is of the **shell**, not of a signed-in timeline. Reinstalling
  the HAP (unavoidable: a bundle cannot switch signing identities) destroyed the
  account's cookie jar, and no credentials were available to sign back in. The
  page in that frame is x.com's own login wall reporting unread counts through
  the same accessible labels the script reads in production; the shell → state →
  `Badge` path is real and unmodified. The count *source* is verified against
  x.com's shipped i18n bundle, and the parser is unit-tested against English,
  Arabic-digit, badge-node, title-fallback and empty-DOM inputs — re-runnable
  with `node scripts/check-unread-counts.mjs`, which pulls the literal back out
  of `WebChrome.ets` and runs it against a stub DOM (7/7 passing).
* `setBadgeNumber` resolved successfully on the AVD but this emulator's launcher
  drew no badge on the icon — rendering is launcher-side. Real HarmonyOS phones
  draw it; treat the launcher badge as best-effort and fail-safe.
* `zh_CN` and `ar` are hand-translated by the agent, not reviewed by native
  speakers. Adding another language means adding one more qualifier directory —
  no code change.

### 9.3 Also in this pass

* **Web DevTools, debug builds only.** `EntryAbility` now calls
  `webview.WebviewController.setWebDebuggingAccess(true)` when
  `context.applicationInfo.debug` is set. This is what `hdc fport` + CDP attach
  to; it is how the live page was inspected in this pass, and it keeps an
  explicitly discouraged debugging surface (SDK docs: *"not recommended in
  release builds"*) out of a release signing, where the flag is false.

Verification commands used:

```bash
hvigorw assembleHap --no-daemon && ./scripts/sign-hap.sh
hdc -t 127.0.0.1:5555 install dist/OpenTwit-Web-1.0.0-signed.hap
hdc -t 127.0.0.1:5555 shell aa start -b com.opentwit.web -a EntryAbility
hdc -t 127.0.0.1:5555 shell uitest screenCap -p /data/local/tmp/shot.png
hdc -t 127.0.0.1:5555 fport tcp:9338 localabstract:webview_devtools_remote_<pid>
curl -s http://127.0.0.1:9338/json          # CDP Runtime.evaluate on the live page
codelinter -f json entry/src/main/ets       # [] — 0 findings
```

## 10. Second reviewer round — badge stability, icon badge, drafts (2026-09-22)

The reviewer came back after testing the build from §9. Four claims; three were
right and are fixed here, one is X's own client and is answered rather than
changed.

### 10.1 "It works on Explore, but it's trippy and buggy when you move to Home" — correct, fixed

Reproduced from the code path, then on the device. The unread script returned 0
for *both* counts whenever it could not find the page's navigation entry, and an
entry is missing for as long as a navigation or reload is in flight. The shell
took that answer at face value, so moving between tabs cleared the badges and
they only came back on the next 30 s tick — Explore happened to keep them
because that route usually swaps timelines in place.

Fix, in two halves:

* the script now answers **-1 for "this page has not published that count yet"**
  and 0 only when the entry is genuinely there with nothing unread, so the shell
  can tell "nothing unread" from "no answer";
* the shell keeps the last known count on -1 and re-asks every 1.2 s (six tries)
  instead of blanking the badge and waiting half a minute.

Evidence — the same action that used to clear it: counts injected, page reloaded
with `location.reload()`, screen captured 1.2 s later. Before this pass that
reload logged `launcher badge -> 0` and the badges disappeared; now the badge
stays put (identical badge pixels in the before/during/after frames,
`launcher badge -> 5` unchanged). `scripts/check-unread-counts.mjs` covers the
new contract, including two "mid-load" cases (9/9 passing).

Known trade-off: with no navigation entry at all — signed out, or a page that
never hydrates — the last count is kept rather than zeroed. A restart starts
from zero, and a signed-in page always has the entry, so the sticky case is only
"signed out mid-session".

### 10.2 "It has potential for app icon homescreen notification itself" — correct, now actually works

§9 already handed the total to `notificationManager.setBadgeNumber`, and §9 also
reported that the launcher drew nothing. That was not the launcher's fault:

* `notificationManager.isNotificationEnabledSync()` returned **false** — the app
  had never been granted notifications;
* HarmonyOS counts the app-icon badge as a notification surface. Its own
  permission dialog says so: *"通知提醒方式可能包括锁屏、横幅、角标、响铃、振动"* —
  badge among lock screen, banner, ring and vibration;
* after granting, the same build's `setBadgeNumber(5)` put a red **5** on the
  OpenTwit icon (`screenshots/fixes-2026-09-22/04-icon-badge-after-permission.jpeg`).

So the fix is the permission, not the badge call. The shell now asks **once, in
context** — the first time there is actually something to badge, never on
launch, never again after a decline (the answer is persisted) — and then polls
for 30 s in case the user allows it from Settings instead. Declining costs only
the launcher icon; the tab bar badges are independent of it. This is the one
user-visible behaviour change in the pass, and it is the platform's model rather
than a choice: without the grant, no app can badge its icon.

### 10.3 "Only the messages is an issue, 'empty inbox' and Disconnected nonsense" — superseded by the native pass

The earlier diagnosis was correct for the web client: x.com redirects
`/messages` to `/i/chat`, and XChat can report `Disconnected` when its realtime
session does not establish. The current pass removes that failure mode from the
user-visible surface by drawing the Messages inbox and conversation with ArkUI
while retaining the web route underneath for session and badge state.

### 10.4 "Find a way to save messages in a draft … self contained locally, ArkData" — good idea, implemented

The composer's text lived in `@State` only, so closing the sheet — or the app —
lost it. It is now written to the same ArkData preferences store the shell
already uses for the account handle and avatar, debounced 700 ms after the last
keystroke and again on the way out, restored when the composer opens, and
cleared when the post actually goes through.

Evidence: typed `draft-survives-restart` into the sheet, `aa force-stop`, cold
start, opened the sheet again — the text and the 22/280 counter are back
(`screenshots/fixes-2026-09-22/05-draft-restored-after-kill.jpeg`).

### 10.5 Also in this pass: the chrome observer no longer runs on every mutation

`chromeScript` installed a `MutationObserver` that ran the full removal pass —
~14 probes, `getBoundingClientRect` on each, then a document-wide scan for the
account handle — on **every** DOM mutation. On a timeline that is a lot of
forced layout; on the chat screen, which mutates continuously, it is the worst
case, and it is the one page the reviewer says feels wrong. Re-runs are now
paced to one per 250 ms (the first pass stays immediate, so first paint still
gets no double chrome), and the handle lookup stops once the handle is known.

### 10.6 "XChat, or a separate app for XChat" — native surface answered

The visible chat surface is now part of this app's ArkUI tree. The web route is
kept only as an invisible session/badge provider, so XChat's own rendering and
connectivity state no longer define the Messages experience.

Device evidence for this round: phone AVD 1320 x 2856 (HarmonyOS 6.1.1 / API 24),
`hvigorw assembleHap` + `sign-hap.sh` + `hdc install -r`, `codelinter -f json
entry/src/main/ets` → `[]`, `node scripts/check-unread-counts.mjs` → 9/9.

## 11. HarmonyOS PC (2in1) + foldable re-check (2026-09-22)

Asked for directly: adapt the app properly for HarmonyOS PC, and check the
foldable UI. The PC half was done on a real 2in1 image, not by reasoning.

### 11.1 Getting a PC image without the mainland-China gate

The same `export` trick that the sibling project's README documents
(`Abhi-Flex1/OpenTwit@e87a9ee`, "Emulator (phone, HarmonyOS 6.1.1)") works for
the 2in1 catalogue entry — no proxy:

```bash
export PATH="$HOME/Developer/command-line-tools/bin:$PATH"
export LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 TZ=Asia/Shanghai
Emulator -license accept
Emulator -imageList -deviceType 2in1            # 6.1.1(24), Release, 2.5 GB
Emulator -install -deviceType 2in1 -osVersion "HarmonyOS 6.1.1(24)" -force
Emulator -create OpenTwitPC -deviceType 2in1 -osVersion "HarmonyOS 6.1.1(24)"
Emulator -start OpenTwitPC                      # holds the terminal, like the phone AVD
```

Result: `~/Library/Huawei/Sdk/system-image/HarmonyOS-6.1.1/pc_all_arm/`, an AVD
whose display is a MateBook-shaped **3120 x 2080 @ 304 dpi = 1642 x 1095 vp**.
`hdc` finds it as `127.0.0.1:5559`. The phone and foldable AVDs already running
were left alone; three at once is more RAM than this host wants, so the phone was
stopped for the PC run and restarted for the final phone check.

### 11.2 What "properly adapted" turned out to mean

Findings on the PC, in the order they showed up:

| # | Finding | Fix |
| --- | --- | --- |
| 1 | The HAP would not be offered to a PC at all: the module declared `default` + `tablet` | `deviceTypes` gains `2in1`, with a 360 x 480 vp window floor and `supportWindowMode: fullscreen/split/floating` |
| 2 | The first launch opened a **phone-shaped window** (about 360 vp wide — bottom bar, stretched mobile page) in the middle of a 1642 vp desktop | On a desktop display the shell now sizes the window to 85% x 90% of the screen, capped at 1440 x 960 vp, and **centres** it; the one-shot flag lives in preferences, so after that the size belongs to the user and the window manager |
| 3 | Resizing without moving left the window hanging over the screen edge (measured: window at x=515 with the web view still reaching x=3120) | `moveWindowTo` after `resize`, both derived from the same display measurement |
| 4 | `display.getDefaultDisplaySync()` answered **1260 x 2719 px** on one launch and 3120 x 2080 on the next — sized from the first answer the window came out tall and phone-shaped | The sizing works in vp off `width / (densityDPI / 160)`, and bails out entirely if the display reports under 1000 vp wide, so a bad early read costs nothing and does not spend the one shot |
| 5 | `getWindowLimits()` looked like the screen but is the platform ceiling (2880 vp here) — using it produced a 4378 x 4651 px window | The display is the reference; the limits are only mentioned in the comment so the next reader does not fall for it |
| 6 | Nothing responded to a mouse | `hoverEffect(HoverEffect.Highlight)` on the rail items, the Home switcher and the header avatar |
| 7 | No keyboard support in the composer | `Esc` leaves the composer, `Ctrl`/`Cmd`+`Enter` posts |
| 8 | The app is a phone app on a PC in one more way: it buzzed | `tick()` is gated behind `canIUse('SystemCapability.Sensors.MiscDevice')`, which is also what the SDK's own syscap warning is about |

The keyboard work needed a second pass, and the device is what caught it:

* wired to `onKeyEvent`, **`Enter` never arrived** — the focused `TextArea`
  consumes the press for its newline, and only the release reached the shell
  (`type=1` in the log, twice: once through the sheet root, once through the
  editor). On a real keyboard that shortcut would simply never have fired.
* moved to `onKeyPreIme`, which ArkUI documents as running *before* the input
  method and the editor, and the same injected keys arrive as a press with the
  modifier held: `composeKey code=2054 type=0 ctrl=true`, which is the submit
  branch.

### 11.3 Foldable and phone re-check on the same build

Rail layout is one component tree flipped at 840 vp, so all three were checked
with the same HAP:

| Form factor | Display | Result |
| --- | --- | --- |
| Phone | 1320 x 2856 = 377 vp | Bottom bar, native header, FAB (`screenshots/fixes-2026-09-22/09-phone-bottom-bar.jpeg`) |
| Foldable unfolded | 2388 x 2480 = 955 vp | Navigation rail + header, page in the system language, FAB (`…/08-foldable-rail-955vp.jpeg`) |
| 2in1 (PC) | 3120 x 2080 = 1642 vp | Window → rail + header, FAB (`…/06-pc-window-centred.jpeg`, `…/07-pc-rail-landscape.jpeg`) |

### 11.4 Boundaries

* **Hover is set, not photographed.** A static `uitest screenCap` cannot show a
  pointer state; the attribute is on the three components and the build is clean.
* **The PC emulator has no physical keyboard**, so its soft keyboard (Celia) had
  to be force-stopped for the key events to reach the app, and the consent window
  it opens has focus of its own — that is emulator plumbing, not the app. On a
  real 2in1 the soft keyboard stays out of the way when a hardware keyboard is
  attached, which is the case the shortcuts are for.
* **The composer's submit path was exercised with an empty draft** (the shortcut
  branch ran; `postFromSheet` returns early on empty text, by design). Typing a
  draft through `uitest uiInput inputText` did not land in the PC emulator's
  `TextArea` once the IME had been stopped, so the visual end of that path is
  carried by the earlier signed-in compose-sheet verification.
* The 2in1 AVD is signed out, like the phone one after its reinstall: the frames
  show the shell and x.com's own logged-out pages.

## 12. Second pass the same day — page chrome the shell had left behind, and a lie about being offline

Date: 2026-09-22 (afternoon). Trigger: the owner relayed user feedback — the
Messages tab showed "empty inbox" and "Disconnected nonsense", and the Home
timeline had a stray X logo floating over it — plus the PC adaptation task.
Every finding below was reproduced on the running AVDs (foldable
`127.0.0.1:5557`, 2in1 `127.0.0.1:5559`) through ArkWeb DevTools before a line
changed.

### 12.1 Findings and fixes

| # | Finding | Evidence it was real | Fix |
| --- | --- | --- | --- |
| 1 | x.com's navigation column was **only half removed**. The stylesheet deleted `nav[aria-label="Primary"]`, but the column that holds it is a full-height `header[role="banner"]`, and the removal pass only matched header *rows* (`height < 160`). The column stayed with its X logo and its 150 px of empty width. | Layout dump on the foldable, at `/home`: `header role=banner [0,0,150,12501]` still laid out. On Home that is the stray logo over the timeline; on Messages it is a **second navigation rail** next to the shell's own. | A banner that spans the viewport height at the left edge is a nav column, not a header row: `height ≥ 200 && width ≤ 360 && left ≤ 8` now removes it, on every route (`WebChrome.chromeScript`). |
| 2 | Removing the page's search *field* left its **pill** behind — an empty rounded rectangle under the native search bar on Explore. | Screenshot of Explore before the fix; the field was `display:none` while its ancestors were still `[17,11,510,40]`. | The row goes with the field: from the field, walk up while the ancestor is still search-row shaped (`200 ≤ width ≤ 620`, `height ≤ 90`, no `[role="tablist"]` inside) and hide the outermost one. |
| 3 | **`navigator.onLine` was false while the connection worked.** x.com believed it: `/i/chat` answered `Chat · Disconnected` and `Empty inbox`, with no conversations at all. | `navigator.onLine: false` on **both** AVDs while `navigator.connection` said `4g`, requests succeeded, and pages rendered. With the flag patched to `true` before page scripts ran, the same page loaded the real inbox (`Living In Harmony · 15m`, `MortCodesWeb · 26m`, `Sigma Group Chat · 2h`, …) — the "nonsense" was the shell's flag, not X's product. | `ONLINE_PATCH` is injected with `runJavaScriptOnDocumentStart`, so the flag is right before any page script reads it. The shell still corrects it downwards (`window.__otOnline = false`) when a main frame really fails, so a genuine offline state is not hidden from the page. |
| 4 | **Popups blocked the renderer.** `onWindowNew` was not implemented, and ArkWeb blocks the render process until the event is answered — so x.com's `target=_blank` flows (the Google and Apple sign-in hand-offs, outbound links) looked like dead buttons. | The sign-in page's own copy for that link ("opens in a new tab"); the event has no default handler in the shell. | `onWindowNew` answers `setWebController(null)` (no second window) and loads the target in the shell's single WebView. |
| 5 | On a 2in1 the shell asked x.com for the **mobile web app** while sitting in a 1642 vp desktop window — a mismatch the site acts on. | Fingerprint read on the 2in1: mobile UA, 1019 x 641 CSS viewport. | `2in1` now uses the desktop user agent (the same rule the e-mail sign-up flow already needed), phones/tablets/foldables keep the mobile web app. |
| 6 | The header-trimming rule hid **the settings page's own rows**. A short link to `/settings…` near the top was assumed to be the header's gear, but x.com's settings page puts its own entries in exactly that shape — so `/settings/notifications` rendered its description and then nothing: no `Filters`, no `Preferences`. | The page's whole text was 168 characters long on the device, and both `a[data-testid="pivot"]` entries were carrying `data-ot-hide`. | Only icon-only links count as chrome now (empty `innerText`). The page's own rows survive, while the header gear and the Messages pencil — both icon-only — are still removed (`screenshots/fixes-2026-09-22/17-settings-page-rows.jpeg`). |

### 12.2 What was re-verified on the device after the fixes

| Check | Result |
| --- | --- |
| Messages tab, foldable | One rail, `Chat` inbox with real conversations, no `Disconnected`, no `Empty inbox` (`screenshots/fixes-2026-09-22/11-chat-inbox-online.jpeg`) |
| Home, foldable | Timeline fills the width, no leftover X logo column (`…/12-foldable-home-no-x-column.jpeg`) |
| Explore, foldable | Native search bar, then the page's own news/trends tabs — no ghost pill (`…/13-explore-ghost-search-gone.jpeg`) |
| Badge stability | `私信` held `3` while moving Home → Notifications → Home; the count only clears on the tab it belongs to |
| Draft (ArkData) | Typed `Draft persistence check 42`, closed the sheet, reopened (26 / 280 restored), force-stopped the app, reopened again — still restored (`…/15-draft-after-restart.jpeg`); the test draft was then cleared |
| 2in1 | Window keeps its free-form chrome and rail, native header intact, page now served as a desktop browser (`…/14-pc-desktop-user-agent.jpeg`) |
| Notification settings, foldable | `Filters` / `Preferences` rows present again, with the native header's gear as the only gear (`…/16-notification-settings-rows.jpeg`, `…/17-settings-page-rows.jpeg`) |

### 12.3 Boundaries and what remains open

* **Login limit is X-side.** While this pass ran, the owner attempted to sign the
  2in1 AVD in and X answered "we've temporarily limited your login" for two
  accounts, so the 2in1 stays signed out and only its signed-out surfaces were
  verified. Two things about the emulator make that limit more likely than on a
  real device, and neither is app code: the image reports `Asia/Shanghai` +
  `zh-Hans` regardless of where the host is, and repeated reinstalls give X a
  fresh browser profile each time. `param set persist.global.language` /
  `persist.time.timezone` are permission-denied on this image (`errNum 1001`),
  so the language/region/timezone can only be changed through the emulator's own
  Settings app.
* **Arabic/RTL was not re-photographed this pass.** The `ar` resource set is
  complete (38/38 keys, no key falling back to English apart from the numeric
  counter), and the shell's own labels demonstrably follow the system language —
  the foldable, whose image is `zh-Hans`, renders `首页 / 探索 / 通知 / 私信 / 我`
  while the 2in1 renders `Home / Explore / Notifications / Messages / Profile`
  from the same HAP. Switching the AVD to Arabic needs the Settings app (see
  above), so the Arabic mirroring frames from the earlier pass still stand.
* **Hover is still set, not photographed** (a static capture cannot show a
  pointer state), and the 2in1's narrow-window bottom bar was not photographed
  this pass: `aa start --ww/--wh` is not honoured on this image, so the window
  could not be resized from the shell. The breakpoint itself is the same
  component tree that the phone (377 vp, bottom bar) and foldable (955 vp, rail)
  frames exercise.
* **Google/Apple sign-in inside a WebView is still Google's call.** The
  new-window fix makes the link respond instead of blocking the page; Google
  itself refuses embedded browsers for OAuth, which the user sees as Google's own
  "this browser or app may not be secure" page. E-mail + password is the path
  that completes inside the shell.

## 13. Reader feedback round — "make chat look native" (2026-09-23)

The owner forwarded three screenshots of a reader's chat with the maintainer and
asked for the whole surface to be as native as possible, with the chat leading.
This section records the pass run against that feedback on the phone AVD
(`OpenTwitPhone`, HarmonyOS 6.1.1 / API 24, 377 vp).

### 13.1 What the reader actually asked for

| Reader's words | Status before | Status now |
| --- | --- | --- |
| "a little brush up on the chat UI list on slight cut off edges for mobile aligned view" | Last conversation row sat hard against the tab bar with no bottom inset | List carries bottom breathing room; the final row scrolls fully clear of the bar |
| "removal of floating circular blue Tweet button when you go to Messages" | Already hidden on Messages and Profile | Unchanged; re-verified |
| "frosted menu for immersiveness" | Account menu used `COMPONENT_THICK` | Account menu and the new inbox filter menu use `COMPONENT_ULTRA_THICK` |
| "Near native experience … Its transformative" (goal, not a defect) | Conversation swapped in place with no motion | Real push/pop transition, and the tab bar gets out of the way |

### 13.2 Fixes in this pass

* **The conversation is now a pushed screen, not a swap.** `NativeMessages`
  owns an `inConversation` state and drives both directions through
  `getUIContext().animateTo` with `TransitionEffect.move(TransitionEdge.END)`
  for the thread and `…START` for the list. `TransitionEdge` follows the layout
  direction, so the same code is a push in Arabic RTL and in English LTR. The
  pop is driven from a `@Watch` on the `open` prop, because the shell's back
  arrow and the system back gesture both only flip that one flag.
* **The shell's tab bar gets out of the way while a thread is open on a phone**
  (`immersiveConversation()` in `MainTabs.ets`). This is what the stock app
  does, and it is also what stops the composer from being squeezed into the
  strip above a permanent bar. The wide layout keeps its rail, because there the
  rail is permanent navigation and does not compete for height.
* **Bottom inset on the conversation list**, which is the reader's "cut off
  edges" complaint. The list now ends with breathing room instead of meeting the
  bar with no space.
* **Swipe actions on a conversation row** (`ListItem.swipeAction`, spring edge
  effect): mute/unmute is backed by the current x.com session route. Archive is
  intentionally absent because the current client does not expose a verified
  archive mutation to this shell.
* **The inbox filter is a real menu**, not a static pill: it now carries the
  chevron the platform puts on a menu trigger and offers All / Unread. Unread is
  the one filter the local session can honour honestly — verified and
  people-you-follow are account-graph facts the shell does not have until the
  real DM list is read off the page.
* **The composer became a composer.** Visible field fill, an emoji panel, and a
  text send slot that greys out when there is nothing to send instead of moving.
  Unsupported attachment/voice affordances were removed instead of displaying a
  local-only success state.
* **Per-message timestamps** under each bubble, and the thread is
  **bottom-anchored** so a short conversation sits on the composer rather than
  floating at the top of an empty page.

### 13.3 The rendering trap worth writing down

The send button was in the layout tree with the right bounds and the right
`backgroundColor`, it answered taps, and it did not paint. The same build also
produced a transposed blue polygon over the avatar column on one launch and
painted the avatars perfectly on the next.

What is actually reliable: a filled circular **`Button` background** can drop
out, while a **`Circle()` shape node** rasterises consistently. Every filled
disc in the native Messages surface — the avatars, the swipe-action buttons, the
send/mic control — is now a `Circle()` inside a transparent `Button`, not a
`Button` background. That change is what made the send button appear. The
transient polygon over the avatars was not reproducible in the same session
afterwards and is treated as emulator GL flakiness (the boot log warns that
`GLD_TEXTURE_INDEX_2D` is unloadable on this image), not as a layout bug: the
`uitest dumpLayout` bounds for those nodes were correct throughout.

### 13.4 Verification on the phone AVD

Every state below was driven with `uitest uiInput` on the phone AVD and read
back from a real screenshot plus `uitest dumpLayout`. The existing gallery
captures are in `screenshots/native-*-v3.jpeg`; the follow-up renderer pass was
kept out of the repository because the captures contain live account content.

| Check | How | Result |
| --- | --- | --- |
| Inbox layout and insets | `screenCap` + `dumpLayout` | 20 vp gutters, 76 vp rows, last row clears the bar |
| Open a thread | tap row | Pushes; tab bar removed; composer at the window bottom |
| Send | type + tap send | Bridge fixture and optimistic/error state covered; a live write to a third party was deliberately not fired |
| Pop | header back arrow | Returns to the inbox, tab bar restored |
| Swipe actions | `uiInput swipe` left | Session-backed Mute disc revealed |
| Filter | tap chip | Frosted menu with All / Unread; background is visibly blurred |
| Search | focus + `uiInput text` | `"wal"` → `Waleed` and `Finn Insiders` (name and preview match) |
| Build | `hvigorw assembleHap` | `BUILD SUCCESSFUL`, 0 errors |
| Linter | `codelinter -f json entry/src/main/ets` | `[]` — no findings (same as baseline) |
| Repo checks | `git diff --check`, media-save, native-surface, bridge, unread and resource JSON parse | all pass |

A follow-up phone-AVD pass on 2026-09-24 opened the real Brady thread and
verified a long outgoing message, a long incoming message, and a short incoming
message. The bubbles were continuous rounded blue/gray surfaces with no black
pixels; the layout dump kept readable text and stable bounds.

### 13.5 Boundaries

* **The native conversation model is session-backed, not seeded.** The inbox,
  thread, search, unread rows, text send and mute are fed by the page's own DM
  API. Attachment sending, voice, calls, video calls and archive remain outside
  this native surface rather than being represented by placeholder state.
* **Unread rows are derived from the inbox's `last_read_event_id` and
  `max_entry_id` markers.** A conversation becomes read when it is opened; a
  later message with a newer timestamp returns to the unread state.
* **The emulator's GL is degraded on this image** and produced one launch with a
  spurious polygon over the avatars. It did not reproduce; a real device is the
  authority for rendering.
* **`compatibleSdkVersion` is 24.** Everything added in this pass is API 12–24,
  so nothing here raises the floor, but the manifest already requires
  HarmonyOS 6.1.1 or newer. Lowering it is a separate change with its own risk
  and was not attempted.

## 14. Real DMs, notifications, and a HarmonyOS-layered shell (2026-09-23)

Feedback this round: the UI still was not good enough, HarmonyOS 7's design
language should be followed, login sessions must survive, push notifications
should work, and DMs should be real rather than demo data.

### 14.1 Two platform facts that bound what is possible here

| Fact | Evidence | Consequence |
| --- | --- | --- |
| No HarmonyOS 7 SDK on this machine | `sdk/default/openharmony/ets/oh-uni-package.json` reports `apiVersion 24 / 6.1.1.125`; no DevEco install; `Emulator -imageList` tops out at `HarmonyOS 6.1.1(24)` | The build stays on API 24. HarmonyOS 7's design language is implemented with APIs that exist at 24; API 26-only components cannot be compiled, let alone run |
| An ArkUI overlay does not survive over a scrolling ArkWeb surface | Reproduced on the phone AVD: a floating title bar over the WebView stopped painting once the page scrolled — with `backgroundBlurStyle(COMPONENT_THICK)` **and** with a fully opaque `backgroundColor`. The bottom bar in the same tree kept painting | The frosted layer goes on the bottom bar (proven to composite); the header keeps its own row |

### 14.2 What changed

* **The bottom bar floats.** The page fills its column, the bar is a
  `backgroundBlurStyle(COMPONENT_THICK)` surface pinned over it, and the page is
  given a matching `padding-bottom` through `immersiveInsetScript`, so its last
  rows scroll clear of the bar while content still passes underneath and blurs.
  This is the one piece of the immersive treatment that the platform actually
  composites, and it is verified in a screenshot with page content behind it.
* **The header tells the truth.** The timeline switcher appears only when there
  is an account to switch timelines for, and the composer FAB only when there is
  an account to post from. A signed-out Home is x.com's landing page, so it gets
  neither.
* **Messages stopped inventing conversations.** `seedNativeConversations()` is
  gone. The surface now renders what the account actually has, and says why when
  there is nothing: signed out, still reading, read failed, or genuinely empty.
* **A real DM bridge** (`dmInboxScript` in WebChrome.ets). It runs inside the
  x.com origin so the session cookies apply, discovers the web client's public
  bearer token from the page's own scripts and caches it on the window, then
  reads the account's inbox. The shell polls it only while Messages is on
  screen, so the native list tracks the account rather than a snapshot.
* **Notifications for new messages**, published with a `wantAgent` that brings
  the app back to the front. The first read of a session only sets a baseline,
  so opening the app never empties a backlog onto the user. The permission is
  still asked once, in context, and a decline is respected.
* **The session is written out explicitly** (`WebCookieManager.saveCookieAsync`)
  when the page goes away, so installing in place during development cannot cost
  the login.

### 14.3 Verified: the DM bridge returns the real inbox

The shipped bridge string was extracted from `WebChrome.ets` and run inside the
signed-in page over CDP (`Runtime.evaluate`), which is the same code the app
runs. Result on the foldable AVD's account:

```json
{"state":"ok","conversations":[
  {"id":"1159005726-1698644562292412416","name":"Brady","handle":"ntropiq",
   "avatar":"https://pbs.twimg.com/profile_images/.../jR7mGXgM_bigger.jpg",
   "text":"I see, I'll try it. Thanks!","out":true,"at":1788161508033,"muted":false},
  ...]}
```

18 conversations, **all 18 with real text and a real timestamp**, correct
inbound/outbound direction, real mute state, and 3 group DMs named from their
own title. Two parsing bugs were found and fixed this way, neither of which
could have been guessed:

* `conversation_id` lives on the message envelope, not inside `message_data`, so
  keying on `message_data.conversation_id` silently produced empty previews and
  zero timestamps for every conversation.
* The payload has no `account_id` field, so the signed-in account has to be
  derived — it is the participant present in the most one-to-one conversations.
  Without that, the account appeared in its own inbox as a contact named after
  itself, 15 times.

### 14.4 Verification status

| Check | How | Result |
| --- | --- | --- |
| Bridge against a real account | CDP `Runtime.evaluate` of the shipped script | 18/18 conversations with text and time |
| Bridge with no session | same script, signed-out AVD | `{"state":"signed-out"}` |
| Messages with no session | phone AVD screenshot | Signed-out panel, no fabricated rows |
| Floating bar layering | phone AVD screenshot | Page content visible and blurred behind the bar |
| Wide layout structure | foldable AVD screenshot + `dumpLayout` | Rail, header and page all laid out correctly |
| Build / linter / repo checks | `hvigorw assembleHap`, `codelinter`, `git diff --check`, `check-unread-counts.mjs` | Build successful, `[]` findings, all pass |

### 14.5 Open, and honest about it

* **The native Messages inbox and thread have now been seen together on the
  phone AVD.** Real rows, unread emphasis, long incoming/outgoing bubbles and
  the short-message path were captured from the running app. The older
  foldable-session caveat remains below because installing a new identity there
  would destroy its separate cookie jar.
* **The wide layout duplicates Messages.** On a wide window x.com renders its own
  Chat column on the home timeline, and its own Post button, neither of which the
  injected stylesheet hides. Both duplicate a native surface we already provide.
  Hiding them needs selectors taken from the signed-in wide DOM, which is the
  same session the point above needs.
* **DM text send is implemented against the live endpoint but was not fired at a
  real person during this pass.** The bridge test covers recipient and
  conversation targeting, successful/error state handling, and the component
  removes a failed optimistic bubble and restores the draft. A live send still
  needs the owner's explicit choice of a safe self-conversation.
* **Offline push is not what this is.** Notifications are published by the app
  from data it has just read. Delivery while the app is closed needs Huawei Push
  Kit with an AGC project and signed builds, which is not something this repo
  can provision.
* **An architectural note on the frosted bars.** A translucent bar is only worth
  anything when content passes under it, and ArkWeb does not reliably composite
  that at the top of the window. If the header should be frosted too, the way to
  get there is a page-side sticky header with `backdrop-filter`, drawn by the
  page rather than by ArkUI — which trades native chrome for the effect, so it is
  a product decision rather than a bug fix.

## 15. Shared page bridge (2026-09-23, same day)

The DM bridge proved the technique for reading the account's own data through the
page session, but it also held the only copy of the fragile half of it. Converting
the remaining surfaces would have meant copying session lookup, bearer discovery
and the header set into each one.

`common/PageBridge.ets` now holds them: the `ct0` lookup, the bearer discovery
(read once from the page's own scripts and cached on `window`), the header set,
and `otGet(path)`, which converts an HTTP failure into a `state` string rather
than an exception. `dmInboxScript()` was rewritten onto it and is the reference
implementation. A new surface is now a body plus `pageBridgeScript(body)`.

The rewrite is behaviour-preserving, and that was checked rather than assumed: the
script generated before the refactor and the one generated after it were both run
against the same stubbed page — signed out, the real inbox payload, HTTP 401,
HTTP 500, and an unexpected payload shape — and all five outputs matched byte for
byte. The build, `codelinter` (`[]`) and the repo checks all pass afterwards.

## 16. Full native conversion (2026-09-23, this pass)

Handoff §3 is now done: Home, Explore, Notifications, Profile and Messages are
all ArkUI reading the account's real data through the page session, polling only
while on screen.

| Surface | Native component | Bridge | Poll |
| --- | --- | --- | --- |
| Home timeline | `components/NativeHome.ets` (`LazyForEach`, v2 cursor paging) | `homeTimelineScript` | 25 s + pull + tab tap |
| Explore trends + suggestions | `components/NativeExplore.ets` | `trendsScript` / `searchTweetsScript` (typeahead) | 60 s + on-submit search |
| Notifications | `components/NativeNotifications.ets` | `notificationsScript` | 20 s + pull |
| Messages thread + send | `components/NativeMessages.ets` (thread history, real POST) | `dmThreadScript` / `dmSendScript` | inbox 6 s, thread 8 s |
| Profile header + posts | `components/NativeProfile.ets` (`LazyForEach`, scroll paging) | `profileScript` (DOM scrape) | on enter + pull |
| Post rows everywhere | `components/NativePostCard.ets` (one row, like/repost via `postActionScript`) | `postActionScript` | on tap |

`common/PageBridge.ets` gained the shared half every surface needs: `otPost`
for real writes, `otAccountFromConvs` hoisted out of the inbox so threads reuse
the same derivation instead of inventing a second one, and `otTime` for the
mixed ms/seconds/ISO timestamps. `dmInboxScript` now also returns `uid` (the
other participant) so one-to-one sends can address `direct_messages/events/new`
for real; old fields are unchanged.

`syncFromUrl` logs `url`, `idx` and `currentIndex` (handoff §5.2), so the next
"native surface did not come up" is one build away from an answer. Wide
duplicates (§5.4) are solved without guessing selectors: every native surface
covers the WebView full-bleed, so the page's own wide Chat column and Post
button stay mounted underneath for session but are never visible.

Every list owns loading, empty, signed-out and failed states; rows keep 76 vp,
20 vp gutters and inset separators; timelines page with `LazyForEach`. Nothing
is fabricated — an endpoint that rotated ends as `signed-out`, `http-<code>`,
`unexpected` or `empty`, never as invented rows.

### 16.1 Live-session verification (foldable AVD, signed in as the owner)

Every endpoint below was probed over CDP `Runtime.evaluate` inside the real
signed-in page (bearer re-discovered from the page's own scripts, `ct0` from
the cookie jar). Two v1.1 assumptions from the plan did not survive contact
with the account and were replaced before anything shipped:

| Assumption | Live result | Shipped as |
| --- | --- | --- |
| `statuses/home_timeline` | 200 with an **empty body** (dead) | v2 `timeline/home.json`: 52 tweets / 37 entries, paging by `cursor-bottom` verified overlap-free across pages |
| `users/show` + `statuses/user_timeline` | 404 (`code 34`) / 200 empty (dead) | DOM scrape of the shell-loaded profile page; selectors verified on `/Abhi_Flex`: 400 px avatar, banner, `UserName`, `UserDescription` ("Italy/India…"), 542 Following / 464 Followers links, 5 `article[data-testid=tweet]` with `/status/<id>`, `time[datetime]`, "9 Replies / 1 repost / 37 Likes" aria-labels |
| `search/tweets` + `search/adaptive` | 200 empty (dead) | v1.1 `search/typeahead` topics (10 back for "HarmonyOS"); Explore search returns genuine topic suggestions, never fabricated tweets |
| `notifications/all` shape | `{globalObjects, timeline.instructions}` with `notification-<id>` entries (`fromUsers[]`, `targetTweets[]`, `clientEventInfo.element` in {`users_liked_your_tweet`, `users_retweeted_your_tweet`, `user_replied_to_your_tweet`, `follow_from_recommended_user`, `user_mentioned_you`, …}, time in `sortIndex`) | Parser rewritten to exactly that shape |
| `dm/conversation/<id>` | 200: flat `{id,time,sender_id,recipient_id,text}` messages plus textless system entries (skipped); `users`/`conversations` live **inside** `conversation_timeline` | Thread parser fixed to that level; fallback to inbox filter kept |
| DM inbox | 18 conversations, 85 entries, 79 with text + time | Unchanged, plus `uid` for sending |

`scripts/check-page-bridge.mjs` (new) assembles the **shipped** `pageBridgeScript`
strings and runs them against stubbed pages shaped like the above: 29/29
passing (parse checks, signed-out, HTTP 401/500, unexpected shapes, thread
system-entry skipping, profile DOM fixture with the exact live hrefs — which
caught an off-by-one in the followers suffix match before it shipped, then
confirmed 542/464 live after the fix).

### 16.2 Device verification (phone AVD, signed out)

All five tabs tapped through: Home / Explore (native search field present) /
Notifications (gear present) / Messages (filter menu, search, signed-out panel)
/ Profile — every header a tab label with no web title leaking and no back
arrow on roots (a login redirect under the native surface used to leak both;
fixed by keying header/back on the visible tab, not the hidden URL). Explore
typing keeps trends (no phantom spinner); submitting runs typeahead.
System Back from Profile lands on Home. The Messages filter menu renders
frosted with All / Unread. Dark mode is by construction (every native colour
is a `sys.color` resource or transparent — grep-verified, no hand palette).
Unread badges read 0 signed out, as they should.

Signed-out panels are now a real sign-in screen (`NativeSignIn`): app mark,
welcome copy, three benefit rows (timeline / notifications / conversations),
a capsule Sign-in CTA and an honest footnote that sign-in runs on x.com with
the session staying on-device — localized in all three locales. Tapping it
reveals the session WebView on `x.com/i/flow/login` under a native Back +
 Sign-in header; Back, tab switch, or the account appearing closes it again
(`webLoginOpen`, verified on device in both directions). The app never sees a
password.

Iteration also caught and fixed a session-skew bug: the first 2in1 run showed
the timeline switcher with no session (a handle persisted in preferences while
the cookie jar was gone). Any bridge answer of `signed-out` now clears the
cached handle and flips every surface to signed-out at once
(`noteSignedOut`, wired into all seven read paths). Wide rail + native panel
verified on a fresh 2in1 install (avatar + "Home", signed-out panel, no FAB,
no web leak).

Emulator note: `aa start` does not always foreground the app on the phone
image (launcher/dialer/lockscreen appeared with no app process change); always
confirm with `pidof` + layout dump before tapping. No app crash was observed
in any run — every black/launcher frame traced to foreground flakiness.

### 16.3 Still honest boundaries

* Per-row DM unread is derived from the inbox read markers; the total tab badge
  still comes from the page's own navigation count.
* Like/repost/DM-send/mute POSTs use the live session headers but were **not**
  fired against the account (that would notify third parties) — implemented,
  covered by bridge fixtures, and awaiting owner-confirmed safe live tests.
* The signed-in native lists and Messages thread are verified on the phone AVD;
  the same signed session is not carried to the foldable because installing the
  new build there would destroy its cookie jar (signing identity switch), and no
  credentials were available to sign back in. The foldable session was left
  intact for the next signed-in pass.
* Offline push still needs Push Kit with an AGC project and is not claimed.

Tooling: `hvigorw assembleHap` BUILD SUCCESSFUL, `codelinter` `[]`,
`git diff --check` clean, `check-unread-counts.mjs` 9/9,
`check-native-surfaces.mjs` all passing, `check-page-bridge.mjs` 22/22.

## 17. Login no longer leaves the app signed out (2026-09-24)

Report: "I'm logged in but app state doesn't get updated."

### 17.1 Root cause

Two gaps combined. First, x.com navigates like an app: a completed login is a
`history.pushState` to `/home` that never fires `onPageEnd`, and handle
discovery only ran there — so a login that finished without a full page load
was never noticed. Second, the mobile web hydrates its navigation client-side:
the account link may not exist on the first read after login, the fast path
came back empty, and with `navigate=false` nothing retried — the shell gave up
until the next full page load, which never came. The surface symptoms match
exactly: logged-in web underneath, signed-out chrome and sign-in screens above.

Verified live that the fast path itself is sound: on the signed-in mobile page
`AppTabBar_Profile_Link => /Abhi_Flex` exists, so re-reading after hydration
is all it takes; the failure was purely never asking again.

### 17.2 Fix

* The injected history hook now runs `discoverOwnProfile(false)` on every
  in-page navigation while signed out — a login redirect is noticed promptly.
* The 30 s badge tick and `onPageShow` retry discovery while signed out, with
  an overlap guard (`discoveringHandle`) so reads cannot interleave.
* If the fast path stays empty but a session cookie (`ct0`) exists and the
  user is not mid-login, the shell falls back to opening the account menu and
  reading it there (`discoverWithSession`, invisible behind the native
  surface, never while the login form is up). The menu bootstrap itself is now
  re-entry guarded.
* `acceptHandle` re-reads all surfaces 3.5 s after the flip, catching reads
  that fired mid-transition, and the scraped profile avatar now feeds the Home
  header until the profile page is visited.
* Session death keeps working in the other direction (`noteSignedOut`).

### 17.3 Verification status

Build SUCCESSFUL, `codelinter []`, all three harnesses green (bridge 29/29 —
extended with discovery-wiring assertions). Signed-out regression verified on
the phone AVD with the fixed build (tabs, sign-in screen, no stuck spinners,
no menu-click spam without a session). The end-to-end login flip was still
unconfirmed at this point and the owner performed the sign-in; §18 records what
that uncovered — the discovery fix alone was not enough, because every async
read was silently returning an empty string.

## 18. Signed-in surfaces were blank: ArkWeb does not await async page reads

### 18.1 Symptom

The WebView showed a fully signed-in x.com while every native surface still
rendered its signed-out copy. Reports of "I'm logged in but the rest of the app
doesn't reflect that" on `x.com/settings/profile`: real account, real session,
native shell stuck on the sign-in panel, lists spinning on `loading`.

### 18.2 Two independent causes

**(a) Identity could not be read on routes with no account navigation.**
`x.com/settings/profile` renders no sidebar, no tab bar and no
`DashButton_ProfileIcon_Link`; the only account-ish nodes on that page are
`Profile_Save_Button` and `ProfessionalButton_Edit_Professional_Profile`, and
no bare-handle links exist. Both discovery paths (nav link, account menu) were
therefore structurally unable to answer, and `twid` only carries the numeric
user id (`u%3D1698…`), not the handle.

Fix: a DOM-free identity read (`sessionIdentityScript`) that derives the account
from the DM inbox's participant map — the participant present in the most
one-to-one conversations is the signed-in user, and its own entry carries
`screen_name` and the avatar. A document-start watcher (`SESSION_WATCHER`)
notices `ct0` appearing and calls `otNative.onSessionAppeared()` so the shell
asks who it is on any route, at any time, including mid-login.

**(b) Every async bridge read resolved to `""`.** This was the real reason the
whole app looked logged out. `WebviewController.runJavaScript()` hands back the
*synchronous* result of the evaluated script, so an `(async function(){…})()`
that resolves to a JSON string later came back empty. Instrumented hilog made
it unambiguous:

```
OpenTwit: home read ->                 <-- empty
OpenTwit: home -> {"state":"error","message":"SecurityError: Faile…
```

The identical script evaluated over CDP on the same page returned real
`globalObjects` — the failure was in how the answer came back, not in the
request. Sync scripts (badges, avatar) were unaffected, which is why the
symptom looked like a login problem rather than a plumbing one.

Fix: async results now travel through the native proxy. `runBridge(name, script,
key)` evaluates a wrapper that resolves the page-side promise and calls
`otNative.onBridgeResult(id, json)`; `PageBridge.setResultHandler` routes it to
`applyBridgeResult(name, key, json)`. Three properties matter:

* a 20 s deadline per read, so a page that never answers cannot leave a
  surface in `loading` forever;
* a `key` per read (conversation, query, handle), so a slow reply for a thread
  the user has left or a query they have replaced is dropped instead of
  overwriting what is on screen;
* `onPageBegin` drops reads still in flight — a full load replaces the page's
  JS context, so those can never answer and their timeouts would flash an
  error over a surface the new page is about to fill.

### 18.3 Transient reads, and the bounded profile retry

The first read after a navigation lands while the document is still swapping:
x.com answers with an empty body and the surface reported a failure until the
next full poll (25 s on Home). A retry ladder (`retryBridgeSoon`, max 4
attempts, 1.5 s apart) brings recovery down to ~1.6 s, verified in hilog:
`home -> error` at 03:06:17.484, `home -> ok` at 03:06:19.960.

Profile additionally points the WebView at `/<handle>` before scraping
(`ensureProfilePage`) and re-reads a bounded number of times while the profile
DOM renders, then says the profile is unavailable instead of spinning forever.

### 18.4 HTML entities in API text

The live thread exposed a content bug: a real DM read "worktrees &amp; moving"
and rendered the entity literally. API text is HTML-escaped; DOM-scraped text
already is not. A shared `otText()` decoder in `SESSION_SETUP` now runs on every
API-sourced string (DM preview, DM thread, tweet shaper for Home/Profile/Search,
notification target text), ampersand last so `&amp;lt;` decodes one level to
`&lt;`. Four harness cases pin this.

### 18.5 Verification

* `node scripts/check-page-bridge.mjs` — 36/36 (new: identity from inbox,
  signed-out, empty-inbox, and four entity-decoding cases).
* `node scripts/check-native-surfaces.mjs` — 88 checks (new: proxy-callback
  plumbing, per-read deadline, navigation drop, thread/search keying, retry
  ladder, DOM-free identity, entity decoding); `check-unread-counts.mjs` — 9/9.
* `hvigorw assembleHap` SUCCESSFUL, `codelinter` `[]`, `git diff --check` clean.
* Live on the phone AVD, signed in as `@Abhi_Flex`, from a cold start: Home
  timeline with media and engagement counts (~3 s), Notifications (likes with
  real text and relative times), Messages (real conversations with previews;
  the API returns 18), a DM thread with full history and corrected `&`,
  Profile (banner, avatar, bio, 542 Following / 464 Followers, own posts with
  counts), Explore trends and 11 typeahead suggestions for "Harmony". Badges:
  Messages 1 → 2 as real unread arrived.
* Evidence: `screenshots/native-live-{home,notifications,messages,explore,profile,thread}.png`.

Still unverified by choice: live writes. `dmSendScript` / `postActionScript`
have correct session headers but were never fired against a real conversation
or post, because that would notify other people.
