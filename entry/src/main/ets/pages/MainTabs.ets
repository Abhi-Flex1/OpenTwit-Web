import web_webview from '@ohos.web.webview';
import mediaquery from '@ohos.mediaquery';
import { preferences } from '@kit.ArkData';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { abilityAccessCtrl, common, PermissionRequestResult, Permissions, wantAgent } from '@kit.AbilityKit';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { KeyCode } from '@kit.InputKit';
import { vibrator } from '@kit.SensorServiceKit';
import {
  BAR_HEIGHT, FONT_FAMILY, HEADER_HEIGHT, PROGRESS_HEIGHT, RAIL_WIDTH, RADIUS, S12, S16, S20, S4, S8,
  TOUCH_TARGET, WIDE_BREAKPOINT
} from '../common/Theme';
import {
  TWITTER_BASE, TWITTER_ROUTES, TWITTER_COMPOSE, TWITTER_UA,
  TWITTER_SIGNUP, TWITTER_LOGIN, TWITTER_NOTIFICATIONS, TWITTER_NOTIF_SETTINGS, TWITTER_EDIT_PROFILE,
  TWITTER_SETTINGS, TWITTER_BOOKMARKS,
  searchUrl, profileUrl, listsUrl, pathOf, routeIndexForUrl, profileHandleForUrl,
  isTabRootPath, userAgentFor
} from '../common/WebConfig';
import {
  OWN_HANDLE_SCRIPT, chromeScript, chromeFlagScript, scrollToTopScript,
  CLICK_POST_BUTTON_SCRIPT, PROFILE_BOOTSTRAP_SCRIPT, fillComposerScript,
  HOME_TAB_SCRIPT, selectHomeTabScript, AVATAR_SCRIPT, UNREAD_COUNTS_SCRIPT,
  ONLINE_PATCH, immersiveInsetScript, dmInboxScript, dmThreadScript, dmSendScript, dmMuteScript,
  notificationsScript, homeTimelineScript, profileScript, trendsScript,
  searchTweetsScript, postActionScript, sessionIdentityScript, SESSION_WATCHER
} from '../common/WebChrome';
import {
  prepareRemoteImage, savePreparedImage, discardPreparedImage,
  MEDIA_SAVE_CANCELLED, MEDIA_SAVE_FAILED, MEDIA_SAVE_OK
} from '../common/MediaSaver';
import { NativeMessages } from '../components/NativeMessages';
import { NativeHome } from '../components/NativeHome';
import { NativeNotifications } from '../components/NativeNotifications';
import { NativeProfile } from '../components/NativeProfile';
import { NativeExplore } from '../components/NativeExplore';

// OpenTwit-Web: the real x.com web app inside a fully native HarmonyOS shell.
//
// The shell owns all app chrome and every visible surface is ArkUI: Home,
// Explore, Notifications, Messages and Profile all render from the page's own
// session through the PageBridge scripts in WebChrome.ets. The single shared
// WebView stays mounted underneath for session, cookies and badge reads, but it
// is never the visible surface — x.com's own top nav, bottom nav and floating
// compose button are removed by the injected chrome.
//
// The single shared WebView lives outside any Tabs on purpose: Tabs destroys its
// inactive TabContent, which would reload x.com on every tab switch.

const DOMAIN: number = 0x0A11;
const TAG: string = 'OpenTwit';
// The bundle this shell is built as; the notification agent has to name it.
const BUNDLE_NAME: string = 'com.opentwit.web';

const PREFS_NAME: string = 'opentwit_web';
const OWN_HANDLE_KEY: string = 'own_handle';
const AVATAR_KEY: string = 'own_avatar';
const DESKTOP_MODE_KEY: string = 'desktop_site';
// The composer's text, kept in ArkData preferences so a draft survives the
// sheet closing and the app being killed.
const COMPOSE_DRAFT_KEY: string = 'compose_draft';
const NOTIFICATION_ASKED_KEY: string = 'notification_asked';
const LOCATION_PERMISSIONS: Permissions[] = ['ohos.permission.LOCATION'];
const FIRST_LOAD_TIMEOUT_MS: number = 15000;
// The page's title and history only settle a moment after it navigates.
const PAGE_STATE_DELAY_MS: number = 700;
// How often the shell re-reads the unread counters from the page. x.com counts
// arrive over its own streaming connection, so a poll is what keeps the tab
// badges and the launcher badge in step with the account.
const BADGE_REFRESH_MS: number = 30000;
// How often the shell re-reads the DM inbox from the page. x.com's own client
// already holds the live connection and repaints its list from it, so reading
// the page this often is what makes the native surface track the account rather
// than a snapshot: a message that lands while the app is open shows up here
// within one tick.
const DM_POLL_MS: number = 6000;
// Live lists poll only while their tab is on screen. Home moves fastest, so it
// polls fastest; trends barely move, so they poll slowest.
const HOME_POLL_MS: number = 25000;
const NOTIF_LIST_POLL_MS: number = 20000;
const TRENDS_POLL_MS: number = 60000;
const THREAD_POLL_MS: number = 8000;
// A page that is mid-load has no navigation to read yet, so the first answer
// can be "not yet" (see UNREAD_COUNTS_SCRIPT). Ask again a few times instead of
// leaving the badges blank until the next tick.
const BADGE_RETRY_MS: number = 1200;
const BADGE_RETRY_LIMIT: number = 6;
// After the notification prompt, keep watching for a while in case the user
// allows it from Settings rather than in the dialog.
const NOTIFICATION_POLL_MS: number = 5000;
const NOTIFICATION_POLL_LIMIT: number = 6;
// The composer writes its draft a moment after the last keystroke.
const DRAFT_SAVE_DEBOUNCE_MS: number = 700;
// How many times the profile surface re-reads while the page finishes
// rendering, before it says the profile is unavailable instead of spinning.
const PROFILE_LOAD_ATTEMPTS: number = 4;
// X can expose the profile header before its first article is hydrated. Keep a
// separate, short settle pass for that case so a real account does not flash
// and then keep an empty "No posts yet" state.
const PROFILE_POST_SETTLE_MS: number = 1800;
const PROFILE_POST_SETTLE_ATTEMPTS: number = 4;

// Bridge exposed to the page as window.otNative. x.com is a single-page app, so
// its navigations never fire the Web component's load callbacks; the injected
// history hook calls this instead. A page-side watcher also calls
// onSessionAppeared the moment a session cookie shows up, which is the only
// reliable signal on pages that carry no account navigation at all (settings,
// post detail, search results — verified on x.com/settings/profile).
//
// Async page work also reports back through here rather than through the
// runJavaScript return value: ArkWeb hands back the *synchronous* result of an
// evaluated script, so an async IIFE resolves to an empty string no matter what
// it eventually returns (reproduced on the phone AVD: every list read logged
// "home read -> " with nothing after it, while the identical script evaluated
// over CDP returned real data). The page therefore calls onBridgeResult when
// its promise settles, which is also what makes the reads real-time.
class PageBridge {
  private handler: (url: string) => void = (url: string) => {
  };
  private sessionHandler: () => void = () => {
  };
  private resultHandler: (id: string, json: string) => void = (id: string, json: string) => {
  };

  setHandler(handler: (url: string) => void): void {
    this.handler = handler;
  }

  setSessionHandler(handler: () => void): void {
    this.sessionHandler = handler;
  }

  setResultHandler(handler: (id: string, json: string) => void): void {
    this.resultHandler = handler;
  }

  onUrlChange(url: string): void {
    this.handler(url);
  }

  onSessionAppeared(): void {
    this.sessionHandler();
  }

  onBridgeResult(id: string, json: string): void {
    this.resultHandler(id, json);
  }
}
// How long the account menu needs before it has rendered its links.
const BOOTSTRAP_SETTLE_MS: number = 1800;

// One conversation as the DM bridge reports it. The bridge runs inside x.com's
// own origin and returns this shape as JSON.
interface DmBridgeConversation {
  id: string;
  name: string;
  handle: string;
  avatar: string;
  uid: string;
  text: string;
  out: boolean;
  at: number;
  muted: boolean;
  unread: number;
}

interface DmBridgePayload {
  state: string;
  conversations?: DmBridgeConversation[];
  message?: string;
}

// Generic timeline post as the bridge reports it. Home, Profile and Search all
// share this shape so the post row renders identically everywhere.
interface TimelineBridgePost {
  id: string;
  name: string;
  handle: string;
  avatar: string;
  text: string;
  at: number;
  likes: number;
  reposts: number;
  replies: number;
  liked: boolean;
  reposted: boolean;
  bookmarked: boolean;
  media: string;
}

interface TimelineBridgePayload {
  state: string;
  posts?: TimelineBridgePost[];
  next?: string;
}

interface ProfileBridgeUser {
  name: string;
  handle: string;
  avatar: string;
  banner: string;
  bio: string;
  location: string;
  followers: number;
  following: number;
  posts: number;
  at: number;
}

interface ProfileBridgePayload {
  state: string;
  user?: ProfileBridgeUser;
  posts?: TimelineBridgePost[];
  next?: string;
}

interface SessionIdentityPayload {
  state: string;
  id: string;
  handle: string;
  name: string;
  avatar: string;
}

// One async page read in flight, keyed by the id the page answers with.
interface BridgePending {
  name: string;
  key: string;
  at: number;
}

interface PendingPostAction {
  kind: string;
  id: string;
  returnUrl: string;
  staged: boolean;
  attempts: number;
}

@Entry
@Component
struct MainTabs {
  @State currentIndex: number = 0;
  @State progress: number = 0;
  @State hasError: boolean = false;
  @State searchText: string = '';
  @State ownHandle: string = '';
  // Signed-in avatar, read off the account's own profile page and cached, so
  // the Home header can show the real account picture like the stock app.
  @State avatarUrl: string = '';
  // Which Home timeline the native switcher has selected: 0 = For you,
  // 1 = Following. Mirrors x.com's own tab row.
  @State homeTabIndex: number = 0;
  @State viewingHandle: string = '';
  @State currentPath: string = '';
  @State currentUrl: string = '';
  @State isWide: boolean = false;
  @State firstLoadDone: boolean = false;
  @State sheetOpen: boolean = false;
  // Messages is a native ArkUI surface. The title/back state lives here so the
  // shell header can show a conversation exactly like a pushed native page.
  @State chatOpen: boolean = false;
  @State chatTitle: string = '';
  // The x.com login flow, shown in the session WebView on top of the native
  // surfaces. Opened from any sign-in screen, closed by Back, by switching
  // tabs, or automatically the moment the account appears.
  @State webLoginOpen: boolean = false;
  // A user-facing web destination (post detail, settings, bookmarks, lists)
  // briefly takes over the shell. Hidden session loads keep using loadWeb().
  @State webDetailOpen: boolean = false;
  @State webDetailTitle: string = '';
  private webDetailReturnIndex: number = 0;
  // Native composer state. "webComposer" is the escape hatch: when the page's
  // own composer cannot be driven (or the post needs media/GIF/poll), the sheet
  // reveals the real x.com composer instead of failing.
  @State draft: string = '';
  @State webComposer: boolean = false;
  @State posting: boolean = false;
  @State mediaSavePath: string = '';
  @State mediaSaveId: string = '';
  @State mediaSaveSheet: boolean = false;
  @State mediaSaveBusy: boolean = false;
  @State mediaSaveDownloading: boolean = false;
  @State mediaSaveReady: boolean = false;
  // True while the shell is reading the signed-in handle behind a native panel.
  @State discovering: boolean = false;
  // The page's own title (x.com's " / X" suffix stripped) and whether there is
  // web history to go back to. The shell draws the header for every page, so
  // these are what the native title bar shows.
  @State refreshing: boolean = false;
  // Unread items, read from the page's own navigation entries. Both the tab bar
  // and the launcher icon show them, so the count does not depend on the web UI
  // being on screen.
  @State unreadNotifications: number = 0;
  @State unreadMessages: number = 0;
  @State pageTitle: string = '';
  @State canGoBack: boolean = false;
  // The account's real DM inbox, exactly as the DM bridge reported it. The
  // native Messages surface parses this; nothing here is seeded or invented.
  @State dmJson: string = '';
  // Open thread history and the other native lists. Each holds the verbatim
  // bridge JSON for its surface; the surface parses and renders it.
  @State threadJson: string = '';
  @State threadId: string = '';
  @State sendStateJson: string = '';
  @State homeJson: string = '';
  @State notifListJson: string = '';
  @State profileJson: string = '';
  @State trendsJson: string = '';
  @State searchJson: string = '';
  // Paging cursors. Home/Notifications use the v2 bottom cursor; profile uses
  // 'more' while the page still renders new articles on scroll.
  private homeNext: string = '';
  private profileNext: string = '';
  private profileFor: string = '';
  private profileLoadingRetry: string = '';
  // Bounded: the profile DOM needs a moment to render, but a page that will
  // never render it (wrong route) must not spin forever.
  private profileLoadAttempts: number = 0;
  private profileSettleAttempts: number = 0;
  private profileSettleTimer: number = -1;
  private searchNext: string = '';
  private searchPending: string = '';
  private controller: web_webview.WebviewController = new web_webview.WebviewController();
  private composeController: web_webview.WebviewController = new web_webview.WebviewController();
  private wideListener: mediaquery.MediaQueryListener | undefined = undefined;
  private bridge: PageBridge = new PageBridge();
  // DM inbox polling. The timer runs only while the Messages tab is on screen.
  private dmTimer: number = -1;
  // Live-list timers. Each runs only while its surface is on screen, so the
  // native lists track the account in near real time without costing anything
  // on the other tabs.
  private homeTimer: number = -1;
  private notifListTimer: number = -1;
  private trendsTimer: number = -1;
  private threadTimer: number = -1;
  // Conversation id -> the timestamp already reported to the user, so a new
  // message notifies once and the same one never notifies twice.
  private dmSeen: Map<string, number> = new Map<string, number>();
  private dmFirstRead: boolean = true;
  private firstLoadTimer: number = -1;
  private badgeTimer: number = -1;
  private badgeRetryTimer: number = -1;
  private badgeRetries: number = 0;
  private draftSaveTimer: number = -1;
  // Whether the notification prompt (the one that lets the icon carry a badge)
  // has been shown, so a decline is respected and never repeated.
  private notificationAsked: boolean = false;
  // Async page work in flight, keyed by a one-shot id. Results come back
  // through PageBridge.onBridgeResult; each entry also carries a deadline so a
  // page that never answers cannot leave a surface loading forever.
  private bridgeSeq: number = 0;
  private bridgePending: Map<string, BridgePending> = new Map<string, BridgePending>();
  // Thread the conversation the in-flight read belongs to, so a reply that
  // lands after the user closed the thread cannot reopen it.
  private pendingThreadId: string = '';
  // How many times each surface has been re-read after a transient failure.
  private bridgeRetries: Record<string, number> = {};
  private pendingSendConversations: Map<string, string> = new Map<string, string>();
  // Bookmark writes are delegated to x.com's own rendered control. If the
  // article is not on the hidden route, this briefly stages its status page
  // there, clicks the real control, and restores the route behind the native
  // surface.
  private pendingPostAction: PendingPostAction | null = null;
  private postActionStageTimer: number = -1;
  // Last count handed to the launcher, so the shell only calls out when it
  // actually changes.
  private badgeShown: number = -1;

