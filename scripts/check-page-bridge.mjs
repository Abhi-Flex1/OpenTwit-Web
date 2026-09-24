#!/usr/bin/env node
// Bridge harness: assembles the SHIPPED PageBridge + WebChrome scripts and runs
// them against a stubbed page, the way the app runs them inside x.com.
// Endpoint shapes come from probes run against a live signed-in session
// (foldable AVD, 2026-09-23); fixtures below are minimal anonymized versions.
//
//   node scripts/check-page-bridge.mjs

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { createHash } from 'node:crypto';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const bridgeSrc = readFileSync(join(root, 'entry/src/main/ets/common/PageBridge.ets'), 'utf8');
const chromeSrc = readFileSync(join(root, 'entry/src/main/ets/common/WebChrome.ets'), 'utf8');

let failed = 0;
function check(name, ok, detail = '') {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}${detail ? ': ' + detail : ''}`);
  if (!ok) failed += 1;
}

// --- extract ArkTS string-concat consts (same technique as check-unread-counts)
function skipComment(src, i) {
  // // comment to end of line, only when not inside a string literal
  const nl = src.indexOf('\n', i);
  return nl < 0 ? src.length : nl;
}
function extractConst(src, name) {
  const marker = `const ${name}: string =`;
  const start = src.indexOf(marker);
  if (start < 0) throw new Error(`${name} not found`);
  const decl = src.slice(src.indexOf('=', start) + 1);
  // statement ends at the first ';\n' at depth 0 of the ArkTS source
  let depth = 0, inS = false, inD = false;
  for (let i = 0; i < decl.length; i++) {
    const c = decl[i];
    if (inS) { if (c === "'" && decl[i - 1] !== '\\') inS = false; continue; }
    if (inD) { if (c === '"' && decl[i - 1] !== '\\') inD = false; continue; }
    // Comments are stripped by the joiner, so the scanner must not let an
    // apostrophe in a comment (e.g. "the user's handle") flip string state.
    if (c === '/' && decl[i + 1] === '/') { i = skipComment(decl, i) - 1; continue; }
    if (c === "'") { inS = true; continue; }
    if (c === '"') { inD = true; continue; }
    if (c === '(') depth++;
    if (c === ')') depth--;
    if (c === ';' && depth === 0) return eval(joinExpr(decl.slice(0, i)));
  }
  throw new Error(`end of ${name} not found`);
}

// Concatenation continuation lines start with `'...' +`; the statements are
// written one fragment per line, so joining the non-empty, non-comment lines
// reproduces the exact runtime value the WebView receives.
function joinExpr(decl) {
  return decl.split('\n').map((l) => l.trim()).filter((l) => l && !l.startsWith('//')).join(' ');
}

// --- extract the body expression passed to pageBridgeScript in fnName
function extractBody(src, fnName) {
  const fnAt = src.indexOf(`function ${fnName}(`);
  if (fnAt < 0) throw new Error(`${fnName} not found`);
  const callAt = src.indexOf('return pageBridgeScript(', fnAt);
  const openAt = src.indexOf('(', src.indexOf('pageBridgeScript', callAt)) + 1;
  let depth = 1, inS = false, inD = false, inT = false;
  for (let i = openAt; i < src.length; i++) {
    const c = src[i], p = src[i - 1];
    if (inS) { if (c === "'" && p !== '\\') inS = false; continue; }
    if (inD) { if (c === '"' && p !== '\\') inD = false; continue; }
    if (inT) { if (c === '`' && p !== '\\') inT = false; continue; }
    if (c === '/' && src[i + 1] === '/') { i = skipComment(src, i) - 1; continue; }
    if (c === "'") { inS = true; continue; }
    if (c === '"') { inD = true; continue; }
    if (c === '`') { inT = true; continue; }
    if (c === '(') depth++;
    if (c === ')') { depth--; if (depth === 0) return src.slice(openAt, i); }
  }
  throw new Error(`body end of ${fnName} not found`);
}

const SESSION_SETUP = extractConst(bridgeSrc, 'SESSION_SETUP');
const FETCH_HELPER = extractConst(bridgeSrc, 'FETCH_HELPER');
const DM_MEDIA_HELPER = extractConst(bridgeSrc, 'DM_MEDIA_HELPER');
const TWEET_SHAPE_JS = extractConst(chromeSrc, 'TWEET_SHAPE_JS');
const DM_MD5_HELPER = extractConst(chromeSrc, 'DM_MD5_HELPER');
function pageBridgeScript(body) {
  return '(async function(){try{' + SESSION_SETUP + FETCH_HELPER + DM_MEDIA_HELPER + body +
    '}catch(e){return JSON.stringify({state:"error",message:String(e).slice(0,120)});}})()';
}

