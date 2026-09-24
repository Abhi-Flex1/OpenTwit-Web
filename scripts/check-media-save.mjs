#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (path) => readFileSync(join(root, path), 'utf8');
const saver = read('entry/src/main/ets/common/MediaSaver.ets');
const card = read('entry/src/main/ets/components/NativePostCard.ets');
const home = read('entry/src/main/ets/components/NativeHome.ets');
const profile = read('entry/src/main/ets/components/NativeProfile.ets');
const main = read('entry/src/main/ets/pages/MainTabs.ets');
const models = read('entry/src/main/ets/common/NativeModels.ets');
const chrome = read('entry/src/main/ets/common/WebChrome.ets');
const manifest = read('entry/src/main/module.json5');

let failed = 0;
function check(name, ok) {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}`);
  if (!ok) failed += 1;
}

check('downloads image bytes over NetworkKit', saver.includes("from '@kit.NetworkKit'") &&
  saver.includes('http.HttpDataType.ARRAY_BUFFER'));
check('validates response and size', saver.includes('responseCode < 200') &&
  saver.includes('bytes.byteLength > MAX_IMAGE_BYTES'));
check('uses the secure SaveButton authorization path', main.includes('SaveButton') &&
  main.includes('SaveButtonOnClickResult.SUCCESS'));
check('does not request broad media-library access for SaveButton',
  !manifest.includes('ohos.permission.WRITE_IMAGEVIDEO') &&
  !manifest.includes('ohos.permission.READ_IMAGEVIDEO'));
check('creates the authorized media asset from the sandbox URI',
  saver.includes('createImageAssetRequest(context, sourceUri)') &&
  saver.includes('helper.applyChanges(assetRequest)'));
check('falls back to the API 24 creation dialog when applyChanges fails',
  saver.includes('showAssetsCreationDialogEx') &&
  saver.includes('destinations.length === 0'));
check('does not reopen the secure destination handle',
  !saver.includes('fileIo.open(destinations[0])') &&
  saver.includes('fileIo.unlink(sourcePath)'));
check('closes files and destroys request', saver.includes('request.destroy()') &&
  saver.includes('fileIo.close(file)'));
check('always removes temporary media', saver.includes('fileIo.unlink(sourcePath)'));
check('media keeps its native aspect ratio', models.includes('mediaWidth') &&
  models.includes('mediaHeight') && chrome.includes('mediaWidth=Number(one.width||0)'));
check('post image exposes a download target', card.includes('post-media-save-') &&
  card.includes('savingMedia') && card.includes('sys.symbol.download'));
check('secure save control is outside post rows', main.includes('mediaSaveSheetView') &&
  main.includes('bindSheet($$this.mediaSaveSheet'));
check('save sheet exposes a ready state', main.includes('post_media_ready') &&
  main.includes('this.mediaSaveReady'));
check('save authorization failures remain retryable', main.includes('TEMPORARY_AUTHORIZATION_FAILED') &&
  main.includes('userCancelEvent(true)'));
check('overlapping media saves are ignored', main.includes('mediaSaveDownloading') &&
  main.includes('mediaSaveSheet') && main.includes('mediaSavePath'));
check('prepared save data is cleaned when the sheet disappears',
  main.includes('onDisAppear') && main.includes('cancelPreparedImage()'));
check('Home and Profile both own the callback', home.includes('onSaveMedia') &&
  profile.includes('onSaveMedia') && main.includes('savePostImage'));
check('shell reports success and failure', main.includes('post_media_saved') &&
  main.includes('post_media_save_failed'));

console.log(failed === 0 ? '\nall media-save checks passed' : `\n${failed} check(s) failed`);
process.exit(failed === 0 ? 0 : 1);