  async aboutToAppear(): Promise<void> {
    this.bridge.setHandler((url: string) => {
      this.syncFromUrl(url);
      if (this.ownHandle === '') {
        // x.com navigates like an app: a completed login is a history.pushState
        // to /home that never fires onPageEnd, so a signed-out shell would
        // never notice the new session without asking here too.
        this.discoverOwnProfile(false);
      }
      this.updateChromeFlag(url);
      this.applyPageChrome(url);
      this.schedulePageStateRead();
    });
    this.bridge.setSessionHandler(() => {
      // The page saw a session cookie appear. Identity comes from the session
      // itself (the inbox names its participants), so this works on any route.
      hilog.info(DOMAIN, TAG, 'page reports a session; reading identity');
      this.readSessionIdentity();
    });
    this.bridge.setResultHandler((id: string, json: string) => {
      const entry = this.bridgePending.get(id);
      if (entry === undefined) {
        return;
      }
      this.bridgePending.delete(id);
      this.applyBridgeResult(entry.name, entry.key, json);
    });
    this.applyBreakpoints();
    this.armFirstLoadTimeout();
    this.armBadgeRefresh();
    try {
      const ctx: common.Context | undefined = this.getUIContext().getHostContext();
      if (ctx !== undefined) {
        const prefs: preferences.Preferences = await preferences.getPreferences(ctx, PREFS_NAME);
        const saved: string = await prefs.get(OWN_HANDLE_KEY, '') as string;
        if (saved !== '') {
          this.ownHandle = saved;
        }
        const avatar: string = await prefs.get(AVATAR_KEY, '') as string;
        if (avatar !== '') {
          this.avatarUrl = avatar;
        }
        const draft: string = await prefs.get(COMPOSE_DRAFT_KEY, '') as string;
        if (draft !== '') {
          this.draft = draft;
        }
        this.notificationAsked = await prefs.get(NOTIFICATION_ASKED_KEY, false) as boolean;
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'preferences unavailable: %{public}s', JSON.stringify(err));
    }
    // The visible tab owns its poller from first paint. Home is index 0.
    this.applyPollersForTab(this.currentIndex);
  }

  // Tells the page how much of its own bottom is covered by the shell's floating
  // tab bar. Without this the last rows of a page would be permanently trapped
  // behind the bar; with it they scroll clear of the bar and the bar still has
  // page content passing under it.
  private applyImmersiveInset(): void {
    const bottom: number = this.isWide || this.immersiveConversation() ? 0 : BAR_HEIGHT;
    try {
      this.controller.runJavaScript(immersiveInsetScript(0, bottom));
    } catch (err) {
    }
  }

  aboutToDisappear(): void {
    if (this.mediaSavePath !== '') {
      this.cancelPreparedImage();
    }
    this.stopDmPolling();
    this.stopHomePolling();
    this.stopNotifListPolling();
    this.stopTrendsPolling();
    this.stopThreadPolling();
    this.clearProfileSettleTimer();
    // Cookies are the login. ArkWeb persists them, but writing the jar out
    // explicitly before the page is torn down means an update in place — which
    // is how this app is installed during development — never costs the session.
    try {
      web_webview.WebCookieManager.saveCookieAsync().catch((err: BusinessError) => {
        hilog.debug(DOMAIN, TAG, 'cookie persist failed: %{public}d', err.code);
      });
    } catch (err) {
      hilog.debug(DOMAIN, TAG, 'cookie persist unavailable: %{public}s', JSON.stringify(err));
    }
    if (this.firstLoadTimer !== -1) {
      clearTimeout(this.firstLoadTimer);
      this.firstLoadTimer = -1;
    }
    if (this.badgeTimer !== -1) {
      clearInterval(this.badgeTimer);
      this.badgeTimer = -1;
    }
    if (this.badgeRetryTimer !== -1) {
      clearTimeout(this.badgeRetryTimer);
      this.badgeRetryTimer = -1;
    }
    if (this.draftSaveTimer !== -1) {
      clearTimeout(this.draftSaveTimer);
      this.draftSaveTimer = -1;
      // Leaving the app is a good moment to make sure the draft is on disk.
      this.saveDraft();
    }
    if (this.wideListener !== undefined) {
      try {
        this.wideListener.off('change');
      } catch (err) {
      }
      this.wideListener = undefined;
    }
  }

  // Coming back to the app is the moment the counts are most likely to be stale
  // (the page kept running in the background), so re-read them here as well as
  // on the timer.
  onPageShow(): void {
    this.refreshBadges();
    if (!this.signedIn()) {
      this.readSessionIdentity();
      this.discoverOwnProfile(false);
    }
    this.refreshVisibleSurface();
  }

  // A page that never finishes loading must not leave the first-load spinner up
  // forever.
  private armFirstLoadTimeout(): void {
    this.firstLoadTimer = setTimeout(() => {
      this.firstLoadDone = true;
    }, FIRST_LOAD_TIMEOUT_MS);
  }

  private finishFirstLoad(): void {
    this.firstLoadDone = true;
    if (this.firstLoadTimer !== -1) {
      clearTimeout(this.firstLoadTimer);
      this.firstLoadTimer = -1;
    }
  }