// --- stub page runner
// Minimal stand-in for the browser's entity decoder, so the shared otText()
// helper is exercised through the same path it takes in ArkWeb.
function decodeEntities(s) {
  return String(s)
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(parseInt(d, 10)))
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&apos;|&#0?39;/g, "'")
    .replace(/&amp;/g, '&');
}
async function run(script, { cookie = '', scripts = [], routes = {}, qs = null, qa = null, pathname = '' } = {}) {
  const listeners = [];
  const document = {
    cookie,
    title: '',
    querySelectorAll(sel) {
      if (sel === 'script[src]') return scripts.map((src) => ({ src }));
      if (qa) return qa(sel);
      return [];
    },
    querySelector(sel) {
      if (qs) return qs(sel);
      return null;
    },
    createElement() {
      return {
        innerHTML: '',
        get value() { return decodeEntities(this.innerHTML); }
      };
    }
  };
  const window = { location: { pathname } };
  const fetch = async (url, opts = {}) => {
    const u = String(url);
    if (scripts.includes(u)) {
      return { text: async () => 'Authorization: Bearer ' + 'A'.repeat(100) };
    }
    const path = u.replace('https://x.com', '');
    const hit = routes[path] ?? routes[path.split('?')[0]];
    if (!hit) return { status: 404, ok: false, json: async () => { throw new Error('no json'); }, text: async () => '', clone() { return this; } };
    if (typeof hit === 'number') return { status: hit, ok: false, json: async () => { throw new Error('no json'); }, text: async () => '', clone() { return this; } };
    return { status: 200, ok: true, json: async () => JSON.parse(JSON.stringify(hit)), text: async () => JSON.stringify(hit), clone() { return this; } };
  };
  const fn = new Function('document', 'window', 'fetch', `return (${script})`);
  const out = await fn(document, window, fetch);
  return { out: JSON.parse(out), window };
}

async function runMediaScript(script, { file, failAt = '', mediaId = 'media-1' } = {}) {
  const calls = [];
  const nativeResults = [];
  const source = new Uint8Array(2 * 1024 * 1024 + 37);
  for (let i = 0; i < source.length; i += 1) source[i] = (i * 31 + 7) & 0xff;
  const fileObject = {
    name: 'fixture.png',
    size: source.length,
    type: 'image/png',
    arrayBuffer: async () => source.buffer.slice(0),
    slice: (start, end) => ({
      name: 'blob',
      size: Math.max(0, end - start),
      type: 'image/png'
    })
  };
  const document = {
    cookie: 'ct0=TOK',
    title: '',
    body: {
      children: [],
      appendChild(node) { this.children.push(node); }
    },
    querySelectorAll(sel) {
      if (sel === 'script[src]') return [{ src: BEARER_SCRIPT }];
      return [];
    },
    querySelector() { return null; },
    getElementById(id) { return this.body.children.find((node) => node.id === id) || null; },
    createElement(tag) {
      if (tag === 'input') {
        const node = {
          id: '',
          type: '',
          accept: '',
          style: {},
          multiple: false,
          files: [],
          onchange: null,
          click() {
            this.files = [fileObject];
            if (this.onchange) this.onchange();
          },
          remove() {
            this.removed = true;
          }
        };
        return node;
      }
      return {
        innerHTML: '',
        get value() { return decodeEntities(this.innerHTML); }
      };
    }
  };
  const window = {
    __otDmFiles: { c1: fileObject },
    otNative: {
      onDmMediaRequest() {},
      onDmMediaResult(conversationId, json) {
        nativeResults.push({ conversationId, payload: JSON.parse(json) });
      }
    },
    URL: {
      createObjectURL() { return 'blob:fixture'; },
      revokeObjectURL() {}
    }
  };
  class FormDataStub {
    constructor() { this.parts = []; }
    append(name, value, filename) { this.parts.push({ name, value, filename }); }
  }
  class BlobStub {}
  const fetch = async (url, options = {}) => {
    const u = String(url);
    calls.push({ url: u, options });
    if (u === BEARER_SCRIPT) {
      return { text: async () => 'Authorization: Bearer ' + 'A'.repeat(100) };
    }
    if (u.includes('command=INIT')) {
      return {
        ok: true,
        status: 200,
        json: async () => ({ media_id_string: mediaId })
      };
    }
    if (u.includes('command=APPEND') && failAt === 'append') {
      return { ok: false, status: 500, json: async () => ({}) };
    }
    if (u.includes('command=APPEND')) {
      return { ok: true, status: 200, json: async () => ({}) };
    }
    if (u.includes('command=FINALIZE')) {
      return {
        ok: true,
        status: 204,
        json: async () => { throw new Error('no body'); }
      };
    }
    if (u.includes('/i/api/1.1/dm/new2.json')) {
      return {
        ok: true,
        status: 200,
        json: async () => ({ entries: [{ message: { id: 'server-message-1' } }] })
      };
    }
    return { ok: false, status: 404, json: async () => ({}) };
  };
  const fn = new Function(
    'document', 'window', 'fetch', 'FormData', 'Blob', 'URL', 'Uint8Array',
    `return (${script})`
  );
  const output = await fn(
    document, window, fetch, FormDataStub, BlobStub, window.URL, Uint8Array
  );
  return {
    out: JSON.parse(output),
    calls,
    nativeResults,
    window,
    fileObject,
    source
  };
}

