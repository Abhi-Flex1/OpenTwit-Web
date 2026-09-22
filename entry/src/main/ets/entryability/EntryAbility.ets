import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import web_webview from '@ohos.web.webview';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    this.enableWebDevToolsForDebugBuilds();
  }

  // ArkWeb's DevTools bridge is what `hdc fport` + CDP attach to. It is a
  // debugging surface, so it is switched on only for a debug build and stays
  // off in anything signed for release.
  private enableWebDevToolsForDebugBuilds(): void {
    if (!this.context.applicationInfo.debug) {
      return;
    }
    try {
      web_webview.WebviewController.setWebDebuggingAccess(true);
      hilog.info(DOMAIN, 'testTag', '%{public}s', 'Web DevTools enabled (debug build)');
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.warn(DOMAIN, 'testTag', 'setWebDebuggingAccess failed: %{public}d %{public}s', e.code, e.message);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    windowStage.loadContent('pages/MainTabs', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
      }
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }
}
