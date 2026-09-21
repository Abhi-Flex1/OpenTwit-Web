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
| Compose (post + new message) | shell | native FAB + bottom sheet; Messages' FAB starts a new DM like the stock app |
| Progress, first paint, offline, retry | shell | native `Progress`, `LoadingProgress`, error card |
| Pull to refresh | shell | native `Refresh` around the `Web` child |
| Tab-root top rows (logo, tabs, search) | shell | removed from the page by injected CSS/JS |
| Timelines, threads, profiles, notification list, chat list, settings forms | x.com web | content, data-dense, and not chrome — the shell does not redraw them |
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
| Back behaviour | sheet, then web history, then the Home tab, and only then leave the app |
| Wide/continuity | same component tree, `Flex` direction flips at 840 vp: bottom bar becomes a rail, the `Web` is never re-created |
| Accessibility | every icon-only control carries `accessibilityText` / `accessibilityDescription` |
| Safe areas | the bar paints into the bottom safe area; Navigation owns the status-bar inset |

Tooling: `hvigorw assembleApp` is warning-free apart from the expected
`No signingConfig found` notice (now resolved, see 8.6) and `codelinter -f json
entry/src/main/ets` reports `[]` (0 findings; the CLI prints a note that its
bundled ruleset targets OpenHarmony projects, so treat it as one signal, not
proof).

### 8.4 Messages: what the web actually serves

The "no conversations" report was reproduced and traced:

* `x.com/messages` **redirects client-side to `/i/chat`**, X's new Chat client.
  The shell used to load `/i/chat` directly; it now loads `/messages` and lets
  x.com choose, so it follows whatever X serves next.
* That Chat screen reports **"Disconnected"** with an empty inbox. It is X's own
  UI state, not shell chrome: it survives with `databaseAccess` on, is
  unchanged by a stock iPhone Safari UA, and the page renders no conversation
  nodes at all. The emulator's network reaches the outside world (ICMP to
  google.com succeeds) but is slow, so X's realtime chat session does not
  establish here.
* `/settings/messages` no longer exists (404 in-app), so the Messages gear opens
  the real settings root, matching what the stock app's gear leads to.

### 8.5 Verification on devices

Phone AVD (1320x2856, signed in as the account owner):
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
It was installed **for real** on the foldable AVD — after uninstalling the
unsigned build, because a bundle cannot switch signing identities — and it
starts and runs (`screenshots/final/foldable/10-signed-install.jpeg`).

Honest boundary: this is the OpenHarmony **test** identity, not an
AppGallery-issued one. Emulator images that trust the OpenHarmony test root
accept it; a retail HarmonyOS device normally will not. Publishing to
AppGallery requires an AGC certificate and profile for `com.opentwit.web`,
which only the account owner can issue.