const BEARER_SCRIPT = 'https://x.com/main.js';
const SIGNED_OUT = { cookie: '' };

// --- fixtures (anonymized shapes from the live session) -----------------------
const dmInbox = {
  inbox_initial_state: {
    users: {
      me: { id_str: 'me', name: 'Me', screen_name: 'me', profile_image_url_https: 'https://x/a_normal.jpg' },
      u1: { id_str: 'u1', name: 'Ann', screen_name: 'ann', profile_image_url_https: 'https://x/b_normal.jpg' }
    },
    conversations: {
      c1: { type: 'ONE_TO_ONE', participants: [{ user_id: 'me' }, { user_id: 'u1' }], muted: false,
        last_read_event_id: '0', max_entry_id: 'm1' }
    },
    entries: [
      { message: { conversation_id: 'c1', time: '1788000000000', message_data: { text: 'hello there', sender_id: 'u1' } } }
    ]
  }
};
const homeV2 = {
  globalObjects: {
    users: { su: { id_str: 'su', name: 'Sam', screen_name: 'sam', profile_image_url_https: 'https://x/s_normal.jpg' } },
    tweets: {
      t1: { id_str: 't1', full_text: 'hello world', created_at: 'Wed Sep 23 12:00:00 +0000 2026', user_id_str: 'su', favorite_count: 3, retweet_count: 1, favorited: false, retweeted: false }
    }
  },
  timeline: { instructions: [{ addEntries: { entries: [
    { entryId: 'tweet-t1', content: { item: { content: { tweet: { id: 't1' } } } } },
    { entryId: 'cursor-bottom-xyz', content: { operation: { cursor: { value: 'CUR123' } } } }
  ] } }] }
};
const notifV2 = {
  globalObjects: {
    users: { fu: { id_str: 'fu', name: 'Ned', screen_name: 'ned', profile_image_url_https: 'https://x/n_normal.jpg' } },
    tweets: { nt: { id_str: 'nt', full_text: 'great post indeed', created_at: 'Wed Sep 23 11:00:00 +0000 2026' } }
  },
  timeline: { instructions: [{ addEntries: { entries: [
    { entryId: 'cursor-top-1', sortIndex: '1790000000002', content: { operation: { cursor: { value: 'TOP' } } } },
    { entryId: 'notification-abc', sortIndex: '1790000000001', content: { item: { content: { notification: { id: 'abc', fromUsers: ['fu'], targetTweets: ['nt'] } }, clientEventInfo: { element: 'users_liked_your_tweet' } } } }
  ] } }] }
};
const trendsPayload = [{ trends: [{ name: '#topic', tweet_volume: 1234 }] }];
const typeahead = { topics: [{ topic: 'harmonyos' }] };

// --- build the shipped scripts -------------------------------------------------
function build(fnName, consts = {}) {
  const names = Object.keys(consts);
  const vals = names.map((k) => consts[k]);
  const bodyFn = new Function(...names, `return (${extractBody(chromeSrc, fnName)})`);
  const body = bodyFn(...vals);
  return pageBridgeScript(body);
}

const scripts = {
  dmInbox: build('dmInboxScript'),
  dmThread: build('dmThreadScript', { safe: JSON.stringify('c1') }),
  dmMediaPick: build('dmMediaPickScript', { cid: JSON.stringify('c1') }),
  dmMediaUpload: build('dmMediaUploadScript', {
    cid: JSON.stringify('c1'),
    caption: JSON.stringify('caption'),
    DM_MD5_HELPER
  }),
  notifications: build('notificationsScript'),
  home: build('homeTimelineScript', { safe: JSON.stringify(''), TWEET_SHAPE_JS }),
  homePaged: build('homeTimelineScript', { safe: JSON.stringify('CUR123'), TWEET_SHAPE_JS }),
  trends: build('trendsScript'),
  search: build('searchTweetsScript', { q: JSON.stringify('harmony') })
};
for (const [k, s] of Object.entries(scripts)) {
  try {
    new Function('document', 'window', 'fetch', `return (${s})`);
    check(`script parses: ${k}`, true);
  } catch (e) {
    check(`script parses: ${k}`, false, e.message.slice(0, 100));
  }
}

const mediaPick = await runMediaScript(scripts.dmMediaPick);
check('media picker requests the native hook',
  mediaPick.nativeResults[0]?.payload?.state === 'selected' &&
  mediaPick.nativeResults[0]?.conversationId === 'c1',
  JSON.stringify(mediaPick.nativeResults));
check('media picker retains the selected File',
  mediaPick.window.__otDmFiles?.c1 === mediaPick.fileObject);

