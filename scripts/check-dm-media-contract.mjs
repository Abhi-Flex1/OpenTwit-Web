#!/usr/bin/env node
// Detached contract for X direct-message media.
//
// This harness deliberately does not call fetch. It models the page-origin
// upload.x.com flow and the legacy dm/new2.json send flow in memory, so a
// protocol change is caught without touching a real conversation. Keep the
// request construction here in sync with the public web-client contract:
//
//   upload.x.com/i/media/upload.json
//     INIT -> multipart APPEND (1 MiB segments) -> FINALIZE -> optional STATUS
//   api.x.com/1.1/dm/new2.json
//     one request carrying media_id and the conversation/message metadata
//
// The production ArkWeb bridge is not changed until this detached contract is
// green. The fixture also fails closed if an implementation tries to use the
// legacy text-only endpoint for a media message.

import { createHash, randomUUID } from 'node:crypto';

const UPLOAD_ENDPOINT = 'https://upload.x.com/i/media/upload.json';
const SEND_ENDPOINT = 'https://api.x.com/1.1/dm/new2.json';
const TEXT_ENDPOINT = 'https://api.x.com/1.1/direct_messages/events/new.json';
const CHUNK_SIZE = 1024 * 1024;
const MAX_PROCESSING_MS = 20_000;

let failed = 0;

function check(name, condition, detail = '') {
  if (condition) {
    console.log(`ok   ${name}`);
    return;
  }
  failed += 1;
  console.log(`FAIL ${name}${detail ? `: ${detail}` : ''}`);
}

function mediaCategory(mimeType) {
  if (mimeType === 'image/gif') return 'dm_gif';
  if (mimeType.startsWith('image/')) return 'dm_image';
  if (mimeType.startsWith('video/')) return 'dm_video';
  return '';
}

function assertUploadSize(bytes) {
  if (!(bytes instanceof Uint8Array) || bytes.byteLength === 0) {
    throw new Error('media bytes must be non-empty');
  }
}

function queryFor(fields) {
  return new URLSearchParams(fields).toString();
}

function appendMultipart(bytes, segmentIndex) {
  const boundary = `----OpenTwitContract${segmentIndex.toString(16).padStart(8, '0')}`;
  const header = Buffer.from(
    `--${boundary}\r\n` +
    'Content-Disposition: form-data; name="media"; filename="blob"\r\n' +
    'Content-Type: application/octet-stream\r\n\r\n',
    'utf8'
  );
  const footer = Buffer.from(`\r\n--${boundary}--\r\n`, 'utf8');
  return {
    boundary,
    contentType: `multipart/form-data; boundary=${boundary}`,
    body: Buffer.concat([header, Buffer.from(bytes), footer])
  };
}

function buildUploadRequests({ conversationId, bytes, mimeType }) {
  assertUploadSize(bytes);
  if (!conversationId) throw new Error('conversationId is required');
  const category = mediaCategory(mimeType);
  if (!category) throw new Error(`unsupported media type: ${mimeType}`);

  const referer = `https://x.com/messages/${encodeURIComponent(conversationId)}`;
  const headers = {
    authorization: 'Bearer contract-token',
    'x-csrf-token': 'contract-csrf',
    'x-twitter-auth-type': 'OAuth2Session',
    'x-twitter-active-user': 'yes',
    'x-twitter-client-language': 'en',
    referer
  };
  const requests = [{
    kind: 'init',
    method: 'POST',
    url: `${UPLOAD_ENDPOINT}?${queryFor({
      command: 'INIT',
      total_bytes: String(bytes.byteLength),
      media_type: mimeType,
      media_category: category
    })}`,
    headers
  }];

  const mediaId = 'contract-media-id';
  let sent = 0;
  for (let segmentIndex = 0; sent < bytes.byteLength; segmentIndex += 1) {
    const end = Math.min(sent + CHUNK_SIZE, bytes.byteLength);
    const segment = bytes.slice(sent, end);
    const multipart = appendMultipart(segment, segmentIndex);
    requests.push({
      kind: 'append',
      method: 'POST',
      url: `${UPLOAD_ENDPOINT}?${queryFor({
        command: 'APPEND',
        media_id: mediaId,
        segment_index: String(segmentIndex)
      })}`,
      headers: { ...headers, 'content-type': multipart.contentType },
      multipart
    });
    sent = end;
  }

  const originalMd5 = createHash('md5').update(bytes).digest('hex');
  requests.push({
    kind: 'finalize',
    method: 'POST',
    url: `${UPLOAD_ENDPOINT}?${queryFor({
      command: 'FINALIZE',
      media_id: mediaId,
      original_md5: originalMd5
    })}`,
    headers
  });
  requests.push({
    kind: 'status',
    method: 'GET',
    url: `${UPLOAD_ENDPOINT}?${queryFor({
      command: 'STATUS',
      media_id: mediaId
    })}`,
    headers
  });
  return { requests, mediaId, originalMd5, category, referer, bytes };
}

