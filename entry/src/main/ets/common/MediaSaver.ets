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

function extensionFromPath(path: string): string {
  const name: string = path.substring(path.lastIndexOf('/') + 1).toLowerCase();
  const dot: number = name.lastIndexOf('.');
  return dot < 0 ? 'jpg' : name.substring(dot + 1);
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
 * Downloads one post image into the app sandbox. The caller keeps the returned
 * path until a root-level SaveButton grants temporary media-library access.
 */
export async function prepareRemoteImage(context: common.UIAbilityContext, url: string,
  postId: string): Promise<string> {
  if (url.indexOf('https://') !== 0 || url.indexOf('pbs.twimg.com') < 0) {
    return '';
  }
  const extension: string = extensionForUrl(url);
  if (extension === '') {
    return '';
  }

  const request: http.HttpRequest = http.createHttp();
  let sourcePath: string = '';
  let sourceFile: fileIo.File | undefined = undefined;
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
      return '';
    }
    const bytes: ArrayBuffer = response.result as ArrayBuffer;
    if (bytes.byteLength <= 0 || bytes.byteLength > MAX_IMAGE_BYTES) {
      return '';
    }

    sourcePath = context.cacheDir + '/open-twit-' + safePostId(postId) + '-' +
      Date.now().toString() + '.' + extension;
    sourceFile = await fileIo.open(sourcePath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    const written: number = await fileIo.write(sourceFile.fd, bytes);
    await closeFile(sourceFile);
    sourceFile = undefined;
    if (written !== bytes.byteLength) {
      try {
        await fileIo.unlink(sourcePath);
      } catch (err) {
      }
      return '';
    }
    return sourcePath;
  } catch (error) {
    const err: BusinessError = error as BusinessError;
    hilog.warn(DOMAIN, TAG, 'image save failed: %{public}d %{public}s', err.code, err.message);
    if (sourcePath !== '') {
      try {
        await fileIo.unlink(sourcePath);
      } catch (err) {
      }
    }
    return '';
  } finally {
    await closeFile(sourceFile);
    request.destroy();
  }
}

/**
 * Commits a prepared sandbox image while the SaveButton's short-lived media
 * grant is active. The source is removed only after the request completes.
 */
export async function savePreparedImage(context: common.UIAbilityContext,
  sourcePath: string, postId: string): Promise<string> {
  if (sourcePath === '') {
    return MEDIA_SAVE_FAILED;
  }
  let helper: photoAccessHelper.PhotoAccessHelper | undefined = undefined;
  try {
    helper = photoAccessHelper.getPhotoAccessHelper(context);
    const sourceUri: string = fileUri.getUriFromPath(sourcePath);
    const assetRequest: photoAccessHelper.MediaAssetChangeRequest =
      photoAccessHelper.MediaAssetChangeRequest.createImageAssetRequest(context, sourceUri);
    try {
      await helper.applyChanges(assetRequest);
      if (assetRequest.getAsset() !== undefined && assetRequest.getAsset().uri !== '') {
        hilog.info(DOMAIN, TAG, 'image save committed with secure asset request: %{public}s', postId);
        return MEDIA_SAVE_OK;
      }
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'secure asset request fallback: %{public}d', err.code);
    }
    // On API 24 the secure save extension copies the source into MediaLibrary
    // before this promise resolves. Its returned value is an internal handle
    // (the emulator can expose the sentinel "-208"), not a path that
    // fileIo.open() may reopen. A nonempty result therefore means the
    // user-approved system save completed successfully.
    const settings: photoAccessHelper.CreationSetting = {
      title: 'OpenTwit-' + safePostId(postId),
      fileNameExtension: extensionFromPath(sourcePath),
      photoType: photoAccessHelper.PhotoType.IMAGE
    };
    const destinations: string[] = await helper.showAssetsCreationDialogEx(
      [sourceUri], [settings]);
    if (destinations.length === 0 || destinations[0] === '') {
      hilog.info(DOMAIN, TAG, 'image save canceled by user: %{public}s', postId);
      return MEDIA_SAVE_CANCELLED;
    }
    hilog.info(DOMAIN, TAG, 'image save committed by secure dialog: %{public}s', postId);
    return MEDIA_SAVE_OK;
  } catch (error) {
    const err: BusinessError = error as BusinessError;
    hilog.warn(DOMAIN, TAG, 'image save commit failed: %{public}d %{public}s', err.code, err.message);
    return MEDIA_SAVE_FAILED;
  } finally {
    if (helper !== undefined) {
      try {
        await helper.release();
      } catch (err) {
      }
    }
    try {
      await fileIo.unlink(sourcePath);
    } catch (err) {
    }
  }
}

export async function discardPreparedImage(sourcePath: string): Promise<void> {
  if (sourcePath === '') {
    return;
  }
  try {
    await fileIo.unlink(sourcePath);
  } catch (err) {
  }
}