const mediaUpload = await runMediaScript(scripts.dmMediaUpload);
const mediaAppends = mediaUpload.calls.filter((call) => call.url.includes('command=APPEND'));
const mediaFinalize = mediaUpload.calls.find((call) => call.url.includes('command=FINALIZE'));
const mediaSend = mediaUpload.calls.find((call) => call.url.includes('/i/api/1.1/dm/new2.json'));
const expectedDigest = createHash('md5').update(Buffer.from(mediaUpload.source)).digest('hex');
check('media upload starts with INIT',
  mediaUpload.calls.some((call) => call.url.includes('command=INIT') &&
    call.url.includes('media_category=dm_image')));
check('media upload sends three multipart APPEND requests', mediaAppends.length === 3);
check('media upload finalizes with the exact MD5',
  mediaFinalize?.url.includes(`original_md5=${expectedDigest}`));
check('media upload sends dm/new2 with media_id',
  mediaUpload.out.state === 'ok' &&
  mediaSend &&
  JSON.parse(mediaSend.options.body).media_id === 'media-1' &&
  JSON.parse(mediaSend.options.body).conversation_id === 'c1');
check('media upload accepts a 204 finalize without a JSON body',
  mediaUpload.out.state === 'ok' && mediaUpload.out.messageId === 'server-message-1');

const mediaFailure = await runMediaScript(scripts.dmMediaUpload, { failAt: 'append' });
check('media upload append failure does not send',
  mediaFailure.out.state === 'append-failed' &&
  !mediaFailure.calls.some((call) => call.url.includes('/i/api/1.1/dm/new2.json')));
check('media upload failure retains the selected File for retry',
  mediaFailure.window.__otDmFiles?.c1 === mediaFailure.fileObject);

// Optionally dump an assembled script for live evaluation in a WebView
// (node scripts/check-page-bridge.mjs --dump <fn> [outfile] [constsJson])
if (process.argv[2] === '--dump') {
  const { writeFileSync } = await import('node:fs');
  const fn = process.argv[3];
  const out = process.argv[4] || '/private/var/folders/pn/f_p_k7xn3r521sbj5shz3c4m0000gn/T/opencode/cdp/dump.js';
  const consts = process.argv[5] ? JSON.parse(process.argv[5]) : {};
  let body = extractBody(chromeSrc, fn);
  // Some bodies call the shared tweet shaper; supply it so a dumped script is
  // exactly what the app runs.
  if (body.includes('otTweet(') && consts.TWEET_SHAPE_JS === undefined) {
    consts.TWEET_SHAPE_JS = extractConst(chromeSrc, 'TWEET_SHAPE_JS');
  }
  const names = Object.keys(consts);
  body = new Function(...names, `return (${body})`)(...names.map((k) => consts[k]));
  writeFileSync(out, pageBridgeScript(body));
  console.log('wrote', out);
  process.exit(0);
}

// --- cases ---------------------------------------------------------------------
const R = (p) => `/i/api/1.1/dm/inbox_initial_state.json?include_conversation_info=true&include_inbox_timelines=true&include_groups=true`;
const inboxPath = '/i/api/1.1/dm/inbox_initial_state.json?include_conversation_info=true&include_inbox_timelines=true&include_groups=true';

let r = await run(scripts.dmInbox, SIGNED_OUT);
check('dm signed-out', r.out.state === 'signed-out', r.out.state);

r = await run(scripts.dmInbox, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [inboxPath]: dmInbox } });
check('dm ok', r.out.state === 'ok' && r.out.conversations.length === 1, JSON.stringify(r.out).slice(0, 120));
check('dm fields', r.out.conversations[0]?.handle === 'ann' && r.out.conversations[0]?.text === 'hello there' && r.out.conversations[0]?.uid === 'u1' && r.out.conversations[0]?.out === false);
check('dm derives unread from read marker', r.out.conversations[0]?.unread === 1, JSON.stringify(r.out.conversations[0]));

const dmSend = build('dmSendScript', {
  rid: JSON.stringify('u1'),
  cid: JSON.stringify('c1'),
  body: JSON.stringify('hello')
});
const dmSendGroup = build('dmSendScript', {
  rid: JSON.stringify(''),
  cid: JSON.stringify('group-1'),
  body: JSON.stringify('group hello')
});
r = await run(dmSend, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: {
  '/i/api/1.1/direct_messages/events/new.json': { ok: true }
}});
check('dm send uses recipient target', r.out.state === 'ok', JSON.stringify(r.out));
r = await run(dmSendGroup, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: {
  '/i/api/1.1/direct_messages/events/new.json': { ok: true }
}});
check('dm group send falls back to conversation target', r.out.state === 'ok', JSON.stringify(r.out));

const dmMute = build('dmMuteScript', {
  cid: JSON.stringify('c1'),
  path: '/i/api/1.1/mutes/conversations/create.json'
});
r = await run(dmMute, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: {
  '/i/api/1.1/mutes/conversations/create.json': { ok: true }
}});
check('dm mute uses conversation route', r.out.state === 'ok', JSON.stringify(r.out));