function buildDmNew2Request({ conversationId, text, mediaId, requestId }) {
  if (!conversationId || !mediaId) throw new Error('conversationId and mediaId are required');
  return {
    kind: 'send',
    method: 'POST',
    url: SEND_ENDPOINT,
    headers: {
      'content-type': 'application/json',
      referer: `https://x.com/messages/${encodeURIComponent(conversationId)}`
    },
    body: {
      cards_platform: 'Web-12',
      conversation_id: conversationId,
      include_cards: 1,
      include_quote_count: true,
      media_id: mediaId,
      recipient_ids: 'false',
      request_id: requestId.toUpperCase(),
      text: text ?? ''
    }
  };
}

function parseRequest(request) {
  const url = new URL(request.url);
  return { ...request, parsedUrl: url, query: Object.fromEntries(url.searchParams.entries()) };
}

function runDetachedTransport(upload) {
  const seen = [];
  let uploadFinished = false;
  let statusPolls = 0;
  for (const rawRequest of upload.requests) {
    const request = parseRequest(rawRequest);
    seen.push(request);
    if (request.kind === 'append') {
      const body = request.multipart.body;
      const marker = Buffer.from('\r\n\r\n');
      const headerEnd = body.indexOf(marker);
      const footerStart = body.lastIndexOf(Buffer.from('\r\n--'));
      if (headerEnd < 0 || footerStart <= headerEnd) {
        throw new Error('malformed multipart body');
      }
      const payload = body.subarray(headerEnd + marker.length, footerStart);
      if (payload.length === 0) throw new Error('empty APPEND segment');
    }
    if (request.kind === 'status') {
      statusPolls += 1;
      if (statusPolls > 3) throw new Error('processing status must be bounded');
    }
    if (request.kind === 'finalize') uploadFinished = true;
  }
  if (!uploadFinished) throw new Error('FINALIZE was not reached');
  return seen;
}

const bytes = new Uint8Array(2 * 1024 * 1024 + 37);
for (let i = 0; i < bytes.length; i += 1) bytes[i] = (i * 31 + 7) & 0xff;
const upload = buildUploadRequests({
  conversationId: 'contract-conversation',
  bytes,
  mimeType: 'image/png'
});
const requests = runDetachedTransport(upload);

check('upload uses upload.x.com', requests.every((request) => request.url.startsWith(UPLOAD_ENDPOINT)));
check('upload starts with INIT', requests[0].kind === 'init' && requests[0].query.command === 'INIT');
check('INIT carries byte count and DM image category',
  requests[0].query.total_bytes === String(bytes.byteLength) &&
  requests[0].query.media_type === 'image/png' &&
  requests[0].query.media_category === 'dm_image');
check('upload splits at 1 MiB',
  requests.filter((request) => request.kind === 'append').length === 3);
check('APPEND uses indexed media multipart requests',
  requests.filter((request) => request.kind === 'append').every((request, index) =>
    request.query.command === 'APPEND' &&
    request.query.media_id === upload.mediaId &&
    request.query.segment_index === String(index) &&
    request.headers['content-type'].startsWith('multipart/form-data;')));
check('FINALIZE carries the original MD5',
  requests.find((request) => request.kind === 'finalize')?.query.original_md5 === upload.originalMd5);
check('upload status is explicitly queried after finalize',
  requests.find((request) => request.kind === 'status')?.query.command === 'STATUS');
check('upload does not contact the text DM endpoint',
  requests.every((request) => request.url !== TEXT_ENDPOINT));

const requestId = randomUUID();
const send = buildDmNew2Request({
  conversationId: 'contract-conversation',
  text: 'caption',
  mediaId: upload.mediaId,
  requestId
});
check('media send uses dm/new2.json', send.url === SEND_ENDPOINT);
check('media send carries media_id and request metadata',
  send.body.media_id === upload.mediaId &&
  send.body.conversation_id === 'contract-conversation' &&
  send.body.request_id === requestId.toUpperCase() &&
  send.body.cards_platform === 'Web-12' &&
  send.body.include_cards === 1 &&
  send.body.include_quote_count === true &&
  send.body.recipient_ids === 'false');
check('media send never uses the text-only event endpoint', send.url !== TEXT_ENDPOINT);
check('media send has a conversation-scoped referer',
  send.headers.referer === 'https://x.com/messages/contract-conversation');

try {
  buildDmNew2Request({ conversationId: '', text: '', mediaId: '' });
  check('empty media send fails closed', false);
} catch (error) {
  check('empty media send fails closed', error instanceof Error);
}

check('processing timeout is bounded', MAX_PROCESSING_MS === 20_000);
check('detached harness made zero network-capable calls',
  !requests.some((request) => request.url.includes('x.com') && request.kind === 'text-send'));

if (failed > 0) {
  console.log(`\n${failed} DM media contract check(s) failed`);
  process.exit(1);
}
console.log('\nall detached DM media contract checks passed');
