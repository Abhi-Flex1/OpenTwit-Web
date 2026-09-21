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