// Bookmark writes use x.com's rendered control. If the article is not on the
// current hidden route, the script reports that the shell must stage the post
// route before retrying the same authenticated control.
function bookmarkArticle() {
  let bookmarked = false;
  const button = {
    click() {
      bookmarked = !bookmarked;
    },
    getAttribute(name) {
      return name === 'data-testid' ? (bookmarked ? 'removeBookmark' : 'bookmark') : null;
    }
  };
  return {
    get bookmarked() { return bookmarked; },
    set bookmarked(value) { bookmarked = value; },
    article: {
      querySelectorAll(sel) {
        if (sel === 'a[href]') {
          return [{ getAttribute: () => '/sam/status/123' }];
        }
        return [];
      },
      querySelector(sel) {
        if (sel === '[data-testid=bookmark]' && !bookmarked) return button;
        if (sel === '[data-testid=removeBookmark]' && bookmarked) return button;
        if (sel === '[data-testid=bookmark],[data-testid=removeBookmark]') return button;
        return null;
      }
    }
  };
}
const bookmarkFixture = bookmarkArticle();
const bookmarkAction = build('postActionScript', {
  k: JSON.stringify('bookmark'),
  tid: JSON.stringify('123'),
  stagedArg: 'false'
});
r = await run(bookmarkAction, {
  cookie: 'ct0=TOK',
  scripts: [BEARER_SCRIPT],
  qa: (sel) => sel === 'article[data-testid=tweet]' ? [bookmarkFixture.article] : []
});
check('bookmark delegates to x.com and confirms state',
  r.out.state === 'ok' && bookmarkFixture.bookmarked === true, JSON.stringify(r.out));
const unbookmarkFixture = bookmarkArticle();
unbookmarkFixture.bookmarked = true;
const unbookmarkAction = build('postActionScript', {
  k: JSON.stringify('unbookmark'),
  tid: JSON.stringify('123'),
  stagedArg: 'false'
});
r = await run(unbookmarkAction, {
  cookie: 'ct0=TOK',
  scripts: [BEARER_SCRIPT],
  qa: (sel) => sel === 'article[data-testid=tweet]' ? [unbookmarkFixture.article] : []
});
check('unbookmark delegates to x.com and confirms state',
  r.out.state === 'ok' && unbookmarkFixture.bookmarked === false, JSON.stringify(r.out));

r = await run(bookmarkAction, {
  cookie: 'ct0=TOK',
  scripts: [BEARER_SCRIPT],
  qa: () => []
});
check('bookmark requests hidden-route staging when the article is absent',
  r.out.state === 'staged', JSON.stringify(r.out));
r = await run(unbookmarkAction, {
  cookie: 'ct0=TOK',
  scripts: [BEARER_SCRIPT],
  qa: () => []
});
check('unbookmark requests hidden-route staging when the article is absent',
  r.out.state === 'staged', JSON.stringify(r.out));
const stagedRedirect = build('postActionScript', {
  k: JSON.stringify('bookmark'),
  tid: JSON.stringify('123'),
  stagedArg: 'true'
});
r = await run(stagedRedirect, {
  cookie: 'ct0=TOK',
  scripts: [BEARER_SCRIPT],
  qa: () => [],
  pathname: '/someone/status/456'
});
check('staged bookmark refuses a redirected status route',
  r.out.state === 'unexpected', JSON.stringify(r.out));

r = await run(scripts.dmInbox, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [inboxPath]: 401 } });
check('dm http-401 → signed-out', r.out.state === 'signed-out', r.out.state);

r = await run(scripts.dmInbox, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [inboxPath]: 500 } });
check('dm http-500', r.out.state === 'http-500', r.out.state);

r = await run(scripts.dmInbox, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [inboxPath]: { nope: 1 } } });
check('dm unexpected shape', r.out.state === 'unexpected', r.out.state);

const homePath = '/i/api/2/timeline/home.json?count=30';
r = await run(scripts.home, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [homePath]: homeV2 } });
check('home ok', r.out.state === 'ok' && r.out.posts.length === 1, JSON.stringify(r.out).slice(0, 140));
check('home post fields', r.out.posts[0]?.handle === 'sam' && r.out.posts[0]?.text === 'hello world' && r.out.next === 'CUR123');

r = await run(scripts.home, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [homePath]: {} } });
check('home no tweets → empty', r.out.state === 'empty', r.out.state);

const notifPath = '/i/api/2/notifications/all.json?count=40';
r = await run(scripts.notifications, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [notifPath]: notifV2 } });
check('notifications ok', r.out.state === 'ok' && r.out.items.length === 1, JSON.stringify(r.out).slice(0, 160));
check('notifications fields', r.out.items[0]?.kind === 'like' && r.out.items[0]?.handle === 'ned' && r.out.items[0]?.text === 'great post indeed' && r.out.items[0]?.at === 1790000000001);
check('notifications carry a target post', r.out.items[0]?.targetId === 'nt');

