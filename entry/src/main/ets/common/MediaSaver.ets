import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0A12;
const TAG: string = 'OpenTwitMedia';
const MAX_IMAGE_BYTES: number = 50 * 1024 * 1024;
const CONNECT_TIMEOUT_MS: number = 15000;
const READ_TIMEOUT_MS: number = 45000;

export const MEDIA_SAVE_OK: string = 'ok';
export const MEDIA_SAVE_CANCELLED: string = 'cancelled';
export const MEDIA_SAVE_FAILED: string = 'failed';

function extensionForUrl(url: string): string {
  const withoutQuery: string = url.split('?')[0].split('#')[0].toLowerCase();
  const slash: number = withoutQuery.lastIndexOf('/');
  const name: string = slash >= 0 ? withoutQuery.substring(slash + 1) : withoutQuery;
  const dot: number = name.lastIndexOf('.');
  if (dot < 0 || dot === name.length - 1) {
    return 'jpg';
  }
  const extension: string = name.substring(dot + 1);
  if (extension === 'jpg' || extension === 'jpeg' || extension === 'png' ||
    extension === 'webp' || extension === 'gif') {
    return extension === 'jpeg' ? 'jpg' : extension;
  }
  return '';
}

function safePostId(postId: string): string {
  let result: string = '';
  for (let i: number = 0; i < postId.length && result.length < 32; i++) {
    const ch: string = postId.charAt(i);
    if ((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') || ch === '_' || ch === '-') {
      result += ch;
    }
  }
  return result === '' ? 'post' : result;
}

async function closeFile(file: fileIo.File | undefined): Promise<void> {
  if (file === undefined) {
    return;
  }
  try {
    await fileIo.close(file);
  } catch (err) {
  }
}

/**
 * Downloads one post image and asks HarmonyOS for a user-approved media-library
 * destination. The temporary app-sandbox file is always removed afterwards.
 */
export async function saveRemoteImage(context: common.UIAbilityContext, url: string,
  postId: string): Promise<string> {
  if (url.indexOf('https://') !== 0 || url.indexOf('pbs.twimg.com') < 0) {
    return MEDIA_SAVE_FAILED;
  }
  const extension: string = extensionForUrl(url);
  if (extension === '') {
    return MEDIA_SAVE_FAILED;
  }

  const request: http.HttpRequest = http.createHttp();
  let sourcePath: string = '';
  let sourceFile: fileIo.File | undefined = undefined;
  let destinationFile: fileIo.File | undefined = undefined;
  let helper: photoAccessHelper.PhotoAccessHelper | undefined = undefined;
  try {
    const response: http.HttpResponse = await request.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      usingCache: false,
      connectTimeout: CONNECT_TIMEOUT_MS,
      readTimeout: READ_TIMEOUT_MS,
      maxLimit: MAX_IMAGE_BYTES
    });
    if (response.responseCode < 200 || response.responseCode >= 300 ||
      response.resultType !== http.HttpDataType.ARRAY_BUFFER) {
      return MEDIA_SAVE_FAILED;
    }
    const bytes: ArrayBuffer = response.result as ArrayBuffer;
    if (bytes.byteLength <= 0 || bytes.byteLength > MAX_IMAGE_BYTES) {
      return MEDIA_SAVE_FAILED;
    }

    sourcePath = context.cacheDir + '/open-twit-' + safePostId(postId) + '-' +
      Date.now().toString() + '.' + extension;
    sourceFile = await fileIo.open(sourcePath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    const written: number = await fileIo.write(sourceFile.fd, bytes);
    await closeFile(sourceFile);
    sourceFile = undefined;
    if (written !== bytes.byteLength) {
      return MEDIA_SAVE_FAILED;
    }

    helper = photoAccessHelper.getPhotoAccessHelper(context);
    const config: photoAccessHelper.PhotoCreationConfig = {
      title: 'OpenTwit-' + safePostId(postId),
      fileNameExtension: extension,
      photoType: photoAccessHelper.PhotoType.IMAGE,
      subtype: photoAccessHelper.PhotoSubtype.DEFAULT
    };
    const destinations: string[] =
      await helper.showAssetsCreationDialog([fileUri.getUriFromPath(sourcePath)], [config]);
    if (destinations.length === 0 || destinations[0] === '') {
      return MEDIA_SAVE_CANCELLED;
    }

    destinationFile = await fileIo.open(destinations[0], fileIo.OpenMode.READ_WRITE);
    sourceFile = await fileIo.open(sourcePath, fileIo.OpenMode.READ_ONLY);
    await fileIo.copyFile(sourceFile.fd, destinationFile.fd);
    await closeFile(sourceFile);
    sourceFile = undefined;
    await closeFile(destinationFile);
    destinationFile = undefined;
    return MEDIA_SAVE_OK;
  } catch (error) {
    const err: BusinessError = error as BusinessError;
    hilog.warn(DOMAIN, TAG, 'image save failed: %{public}d %{public}s', err.code, err.message);
    return MEDIA_SAVE_FAILED;
  } finally {
    await closeFile(sourceFile);
    await closeFile(destinationFile);
    request.destroy();
    if (helper !== undefined) {
      try {
        await helper.release();
      } catch (err) {
      }
    }
    if (sourcePath !== '') {
      try {
        await fileIo.unlink(sourcePath);
      } catch (err) {
      }
    }
  }
}
