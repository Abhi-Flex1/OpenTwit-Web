import { FONT_FAMILY, ROW_HEIGHT, S12, S16, S20, S4, S8 } from '../common/Theme';
import { NativeNotificationItem, relativeTime, stateOf } from '../common/NativeModels';
import { NativeSignIn } from './NativeSignIn';

interface BridgeNotifItem {
  id: string;
  targetId: string;
  kind: string;
  name: string;
  handle: string;
  avatar: string;
  text: string;
  at: number;
}

interface BridgeNotifPayload {
  state: string;
  items?: BridgeNotifItem[];
}

// Notifications: likes, reposts, follows, mentions and replies, straight off
// the account's own notification list. Polls while on screen; the shell clears
// the tab badge while this tab is open, like the stock app.
@Component
export struct NativeNotifications {
  @Prop @Watch('onJsonChanged') notifJson: string = '';
  @State items: NativeNotificationItem[] = [];
  @State notifState: string = 'loading';
  @State refreshing: boolean = false;
  onRefresh: () => void = () => {
  };
  onOpenItem: (id: string, targetId: string) => void = () => {
  };
  onSignIn: () => void = () => {
  };

  aboutToAppear(): void {
    this.onJsonChanged();
  }

  onJsonChanged(): void {
    const state: string = stateOf(this.notifJson);
    this.notifState = state;
    if (state === 'ok') {
      try {
        const payload = JSON.parse(this.notifJson) as BridgeNotifPayload;
        const out: NativeNotificationItem[] = [];
        const src: BridgeNotifItem[] = payload.items ?? [];
        for (let i: number = 0; i < src.length; i++) {
          const n: BridgeNotifItem = src[i];
          if (!n) {
            continue;
          }
          out.push({
            id: n.id ?? ('n-' + i),
            targetId: n.targetId ?? '',
            kind: n.kind ?? 'mention',
            name: n.name ?? '',
            handle: n.handle ?? '',
            avatar: n.avatar ?? '',
            text: n.text ?? '',
            at: n.at ?? 0,
            time: relativeTime(n.at ?? 0)
          });
        }
        this.items = out;
      } catch (err) {
        this.items = [];
      }
    }
    this.refreshing = false;
  }

  private kindSymbol(kind: string): Resource {
    if (kind === 'like') {
      return $r('sys.symbol.heart_fill');
    } else if (kind === 'repost') {
      return $r('sys.symbol.repeat');
    } else if (kind === 'follow') {
      return $r('sys.symbol.person_badge_plus');
    }
    return $r('sys.symbol.message_fill');
  }

  private kindLabel(kind: string): Resource {
    if (kind === 'like') {
      return $r('app.string.notif_liked');
    } else if (kind === 'repost') {
      return $r('app.string.notif_reposted');
    } else if (kind === 'follow') {
      return $r('app.string.notif_followed');
    } else if (kind === 'reply') {
      return $r('app.string.notif_replied');
    } else if (kind === 'quote') {
      return $r('app.string.notif_quoted');
    }
    return $r('app.string.notif_mentioned');
  }

  private initials(name: string): string {
    let result: string = '';
    const words: string[] = name.split(' ');
    for (let i: number = 0; i < words.length && result.length < 2; i++) {
      const word: string = words[i].trim();
      if (word.length > 0) {
        result += word.charAt(0).toUpperCase();
      }
    }
    return result === '' ? '?' : result;
  }

  @Builder
  statePanel(symbol: Resource, title: Resource, message: Resource, showRetry: boolean) {
    Column({ space: S8 }) {
      SymbolGlyph(symbol)
        .fontSize(44)
        .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
      Text(title)
        .fontSize(17)
        .fontFamily(FONT_FAMILY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
      Text(message)
        .fontSize(14)
        .fontFamily(FONT_FAMILY)
        .textAlign(TextAlign.Center)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      if (showRetry) {
        Button($r('app.string.retry'))
          .type(ButtonType.Capsule)
          .fontFamily(FONT_FAMILY)
          .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
          .margin({ top: S8 })
          .onClick(() => {
            this.refreshing = true;
            this.onRefresh();
          })
      }
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(S16)
  }

  @Builder
  row(item: NativeNotificationItem) {
    ListItem() {
      Row({ space: S12 }) {
        Stack() {
          SymbolGlyph(this.kindSymbol(item.kind))
            .fontSize(20)
            .fontColor([$r('sys.color.ohos_id_color_emphasize')])
            .width(40)
            .height(40)
            .accessibilityLevel('no')
          if (item.avatar !== '') {
            Image(item.avatar)
              .width(28)
              .height(28)
              .borderRadius(14)
              .objectFit(ImageFit.Cover)
              .align(Alignment.BottomEnd)
              .offset({ x: 8, y: 8 })
          }
        }
        .width(48)
        .height(48)
        Column({ space: S4 }) {
          Row({ space: S4 }) {
            Text(item.name !== '' ? item.name : ('@' + item.handle))
              .fontSize(15)
              .fontFamily(FONT_FAMILY)
              .fontWeight(FontWeight.Medium)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .layoutWeight(1)
            if (item.time !== '') {
              Text(item.time)
                .fontSize(12)
                .fontFamily(FONT_FAMILY)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            }
          }
          .width('100%')
          Text(this.kindLabel(item.kind))
            .fontSize(13)
            .fontFamily(FONT_FAMILY)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          if (item.text !== '') {
            Text(item.text)
              .fontSize(14)
              .fontFamily(FONT_FAMILY)
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .constraintSize({ minHeight: ROW_HEIGHT })
      .padding({ left: S20, right: S20, top: S12, bottom: S12 })
      .alignItems(VerticalAlign.Top)
      .onClick(() => {
        this.onOpenItem(item.id, item.targetId);
      })
    }
  }

  build() {
    Column({ space: 0 }) {
      if (this.notifState === 'signed-out') {
        NativeSignIn({
          onSignIn: () => {
            this.onSignIn();
          }
        })
      } else if (this.notifState === 'loading' && this.items.length === 0) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color($r('sys.color.ohos_id_color_emphasize'))
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if ((this.notifState === 'error' || this.notifState.indexOf('http-') === 0 ||
        this.notifState === 'no-bearer' || this.notifState === 'unexpected') && this.items.length === 0) {
        this.statePanel($r('sys.symbol.exclamationmark_circle_fill'),
          $r('app.string.notif_unavailable_title'),
          $r('app.string.notif_unavailable_message'), true)
      } else if (this.items.length === 0) {
        this.statePanel($r('sys.symbol.bell_fill'),
          $r('app.string.notif_empty_title'),
          $r('app.string.notif_empty_message'), true)
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: 0 }) {
            ForEach(this.items, (item: NativeNotificationItem) => {
              this.row(item)
            }, (item: NativeNotificationItem) => item.id)
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ bottom: S8 })
          .edgeEffect(EdgeEffect.Spring)
          .cachedCount(8)
        }
        .width('100%')
        .layoutWeight(1)
        .pullToRefresh(true)
        .onRefreshing(() => {
          this.refreshing = true;
          this.onRefresh();
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