r = await run(scripts.notifications, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [notifPath]: { globalObjects: {}, timeline: { instructions: [] } } } });
check('notifications none → empty', r.out.state === 'empty', r.out.state);

const trendsPath = '/i/api/1.1/trends/place.json?id=1';
r = await run(scripts.trends, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [trendsPath]: trendsPayload } });
check('trends ok', r.out.state === 'ok' && r.out.trends[0]?.name === '#topic', JSON.stringify(r.out).slice(0, 80));

const taPath = '/i/api/1.1/search/typeahead.json?q=harmony&result_type=topics%2Cusers&count=12';
r = await run(scripts.search, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [taPath]: typeahead } });
check('search suggestions ok', r.out.state === 'ok' && r.out.trends[0]?.name === 'harmonyos', JSON.stringify(r.out).slice(0, 80));

// thread: conversation endpoint fixture (flat messages + system entry)
const threadFixture = {
  conversation_timeline: {
    users: {}, conversations: {},
    entries: [
      { participants_leave: { x: 1 } },
      { id: 'm1', time: '1785000000000', sender_id: 'u1', recipient_id: 'me', text: 'hey' }
    ]
  }
};
const mediaOnlyThreadFixture = {
  conversation_timeline: {
    users: {}, conversations: {},
    entries: [{
      id: 'm-media',
      time: '1785000000000',
      sender_id: 'me',
      text: '',
      message_data: {
        text: '',
        sender_id: 'me',
        attachment: {
          photo: {
            media_url_https: 'https://pbs.twimg.com/media/fixture.jpg',
            alt_text: 'Fixture image'
          }
        }
      }
    }]
  }
};
const threadPath = '/i/api/1.1/dm/conversation/c1.json?include_conversation_info=true';
r = await run(scripts.dmThread, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [threadPath]: threadFixture } });
check('thread ok skips system entries', r.out.state === 'ok' && r.out.messages.length === 1 && r.out.messages[0]?.text === 'hey', JSON.stringify(r.out).slice(0, 120));
r = await run(scripts.dmThread, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [threadPath]: mediaOnlyThreadFixture } });
check('thread keeps media-only messages',
  r.out.state === 'ok' && r.out.messages.length === 1 &&
  r.out.messages[0]?.text === '' &&
  r.out.messages[0]?.mediaUrl === 'https://pbs.twimg.com/media/fixture.jpg' &&
  r.out.messages[0]?.mediaAlt === 'Fixture image',
  JSON.stringify(r.out));

// API text is HTML-escaped: a real DM arrived as "worktrees &amp; moving" and
// rendered the entity literally until otText() was added. Same for tweet and
// notification text, which share the tweet shaper / notification reader.
const escaped = 'a &amp; b &lt;3 &quot;c&quot; d&#39;e';
const decoded = 'a & b <3 "c" d\'e';
const dmInboxEscaped = JSON.parse(JSON.stringify(dmInbox));
dmInboxEscaped.inbox_initial_state.entries[0].message.message_data.text = escaped;
r = await run(scripts.dmInbox, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [inboxPath]: dmInboxEscaped } });
check('dm preview decodes entities', r.out.conversations[0]?.text === decoded, r.out.conversations[0]?.text);

const threadEscaped = JSON.parse(JSON.stringify(threadFixture));
threadEscaped.conversation_timeline.entries[1].text = escaped;
r = await run(scripts.dmThread, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [threadPath]: threadEscaped } });
check('thread decodes entities', r.out.messages[0]?.text === decoded, r.out.messages[0]?.text);

const homeEscaped = JSON.parse(JSON.stringify(homeV2));
homeEscaped.globalObjects.tweets.t1.full_text = escaped;
r = await run(scripts.home, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [homePath]: homeEscaped } });
check('home decodes entities', r.out.posts[0]?.text === decoded, r.out.posts[0]?.text);

const notifEscaped = JSON.parse(JSON.stringify(notifV2));
notifEscaped.globalObjects.tweets.nt.full_text = escaped;
r = await run(scripts.notifications, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [notifPath]: notifEscaped } });
check('notifications decode entities', r.out.items[0]?.text === decoded, r.out.items[0]?.text);

