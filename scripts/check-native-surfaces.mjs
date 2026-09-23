#!/usr/bin/env node
// Native surfaces contract check: every tab is ArkUI reading from the page
// session, with honest loading/empty/signed-out/failed states and no invented
// rows.
//
//   node scripts/check-native-surfaces.mjs
//
// Checks, without a device or network:
//  1. PageBridge holds the fragile half once (otGet/otPost/account/time).
//  2. Every surface script exists and goes through pageBridgeScript.
//  3. All user-visible strings exist in base + zh_CN + ar.
//  4. Parsers accept the documented shapes and reject garbage as states.

import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const read = (p) => readFileSync(join(root, p), 'utf8');

let failed = 0;
function check(name, ok, detail = '') {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}${detail ? ': ' + detail : ''}`);
  if (!ok) failed += 1;
}

// 1. Shared bridge -----------------------------------------------------------
const bridge = read('entry/src/main/ets/common/PageBridge.ets');
for (const token of ['otGet', 'otPost', 'otAccountFromConvs', 'otTime', 'pageBridgeScript']) {
  check(`PageBridge holds ${token}`, bridge.includes(token));
}

// 2. Surface scripts ----------------------------------------------------------
const chrome = read('entry/src/main/ets/common/WebChrome.ets');
const surfaces = [
  'dmInboxScript', 'dmThreadScript', 'dmSendScript',
  'notificationsScript', 'homeTimelineScript', 'profileScript',
  'trendsScript', 'searchTweetsScript', 'postActionScript'
];
for (const fn of surfaces) {
  check(`WebChrome exports ${fn}`, chrome.includes(`function ${fn}`));
}
check('surfaces go through pageBridgeScript',
  (chrome.match(/pageBridgeScript\(/g) || []).length >= surfaces.length);
check('reads use otGet', chrome.includes('otGet('));
check('writes use otPost', chrome.includes('otPost('));
check('home uses verified v2 timeline + cursor paging',
  chrome.includes('/i/api/2/timeline/home.json') && chrome.includes('cursor-bottom'));
check('notifications use verified timeline entries',
  chrome.includes('clientEventInfo') && chrome.includes('fromUsers'));
check('profile reads the rendered page (v1.1 user endpoints are dead)',
  chrome.includes('UserName') && !chrome.includes('users/show'));
check('search uses verified typeahead topics',
  chrome.includes('search/typeahead') && !chrome.includes('search/tweets.json'));
check('DM inbox uses shared account derivation',
  chrome.includes('otAccountFromConvs(convs)'));
check('inbox carries uid for sending', chrome.includes('uid'));

// 3. Components exist and own their states ------------------------------------
const components = [
  'entry/src/main/ets/components/NativeHome.ets',
  'entry/src/main/ets/components/NativeNotifications.ets',
  'entry/src/main/ets/components/NativeProfile.ets',
  'entry/src/main/ets/components/NativeExplore.ets',
  'entry/src/main/ets/components/NativeMessages.ets',
  'entry/src/main/ets/components/NativePostCard.ets',
  'entry/src/main/ets/components/NativeSignIn.ets',
  'entry/src/main/ets/common/NativeModels.ets'
];
for (const c of components) {
  check(`component exists ${c.split('/').pop()}`, existsSync(join(root, c)));
}
const home = read('entry/src/main/ets/components/NativeHome.ets');
check('Home pages with LazyForEach', home.includes('LazyForEach'));
check('Home has loading state', home.includes("'loading'") || home.includes('"loading"'));
check('Home has signed-out state', home.includes('signed-out'));
check('Home has empty state', home.includes('empty'));
const main = read('entry/src/main/ets/pages/MainTabs.ets');
for (const token of ['homeJson', 'notifListJson', 'profileJson', 'trendsJson', 'searchJson', 'threadJson']) {
  check(`shell owns ${token}`, main.includes(token));
}
for (const token of ['startHomePolling', 'startNotifListPolling', 'startTrendsPolling', 'startThreadPolling']) {
  check(`shell polls ${token}`, main.includes(token));
}
check('shell instruments syncFromUrl', main.includes('syncFromUrl url='));
check('SPA navigations trigger handle discovery', main.includes('discoverOwnProfile(false);\n      }\n      this.updateChromeFlag'));
check('signed-out backstop retries discovery', main.includes('if (!this.signedIn()) {\n        // Backstop'));
check('menu fallback gated on session + idle login', main.includes('discoverWithSession'));
check('session death clears cached handle', main.includes('noteSignedOut(json)'));

// Async page reads must come back through the proxy, not runJavaScript's return
// value: ArkWeb hands back the synchronous result of an async IIFE, which is
// always "" — that is what left every signed-in surface blank.
check('async reads return via the proxy callback', main.includes('window.otNative.onBridgeResult(id,String(v))'));
check('callback is exposed to the page', main.includes("methodList: ['onUrlChange', 'onSessionAppeared', 'onBridgeResult']"));
check('reads have a deadline', main.includes('BRIDGE_TIMEOUT_MS') && main.includes('read timed out'));
check('stale reads dropped on navigation', main.includes('this.dropPendingBridgeReads();'));
check('late thread replies are keyed', main.includes("key !== '' && key === this.threadId"));
check('late search replies are keyed', main.includes('if (key === this.searchPending)'));
check('transient failures retry quickly', main.includes('retryBridgeSoon') && main.includes('1500 * attempt'));
check('identity read is DOM-free', main.includes('sessionIdentityScript') && chrome.includes('otAccountFromInbox'));
check('API text is entity-decoded', chrome.includes('otText(md.text)') && chrome.includes('otText(t.full_text||t.text)'));

// 4. Strings in all three locales ---------------------------------------------
const locales = [
  'entry/src/main/resources/base/element/string.json',
  'entry/src/main/resources/zh_CN/element/string.json',
  'entry/src/main/resources/ar/element/string.json'
];
const parsed = locales.map((p) => JSON.parse(read(p)));
const baseKeys = new Set(parsed[0].string.map((s) => s.name));
const required = [
  'home_signed_out_title', 'home_unavailable_title', 'home_empty_title',
  'notif_empty_title', 'notif_liked', 'notif_followed',
  'profile_edit', 'profile_followers', 'profile_no_posts',
  'explore_trends_title', 'explore_no_results_title',
  'post_like', 'post_repost', 'post_action_failed',
  'messages_loading_thread', 'messages_send_unavailable',
  'signin_title', 'signin_message', 'signin_benefit_home', 'signin_button', 'signin_note'
];
for (const key of required) {
  check(`string ${key} in base`, baseKeys.has(key));
}
for (let i = 1; i < parsed.length; i++) {
  const keys = new Set(parsed[i].string.map((s) => s.name));
  const missing = [...baseKeys].filter((k) => !keys.has(k));
  check(`locale ${locales[i]} covers base (${baseKeys.size} keys)`,
    missing.length === 0, missing.slice(0, 5).join(','));
}

// 5. Parser behaviour on stubbed payloads --------------------------------------
// Mirrors NativeModels.parsePosts/stateOf without importing ArkTS.
function stateOf(json) {
  if (!json) return 'loading';
  try {
    const p = JSON.parse(json);
    return p && p.state ? p.state : 'error';
  } catch {
    return 'error';
  }
}
check('stateOf loading', stateOf('') === 'loading');
check('stateOf ok', stateOf('{"state":"ok"}') === 'ok');
check('stateOf signed-out', stateOf('{"state":"signed-out"}') === 'signed-out');
check('stateOf garbage is error', stateOf('not json') === 'error');

const timelineOk = JSON.stringify({
  state: 'ok',
  posts: [{ id: '1', name: 'A', handle: 'a', avatar: '', text: 'hi', at: Date.now(),
    likes: 3, reposts: 1, replies: 0, liked: false, reposted: false, media: '' }],
  next: '1'
});
check('timeline ok parses', stateOf(timelineOk) === 'ok');
check('timeline empty is honest', stateOf('{"state":"empty"}') === 'empty');

console.log(failed === 0 ? '\nall native-surface checks passed' : `\n${failed} check(s) failed`);
process.exit(failed === 0 ? 0 : 1);