  // Bottom bar on phones, side rail on wide layouts. The listener only flips a
  // state flag, so the WebView is never re-created by a breakpoint change.
  private applyBreakpoints(): void {
    try {
      const listener: mediaquery.MediaQueryListener =
        this.getUIContext().getMediaQuery().matchMediaSync('(width>=' + WIDE_BREAKPOINT + 'vp)');
      this.isWide = listener.matches;
      listener.on('change', (result: mediaquery.MediaQueryResult) => {
        this.isWide = result.matches;
        // The bottom bar only covers the page on the narrow layout, so the
        // page's own bottom inset changes with the breakpoint.
        this.applyImmersiveInset();
      });
      this.wideListener = listener;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'media query unavailable: %{public}s', JSON.stringify(err));
    }
  }

  // Short tick on tab change — HarmonyOS expects light tactile confirmation for
  // navigation, and a device without a motor simply rejects the request.
  private tick(): void {
    // 2in1 desktops have no motor, and the SDK marks vibration as a capability
    // that is not present on every device type.
    if (!canIUse('SystemCapability.Sensors.MiscDevice')) {
      return;
    }
    try {
      vibrator.startVibration({ type: 'time', duration: 10 }, { id: 0, usage: 'unknown' })
        .catch((err: Error) => {
          hilog.debug(DOMAIN, TAG, 'no haptics: %{public}s', err.message);
        });
    } catch (err) {
    }
  }

  private toast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (err) {
    }
  }

  // System back: close the sheet, then walk the web history, then return to the
  // Home tab, and only then let the system close the app (HarmonyOS UX
  // requirement — back must not drop the user out of a page they can leave).
  onBackPress(): boolean {
    if (this.sheetOpen) {
      this.sheetOpen = false;
      return true;
    }
    if (this.chatOpen) {
      this.chatOpen = false;
      this.chatTitle = '';
      this.threadId = '';
      this.threadJson = '';
      this.stopThreadPolling();
      return true;
    }
    if (this.webLoginOpen) {
      this.webLoginOpen = false;
      return true;
    }
    if (this.webDetailOpen) {
      this.closeWebDetail();
      return true;
    }
    // Every visible surface is native ArkUI over a hidden session WebView, so
    // web history is invisible and must not intercept Back. Native roots go
    // Home first, then the system may leave the app (HarmonyOS UX requirement).
    if (this.currentIndex !== 0) {
      this.goRoute(0);
      return true;
    }
    return false;
  }

  private tabLabel(index: number): Resource {
    if (index === 0) {
      return $r('app.string.tab_home');
    } else if (index === 1) {
      return $r('app.string.tab_explore');
    } else if (index === 2) {
      return $r('app.string.tab_notifications');
    } else if (index === 3) {
      return $r('app.string.tab_messages');
    }
    return $r('app.string.tab_profile');
  }

  private async saveOwnHandle(handle: string): Promise<void> {
    try {
      const ctx: common.Context | undefined = this.getUIContext().getHostContext();
      if (ctx === undefined) {
        return;
      }
      const prefs: preferences.Preferences = await preferences.getPreferences(ctx, PREFS_NAME);
      await prefs.put(OWN_HANDLE_KEY, handle);
      await prefs.flush();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'own handle not persisted: %{public}s', JSON.stringify(err));
    }
  }

  private async saveAvatar(url: string): Promise<void> {
    try {
      const ctx: common.Context | undefined = this.getUIContext().getHostContext();
      if (ctx === undefined) {
        return;
      }
      const prefs: preferences.Preferences = await preferences.getPreferences(ctx, PREFS_NAME);
      await prefs.put(AVATAR_KEY, url);
      await prefs.flush();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'avatar not persisted: %{public}s', JSON.stringify(err));
    }
  }

  // WebviewController.runJavaScript answers with the evaluated result
  // JSON-encoded, so a JavaScript string arrives quoted. Every value the shell
  // reads back out of a page goes through here first.
  private static unquote(raw: string): string {
    if (!raw) {
      return '';
    }
    const first: string = raw.charAt(0);
    if (first === '"' && raw.length >= 2) {
      try {
        return JSON.parse(raw) as string;
      } catch (err) {
        return raw.substring(1, raw.length - 1);
      }
    }
    if (raw === 'undefined' || raw === 'null') {
      return '';
    }
    return raw;
  }

  private static parseHandle(raw: string): string {
    if (!raw) {
      return '';
    }
    const slash: number = raw.indexOf('/');
    if (slash < 0) {
      return '';
    }
    let out: string = '';
    for (let i: number = slash + 1; i < raw.length && out.length < 15; i++) {
      const ch: string = raw.charAt(i);
      if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
        (ch >= '0' && ch <= '9') || ch === '_') {
        out += ch;
      } else {
        break;
      }
    }
    // Case is kept: x.com treats handles case-insensitively but displays
    // them as typed, and the shell mirrors the page in the title bar.
    return out.length >= 1 ? out : '';
  }

  private clearProfileSettleTimer(): void {
    if (this.profileSettleTimer !== -1) {
      clearTimeout(this.profileSettleTimer);
      this.profileSettleTimer = -1;
    }
  }

  private resetProfileSettle(): void {
    this.clearProfileSettleTimer();
    this.profileSettleAttempts = 0;
  }

  private scheduleProfilePostSettle(key: string): void {
    if (this.profileSettleTimer !== -1 || this.profileSettleAttempts >= PROFILE_POST_SETTLE_ATTEMPTS) {
      return;
    }
    this.profileSettleAttempts++;
    this.profileSettleTimer = setTimeout(() => {
      this.profileSettleTimer = -1;
      if (this.currentIndex !== 4 || this.profileFor !== key) {
        return;
      }
      let count: number = 0;
      try {
        const payload = JSON.parse(this.profileJson) as ProfileBridgePayload;
        count = payload.posts?.length ?? 0;
      } catch (err) {
      }
      if (count === 0 && this.profileSettleAttempts < PROFILE_POST_SETTLE_ATTEMPTS) {
        this.refreshProfile(key);
      } else {
        // This is either hydrated or genuinely empty. Either way, do not keep a
        // background timer alive for a profile the user is no longer looking at.
        this.profileSettleAttempts = 0;
      }
    }, PROFILE_POST_SETTLE_MS);
  }

  // How long an async page read may take before the surface is told it failed.
  private static readonly BRIDGE_TIMEOUT_MS: number = 20000;

  // Run an async bridge script and receive its JSON through the proxy callback.
  // The script is evaluated synchronously (returning ''), the page's promise is
  // awaited there, and the answer is handed back to this method by id.
  // `key` says what the read is about (conversation, query, handle), so a reply
  // that arrives after the user moved on is dropped instead of overwriting the
  // surface they are looking at now.
  private runBridge(name: string, script: string, key: string): void {
    this.bridgeSeq++;
    const id: string = name + '-' + this.bridgeSeq.toString();
    this.bridgePending.set(id, { name: name, key: key, at: Date.now() });
    const wrapped: string =
      '(function(){var id=' + JSON.stringify(id) + ';' +
      'function send(v){try{window.otNative.onBridgeResult(id,String(v));}catch(e){}}' +
      'try{Promise.resolve(' + script + ').then(send).catch(function(e){' +
      'send(JSON.stringify({state:"error",message:String(e).slice(0,120)}));});}catch(e){' +
      'send(JSON.stringify({state:"error"}));}' +
      'return "";})()';
    try {
      this.controller.runJavaScript(wrapped);
    } catch (err) {
      this.bridgePending.delete(id);
      hilog.info(DOMAIN, TAG, '%{public}s read could not start', name);
      if (name === 'sendDm') {
        this.applyBridgeResult(name, key, '{"state":"error"}');
      } else {
        this.retryBridgeSoon(name);
      }
    }
    setTimeout(() => {
      if (this.bridgePending.has(id)) {
        this.bridgePending.delete(id);
        hilog.info(DOMAIN, TAG, '%{public}s read timed out', name);
        this.applyBridgeResult(name, key, '{"state":"error"}');
      }
    }, MainTabs.BRIDGE_TIMEOUT_MS);
  }

  // A full page load replaces the page's JavaScript context, so any read still
  // in flight can never answer: drop them instead of timing out 20 s later and
  // flashing an error over a surface that the new page is about to fill.
  private dropPendingBridgeReads(): void {
    if (this.bridgePending.size > 0) {
      hilog.debug(DOMAIN, TAG, 'page load: dropping %{public}d pending read(s)',
        this.bridgePending.size);
      this.bridgePending.forEach((entry: BridgePending) => {
        if (entry.name === 'sendDm') {
          this.sendStateJson = JSON.stringify({ state: 'error', messageId: entry.key });
          this.pendingSendConversations.delete(entry.key);
        }
      });
      this.bridgePending.clear();
    }
    if (this.pendingPostAction !== null && !this.pendingPostAction.staged) {
      this.finishPostAction(false);
    }
  }

  // Results land here by surface name, so one callback path serves every read.
  private applyBridgeResult(name: string, key: string, json: string): void {
    if (json === '') {
      return;
    }
    hilog.debug(DOMAIN, TAG, '%{public}s -> %{public}s', name, json.slice(0, 48));
    // A read that lands while the page is still settling comes back as an
    // error or empty. Retry it in a couple of seconds rather than leaving the
    // surface showing a failure until the next full poll (25 s on Home).
    const isWriteBridge: boolean = name === 'sendDm' || name === 'dmMute' || name === 'postAction';
    if (!isWriteBridge &&
      (json.indexOf('"state":"error"') >= 0 || json.indexOf('"state":"unexpected"') >= 0)) {
      this.retryBridgeSoon(name);
    } else {
      this.bridgeRetries['retry-' + name] = 0;
    }
    if (name === 'home') {
      this.homeJson = json;
      this.noteSignedOut(json);
      this.homeNext = MainTabs.nextCursor(json);
    } else if (name === 'homeMore') {
      if (this.homeJson !== '') {
        this.homeJson = MainTabs.mergeTimeline(this.homeJson, json);
      }
      this.homeNext = MainTabs.nextCursor(json);
    } else if (name === 'notif') {
      this.notifListJson = json;
      this.noteSignedOut(json);
    } else if (name === 'trends') {
      this.trendsJson = json;
      this.noteSignedOut(json);
    } else if (name === 'search') {
      // A slower earlier query must never overwrite the one on screen.
      if (key === this.searchPending) {
        this.searchJson = json;
        this.noteSignedOut(json);
        this.searchNext = MainTabs.nextCursor(json);
      }
    } else if (name === 'dm') {
      this.dmJson = json;
      this.noteSignedOut(json);
      this.reportNewDms(json);
    } else if (name === 'thread') {
      // A reply for a conversation the user has left must not reopen it.
      if (key !== '' && key === this.threadId) {
        this.threadJson = json;
        this.noteSignedOut(json);
      }
    } else if (name === 'profile') {
      if (key !== this.profileFor) {
        return;
      }
      this.profileJson = json;
      this.noteSignedOut(json);
      this.profileNext = MainTabs.nextCursor(json);
      this.profileLoadingRetry = '';
      // The header avatar comes from here too: the scraped profile carries the
      // account's own picture, so Home's title bar is right even on a cold start.
      try {
        const payload = JSON.parse(json) as ProfileBridgePayload;
        const avatar: string = payload.user?.avatar ?? '';
        if (avatar.indexOf('http') === 0 && avatar !== this.avatarUrl) {
          this.avatarUrl = avatar;
          this.saveAvatar(avatar);
        }
        const postCount: number = payload.posts?.length ?? 0;
        if (postCount > 0) {
          this.resetProfileSettle();
        } else if (payload.user !== undefined) {
          this.scheduleProfilePostSettle(key);
        }
      } catch (err) {
      }
      if (json.indexOf('"state":"loading"') >= 0) {
        // The profile DOM renders a beat after the page. Re-read a few times,
        // then say the profile is unavailable instead of spinning forever.
        if (this.profileLoadAttempts < PROFILE_LOAD_ATTEMPTS) {
          this.profileLoadAttempts++;
          setTimeout(() => {
            if (this.currentIndex === 4 && this.profileFor === key &&
              this.profileJson.indexOf('"state":"loading"') >= 0) {
              this.refreshProfile(key);
            }
          }, 2500);
        } else {
          this.profileJson = '{"state":"unexpected"}';
        }
      } else {
        this.profileLoadAttempts = 0;
      }
    } else if (name === 'profileMore') {
      if (key !== this.profileFor) {
        return;
      }
      this.profileJson = MainTabs.mergeProfile(this.profileJson, json);
      this.profileNext = MainTabs.nextCursor(json);
    } else if (name === 'identity') {
      this.applyIdentity(json);
    } else if (name === 'sendDm') {
      const conversationId: string = this.pendingSendConversations.get(key) ?? '';
      this.pendingSendConversations.delete(key);
      if (json.indexOf('"state":"ok"') >= 0) {
        this.sendStateJson = JSON.stringify({ state: 'ok', messageId: key });
        this.tick();
        if (conversationId !== '') {
          this.refreshThread(conversationId);
        }
        this.refreshDms();
      } else if (json.indexOf('signed-out') >= 0) {
        this.sendStateJson = JSON.stringify({ state: 'error', messageId: key });
        this.toast($r('app.string.messages_signed_out_title'));
      } else {
        this.sendStateJson = JSON.stringify({ state: 'error', messageId: key });
        this.toast($r('app.string.messages_send_unavailable'));
      }
    } else if (name === 'dmMute') {
      if (json.indexOf('"state":"ok"') >= 0) {
        this.refreshDms();
      } else {
        this.toast($r('app.string.messages_mute_unavailable'));
      }
    } else if (name === 'postAction') {
      if (this.pendingPostAction === null) {
        return;
      }
      if (json.indexOf('"state":"staged"') >= 0) {
        this.stagePostAction();
      } else if (json.indexOf('"state":"ok"') >= 0) {
        this.finishPostAction(true);
      } else {
        this.finishPostAction(false);
      }
    }
  }

  // A transient page failure is common right after a navigation (the page is
  // still swapping documents, so a fetch answers empty). Re-read the same
  // surface shortly after, a few times, before the surface settles on a state.
  private retryBridgeSoon(name: string): void {
    const key: string = 'retry-' + name;
    this.bridgeRetries[key] = (this.bridgeRetries[key] ?? 0) + 1;
    const attempt: number = this.bridgeRetries[key];
    if (attempt > 4) {
      return;
    }
    setTimeout(() => {
      if (this.bridgeRetries[key] !== attempt) {
        return;
      }
      switch (name) {
        case 'home':
          this.refreshHome();
          break;
        case 'homeMore':
          this.loadMoreHome();
          break;
        case 'notif':
          this.refreshNotifList();
          break;
        case 'trends':
          this.refreshTrends();
          break;
        case 'search':
          this.runSearch(this.searchText);
          break;
        case 'dm':
          this.refreshDms();
          break;
        case 'thread':
          this.refreshThread(this.pendingThreadId);
          break;
        case 'profile':
          this.refreshProfile(this.viewingHandle !== '' ? this.viewingHandle : this.ownHandle);
          break;
        case 'profileMore':
          this.loadMoreProfile();
          break;
        case 'identity':
          this.readSessionIdentity();
          break;
        default:
          break;
      }
    }, 1500 * attempt);
  }

  // Identity straight off the session, no DOM. The inbox names its
  // participants, so the account in the most one-to-one conversations is the
  // signed-in user; its entry carries the handle and picture. This is the only
  // identity source that works on routes with no account navigation at all
  // (settings, post detail, search — verified on x.com/settings/profile, where
  // both the nav link and the account menu are absent).
  private readSessionIdentity(): void {
    if (this.ownHandle !== '') {
      return;
    }
    this.runBridge('identity', sessionIdentityScript(), '');
  }

  private applyIdentity(json: string): void {
    if (json.indexOf('"state":"ok"') < 0) {
      return;
    }
    try {
      const payload = JSON.parse(json) as SessionIdentityPayload;
      if (payload.handle === '') {
        return;
      }
      if (payload.avatar !== '' && payload.avatar !== this.avatarUrl) {
        this.avatarUrl = payload.avatar;
        this.saveAvatar(payload.avatar);
      }
      this.acceptHandle(payload.handle, false);
    } catch (err) {
    }
  }

  // Handle discovery runs on full page loads, on every in-page navigation and
  // on the badge tick while signed out: x.com hydrates its navigation
  // client-side, so the account link may not exist on the first read after a
  // login, and a completed login often never fires onPageEnd at all. The guard
  // keeps overlapping reads from interleaving.
  private discoveringHandle: boolean = false;

  private discoverOwnProfile(navigate: boolean): void {
    if (this.ownHandle !== '') {
      this.finishDiscover(navigate);
      return;
    }
    if (this.discoveringHandle) {
      return;
    }
    // Fast path: a layout that links the account directly (the desktop sidebar
    // and the mobile tab bar do; settings, post detail and search do not).
    let pending: Promise<string> | undefined = undefined;
    try {
      pending = this.controller.runJavaScript(OWN_HANDLE_SCRIPT);
    } catch (err) {
      pending = undefined;
    }
    if (pending === undefined) {
      this.discoverWithSession(navigate);
      return;
    }
    this.discoveringHandle = true;
    (pending as Promise<string>).then((raw: string) => {
      this.discoveringHandle = false;
      const direct: string = MainTabs.parseHandle('/' + MainTabs.unquote(raw));
      if (direct !== '') {
        this.acceptHandle(direct, navigate);
        return;
      }
      this.discoverWithSession(navigate);
    }).catch(() => {
      this.discoveringHandle = false;
      this.discoverWithSession(navigate);
    });
  }

  // The DOM came up empty. With a session present the identity read answers on
  // any page, so try that first; the account menu is the last resort (it is
  // invisible behind the native surface and never runs mid-login).
  private discoverWithSession(navigate: boolean): void {
    if (navigate) {
      this.bootstrapProfile();
      return;
    }
    if (this.webLoginOpen || this.discovering || this.ownHandle !== '') {
      return;
    }
    try {
      this.controller.runJavaScript('document.cookie.indexOf("ct0=")>=0?"1":""').then((raw: string) => {
        if (MainTabs.unquote(raw) !== '1' || this.ownHandle !== '' ||
          this.webLoginOpen || this.discovering) {
          return;
        }
        this.readSessionIdentity();
        // The inbox answers on any page, but an account with an empty DM inbox
        // gives no identity that way; the menu read covers that case.
        setTimeout(() => {
          if (this.ownHandle === '' && !this.webLoginOpen && !this.discovering) {
            this.bootstrapProfile();
          }
        }, 1200);
      }).catch(() => {
      });
    } catch (err) {
    }
  }

  // The signed-in handle is only published inside the account menu on the
  // mobile web, so this opens that menu, reads the handle and closes it again —
  // behind a native panel, so what the user sees is a HarmonyOS spinner. It
  // runs at most once per install; the handle is then persisted.
  private bootstrapProfile(): void {
    if (this.discovering) {
      return;
    }
    this.discovering = true;
    let pending: Promise<string> | undefined = undefined;
    try {
      pending = this.controller.runJavaScript(PROFILE_BOOTSTRAP_SCRIPT);
    } catch (err) {
      pending = undefined;
    }
    if (pending === undefined) {
      this.finishBootstrap('');
      return;
    }
    (pending as Promise<string>).then(() => {
      setTimeout(() => {
        try {
          this.controller.runJavaScript('window.__otBoot||""').then((raw: string) => {
            this.finishBootstrap(MainTabs.parseHandle('/' + MainTabs.unquote(raw)));
          }).catch(() => {
            this.finishBootstrap('');
          });
        } catch (err) {
          this.finishBootstrap('');
        }
      }, BOOTSTRAP_SETTLE_MS + 1600);
    }).catch(() => {
      this.finishBootstrap('');
    });
  }

  private finishBootstrap(handle: string): void {
    this.discovering = false;
    if (handle !== '') {
      this.acceptHandle(handle, true);
      return;
    }
    this.finishDiscover(true);
  }

  private acceptHandle(handle: string, navigate: boolean): void {
    this.ownHandle = handle;
    this.saveOwnHandle(handle);
    // The account just appeared (login or discovery): the login view has done
    // its job and every signed-out panel must flip to live lists at once.
    this.webLoginOpen = false;
    this.refreshVisibleSurface();
    // Reads fired mid-transition can beat hydration (no bearer yet, half DOM),
    // so re-read once settled. The first pass is immediate for a fast flip.
    setTimeout(() => {
      if (this.signedIn()) {
        this.refreshVisibleSurface();
      }
    }, 3500);
    this.finishDiscover(navigate);
  }

  // Any sign-in screen lands here: reveal the session WebView on the login
  // flow. The account menu, timeline switcher and FAB stay hidden behind it
  // until the session answers.
  private openWebLogin(): void {
    this.webDetailOpen = false;
    this.webDetailTitle = '';
    this.webLoginOpen = true;
    this.loadWeb(TWITTER_LOGIN);
  }

  // A signed-out visitor is sent to the profile editor too: x.com redirects
  // that URL to its own login flow, so the shell does not have to guess.
  private finishDiscover(navigate: boolean): void {
    if (!navigate) {
      return;
    }
    if (this.ownHandle !== '') {
      this.viewingHandle = this.ownHandle;
      this.loadWeb(profileUrl(this.ownHandle));
      return;
    }
    this.loadWeb(TWITTER_EDIT_PROFILE);
  }

  private loadWeb(url: string): void {
    this.hasError = false;
    this.progress = 0;
    try {
      // x.com refuses e-mail sign-up on its mobile web path, so that flow is
      // loaded with a desktop user agent. No user-facing switch: the shell
      // picks what the page needs.
      this.controller.setCustomUserAgent(
        userAgentFor(deviceInfo.deviceType === '2in1' || url.indexOf('/i/flow/signup') >= 0));
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'UA switch failed: %{public}s', JSON.stringify(err));
    }
    try {
      this.controller.loadUrl(url);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'loadUrl failed: %{public}s', JSON.stringify(err));
    }
  }

  // User-facing web navigation. The session WebView is already mounted and is
  // reused so cookies, bearer state, and account context stay identical to the
  // native bridge; the detail flag is what makes it visible above the native tab.
  private openWebDetail(url: string): void {
    if (url === '') {
      return;
    }
    this.webLoginOpen = false;
    this.webDetailReturnIndex = this.currentIndex;
    this.webDetailOpen = true;
    this.webDetailTitle = this.webDetailTitleForUrl(url);
    this.loadWeb(url);
  }

  private webDetailTitleForUrl(url: string): string {
    const path: string = pathOf(url);
    if (path.indexOf('/status/') >= 0) {
      return this.localized($r('app.string.post'));
    }
    if (path.indexOf('/settings/notifications') >= 0) {
      return this.localized($r('app.string.menu_notification_settings'));
    }
    if (path.indexOf('/settings') >= 0) {
      return this.localized($r('app.string.menu_settings'));
    }
    if (path.indexOf('/i/bookmarks') >= 0) {
      return this.localized($r('app.string.menu_bookmarks'));
    }
    if (path.indexOf('/lists') >= 0) {
      return this.localized($r('app.string.menu_lists'));
    }
    if (path.indexOf('/notifications') === 0) {
      return this.localized($r('app.string.tab_notifications'));
    }
    return '';
  }

  private closeWebDetail(): void {
    const returnIndex: number = this.webDetailReturnIndex;
    this.webDetailOpen = false;
    this.webDetailTitle = '';
    this.webDetailReturnIndex = 0;
    this.currentIndex = returnIndex;
    this.currentPath = '';
    this.currentUrl = '';
    this.pageTitle = '';
    this.canGoBack = false;
    this.applyImmersiveInset();
    if (returnIndex === 4 && this.viewingHandle !== '') {
      this.loadWeb(profileUrl(this.viewingHandle));
    } else if (returnIndex >= 0 && returnIndex < TWITTER_ROUTES.length) {
      this.loadWeb(TWITTER_ROUTES[returnIndex]);
    }
    this.refreshVisibleSurface();
  }

  // A 2in1 window is a desktop, so it asks x.com for the desktop web app: a
  // phone user agent inside a 1000+ vp window is a mismatch the site acts on
  // (and one its sign-in risk checks can read as an emulated browser). Phones,
  // tablets and unfolded foldables keep the mobile web app they were built
  // against.
  private userAgent(): string {
    return userAgentFor(deviceInfo.deviceType === '2in1');
  }

  // Feeds the document-start navigator.onLine patch (see ONLINE_PATCH). The
  // shell only ever corrects it downwards, when the main frame really failed.
  private setOnlineFlag(online: boolean): void {
    try {
      this.controller.runJavaScript('window.__otOnline=' + (online ? 'true' : 'false') + ';');
    } catch (err) {
    }
  }

  private syncFromUrl(url: string): void {
    const idx: number = routeIndexForUrl(url);
    hilog.debug(DOMAIN, TAG, 'syncFromUrl url=%{public}s idx=%{public}d current=%{public}d',
      url, idx, this.currentIndex);
    if (this.webDetailOpen) {
      const detailTitle: string = this.webDetailTitleForUrl(url);
      if (detailTitle !== '') {
        this.webDetailTitle = detailTitle;
      }
    }
    if (idx >= 0 && idx !== this.currentIndex) {
      this.currentIndex = idx;
      this.applyPollersForTab(idx);
      // Web-driven tab change (redirect, login wall lifting) must re-read the
      // newly visible native list at once, not on the next timer tick.
      this.refreshVisibleSurface();
    }
    const handle: string = profileHandleForUrl(url);
    if (handle !== '' && handle !== this.viewingHandle) {
      this.viewingHandle = handle;
      if (this.currentIndex === 4) {
        this.refreshProfile(handle);
      }
    } else if (handle === '' && this.viewingHandle !== '' && idx !== 4) {
      this.viewingHandle = '';
    } else {
      this.viewingHandle = handle !== '' ? handle : this.viewingHandle;
    }
    this.currentPath = pathOf(url);
    this.currentUrl = url;
  }

  // One poller per visible surface. Only the on-screen surface polls, so five
  // native lists stay live without five timers always running.
  private applyPollersForTab(index: number): void {
    if (index === 0) {
      this.startHomePolling();
    } else {
      this.stopHomePolling();
    }
    if (index === 1) {
      this.startTrendsPolling();
    } else {
      this.stopTrendsPolling();
    }
    if (index === 2) {
      this.startNotifListPolling();
    } else {
      this.stopNotifListPolling();
    }
    if (index === 3) {
      this.startDmPolling();
    } else {
      this.stopDmPolling();
      this.stopThreadPolling();
    }
    if (index === 4) {
      const handle: string = this.viewingHandle !== '' ? this.viewingHandle : this.ownHandle;
      if (handle !== '') {
        this.refreshProfile(handle);
      } else {
        this.profileFor = '';
        this.profileNext = '';
        this.profileJson = '{"state":"signed-out"}';
      }
    }
  }

  private refreshVisibleSurface(): void {
    if (this.currentIndex === 0) {
      this.refreshHome();
    } else if (this.currentIndex === 1) {
      this.refreshTrends();
      if (this.searchText.trim() !== '') {
        this.runSearch(this.searchText.trim());
      }
    } else if (this.currentIndex === 2) {
      this.refreshNotifList();
    } else if (this.currentIndex === 3) {
      this.refreshDms();
      if (this.threadId !== '' && this.chatOpen) {
        this.refreshThread(this.threadId);
      }
    } else if (this.currentIndex === 4) {
      const handle: string = this.viewingHandle !== '' ? this.viewingHandle : this.ownHandle;
      if (handle !== '') {
        this.refreshProfile(handle);
      }
    }
  }

  private goRoute(index: number): void {
    if (this.webDetailOpen) {
      this.webDetailOpen = false;
      this.webDetailTitle = '';
      this.webDetailReturnIndex = 0;
      if (index === this.currentIndex) {
        if (index === 4) {
          this.openOwnProfile();
          return;
        }
        this.loadWeb(TWITTER_ROUTES[index]);
        this.refreshVisibleSurface();
        return;
      }
    }
    // Leaving the login view by navigation closes it; the session underneath
    // stays exactly where the flow left it.
    this.webLoginOpen = false;
    if (index === 4) {
      this.openOwnProfile();
      return;
    }
    if (this.currentIndex === 3 && index !== 3) {
      this.chatOpen = false;
      this.chatTitle = '';
      this.threadId = '';
      this.threadJson = '';
      this.stopThreadPolling();
    }
    if (index === this.currentIndex) {
      if (index === 3 && this.chatOpen) {
        this.chatOpen = false;
        this.chatTitle = '';
        this.threadId = '';
        this.threadJson = '';
        this.stopThreadPolling();
        return;
      }
      // Tapping the active tab re-reads its native list, like the stock app.
      this.refreshVisibleSurface();
      return;
    }
    this.tick();
    this.currentIndex = index;
    this.viewingHandle = '';
    this.applyPollersForTab(index);
    this.refreshVisibleSurface();
    this.loadWeb(TWITTER_ROUTES[index]);
  }

  // Native Home switcher drives the native timeline first and the hidden page
  // second (the page keeps session/unread state). The underline moves at once;
  // the list re-reads from the top.
  private selectHomeTab(index: number): void {
    if (index === this.homeTabIndex) {
      this.refreshHome();
      return;
    }
    try {
      this.controller.runJavaScript(selectHomeTabScript(index));
    } catch (err) {
    }
    this.tick();
    this.homeTabIndex = index;
    this.homeNext = '';
    this.homeJson = '';
    this.refreshHome();
    this.schedulePageStateRead();
  }

  private openOwnProfile(): void {
    this.currentIndex = 4;
    this.hasError = false;
    this.webLoginOpen = false;
    this.applyPollersForTab(4);
    if (this.ownHandle !== '') {
      this.viewingHandle = this.ownHandle;
      this.refreshProfile(this.ownHandle);
      this.loadWeb(profileUrl(this.ownHandle));
      return;
    }
    this.progress = 0;
    this.discoverOwnProfile(true);
  }

  private titleMain(): string {
    if (this.webDetailOpen) {
      return this.webDetailTitle;
    }
    if (this.currentIndex === 3 && this.chatOpen) {
      return this.chatTitle;
    }
    if (this.webLoginOpen) {
      return this.localized($r('app.string.signin_button'));
    }
    // Every visible surface is native ArkUI; the WebView underneath stays on
    // whatever session URL it needs (often a login flow when signed out), so
    // the web title and path must never leak into the native header. Tab roots
    // show the tab label; only a profile shows a handle.
    if (this.currentIndex === 0 || this.currentIndex === 1 || this.currentIndex === 2 ||
      this.currentIndex === 3) {
      return '';
    }
    if (this.viewingHandle !== '') {
      // The stock app titles a profile with the display name and puts the
      // handle underneath. x.com titles the page "Abhi (@Abhi_Flex) / X".
      const name: string = MainTabs.nameInTitle(this.pageTitle);
      if (name !== '') {
        return name;
      }
      return '@' + this.profileHandle();
    }
    if (isTabRootPath(this.currentPath)) {
      return '';
    }
    return this.pageTitle;
  }

  // Handle spelled the way the page spells it, falling back to the one in the
  // URL (which x.com lowercases).
  private profileHandle(): string {
    const fromTitle: string = MainTabs.handleInTitle(this.pageTitle);
    return fromTitle !== '' ? fromTitle : this.viewingHandle;
  }

  private static nameInTitle(title: string): string {
    const at: number = title.indexOf(' (@');
    if (at > 0) {
      return title.substring(0, at);
    }
    return '';
  }

  private static handleInTitle(title: string): string {
    const at: number = title.indexOf('@');
    if (at < 0) {
      return '';
    }
    let out: string = '';
    for (let i: number = at + 1; i < title.length && out.length < 15; i++) {
      const ch: string = title.charAt(i);
      const ok: boolean = (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
        (ch >= '0' && ch <= '9') || ch === '_';
      if (!ok) {
        break;
      }
      out += ch;
    }
    return out;
  }

  private localized(key: Resource): string {
    try {
      const ctx: common.Context | undefined = this.getUIContext().getHostContext();
      if (ctx !== undefined) {
        return ctx.resourceManager.getStringSync(key.id);
      }
    } catch (err) {
    }
    return '';
  }

  // Second line of the header: a profile shows its handle, a post shows what
  // kind of page it is. Tab roots and everything else show nothing — no URLs.
  private subtitleMain(): string {
    if (this.webDetailOpen) {
      return '';
    }
    if (this.currentIndex === 3 && this.chatOpen) {
      return '';
    }
    if (this.currentIndex === 3) {
      return '';
    }
    if (this.viewingHandle !== '') {
      return '@' + this.profileHandle();
    }
    if (isTabRootPath(this.currentPath)) {
      return '';
    }
    const handle: string = profileHandleForUrl(this.currentUrl);
    if (handle !== '') {
      return '@' + handle;
    }
    if (this.currentPath.indexOf('/status/') >= 0) {
      return this.localized($r('app.string.post'));
    }
    return '';
  }

  private reloadCurrent(): void {
    this.progress = 0;
    this.refreshing = true;
    try {
      this.controller.refresh();
    } catch (err) {
      this.loadWeb(TWITTER_ROUTES[this.currentIndex]);
    }
  }

  // How far down the page the page's own header can sit. A phone keeps its
  // header in the top strip; a wide layout pushes it well below the fold.
  private chromeBand(): number {
    return this.isWide ? 300 : 140;
  }

  private applyPageChrome(url: string): void {
    const root: boolean = isTabRootPath(pathOf(url));
    try {
      this.controller.runJavaScript(chromeScript(this.ownHandle, root, this.chromeBand()));
    } catch (err) {
    }
    // The inset has to be re-stated after every navigation: a fresh document has
    // no style element, so the page would otherwise start under the title bar.
    this.applyImmersiveInset();
  }

  private updateChromeFlag(url: string): void {
    try {
      this.controller.runJavaScript(chromeFlagScript(isTabRootPath(pathOf(url)), this.chromeBand()));
    } catch (err) {
    }
  }

  // Unread counters, straight off the page's own navigation entries. The page
  // is the only thing that knows the account's counts, and it already publishes
  // them for its own (hidden) tab row — see UNREAD_COUNTS_SCRIPT.
  //
  // A negative count means the page has not told us yet (still loading, or its
  // navigation has not hydrated), so the previous value stands and the read is
  // retried. Moving between tabs used to wipe the badges because a mid-reload
  // read came back empty and was taken at face value.
  private refreshBadges(): void {
    try {
      this.controller.runJavaScript(UNREAD_COUNTS_SCRIPT).then((raw: string) => {
        this.applyBadgeCounts(MainTabs.unquote(raw));
      }, (err: BusinessError) => {
        hilog.debug(DOMAIN, TAG, 'badge read failed: %{public}d %{public}s', err.code, err.message);
        this.retryBadgeRead();
      });
    } catch (err) {
      this.retryBadgeRead();
    }
  }

  private applyBadgeCounts(counts: string): void {
    const cut: number = counts.indexOf('/');
    if (cut <= 0) {
      this.retryBadgeRead();
      return;
    }
    const notifications: number = Number.parseInt(counts.substring(0, cut), 10);
    const messages: number = Number.parseInt(counts.substring(cut + 1), 10);
    if (Number.isNaN(notifications) || Number.isNaN(messages)) {
      this.retryBadgeRead();
      return;
    }
    if (notifications >= 0) {
      this.unreadNotifications = notifications;
    }
    if (messages >= 0) {
      this.unreadMessages = messages;
    }
    if (notifications < 0 || messages < 0) {
      this.retryBadgeRead();
    } else {
      this.badgeRetries = 0;
    }
    this.syncLauncherBadge();
  }

  // Ask again shortly — bounded, and only while the page still owes an answer.
  private retryBadgeRead(): void {
    if (this.badgeRetryTimer !== -1 || this.badgeRetries >= BADGE_RETRY_LIMIT) {
      return;
    }
    this.badgeRetries++;
    this.badgeRetryTimer = setTimeout(() => {
      this.badgeRetryTimer = -1;
      this.refreshBadges();
    }, BADGE_RETRY_MS);
  }

  // Keep the launcher icon's own badge in step with what the tab bar shows, so
  // the count is visible without opening the app (HarmonyOS draws the badge on
  // the desktop icon or the folder the icon sits in).
  private syncLauncherBadge(): void {
    const total: number = this.unreadNotifications + this.unreadMessages;
    if (total === this.badgeShown) {
      return;
    }
    if (total > 0 && !this.notificationsAllowed()) {
      // HarmonyOS treats the app-icon badge as a notification surface — its own
      // permission dialog lists "角标 / badge" among the reminder modes — so
      // nothing lands on the icon until the account allows notifications.
      this.askForNotificationsOnce();
      return;
    }
    this.badgeShown = total;
    hilog.info(DOMAIN, TAG, 'launcher badge -> %{public}d', total);
    try {
      notificationManager.setBadgeNumber(total)
        .then(() => {
          hilog.info(DOMAIN, TAG, 'launcher badge accepted: %{public}d', total);
        })
        .catch((err: BusinessError) => {
          hilog.warn(DOMAIN, TAG, 'launcher badge rejected: %{public}d %{public}s', err.code, err.message);
        });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'launcher badge unavailable: %{public}s', JSON.stringify(err));
    }
  }

  private notificationsAllowed(): boolean {
    try {
      return notificationManager.isNotificationEnabledSync();
    } catch (err) {
      return false;
    }
  }

  // Asked once, in context — when there is finally something to badge — and
  // never again after a decline. The tab bar badges do not depend on it, so
  // saying no only costs the launcher icon.
  private askForNotificationsOnce(): void {
    if (this.notificationAsked) {
      return;
    }
    this.notificationAsked = true;
    this.saveNotificationAsked();
    this.retryLauncherBadgeWhenAllowed(0);
    const host: common.Context | undefined = this.getUIContext().getHostContext();
    if (host === undefined) {
      return;
    }
    try {
      notificationManager.requestEnableNotification(host as common.UIAbilityContext)
        .then(() => {
          hilog.info(DOMAIN, TAG, '%{public}s', 'notifications allowed for the icon badge');
          this.badgeShown = -1;
          this.syncLauncherBadge();
        })
        .catch((err: BusinessError) => {
          hilog.info(DOMAIN, TAG, 'notifications declined (%{public}d): icon badge stays off', err.code);
        });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'notification request failed: %{public}s', JSON.stringify(err));
    }
  }

  // The Messages tab is the account's real inbox. The page already holds the live
  // connection to x.com and repaints itself from it, so reading the page on a
  // tick is what keeps the native list in step with the account — including a
  // message that arrives while the app is open. Polling runs only while the tab
  // is on screen, so it costs nothing on the other four.
  private startDmPolling(): void {
    if (this.dmTimer !== -1) {
      return;
    }
    this.refreshDms();
    this.dmTimer = setInterval(() => {
      this.refreshDms();
    }, DM_POLL_MS);
  }

  private stopDmPolling(): void {
    if (this.dmTimer === -1) {
      return;
    }
    clearInterval(this.dmTimer);
    this.dmTimer = -1;
  }

  private refreshDms(): void {
    if (!this.signedIn()) {
      // No account yet: say so plainly instead of showing anything at all.
      this.dmJson = '{"state":"signed-out"}';
      return;
    }
    this.runBridge('dm', dmInboxScript(), '');
  }

  // --- Home timeline: real posts, paging, live while on screen ---------------

  private startHomePolling(): void {
    if (this.homeTimer !== -1) {
      return;
    }
    this.refreshHome();
    this.homeTimer = setInterval(() => {
      this.refreshHome();
    }, HOME_POLL_MS);
  }

  private stopHomePolling(): void {
    if (this.homeTimer === -1) {
      return;
    }
    clearInterval(this.homeTimer);
    this.homeTimer = -1;
  }

  private refreshHome(): void {
    if (!this.signedIn()) {
      this.homeJson = '{"state":"signed-out"}';
      return;
    }
    this.runBridge('home', homeTimelineScript(''), '');
  }

  private loadMoreHome(): void {
    if (!this.signedIn() || this.homeNext === '') {
      return;
    }
    this.runBridge('homeMore', homeTimelineScript(this.homeNext), '');
  }

  // --- Notifications list ----------------------------------------------------

  private startNotifListPolling(): void {
    if (this.notifListTimer !== -1) {
      return;
    }
    this.refreshNotifList();
    this.notifListTimer = setInterval(() => {
      this.refreshNotifList();
    }, NOTIF_LIST_POLL_MS);
  }

  private stopNotifListPolling(): void {
    if (this.notifListTimer === -1) {
      return;
    }
    clearInterval(this.notifListTimer);
    this.notifListTimer = -1;
  }

  private refreshNotifList(): void {
    if (!this.signedIn()) {
      this.notifListJson = '{"state":"signed-out"}';
      return;
    }
    this.runBridge('notif', notificationsScript(), '');
  }

  // --- Profile ---------------------------------------------------------------

  // The profile is scraped off the rendered profile page, so the page must
  // actually BE the profile. Opening Profile from a signed-out state lands on
  // /settings/profile, which has no profile DOM at all (verified: no UserName,
  // no articles) and would spin forever — so point the WebView at /<handle>
  // first and scrape once that has rendered.
  private ensureProfilePage(handle: string): void {
    const clean: string = handle.charAt(0) === '@' ? handle.substring(1) : handle;
    const path: string = pathOf(this.currentUrl);
    if (path === '/' + clean.toLowerCase()) {
      return;
    }
    this.loadWeb(profileUrl(clean));
  }

  private refreshProfile(handle: string): void {
    const clean: string = handle.charAt(0) === '@' ? handle.substring(1) : handle;
    if (clean === '') {
      this.profileFor = '';
      this.profileNext = '';
      this.profileJson = '{"state":"signed-out"}';
      return;
    }
    if (this.profileFor !== clean.toLowerCase()) {
      this.resetProfileSettle();
      this.profileFor = clean.toLowerCase();
      this.profileNext = '';
      this.profileJson = '';
      this.profileLoadAttempts = 0;
    }
    if (!this.signedIn()) {
      this.profileJson = '{"state":"signed-out"}';
      return;
    }
    // The profile is scraped off the rendered page the shell loads underneath,
    // which needs a moment after navigation. A `loading` answer is handled
    // where results land, so the read itself stays a single call.
    const attemptKey: string = clean.toLowerCase();
    this.ensureProfilePage(clean);
    this.runBridge('profile', profileScript(clean, ''), attemptKey);
  }

  private loadMoreProfile(): void {
    const handle: string = this.viewingHandle !== '' ? this.viewingHandle : this.ownHandle;
    if (!this.signedIn() || handle === '' || this.profileNext === '') {
      return;
    }
    this.runBridge('profileMore', profileScript(handle, this.profileNext),
      handle.toLowerCase());
  }

  // --- Explore: trends + search ----------------------------------------------

  private startTrendsPolling(): void {
    if (this.trendsTimer !== -1) {
      return;
    }
    this.refreshTrends();
    this.trendsTimer = setInterval(() => {
      this.refreshTrends();
    }, TRENDS_POLL_MS);
  }

  private stopTrendsPolling(): void {
    if (this.trendsTimer === -1) {
      return;
    }
    clearInterval(this.trendsTimer);
    this.trendsTimer = -1;
  }

  private refreshTrends(): void {
    if (!this.signedIn()) {
      this.trendsJson = '{"state":"signed-out"}';
      return;
    }
    this.runBridge('trends', trendsScript(), '');
  }

  private runSearch(query: string): void {
    const q: string = query.trim();
    if (q === '') {
      this.searchJson = '';
      this.searchNext = '';
      return;
    }
    this.searchPending = q;
    this.searchJson = '';
    if (!this.signedIn()) {
      this.searchJson = '{"state":"signed-out"}';
      return;
    }
    this.runBridge('search', searchTweetsScript(q, ''), q);
  }

  // --- Thread history + real sending ------------------------------------------

  private startThreadPolling(id: string): void {
    this.stopThreadPolling();
    this.threadId = id;
    this.refreshThread(id);
    this.threadTimer = setInterval(() => {
      if (this.threadId !== '') {
        this.refreshThread(this.threadId);
      }
    }, THREAD_POLL_MS);
  }

  private stopThreadPolling(): void {
    if (this.threadTimer !== -1) {
      clearInterval(this.threadTimer);
      this.threadTimer = -1;
    }
  }

  private refreshThread(id: string): void {
    if (!this.signedIn() || id === '') {
      return;
    }
    this.pendingThreadId = id;
    this.runBridge('thread', dmThreadScript(id), id);
  }

  private sendDm(conversationId: string, recipientId: string, text: string,
    messageId: string): void {
    if (!this.signedIn() || text.trim() === '' || conversationId === '') {
      this.sendStateJson = JSON.stringify({ state: 'error', messageId: messageId });
      this.toast($r('app.string.messages_send_unavailable'));
      return;
    }
    this.pendingSendConversations.set(messageId, conversationId);
    this.sendStateJson = JSON.stringify({ state: 'sending', messageId: messageId });
    this.runBridge('sendDm', dmSendScript(recipientId, text, conversationId), messageId);
  }

  private muteDm(conversationId: string, muted: boolean): void {
    if (!this.signedIn() || conversationId === '') {
      this.toast($r('app.string.messages_mute_unavailable'));
      return;
    }
    this.runBridge('dmMute', dmMuteScript(conversationId, muted), conversationId);
  }

  // --- Post actions: the real write behind an optimistic row ------------------

  private runPostAction(kind: string, id: string): void {
    if (!this.signedIn() || id === '') {
      return;
    }
    if (kind === 'reply') {
      this.openCompose();
      return;
    }
    if (this.pendingPostAction !== null) {
      return;
    }
    const returnUrl: string = this.currentUrl !== '' ? this.currentUrl :
      TWITTER_ROUTES[this.currentIndex];
    this.pendingPostAction = {
      kind: kind,
      id: id,
      returnUrl: returnUrl,
      staged: false,
      attempts: 0
    };
    this.runBridge('postAction', postActionScript(kind, id), id);
  }

  private stagePostAction(): void {
    const action: PendingPostAction | null = this.pendingPostAction;
    if (action === null) {
      return;
    }
    if (!action.staged) {
      action.staged = true;
      this.loadWeb(TWITTER_BASE + '/i/web/status/' + encodeURIComponent(action.id));
      return;
    }
    if (action.attempts >= 5) {
      this.finishPostAction(false);
      return;
    }
    this.scheduleStagedPostAction();
  }

  private scheduleStagedPostAction(): void {
    const action: PendingPostAction | null = this.pendingPostAction;
    if (action === null || !action.staged) {
      return;
    }
    if (this.postActionStageTimer !== -1) {
      clearTimeout(this.postActionStageTimer);
    }
    this.postActionStageTimer = setTimeout(() => {
      this.postActionStageTimer = -1;
      const current: PendingPostAction | null = this.pendingPostAction;
      if (current === null || !current.staged) {
        return;
      }
      current.attempts++;
      this.runBridge('postAction', postActionScript(current.kind, current.id, true), current.id);
    }, 1200);
  }

  private finishPostAction(success: boolean): void {
    const action: PendingPostAction | null = this.pendingPostAction;
    this.pendingPostAction = null;
    if (this.postActionStageTimer !== -1) {
      clearTimeout(this.postActionStageTimer);
      this.postActionStageTimer = -1;
    }
    if (action !== null && action.staged && action.returnUrl !== '') {
      this.loadWeb(action.returnUrl);
    }
    if (success) {
      this.tick();
      this.refreshVisibleSurface();
    } else {
      this.toast($r('app.string.post_action_failed'));
    }
  }

  private async savePostImage(url: string, id: string): Promise<string> {
    if (this.mediaSaveBusy || this.mediaSaveDownloading || this.mediaSaveSheet ||
      this.mediaSavePath !== '') {
      hilog.info(DOMAIN, TAG, 'media save already open; ignoring duplicate request');
      return MEDIA_SAVE_CANCELLED;
    }
    hilog.info(DOMAIN, TAG, 'media save start: %{public}s', id);
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      hilog.warn(DOMAIN, TAG, 'media save unavailable: %{public}s', id);
      this.toast($r('app.string.post_media_save_failed'));
      return MEDIA_SAVE_FAILED;
    }
    this.mediaSaveDownloading = true;
    this.toast($r('app.string.post_media_downloading'));
    let sourcePath: string = '';
    try {
      sourcePath = await prepareRemoteImage(ctx as common.UIAbilityContext, url, id);
    } finally {
      this.mediaSaveDownloading = false;
    }
    if (sourcePath === '') {
      this.toast($r('app.string.post_media_save_failed'));
      return MEDIA_SAVE_FAILED;
    }
    this.mediaSavePath = sourcePath;
    this.mediaSaveId = id;
    this.mediaSaveReady = true;
    this.mediaSaveSheet = true;
    return MEDIA_SAVE_CANCELLED;
  }

  private async commitPreparedImage(): Promise<void> {
    if (this.mediaSaveBusy || this.mediaSavePath === '') {
      return;
    }
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      await discardPreparedImage(this.mediaSavePath);
      this.clearMediaSaveState();
      this.toast($r('app.string.post_media_save_failed'));
      return;
    }
    this.mediaSaveBusy = true;
    const result: string = await savePreparedImage(
      ctx as common.UIAbilityContext, this.mediaSavePath, this.mediaSaveId);
    this.mediaSaveBusy = false;
    this.clearMediaSaveState();
    if (result === MEDIA_SAVE_OK) {
      this.toast($r('app.string.post_media_saved'));
    } else {
      this.toast($r('app.string.post_media_save_failed'));
    }
  }

  private async cancelPreparedImage(): Promise<void> {
    await discardPreparedImage(this.mediaSavePath);
    this.clearMediaSaveState();
  }

  private clearMediaSaveState(): void {
    this.mediaSaveSheet = false;
    this.mediaSavePath = '';
    this.mediaSaveId = '';
    this.mediaSaveBusy = false;
    this.mediaSaveReady = false;
  }

  private static nextCursor(json: string): string {
    try {
      const payload = JSON.parse(json) as TimelineBridgePayload;
      if (payload && payload.next) {
        return payload.next;
      }
      return '';
    } catch (err) {
      return '';
    }
  }

  // Paged reads return only the new slice; the shell merges it onto what the
  // surface already shows, de-duplicated by id, so scrolling never loses rows.
  private static mergeTimeline(oldJson: string, newJson: string): string {
    try {
      const oldP = JSON.parse(oldJson) as TimelineBridgePayload;
      const newP = JSON.parse(newJson) as TimelineBridgePayload;
      if (!oldP || oldP.state !== 'ok') {
        return newJson;
      }
      if (!newP || newP.state !== 'ok' || !newP.posts) {
        return oldJson;
      }
      const seen: Record<string, boolean> = {};
      const merged: TimelineBridgePost[] = [];
      const oldPosts: TimelineBridgePost[] = oldP.posts ?? [];
      const newPosts: TimelineBridgePost[] = newP.posts ?? [];
      for (let i: number = 0; i < oldPosts.length; i++) {
        if (!seen[oldPosts[i].id]) {
          seen[oldPosts[i].id] = true;
          merged.push(oldPosts[i]);
        }
      }
      for (let j: number = 0; j < newPosts.length; j++) {
        if (!seen[newPosts[j].id]) {
          seen[newPosts[j].id] = true;
          merged.push(newPosts[j]);
        }
      }
      // A paged `max_id` read repeats the cursor row; drop it once.
      const result: TimelineBridgePayload = { state: 'ok', posts: merged, next: newP.next ?? '' };
      return JSON.stringify(result);
    } catch (err) {
      return oldJson !== '' ? oldJson : newJson;
    }
  }

  // Profile paging keeps the header: the merged payload carries the old user
  // with the combined post list, so the header never drops out while paging.
  // When a scroll-and-rescrape round adds no new ids the list is complete and
  // the cursor clears, which releases the component's loading row.
  private static mergeProfile(oldJson: string, newJson: string): string {
    try {
      const oldP = JSON.parse(oldJson) as ProfileBridgePayload;
      const newP = JSON.parse(newJson) as ProfileBridgePayload;
      if (!oldP || oldP.state !== 'ok') {
        return newJson;
      }
      if (!newP || newP.state !== 'ok') {
        return oldJson;
      }
      const mergedPostsJson: string = MainTabs.mergeTimeline(oldJson, newJson);
      const merged = JSON.parse(mergedPostsJson) as TimelineBridgePayload;
      const oldCount: number = (oldP.posts ?? []).length;
      const mergedCount: number = (merged.posts ?? []).length;
      const result: ProfileBridgePayload = {
        state: 'ok',
        user: oldP.user ?? newP.user,
        posts: merged.posts ?? [],
        next: mergedCount > oldCount ? (newP.next ?? '') : ''
      };
      return JSON.stringify(result);
    } catch (err) {
      return oldJson !== '' ? oldJson : newJson;
    }
  }

  // A conversation whose newest inbound message is newer than the one already
  // reported gets one notification. The first read of a session only sets the
  // baseline, so opening the app never empties a backlog onto the user.
  private reportNewDms(json: string): void {
    let payload: DmBridgePayload | undefined = undefined;
    try {
      payload = JSON.parse(json) as DmBridgePayload;
    } catch (err) {
      return;
    }
    if (payload === undefined || payload.state !== 'ok' || payload.conversations === undefined) {
      return;
    }
    const list: DmBridgeConversation[] = payload.conversations;
    const baseline: boolean = this.dmFirstRead;
    this.dmFirstRead = false;
    if (baseline || !this.notificationsAllowed()) {
      if (baseline && !this.notificationsAllowed() && list.length > 0) {
        // There is something to notify about, which is the moment to ask.
        this.askForNotificationsOnce();
      }
      for (let i: number = 0; i < list.length; i++) {
        this.dmSeen.set(list[i].id, list[i].at);
      }
      return;
    }
    for (let i: number = 0; i < list.length; i++) {
      const item: DmBridgeConversation = list[i];
      if (item.out) {
        continue;
      }
      const seen: number | undefined = this.dmSeen.get(item.id);
      if (seen !== undefined && item.at <= seen) {
        continue;
      }
      this.dmSeen.set(item.id, item.at);
      this.publishDmNotification(item);
    }
  }

  // One notification per new inbound message. The agent brings the app back to
  // the front rather than to whatever page happened to be open.
  private publishDmNotification(item: DmBridgeConversation): void {
    const title: string = item.name !== '' ? item.name : item.handle;
    const body: string = item.text !== '' ? item.text : 'New message';
    hilog.info(DOMAIN, TAG, 'dm notification: %{public}s', title);
    const info: wantAgent.WantAgentInfo = {
      wants: [{
        bundleName: BUNDLE_NAME,
        abilityName: 'EntryAbility'
      }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    wantAgent.getWantAgent(info).then((agent: object) => {
      return notificationManager.publish({
        id: 1,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: body,
            additionalText: 'OpenTwit'
          }
        },
        wantAgent: agent
      });
    }).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'dm notification failed: %{public}d %{public}s', err.code, err.message);
    });
  }

  // The user may allow notifications in Settings instead of in our dialog. Keep
  // checking for a while so the icon picks the count up without a relaunch.
  private retryLauncherBadgeWhenAllowed(attempt: number): void {
    if (attempt >= NOTIFICATION_POLL_LIMIT) {
      return;
    }
    setTimeout(() => {
      if (this.notificationsAllowed()) {
        this.badgeShown = -1;
        this.syncLauncherBadge();
        return;
      }
      this.retryLauncherBadgeWhenAllowed(attempt + 1);
    }, NOTIFICATION_POLL_MS);
  }

  private armBadgeRefresh(): void {
    if (this.badgeTimer !== -1) {
      clearInterval(this.badgeTimer);
    }
    this.badgeTimer = setInterval(() => {
      this.badgeRetries = 0;
      this.refreshBadges();
      if (!this.signedIn()) {
        // Backstop for a login the navigations missed: keep asking the page
        // who it is until it answers with an account. One cheap read per tick.
        this.readSessionIdentity();
        this.discoverOwnProfile(false);
      }
    }, BADGE_REFRESH_MS);
  }

  // Badge for a tab bar item: the count lives on Notifications and Messages,
  // and clears while that tab is the one on screen — the same thing the stock
  // app does when you open the tab and read it.
  private badgeCount(index: number): number {
    if (index === this.currentIndex) {
      return 0;
    }
    if (index === 2) {
      return this.unreadNotifications;
    }
    if (index === 3) {
      return this.unreadMessages;
    }
    return 0;
  }

  private static stripSiteSuffix(raw: string): string {
    let title: string = MainTabs.unquote(raw);
    const suffix: string = ' / X';
    if (title.length > suffix.length &&
      title.substring(title.length - suffix.length) === suffix) {
      title = title.substring(0, title.length - suffix.length);
    }
    // A post is titled "<author> on X: \"<text>\"" — the header should name the
    // author, not quote the whole post back at the user.
    const marker: string = ' on X: ';
    const at: number = title.indexOf(marker);
    if (at > 0) {
      title = title.substring(0, at);
    }
    return title;
  }

  // x.com's own header is removed on every page, so the shell takes the page
  // name from the document title instead (e.g. "Abhi (@Abhi_Flex) / X").
  private readPageState(): void {
    try {
      this.controller.runJavaScript('document.title').then((raw: string) => {
        const title: string = MainTabs.unquote(raw);
        this.pageTitle = MainTabs.stripSiteSuffix(title);
      });
    } catch (err) {
    }
    this.readHomeTab();
    this.readAvatar();
    try {
      this.canGoBack = this.controller.accessBackward();
    } catch (err) {
      this.canGoBack = false;
    }
  }

  // Keep the native Home switcher in step with whatever the page selected last
  // (the row is hidden, so this is the only place the state can come from).
  private readHomeTab(): void {
    try {
      this.controller.runJavaScript(HOME_TAB_SCRIPT).then((raw: string) => {
        const index: number = Number.parseInt(MainTabs.unquote(raw), 10);
        if (!Number.isNaN(index) && index >= 0) {
          this.homeTabIndex = index;
        }
      });
    } catch (err) {
    }
  }

  // Only the account's own profile page carries the signed-in avatar, and it is
  // worth a native fetch: the shell shows it in the Home header.
  private readAvatar(): void {
    if (this.ownHandle === '' || this.avatarUrl !== '') {
      return;
    }
    const handle: string = this.ownHandle.toLowerCase();
    if (this.currentPath !== '/' + handle) {
      return;
    }
    try {
      this.controller.runJavaScript(AVATAR_SCRIPT).then((raw: string) => {
        const url: string = MainTabs.unquote(raw);
        if (url.indexOf('http') === 0) {
          this.avatarUrl = url;
          this.saveAvatar(url);
        }
      });
    } catch (err) {
    }
  }

  private schedulePageStateRead(): void {
    setTimeout(() => {
      this.readPageState();
      this.refreshBadges();
    }, PAGE_STATE_DELAY_MS);
  }


  private goBack(): void {
    if (this.currentIndex === 3 && this.chatOpen) {
      this.chatOpen = false;
      this.chatTitle = '';
      this.threadId = '';
      this.threadJson = '';
      this.stopThreadPolling();
      return;
    }
    if (this.webLoginOpen) {
      this.webLoginOpen = false;
      return;
    }
    if (this.webDetailOpen) {
      this.closeWebDetail();
      return;
    }
    if (this.currentIndex !== 0) {
      this.goRoute(0);
    }
  }

  // Never auto-grant: the user decides, and only then do we ask the system for
  // ohos.permission.LOCATION and answer the web page with a real result.
  private askLocation(origin: string, geolocation: JsGeolocation): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.location_dialog_title'),
      message: $r('app.string.location_dialog_message'),
      primaryButton: {
        value: $r('app.string.deny'),
        action: () => {
          this.answerLocation(origin, geolocation, false);
        }
      },
      secondaryButton: {
        value: $r('app.string.allow'),
        action: () => {
          const ctx: common.Context | undefined = this.getUIContext().getHostContext();
          if (ctx === undefined) {
            this.answerLocation(origin, geolocation, false);
            return;
          }
          abilityAccessCtrl.createAtManager()
            .requestPermissionsFromUser(ctx, LOCATION_PERMISSIONS)
            .then((result: PermissionRequestResult) => {
              const granted: boolean = result.authResults.length > 0 && result.authResults[0] === 0;
              this.answerLocation(origin, geolocation, granted);
            })
            .catch((err: Error) => {
              hilog.warn(DOMAIN, TAG, 'location permission denied: %{public}s', err.message);
              this.answerLocation(origin, geolocation, false);
            });
        }
      }
    });
  }

  private answerLocation(origin: string, geolocation: JsGeolocation, allowed: boolean): void {
    try {
      geolocation.invoke(origin, allowed, false);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'geolocation invoke failed: %{public}s', JSON.stringify(err));
    }
  }

  // x.com's composer and profile editor ask for files through the WebView file
  // selector; wiring it to the system picker is what makes uploads work.
  private openFileSelector(event: OnShowFileSelectorEvent): void {
    try {
      const multiple: boolean =
        event.fileSelector.getMode() === FileSelectorMode.FileOpenMultipleMode;
      const options: photoAccessHelper.PhotoSelectOptions =
        new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_VIDEO_TYPE;
      options.maxSelectNumber = multiple ? 10 : 1;
      new photoAccessHelper.PhotoViewPicker().select(options)
        .then((result: photoAccessHelper.PhotoSelectResult) => {
          event.result.handleFileList(result.photoUris);
        })
        .catch((err: Error) => {
          hilog.warn(DOMAIN, TAG, 'file picker cancelled: %{public}s', err.message);
          event.result.handleFileList([]);
        });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'file selector failed: %{public}s', JSON.stringify(err));
      event.result.handleFileList([]);
    }
  }

  private openCompose(): void {
    // A fresh controller per sheet: the sheet's WebView is destroyed on close.
    this.composeController = new web_webview.WebviewController();
    // Whatever was typed last time is still here (see COMPOSE_DRAFT_KEY); the
    // composer opens with the draft in place instead of an empty box.
    this.webComposer = false;
    this.posting = false;
    this.sheetOpen = true;
  }

  // Drafts are saved as you type, so closing the sheet — or the app — cannot
  // lose what was written.
  private scheduleDraftSave(): void {
    if (this.draftSaveTimer !== -1) {
      clearTimeout(this.draftSaveTimer);
    }
    this.draftSaveTimer = setTimeout(() => {
      this.draftSaveTimer = -1;
      this.saveDraft();
    }, DRAFT_SAVE_DEBOUNCE_MS);
  }

  private saveDraft(): void {
    this.putPreference(COMPOSE_DRAFT_KEY, this.draft);
  }

  private saveNotificationAsked(): void {
    this.putPreference(NOTIFICATION_ASKED_KEY, true);
  }

  // Desktop keyboards: Escape leaves the composer and Ctrl/Cmd+Enter posts —
  // the two shortcuts every client of this kind has, and on a 2in1 they are
  // faster than reaching for the sheet's buttons. Returns true when the key is
  // consumed so it does not also reach the editor.
  private composeKey(event: KeyEvent): boolean {
    if (event.type !== KeyType.Down) {
      return false;
    }
    if (event.keyCode === KeyCode.KEYCODE_ESCAPE) {
      this.sheetOpen = false;
      return true;
    }
    if (event.keyCode !== KeyCode.KEYCODE_ENTER) {
      return false;
    }
    if (event.metaKey === 1 || MainTabs.ctrlDown(event)) {
      this.postFromSheet();
      return true;
    }
    return false;
  }

  private static ctrlDown(event: KeyEvent): boolean {
    try {
      // Optional on the type: it is absent on older devices and under a stylus.
      if (event.getModifierKeyState === undefined) {
        return false;
      }
      return event.getModifierKeyState(['Ctrl']);
    } catch (err) {
      return false;
    }
  }

  private async putPreference(key: string, value: preferences.ValueType): Promise<void> {
    try {
      const ctx: common.Context | undefined = this.getUIContext().getHostContext();
      if (ctx === undefined) {
        return;
      }
      const prefs: preferences.Preferences = await preferences.getPreferences(ctx, PREFS_NAME);
      await prefs.put(key, value);
      await prefs.flush();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'preference write failed: %{public}s', JSON.stringify(err));
    }
  }

  // Native "Post": type the draft into the page's own editor, then press the
  // page's own submit button. The whole composer is HarmonyOS UI — only the
  // submit goes through x.com, so the post is a real post.
  private postFromSheet(): void {
    const text: string = this.draft.trim();
    if (text === '' || this.posting) {
      return;
    }
    this.posting = true;
    let pending: Promise<string> | undefined = undefined;
    try {
      pending = this.composeController.runJavaScript(fillComposerScript(text));
    } catch (err) {
      pending = undefined;
    }
    if (pending === undefined) {
      this.posting = false;
      this.openWebComposer();
      return;
    }
    (pending as Promise<string>).then((filled: string) => {
      if (MainTabs.unquote(filled) !== 'ok') {
        // The page's composer is not ready: hand the draft to the web composer
        // rather than dropping it.
        return '';
      }
      return this.composeController.runJavaScript(CLICK_POST_BUTTON_SCRIPT) as Promise<string>;
    }).then((result: string) => {
      this.posting = false;
      if (MainTabs.unquote(result) === 'ok') {
        this.tick();
        this.toast($r('app.string.compose_post_sent'));
        this.sheetOpen = false;
        // The draft is now a post; clear what was saved for next time.
        this.draft = '';
        this.saveDraft();
      } else {
        // The text is already in the page's editor; showing it lets the user
        // finish there (media, polls, threads) without retyping.
        this.openWebComposer();
      }
    }).catch(() => {
      this.posting = false;
      this.openWebComposer();
    });
  }

  private openWebComposer(): void {
    this.posting = false;
    this.webComposer = true;
    if (this.draft.trim() !== '') {
      this.toast($r('app.string.compose_web_fallback'));
    }
  }

  // Back only exists where there is history to walk and the page is not one of
  // the five tab roots.
  // Back only exists on a pushed native screen (an open conversation or the
  // login flow). Tab roots are native lists; the hidden session WebView's
  // history is invisible and must never surface as a back arrow.
  private showBack(): boolean {
    return (this.currentIndex === 3 && this.chatOpen) || this.webLoginOpen || this.webDetailOpen;
  }

  // Every tab root is native, so there is no web-history back to offer. Only
  // an open conversation is a pushed screen.
  private isTabRoot(): boolean {
    if (this.currentIndex === 3 && this.chatOpen) {
      return false;
    }
    return true;
  }

  private isHomeRoot(): boolean {
    return !this.webDetailOpen && this.currentIndex === 0;
  }

  // The page is the live authority on the session: preferences can outlive it
  // (a handle persisted on disk while the cookie jar was lost to a reinstall or
  // expiry). Any bridge answer of `signed-out` while a handle is cached means
  // the session is dead, so the cached handle goes and every surface flips to
  // its signed-out panel at once instead of showing signed-in chrome over dead
  // reads. Verified shape on device: fresh 2in1 showed the timeline switcher
  // with no session until this reconciliation landed.
  private noteSignedOut(json: string): void {
    if (json.indexOf('"state":"signed-out"') < 0 || this.ownHandle === '') {
      return;
    }
    hilog.info(DOMAIN, TAG, 'session dead, clearing cached handle');
    this.ownHandle = '';
    this.avatarUrl = '';
    this.saveOwnHandle('');
    this.saveAvatar('');
    if (this.chatOpen) {
      this.chatOpen = false;
      this.chatTitle = '';
      this.threadId = '';
      this.threadJson = '';
      this.stopThreadPolling();
    }
    this.dmJson = '{"state":"signed-out"}';
    this.homeJson = '{"state":"signed-out"}';
    this.notifListJson = '{"state":"signed-out"}';
    this.trendsJson = '{"state":"signed-out"}';
    this.searchJson = this.searchText.trim() !== '' ? '{"state":"signed-out"}' : '';
    this.profileFor = '';
    this.profileNext = '';
    this.profileJson = '{"state":"signed-out"}';
    this.applyImmersiveInset();
  }

  // The page is the only authority on whether anyone is signed in: the account
  // handle is read off x.com's own account menu (see discoverOwnProfile). Until
  // it answers, the shell shows the signed-out chrome rather than offering a
  // composer or a timeline switcher that cannot work.
  private signedIn(): boolean {
    return this.ownHandle !== '';
  }

  // A conversation is a pushed screen, so on a phone the shell puts its own tab
  // bar away and lets the thread and composer own the window — the same thing
  // the stock app does. The wide layout keeps its rail: there the rail is
  // permanent navigation and does not compete with the composer for height.
  private immersiveConversation(): boolean {
    return !this.isWide && this.currentIndex === 3 && this.chatOpen;
  }

  // Explore owns the native search field. The visible tab is the authority, not
  // the hidden session URL (which is often a login flow when signed out).
  private isExploreSurface(): boolean {
    return !this.webDetailOpen && this.currentIndex === 1;
  }

  @Builder
  backButton() {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph($r('sys.symbol.arrow_left'))
        .fontSize(22)
        .fontColor([$r('sys.color.ohos_id_color_text_primary')])
    }
    .width(TOUCH_TARGET)
    .height(TOUCH_TARGET)
    .backgroundColor(Color.Transparent)
    .accessibilityText($r('app.string.back'))
    .accessibilityLevel('yes')
    .onClick(() => {
      this.goBack();
    })
  }

  // Account picture, as the stock app has it: top-left on Home, and the entry
  // point to the account's own pages. Until the profile page has been visited
  // once there is no picture to read, so the HarmonyOS account glyph stands in.
  @Builder
  accountAvatar() {
    Row() {
      if (this.avatarUrl !== '') {
        Image(this.avatarUrl)
          .width(32)
          .height(32)
          .borderRadius(16)
          .objectFit(ImageFit.Cover)
      } else {
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
          .fontSize(32)
          .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
      }
    }
    .width(TOUCH_TARGET)
    .height(TOUCH_TARGET)
    .justifyContent(FlexAlign.Center)
    // Pointer devices (2in1 / tablet with a mouse) get the hover the phone
    // never needed.
    .hoverEffect(HoverEffect.Highlight)
    .accessibilityText($r('app.string.menu_account'))
    .accessibilityLevel('yes')
    .bindMenu(this.accountMenu)
  }

  // The account pages the stock app keeps one level down from the avatar.
  @Builder
  accountMenu() {
    Menu() {
      if (this.ownHandle !== '') {
        MenuItem({
          content: $r('app.string.menu_view_profile'),
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.person_fill'))
        })
          .onClick(() => {
            this.openOwnProfile();
          })
        MenuItem({
          content: $r('app.string.menu_bookmarks'),
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.bookmark_fill'))
          })
          .onClick(() => {
            this.openWebDetail(TWITTER_BOOKMARKS);
          })
        MenuItem({
          content: $r('app.string.menu_lists'),
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.list_bullet_square_fill'))
          })
          .onClick(() => {
            this.openWebDetail(listsUrl(this.ownHandle));
          })
      } else {
        MenuItem({
          content: $r('app.string.menu_create_account'),
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.person_badge_plus'))
          })
          .onClick(() => {
            this.openWebDetail(TWITTER_SIGNUP);
          })
      }
      MenuItem({
        content: $r('app.string.menu_settings'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.gearshape'))
        })
        .onClick(() => {
          this.openWebDetail(TWITTER_SETTINGS);
        })
    }
    // Frosted rather than opaque: the menu floats over the page content and the
    // blur is what makes it read as a HarmonyOS surface instead of a card.
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
  }

  // "For you / Following", the one piece of the Home header the stock app draws
  // itself. The page's own copy of this row is hidden by the injected chrome, so
  // each tap drives the page's real tab instead of faking a timeline switch.
  @Builder
  homeTimelineTabs() {
    Row({ space: S4 }) {
      this.homeTimelineTab($r('app.string.home_for_you'), 0)
      this.homeTimelineTab($r('app.string.home_following'), 1)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  homeTimelineTab(label: Resource, index: number) {
    Column({ space: 0 }) {
      Text(label)
        .fontSize(15)
        .fontFamily(FONT_FAMILY)
        .fontWeight(this.homeTabIndex === index ? FontWeight.Bold : FontWeight.Regular)
        // A large system font must not push the switcher out of the title bar.
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor(this.homeTabIndex === index
          ? $r('sys.color.ohos_id_color_text_primary')
          : $r('sys.color.ohos_id_color_text_secondary'))
      Column()
        .width(44)
        .height(3)
        .margin({ top: 5 })
        .borderRadius(2)
        .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
        .opacity(this.homeTabIndex === index ? 1 : 0)
    }
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: S12, right: S12 })
    .hoverEffect(HoverEffect.Highlight)
    .accessibilityText(label)
    .accessibilityLevel('yes')
    .onClick(() => {
      this.selectHomeTab(index);
    })
  }

  @Builder
  headerSearch() {
    Row() {
      Search({ value: $$this.searchText, placeholder: $r('app.string.search_placeholder') })
        .width('100%')
        .height(38)
        .placeholderFont({ size: 15, family: FONT_FAMILY })
        .textFont({ size: 15, family: FONT_FAMILY })
        .onChange((value: string) => {
          this.searchText = value;
          if (value.trim() === '') {
            this.searchJson = '';
            this.searchNext = '';
          }
        })
        .onSubmit((value: string) => {
          this.searchText = value;
          if (this.currentIndex !== 1) {
            this.goRoute(1);
          }
          if (value.trim() !== '') {
            this.runSearch(value.trim());
          }
        })
    }
    .layoutWeight(1)
    .height('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ right: S8 })
  }

  @Builder
  headerTitles() {
    Column({ space: 0 }) {
      Text(this.headerTitle())
        .fontSize(20)
        .fontFamily(FONT_FAMILY)
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
      if (this.subtitleMain() !== '') {
        Text(this.subtitleMain())
          .fontSize(11)
          .fontFamily(FONT_FAMILY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
  }

  private headerTitle(): string {
    const title: string = this.titleMain();
    // "X" is x.com's own site name and what it titles unknown pages with, so it
    // is not a page name: fall back to the tab the user is on.
    if (title !== '' && title !== 'X') {
      return title;
    }
    return this.localized(this.tabLabel(this.currentIndex));
  }

  // One trailing action per tab, matching the stock app: notification settings
  // on Notifications, message settings on Messages, settings on your own
  // profile, nothing anywhere else.
  @Builder
  headerAction() {
    // Actions belong to a tab's own root screen. The hidden session URL is
    // irrelevant (often a login flow); the visible native tab decides. The
    // login view carries no actions besides Back.
    if (!this.webLoginOpen && !this.webDetailOpen) {
      if (this.currentIndex === 3 && this.chatOpen) {
      // Calls, video calls, and the overflow menu still belong to the web
      // client. Do not draw native controls that only show a toast; add them
      // here when their session-backed actions are implemented.
    } else if (this.currentIndex === 2) {
      this.headerIconButton($r('sys.symbol.gearshape'), $r('app.string.menu_notification_settings'),
        () => {
          this.openWebDetail(TWITTER_NOTIF_SETTINGS);
        })
    } else if (this.currentIndex === 3 && !this.chatOpen) {
      // x.com has no separate direct-message settings page any more (its
      // /settings/messages route is gone), so this opens the settings root the
      // stock app's gear leads to as well.
      this.headerIconButton($r('sys.symbol.gearshape'), $r('app.string.menu_settings'), () => {
        this.openWebDetail(TWITTER_SETTINGS);
      })
    } else if (this.currentIndex === 4 && this.isOwnProfile()) {
      this.headerIconButton($r('sys.symbol.gearshape'), $r('app.string.menu_settings'), () => {
        this.openWebDetail(TWITTER_SETTINGS);
      })
    }
    }
  }

  private isOwnProfile(): boolean {
    return this.ownHandle !== '' &&
      this.viewingHandle.toLowerCase() === this.ownHandle.toLowerCase();
  }

  @Builder
  headerIconButton(symbol: Resource, label: Resource, action: () => void) {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(symbol)
        .fontSize(22)
        .fontColor([$r('sys.color.ohos_id_color_text_primary')])
    }
    .width(TOUCH_TARGET)
    .height(TOUCH_TARGET)
    .backgroundColor(Color.Transparent)
    .accessibilityText(label)
    .accessibilityLevel('yes')
    .onClick(action)
  }

  // Filled HarmonyOS Symbols for the tab bar. The bar never falls back to
  // outline glyphs: the same filled icon is drawn in both states and colour
  // carries the selection (system blue when active, secondary grey when not).
  //
  // Explore uses the compass rather than the magnifier because the HarmonyOS
  // symbol set ships no filled magnifier (house/bell/envelope/person all have a
  // _fill twin; magnifyingglass does not), and an outline glyph among four
  // filled ones reads as a rendering mistake.
  private tabSymbol(index: number): Resource {
    if (index === 0) {
      return $r('sys.symbol.house_fill');
    } else if (index === 1) {
      return $r('sys.symbol.compass_circle_fill');
    } else if (index === 2) {
      return $r('sys.symbol.bell_fill');
    } else if (index === 3) {
      return $r('sys.symbol.envelope_fill');
    }
    return $r('sys.symbol.person_fill');
  }

  @Builder
  navItem(index: number) {
    Column({ space: S4 }) {
      Badge({
        count: this.badgeCount(index),
        position: BadgePosition.RightTop,
        style: { fontSize: 10, badgeSize: 16 }
      }) {
        SymbolGlyph(this.tabSymbol(index))
          .fontSize(this.isWide ? 26 : 23)
          .fontColor([this.currentIndex === index
            ? $r('sys.color.ohos_id_color_emphasize')
            : $r('sys.color.ohos_id_color_text_secondary')])
      }
      Text(this.tabLabel(index))
        .fontSize(11)
        .fontFamily(FONT_FAMILY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.currentIndex === index
          ? $r('sys.color.ohos_id_color_emphasize')
          : $r('sys.color.ohos_id_color_text_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .width(this.isWide ? RAIL_WIDTH : undefined)
    .height(this.isWide ? TOUCH_TARGET + S16 : undefined)
    .layoutWeight(this.isWide ? 0 : 1)
    // Mouse hover, so the rail reads as a desktop navigation rail on 2in1.
    .hoverEffect(HoverEffect.Highlight)
    .accessibilityText(this.tabLabel(index))
    .accessibilityDescription(this.tabLabel(index))
    .accessibilityLevel('yes')
    .onClick(() => {
      this.goRoute(index);
    })
  }

  // The title bar stays in the layout rather than floating over the page.
  //
  // A frosted bar needs content scrolling underneath it to be worth anything,
  // but an ArkUI overlay above an ArkWeb surface does not survive the page
  // scrolling: the bar stops painting entirely (reproduced on the phone AVD with
  // both a blurred and a fully opaque background). The bottom bar is different —
  // it keeps compositing — so the layering lives there, and the header takes its
  // own row where it is guaranteed to be drawn.
  @Builder
  headerBar() {
    Column() {
      Row({ space: 0 }) {
        if (this.showBack()) {
          this.backButton()
        } else if (this.isHomeRoot()) {
          this.accountAvatar()
        }
        // The timeline switcher is the signed-in Home header. A signed-out Home
        // is x.com's own landing page and has no timeline to switch.
        if (this.isHomeRoot() && this.signedIn()) {
          this.homeTimelineTabs()
        } else if (this.isExploreSurface()) {
          this.headerSearch()
        } else {
          this.headerTitles()
        }
        this.headerAction()
      }
      .width('100%')
      .height(HEADER_HEIGHT)
      .alignItems(VerticalAlign.Center)
      .padding({ left: this.showBack() ? S4 : S12, right: S4 })
      // The load indicator rides the bottom edge of the bar, the way the system
      // does it, instead of sitting inside the page area.
      if (this.progress < 100 && !this.hasError) {
        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(PROGRESS_HEIGHT)
          .color($r('sys.color.ohos_id_color_emphasize'))
          .backgroundColor(Color.Transparent)
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }

  // Phone only: the bottom bar floats over the page for the same reason the
  // header does. On a wide window the rail stays in the layout, where it belongs.
  @Builder
  floatingTabBar() {
    Column() {
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.ohos_id_color_list_separator'))
      Flex({
        direction: FlexDirection.Row,
        justifyContent: FlexAlign.SpaceBetween,
        alignItems: ItemAlign.Center
      }) {
        this.navItem(0)
        this.navItem(1)
        this.navItem(2)
        this.navItem(3)
        this.navItem(4)
      }
      .width('100%')
      .height(BAR_HEIGHT)
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  @Builder
  navBar() {
    Column() {
      if (!this.isWide) {
        Divider()
          .strokeWidth(0.5)
          .color($r('sys.color.ohos_id_color_list_separator'))
      }
      Flex({
        direction: this.isWide ? FlexDirection.Column : FlexDirection.Row,
        justifyContent: this.isWide ? FlexAlign.Center : FlexAlign.SpaceBetween,
        alignItems: ItemAlign.Center
      }) {
        this.navItem(0)
        this.navItem(1)
        this.navItem(2)
        this.navItem(3)
        this.navItem(4)
      }
      .width('100%')
      .height(this.isWide ? '100%' : BAR_HEIGHT)
    }
    .width(this.isWide ? RAIL_WIDTH : '100%')
    .height(this.isWide ? '100%' : BAR_HEIGHT)
    // Start (not Center) so the bar row keeps its position when the background
    // is expanded into the bottom safe area below.
    .justifyContent(this.isWide ? FlexAlign.Center : FlexAlign.Start)
    // One chrome surface for the whole shell: the tab bar and rail use the same
    // background as the title bar and the page, so there is no grey-vs-white
    // seam between the bar and the window area below it. The hairline divider
    // above the row keeps the separation from the web content.
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    // Paint that surface all the way to the screen edge on devices where the
    // layout stops at the navigation-indicator safe area.
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  @Builder
  composeFab() {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph($r('sys.symbol.square_and_pencil_fill'))
        .fontSize(24)
        .fontColor([$r('sys.color.ohos_id_color_foreground_contrary')])
    }
    .width(56)
    .height(56)
    .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
    .shadow({ radius: 12, color: '#33000000', offsetX: 0, offsetY: 4 })
    .margin({ right: S16, bottom: S16 })
    .accessibilityText($r('app.string.compose_title'))
    .accessibilityLevel('yes')
    .onClick(() => {
      this.openCompose();
    })
  }

  @Builder
  errorState() {
    Column({ space: S12 }) {
      SymbolGlyph($r('sys.symbol.wifi_slash'))
        .fontSize(48)
        .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
      Text($r('app.string.error_title'))
        .fontSize(17)
        .fontFamily(FONT_FAMILY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
      Text($r('app.string.error_message'))
        .fontSize(14)
        .fontFamily(FONT_FAMILY)
        .textAlign(TextAlign.Center)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      Button($r('app.string.retry'))
        .type(ButtonType.Capsule)
        .fontFamily(FONT_FAMILY)
        .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
        .margin({ top: S8 })
        .onClick(() => {
          this.hasError = false;
          this.progress = 0;
          try {
            this.controller.refresh();
          } catch (err) {
          }
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: S16, right: S16 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }

  @Builder
  webView() {
    Web({ src: TWITTER_ROUTES[0], controller: this.controller })
      .width('100%')
      .height('100%')
      // Injected at document start, so the page's history hook always finds it.
      .javaScriptProxy({
        object: this.bridge,
        name: 'otNative',
        methodList: ['onUrlChange', 'onSessionAppeared', 'onBridgeResult'],
        controller: this.controller
      })
      .onControllerAttached(() => {
        // userAgent() on the attribute is deprecated; the controller API is the
        // supported way and can only run once the controller is bound.
        try {
          this.controller.setCustomUserAgent(this.userAgent());
        } catch (err) {
          hilog.warn(DOMAIN, TAG, 'custom UA rejected: %{public}s', JSON.stringify(err));
        }
      })
      // x.com opens some flows — the Google and Apple sign-in hand-offs, and
      // links that leave the site — in a new tab. ArkWeb blocks the renderer
      // until this event is answered, which is why those links used to look
      // dead; the shell deliberately has one WebView, so the target is loaded
      // here and no second window is created.
      .onWindowNew((event: OnWindowNewEvent) => {
        try {
          const target: string = event.targetUrl;
          try {
            event.handler.setWebController(null);
          } catch (err) {
            hilog.warn(DOMAIN, TAG, 'new-window hand-off failed: %{public}s', JSON.stringify(err));
          }
          if (target !== '') {
            hilog.info(DOMAIN, TAG, 'new-window request served in place: %{public}s', target);
            this.loadWeb(target);
          }
        } catch (err) {
        }
      })
      // Runs before any page script: ArkWeb's own navigator.onLine is wrong on
      // these images, and x.com's Chat and sign-in flows act on it. The session
      // watcher goes in the same slot so it is installed from document start
      // and can report a login the moment its cookie appears.
      .runJavaScriptOnDocumentStart([
        { script: ONLINE_PATCH, scriptRules: ['*'] },
        { script: SESSION_WATCHER, scriptRules: ['*'] }
      ])
      .javaScriptAccess(true)
      .domStorageAccess(true)
      // x.com's chat client keeps its session state in browser storage; ArkWeb
      // gates the database APIs behind this flag and defaults them off.
      .databaseAccess(true)
      .fileAccess(false)
      .mixedMode(MixedMode.Compatible)
      .cacheMode(CacheMode.Default)
      .overviewModeAccess(true)
      .zoomAccess(true)
      .geolocationAccess(true)
      .mediaPlayGestureAccess(false)
      .darkMode(WebDarkMode.Auto)
      .textZoomRatio(100)
      .onProgressChange((event) => {
        if (event) {
          this.progress = event.newProgress;
        }
      })
      .onPageBegin(() => {
        this.hasError = false;
        this.dropPendingBridgeReads();
      })
      .onPageEnd((event) => {
        this.progress = 100;
        this.refreshing = false;
        this.finishFirstLoad();
        // A page that rendered was served, so the connection is up — this is
        // what keeps the injected navigator.onLine patch honest.
        this.setOnlineFlag(true);
        if (event && event.url) {
          this.syncFromUrl(event.url);
          this.applyPageChrome(event.url);
        }
        this.schedulePageStateRead();
        this.scheduleStagedPostAction();
        if (this.ownHandle === '') {
          // A restored session can show up with no navigation at all; the
          // session read answers on any page.
          this.readSessionIdentity();
          this.discoverOwnProfile(false);
        }
      })
      .onLoadIntercept((event) => {
        try {
          const url: string = event.data.getRequestUrl();
          if (url !== '' && (url.indexOf('x.com') >= 0 || url.indexOf('twitter.com') >= 0)) {
            this.syncFromUrl(url);
            this.updateChromeFlag(url);
          }
        } catch (err) {
        }
        return false;
      })
      .onErrorReceive((event) => {
        // Subresource failures (images, analytics) are normal on x.com — only
        // treat main-frame failures as fatal.
        try {
          if (event && event.request && !event.request.isMainFrame()) {
            return;
          }
        } catch (err) {
        }
        this.hasError = true;
        this.progress = 100;
        this.refreshing = false;
        this.finishFirstLoad();
        this.setOnlineFlag(false);
      })
      .onRenderExited((event) => {
        // The render process is restarted by the system; recover by loading the
        // page again instead of dumping the user on an error card.
        hilog.warn(DOMAIN, TAG, 'render exited: %{public}s', JSON.stringify(event));
        this.hasError = false;
        this.progress = 0;
        try {
          this.controller.refresh();
        } catch (err) {
          this.hasError = true;
        }
      })
      .onGeolocationShow((event) => {
        if (event && event.geolocation) {
          this.askLocation(event.origin, event.geolocation);
        }
      })
      .onShowFileSelector((event) => {
        this.openFileSelector(event);
        return true;
      })
  }

  @Builder
  webArea() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column({ space: 0 }) {
        // Single shared WebView — session, cookies and badge reads live here.
        // It is never the visible surface: every tab is native ArkUI on top.
        if (this.hasError) {
          this.errorState()
        } else {
          Column() {
            // HarmonyOS pull-to-refresh drives the WebView directly, so the
            // header does not need a refresh button.
            Refresh({ refreshing: $$this.refreshing }) {
              this.webView()
            }
            .width('100%')
            .height('100%')
            .pullToRefresh(true)
            .onRefreshing(() => {
              this.refreshing = true;
              this.reloadCurrent();
            })
          }
          .width('100%')
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      if (!this.firstLoadDone && this.currentIndex !== 0 && this.currentIndex !== 1 &&
        this.currentIndex !== 2 && this.currentIndex !== 3 && this.currentIndex !== 4) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color($r('sys.color.ohos_id_color_emphasize'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('sys.color.ohos_id_color_background'))
      }

      // Reading the signed-in handle briefly opens the page's account menu.
      // This native panel is what the user sees while that happens.
      if (this.discovering) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color($r('sys.color.ohos_id_color_emphasize'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('sys.color.ohos_id_color_background'))
      }

      // Every visible surface is native ArkUI. The WebView stays mounted
      // underneath for session and badge state, but what the user sees and
      // touches is the native list — which is also what hides the page's own
      // wide-layout Chat column and Post button without guessing selectors.
      if (this.currentIndex === 0 && !this.webLoginOpen && !this.webDetailOpen) {
        NativeHome({
          homeJson: this.homeJson,
          homeTab: this.homeTabIndex,
          onRefresh: () => {
            this.homeNext = '';
            this.refreshHome();
          },
          onLoadMore: () => {
            this.loadMoreHome();
          },
          onPostAction: (kind: string, id: string) => {
            this.runPostAction(kind, id);
          },
          onOpenPost: (id: string) => {
            this.openWebDetail(TWITTER_BASE + '/i/web/status/' + id);
          },
          onSaveMedia: (url: string, id: string) => {
            return this.savePostImage(url, id);
          },
          onSignIn: () => {
            this.openWebLogin();
          }
        })
          .width('100%')
          .height('100%')
          .padding({ bottom: this.isWide ? 0 : BAR_HEIGHT })
      }
      if (this.currentIndex === 1 && !this.webLoginOpen && !this.webDetailOpen) {
        NativeExplore({
          trendsJson: this.trendsJson,
          searchJson: this.searchJson,
          searchText: this.searchText,
          onRefreshTrends: () => {
            this.refreshTrends();
          },
          onSearch: (query: string) => {
            this.searchText = query;
            this.runSearch(query);
          },
          onOpenTrend: (name: string) => {
            this.searchText = name;
          },
          onSignIn: () => {
            this.openWebLogin();
          }
        })
          .width('100%')
          .height('100%')
          .padding({ bottom: this.isWide ? 0 : BAR_HEIGHT })
      }
      if (this.currentIndex === 2 && !this.webLoginOpen && !this.webDetailOpen) {
        NativeNotifications({
          notifJson: this.notifListJson,
          onRefresh: () => {
            this.refreshNotifList();
          },
          onOpenItem: (id: string, targetId: string) => {
            if (targetId !== '') {
              this.openWebDetail(TWITTER_BASE + '/i/web/status/' + targetId);
            } else {
              this.openWebDetail(TWITTER_NOTIFICATIONS);
            }
          },
          onSignIn: () => {
            this.openWebLogin();
          }
        })
          .width('100%')
          .height('100%')
          .padding({ bottom: this.isWide ? 0 : BAR_HEIGHT })
      }
      // The Messages tab is native ArkUI end to end. The shared WebView stays
      // mounted underneath for login/session state and unread badge reads, but
      // the list, conversation and composer are drawn by NativeMessages.
      if (this.currentIndex === 3 && !this.webLoginOpen && !this.webDetailOpen) {
        NativeMessages({
          open: this.chatOpen,
          dmJson: this.dmJson,
          threadJson: this.threadJson,
          onConversationChange: (open: boolean, title: string) => {
            this.chatOpen = open;
            this.chatTitle = title;
            if (!open) {
              this.threadId = '';
              this.threadJson = '';
              this.stopThreadPolling();
            }
            // The bottom bar steps aside for a conversation, so the page's own
            // bottom inset has to change with it.
            this.applyImmersiveInset();
          },
          onRequestThread: (id: string) => {
            this.startThreadPolling(id);
          },
          sendStateJson: this.sendStateJson,
          onSendMessage: (id: string, uid: string, text: string, messageId: string) => {
            this.sendDm(id, uid, text, messageId);
          },
          onMuteConversation: (id: string, muted: boolean) => {
            this.muteDm(id, muted);
          },
          onSignIn: () => {
            this.openWebLogin();
          }
        })
          .width('100%')
          .height('100%')
          // The native surface is not a web page, so it clears the floating tab
          // bar with real padding rather than an injected stylesheet.
          .padding({
            bottom: this.immersiveConversation() ? 0 : BAR_HEIGHT
          })
      }
      if (this.currentIndex === 4 && !this.webLoginOpen && !this.webDetailOpen) {
        NativeProfile({
          profileJson: this.profileJson,
          viewingHandle: this.viewingHandle !== '' ? this.viewingHandle : this.ownHandle,
          onRefresh: () => {
            const handle: string = this.viewingHandle !== '' ? this.viewingHandle : this.ownHandle;
            if (handle !== '') {
              this.profileFor = '';
              this.refreshProfile(handle);
            }
          },
          onLoadMore: () => {
            this.loadMoreProfile();
          },
          onPostAction: (kind: string, id: string) => {
            this.runPostAction(kind, id);
          },
          onOpenPost: (id: string) => {
            this.openWebDetail(TWITTER_BASE + '/i/web/status/' + id);
          },
          onSaveMedia: (url: string, id: string) => {
            return this.savePostImage(url, id);
          },
          onEditProfile: () => {
            this.openWebDetail(TWITTER_EDIT_PROFILE);
          },
          onSignIn: () => {
            this.openWebLogin();
          }
        })
          .width('100%')
          .height('100%')
          .padding({ bottom: this.isWide ? 0 : BAR_HEIGHT })
      }

      // Native compose entry point, like the stock app: on content tabs only
      // (never on Profile or Messages, never over the login flow), only once
      // a page is on screen, and only when there is an account to post from.
      if (this.currentIndex !== 4 && this.currentIndex !== 3 && !this.hasError &&
        !this.webLoginOpen && !this.webDetailOpen && this.signedIn()) {
        this.composeFab()
      }
    }
    .width('100%')
    .height('100%')
    .flexGrow(1)
    .flexShrink(1)
    // Native surfaces fill this box; clipping keeps lists from drawing over the
    // shell's title bar while the window resizes for the IME.
    .clip(true)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }

  @Builder
  composeSheet() {
    Stack({ alignContent: Alignment.TopStart }) {
      // x.com's own composer, kept invisible under the native panel. It exists
      // only so the native Post button submits through the real web session;
      // if it has to surface (media, polls, threads, or an undrivable editor)
      // it is revealed and the native panel steps aside.
      Web({ src: TWITTER_COMPOSE, controller: this.composeController })
        .width('100%')
        .height('100%')
        .opacity(this.webComposer ? 1 : 0)
        .onControllerAttached(() => {
          try {
            this.composeController.setCustomUserAgent(this.userAgent());
          } catch (err) {
          }
        })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(false)
        .mixedMode(MixedMode.Compatible)
        .cacheMode(CacheMode.Default)
        .zoomAccess(false)
        .darkMode(WebDarkMode.Auto)
        .onShowFileSelector((event) => {
          this.openFileSelector(event);
          return true;
        })

      Column({ space: 0 }) {
        Row() {
          Button($r('app.string.compose_cancel'))
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .fontFamily(FONT_FAMILY)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .onClick(() => {
              this.sheetOpen = false;
            })
          Blank()
          Text($r('app.string.compose_title'))
            .fontSize(17)
            .fontFamily(FONT_FAMILY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
          Blank()
          Button($r('app.string.compose_post'))
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .fontFamily(FONT_FAMILY)
            .enabled(this.draft.trim() !== '' && !this.posting)
            .onClick(() => {
              this.postFromSheet();
            })
        }
        .width('100%')
        .padding({ left: S8, right: S8, top: S8, bottom: S8 })
        .alignItems(VerticalAlign.Center)

        Divider()
          .strokeWidth(0.5)
          .color($r('sys.color.ohos_id_color_list_separator'))

        // Counter and the web-composer escape hatch sit above the field: with
        // the keyboard up, the bottom of the sheet is off screen.
        Row() {
          Text($r('app.string.compose_counter', this.draft.length))
            .fontSize(13)
            .fontFamily(FONT_FAMILY)
            .fontColor(this.draft.length > 280
              ? $r('sys.color.ohos_id_color_warning')
              : $r('sys.color.ohos_id_color_text_secondary'))
          Blank()
          // The parts of composing that are x.com's, not the shell's: media,
          // GIFs, polls and threads.
          Button($r('app.string.compose_more'))
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .fontFamily(FONT_FAMILY)
            .onClick(() => {
              this.openWebComposer();
            })
        }
        .width('100%')
        .padding({ left: S16, right: S8, top: S4, bottom: S4 })
        .alignItems(VerticalAlign.Center)

        TextArea({ text: $$this.draft, placeholder: $r('app.string.compose_placeholder') })
          .width('100%')
          .layoutWeight(1)
          .fontFamily(FONT_FAMILY)
          .fontSize(18)
          .backgroundColor(Color.Transparent)
          .padding({ left: S16, right: S16, top: S12 })
          .onChange(() => {
            this.scheduleDraftSave();
          })
          // Pre-IME: the editor would otherwise swallow Enter (it is a newline
          // there), so Ctrl/Cmd+Enter has to be handled before the input method
          // and the editor ever see the key.
          .onKeyPreIme((event: KeyEvent) => this.composeKey(event))
          .defaultFocus(true)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_background'))
      .visibility(this.webComposer ? Visibility.Hidden : Visibility.Visible)
    }
    .width('100%')
    .height('100%')
    .borderRadius({ topLeft: RADIUS, topRight: RADIUS })
    .clip(true)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    // Escape works from anywhere in the sheet, not only from the editor.
    .onKeyEvent((event: KeyEvent) => this.composeKey(event))
  }

  @Builder
  mediaSaveSheetView() {
    Column({ space: S12 }) {
      Text($r('app.string.post_save_image'))
        .fontSize(20)
        .fontFamily(FONT_FAMILY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
      Text(this.mediaSaveReady
        ? $r('app.string.post_media_ready')
        : $r('app.string.post_media_downloading'))
        .fontSize(14)
        .fontFamily(FONT_FAMILY)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      SaveButton({
        icon: SaveIconStyle.FULL_FILLED,
        text: SaveDescription.SAVE_IMAGE,
        buttonType: ButtonType.Capsule
      })
        .width(180)
        .height(52)
        .fontSize(16)
        .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
        .enabled(this.mediaSaveReady && !this.mediaSaveBusy)
        .onClick(async (event: ClickEvent, result: SaveButtonOnClickResult) => {
          if (result === SaveButtonOnClickResult.SUCCESS) {
            await this.commitPreparedImage();
          } else if (result === SaveButtonOnClickResult.CANCELED_BY_USER) {
            await this.cancelPreparedImage();
          } else if (result === SaveButtonOnClickResult.TEMPORARY_AUTHORIZATION_FAILED) {
            hilog.warn(DOMAIN, TAG, 'media save authorization failed');
            this.toast($r('app.string.post_media_save_failed'));
          }
        })
        .userCancelEvent(true)
      Button($r('app.string.compose_cancel'))
        .width(180)
        .height(44)
        .backgroundColor(Color.Transparent)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .onClick(async () => {
          await this.cancelPreparedImage();
        })
    }
    .width('100%')
    .padding({ left: S20, right: S20, top: S20, bottom: S20 })
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .onDisAppear(() => {
      if (this.mediaSavePath !== '' && !this.mediaSaveBusy) {
        this.cancelPreparedImage();
      }
    })
  }

  build() {
    // alignContent Bottom pins the floating tab bar to the bottom edge while the
    // content column behind it keeps the full window.
    Stack({ alignContent: Alignment.Bottom }) {
      // Row on a wide window puts the rail on the left; Column on a phone stacks
      // the header over the page. Either way the header and the page share one
      // content column, so the header spans the page and not the rail.
      Flex({ direction: this.isWide ? FlexDirection.Row : FlexDirection.Column }) {
        if (this.isWide) {
          this.navBar()
        }
        Column() {
          this.headerBar()
          this.webArea()
        }
        .layoutWeight(1)
        .height('100%')
      }
      .width('100%')
      .height('100%')

      if (!this.isWide && !this.immersiveConversation()) {
        this.floatingTabBar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .bindSheet($$this.sheetOpen, this.composeSheet(), {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: false,
      blurStyle: BlurStyle.COMPONENT_ULTRA_THICK
    })
    .bindSheet($$this.mediaSaveSheet, this.mediaSaveSheetView(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: false,
      blurStyle: BlurStyle.COMPONENT_ULTRA_THICK
    })
  }
}
