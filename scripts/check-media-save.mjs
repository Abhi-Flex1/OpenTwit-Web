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

let failed = 0;
function check(name, ok) {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}`);
  if (!ok) failed += 1;
}

check('downloads image bytes over NetworkKit', saver.includes("from '@kit.NetworkKit'") &&
  saver.includes('http.HttpDataType.ARRAY_BUFFER'));
check('validates response and size', saver.includes('responseCode < 200') &&
  saver.includes('bytes.byteLength > MAX_IMAGE_BYTES'));
check('writes through a sandbox file URI', saver.includes('fileUri.getUriFromPath(sourcePath)'));
check('uses native save authorization', saver.includes('showAssetsCreationDialog'));
check('does not reopen the system destination handle', !saver.includes('fileIo.copyFile') &&
  !saver.includes('fileIo.open(destinations[0]'));
check('closes files and destroys request', saver.includes('request.destroy()') &&
  saver.includes('fileIo.close(file)'));
check('always removes temporary media', saver.includes('fileIo.unlink(sourcePath)'));
check('media keeps its native aspect ratio', models.includes('mediaWidth') &&
  models.includes('mediaHeight') && chrome.includes('mediaWidth=Number(one.width||0)'));
check('post image exposes a save control', card.includes('sys.symbol.download') &&
  card.includes('post_save_image') && card.includes('savingMedia'));
check('save control is outside the post navigation target', card.includes('onOpen: () =>') &&
  card.indexOf('this.onOpen();') < card.indexOf("sys.symbol.download"));
check('Home and Profile both own the callback', home.includes('onSaveMedia') &&
  profile.includes('onSaveMedia') && main.includes('savePostImage'));
check('shell reports success and failure', main.includes('post_media_saved') &&
  main.includes('post_media_save_failed'));

console.log(failed === 0 ? '\nall media-save checks passed' : `\n${failed} check(s) failed`);
process.exit(failed === 0 ? 0 : 1);
