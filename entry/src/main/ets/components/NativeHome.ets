import { FONT_FAMILY, ROW_HEIGHT, S12, S16, S20, S4, S8 } from '../common/Theme';
import { NativePost, parsePosts, nextCursorOf, stateOf } from '../common/NativeModels';
import { NativeSignIn } from './NativeSignIn';
import { NativePostCard } from './NativePostCard';

// Home timeline: the account's real posts, newest first, paging by max_id.
// Polls only while on screen (the shell owns the timer); pull-to-refresh and
// the tab switcher both re-read from the top.
class TimelineSource implements IDataSource {
  private list: NativePost[] = [];
  private listener: DataChangeListener | undefined = undefined;

  constructor(list: NativePost[]) {
    this.list = list;
  }

  setList(list: NativePost[]): void {
    this.list = list;
    if (this.listener !== undefined) {
      this.listener.onDataReloaded();
    }
  }

  totalCount(): number {
    return this.list.length;
  }

  getData(index: number): NativePost {
    return this.list[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listener = listener;
  }

  unregisterDataChangeListener(_listener: DataChangeListener): void {
    this.listener = undefined;
  }
}

@Component
export struct NativeHome {
  @Prop @Watch('onJsonChanged') homeJson: string = '';
  @Prop homeTab: number = 0;
  @State posts: NativePost[] = [];
  @State homeState: string = 'loading';
  @State refreshing: boolean = false;
  @State loadingMore: boolean = false;
  private source: TimelineSource = new TimelineSource([]);
  onRefresh: () => void = () => {
  };
  onLoadMore: () => void = () => {
  };
  onPostAction: (kind: string, id: string) => void = () => {
  };
  onSaveMedia: (url: string, id: string) => Promise<string> = (_url: string, _id: string): Promise<string> => {
    return Promise.resolve('cancelled');
  };
  onOpenPost: (id: string) => void = () => {
  };
  onSignIn: () => void = () => {
  };

  aboutToAppear(): void {
    this.onJsonChanged();
  }

  onJsonChanged(): void {
    const state: string = stateOf(this.homeJson);
    this.homeState = state;
    if (state === 'ok') {
      const list: NativePost[] = parsePosts(this.homeJson);
      // Paged reads append on the shell side; a top refresh replaces.
      // Distinguish by cursor: if the payload carries the same head, keep it
      // simple and replace — the shell passes the merged list for paging.
      this.posts = list;
      this.source.setList(this.posts);
    } else if (state === 'loading') {
      // Keep previous posts while reloading, so a poll never blanks the list.
    } else {
      // empty / signed-out / error leave posts as-is; the state panel explains.
    }
    this.refreshing = false;
    this.loadingMore = false;
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

  build() {
    Column({ space: 0 }) {
      if (this.homeState === 'signed-out') {
        NativeSignIn({
          onSignIn: () => {
            this.onSignIn();
          }
        })
      } else if (this.homeState === 'loading' && this.posts.length === 0) {
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
      } else if ((this.homeState === 'error' || this.homeState.indexOf('http-') === 0 ||
        this.homeState === 'no-bearer' || this.homeState === 'unexpected') && this.posts.length === 0) {
        this.statePanel($r('sys.symbol.exclamationmark_circle_fill'),
          $r('app.string.home_unavailable_title'),
          $r('app.string.home_unavailable_message'), true)
      } else if ((this.homeState === 'ok' || this.homeState === 'empty') && this.posts.length === 0) {
        this.statePanel($r('sys.symbol.house_fill'),
          $r('app.string.home_empty_title'),
          $r('app.string.home_empty_message'), true)
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: 0 }) {
            LazyForEach(this.source,
              (item: NativePost) => {
                ListItem() {
                  Column({ space: 0 }) {
                    NativePostCard({
                      post: item,
                      onOpen: () => {
                        this.onOpenPost(item.id);
                      },
                      onAction: (kind: string, id: string) => {
                        this.onPostAction(kind, id);
                      },
                      onSaveMedia: (url: string) => {
                        return this.onSaveMedia(url, item.id);
                      }
                    })
                    Divider()
                      .strokeWidth(0.5)
                      .color($r('sys.color.ohos_id_color_list_separator'))
                      .margin({ left: S20 + 40 + S12 })
                  }
                  .width('100%')
                }
              }, (item: NativePost) => item.id)
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ bottom: S8 })
          .cachedCount(6)
          .edgeEffect(EdgeEffect.Spring)
          .onReachEnd(() => {
            if (!this.loadingMore && this.posts.length > 0) {
              this.loadingMore = true;
              this.onLoadMore();
              // The shell answers a page by changing the JSON prop, which resets
              // this flag. If it stays silent (end of list) the watchdog
              // releases the row instead of spinning forever.
              const stamp: number = this.posts.length;
              setTimeout(() => {
                if (this.loadingMore && this.posts.length === stamp) {
                  this.loadingMore = false;
                }
              }, 6000);
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .pullToRefresh(true)
        .onRefreshing(() => {
          this.refreshing = true;
          this.onRefresh();
        })
        if (this.loadingMore) {
          Row() {
            LoadingProgress()
              .width(28)
              .height(28)
              .color($r('sys.color.ohos_id_color_emphasize'))
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: S8, bottom: S12 })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