// profile: rendered DOM fixture (hrefs/texts copied from the live profile page)
function fakeEl(props = {}) {
  return {
    innerText: props.innerText ?? '',
    src: props.src ?? '',
    getAttribute(name) { return props.attrs?.[name] ?? null; },
    getBoundingClientRect() { return props.rect ?? { width: 0, top: 0 }; },
    querySelector(sel) {
      if (sel === 'div[data-testid=tweetText]') return { innerText: props.tweetText ?? '' };
      if (sel === 'time') return { getAttribute: () => props.datetime ?? '' };
      return null;
    },
    querySelectorAll(sel) {
      if (sel === 'a[href]') return (props.links ?? []).map((l) => fakeEl({ attrs: { href: l.h } }));
      if (sel === 'button,[role=button]') return (props.btns ?? []).map((b) => fakeEl({ attrs: { 'aria-label': b } }));
      return [];
    }
  };
}
const profileDoc = {
  qs(sel) {
    if (sel === '[data-testid=UserName]') return fakeEl({ innerText: 'Abhi\n@Abhi_Flex' });
    if (sel === 'input[type=password]') return null;
    if (sel === '[data-testid=UserDescription]') return fakeEl({ innerText: 'Design bio here' });
    if (sel === 'img[src*=profile_banners]') return fakeEl({ src: 'https://x/banner.jpg' });
    return null;
  },
  qa(sel) {
    if (sel === 'a[aria-label]') {
      return [followLink('Follow', '/Abhi_Flex')];
    }
    if (sel === 'img[src*=profile_images]') {
      return [fakeEl({ src: 'https://x/small_x96.jpg', rect: { width: 40, top: 719 } }),
        fakeEl({ src: 'https://x/big_400x400.jpg', rect: { width: 134, top: 184 } })];
    }
    if (sel === 'a[href]') {
      return [fakeEl({ attrs: { href: '/Abhi_Flex/following' }, innerText: '542 Following' }),
        fakeEl({ attrs: { href: '/Abhi_Flex/verified_followers' }, innerText: '464 Followers' })];
    }
    if (sel === 'article[data-testid=tweet]') {
      return [fakeEl({
        links: [{ h: '/Abhi_Flex/status/123' }], tweetText: 'hello post', datetime: '2026-07-21T12:05:43.000Z',
        btns: ['9 Replies. Reply', '1 repost. Repost', '37 Likes. Like', 'Bookmarked']
      })];
    }
    return [];
  }
};
const profileScriptSrc = build('profileScript', { h: JSON.stringify('Abhi_Flex'), m: JSON.stringify('') });
try {
  new Function('document', 'window', 'fetch', `return (${profileScriptSrc})`);
  check('script parses: profile', true);
} catch (e) {
  check('script parses: profile', false, e.message.slice(0, 100));
}
r = await run(profileScriptSrc, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], qs: profileDoc.qs, qa: profileDoc.qa });
check('profile ok', r.out.state === 'ok', r.out.state);
check('profile header counts', r.out.user?.handle === 'Abhi_Flex' && r.out.user?.following === 542 && r.out.user?.followers === 464,
  JSON.stringify(r.out.user).slice(0, 140));
check('profile avatar picks largest', (r.out.user?.avatar ?? '').includes('400x400'), r.out.user?.avatar);
check('profile posts', r.out.posts?.length === 1 && r.out.posts[0]?.id === '123' && r.out.posts[0]?.likes === 37,
  JSON.stringify(r.out.posts).slice(0, 120));
check('profile carries bookmark state', r.out.posts?.[0]?.bookmarked === true,
  JSON.stringify(r.out.posts?.[0]));
check('profile reports the requested follow state',
  r.out.user?.followState === 'follow', JSON.stringify(r.out.user));
r = await run(profileScriptSrc, { cookie: '', scripts: [] });
check('profile no cookie → signed-out', r.out.state === 'signed-out', r.out.state);
r = await run(profileScriptSrc, {
  cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT],
  qs: () => null, qa: () => []
});
check('profile unrendered → loading', r.out.state === 'loading', r.out.state);

// Follow / unfollow uses the same rendered control x.com owns. Keep the
// fixture's link and button in the real sibling shape: the overlay link owns
// the accessible label while the button owns the click handler.
function followFixture(initial = 'follow', handle = 'Abhi_Flex', extra = false) {
  let state = initial;
  let clicks = 0;
  const button = {
    innerText: state === 'follow' ? 'Follow' : 'Following',
    textContent: '',
    getAttribute(name) {
      if (name === 'aria-label') return state === 'follow' ? 'Follow' : 'Following';
      return null;
    },
    click() {
      clicks += 1;
      state = state === 'follow' ? 'following' : 'follow';
      button.innerText = state === 'follow' ? 'Follow' : 'Following';
    }
  };
  const other = extra ? followFixture(initial, 'SomeoneElse') : null;
  const link = followLink(() => state, `/${handle}`, button);
  const otherLink = other ? other.link : null;
  return {
    link,
    otherLink,
    get state() { return state; },
    get clicks() { return clicks; },
    get otherClicks() { return other?.clicks ?? 0; }
  };
}

function followLink(labelOrGetter, href, button = null) {
  const link = {
    getAttribute(name) {
      if (name === 'aria-label') {
        return typeof labelOrGetter === 'function' ? labelOrGetter() : labelOrGetter;
      }
      if (name === 'href') return href;
      return null;
    },
    parentElement: null
  };
  const owner = {
    querySelector(selector) {
      return selector === 'button' ? button : null;
    }
  };
  link.parentElement = owner;
  return link;
}

const followAction = build('profileActionScript', {
  h: JSON.stringify('Abhi_Flex'),
  followArg: 'true',
  stagedArg: 'false'
});
const unfollowAction = build('profileActionScript', {
  h: JSON.stringify('Abhi_Flex'),
  followArg: 'false',
  stagedArg: 'false'
});
try {
  new Function('document', 'window', 'fetch', `return (${followAction})`);
  new Function('document', 'window', 'fetch', `return (${unfollowAction})`);
  check('profile action scripts parse', true);
} catch (e) {
  check('profile action scripts parse', false, e.message.slice(0, 120));
}

const followCase = followFixture('follow', 'Abhi_Flex', true);
r = await run(followAction, {
  cookie: 'ct0=TOK',
  scripts: [BEARER_SCRIPT],
  pathname: '/Abhi_Flex',
  qa: (sel) => sel === 'a[aria-label]' ? [followCase.link, followCase.otherLink].filter(Boolean) : []
});
check('follow clicks the requested profile control',
  r.out.state === 'ok' && followCase.state === 'following' && followCase.clicks === 1 &&
  followCase.otherClicks === 0,
  JSON.stringify({ out: r.out, state: followCase.state, clicks: followCase.clicks }));

const followingProfileDoc = {
  qs: profileDoc.qs,
  qa(sel) {
    if (sel === 'a[aria-label]') return [followLink('Following', '/Abhi_Flex')];
    return profileDoc.qa(sel);
  }
};
r = await run(profileScriptSrc, {
  cookie: 'ct0=TOK',
  scripts: [BEARER_SCRIPT],
  qs: followingProfileDoc.qs,
  qa: followingProfileDoc.qa
});
check('profile reports following state from rendered control',
  r.out.user?.followState === 'following', JSON.stringify(r.out.user));

const unfollowCase = followFixture('following', 'Abhi_Flex');
r = await run(unfollowAction, {
  cookie: 'ct0=TOK',
  scripts: [BEARER_SCRIPT],
  pathname: '/Abhi_Flex',
  qa: (sel) => sel === 'a[aria-label]' ? [unfollowCase.link] : []
});
check('unfollow clicks the requested profile control',
  r.out.state === 'ok' && unfollowCase.state === 'follow' && unfollowCase.clicks === 1,
  JSON.stringify({ out: r.out, state: unfollowCase.state, clicks: unfollowCase.clicks }));

const idempotentCase = followFixture('following', 'Abhi_Flex');
r = await run(followAction, {
  cookie: 'ct0=TOK',
  scripts: [BEARER_SCRIPT],
  pathname: '/Abhi_Flex',
  qa: (sel) => sel === 'a[aria-label]' ? [idempotentCase.link] : []
});
check('already-following follow is idempotent',
  r.out.state === 'ok' && idempotentCase.state === 'following' && idempotentCase.clicks === 0,
  JSON.stringify({ out: r.out, state: idempotentCase.state, clicks: idempotentCase.clicks }));

r = await run(followAction, {
  cookie: 'ct0=TOK',
  scripts: [BEARER_SCRIPT],
  pathname: '/someone-else',
  qa: () => []
});
check('follow on a different route requests staging', r.out.state === 'staged', JSON.stringify(r.out));

const stagedFollow = build('profileActionScript', {
  h: JSON.stringify('Abhi_Flex'),
  followArg: 'true',
  stagedArg: 'true'
});
r = await run(stagedFollow, {
  cookie: 'ct0=TOK',
  scripts: [BEARER_SCRIPT],
  pathname: '/SomeoneElse',
  qa: () => []
});
check('staged follow refuses a redirected profile route',
  r.out.state === 'unexpected', JSON.stringify(r.out));

// session identity: the inbox names its participants, so the signed-in account
// is the one in the most one-to-one conversations — its own entry gives handle
// + avatar. This is the source that works on routes with no account nav.
const identityScript = build('sessionIdentityScript');
const identityInboxPath = '/i/api/1.1/dm/inbox_initial_state.json?include_conversation_info=true&include_groups=true';
r = await run(identityScript, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [identityInboxPath]: dmInbox } });
check('identity from inbox', r.out.state === 'ok' && r.out.handle === 'me' && r.out.avatar.endsWith('_bigger.jpg'),
  JSON.stringify(r.out).slice(0, 140));
r = await run(identityScript, { cookie: '', scripts: [] });
check('identity signed-out', r.out.state === 'signed-out', r.out.state);
const noDm = { inbox_initial_state: { users: {}, conversations: {}, entries: [] } };
r = await run(identityScript, { cookie: 'ct0=TOK', scripts: [BEARER_SCRIPT], routes: { [identityInboxPath]: noDm } });
check('identity with empty inbox → empty', r.out.state === 'empty', r.out.state);

console.log(failed === 0 ? '\nall bridge checks passed' : `\n${failed} check(s) failed`);
process.exit(failed === 0 ? 0 : 1);
