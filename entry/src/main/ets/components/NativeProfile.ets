import { FONT_FAMILY, RADIUS_SM, S12, S16, S20, S4, S8 } from '../common/Theme';
import { NativePost, NativeProfileUser, parsePosts, stateOf, formatCount } from '../common/NativeModels';
import { BridgePost } from '../common/NativeModels';
import { NativePostCard } from './NativePostCard';
import { NativeSignIn } from './NativeSignIn';

interface BridgeProfileUser {
  name: string;
  handle: string;
  avatar: string;
  banner: string;
  bio: string;
  location: string;
  followers: number;
  following: number;
  posts: number;
  at: number;
}

interface BridgeProfilePayload {
  state: string;
  user?: BridgeProfileUser;
  posts?: BridgePost[];
}

class ProfilePostsSource implements IDataSource {
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

// Profile: header drawn from the account's real user object plus its recent
// posts. The shell passes the viewing handle; the payload carries the user.
@Component
export struct NativeProfile {
  @Prop @Watch('onJsonChanged') profileJson: string = '';
  @Prop viewingHandle: string = '';
  @Prop isOwnProfile: boolean = false;
  @State user: NativeProfileUser | undefined = undefined;
  @State posts: NativePost[] = [];
  @State profileState: string = 'loading';
  @State refreshing: boolean = false;
  @State loadingMore: boolean = false;
  private source: ProfilePostsSource = new ProfilePostsSource([]);
  onRefresh: () => void = () => {
  };
  onLoadMore: () => void = () => {
  };
  onPostAction: (kind: string, id: string) => void = () => {
  };
  onOpenPost: (id: string) => void = (_id: string) => {
  };
  onSaveMedia: (url: string, id: string) => Promise<string> = (_url: string, _id: string): Promise<string> => {
    return Promise.resolve('cancelled');
  };
  onEditProfile: () => void = () => {
  };
  onSignIn: () => void = () => {
  };

  aboutToAppear(): void {
    this.onJsonChanged();
  }

  onJsonChanged(): void {
    const state: string = stateOf(this.profileJson);
    this.profileState = state;
    if (state === 'ok') {
      try {
        const payload = JSON.parse(this.profileJson) as BridgeProfilePayload;
        if (payload.user) {
          this.user = {
            name: payload.user.name ?? '',
            handle: payload.user.handle ?? this.viewingHandle,
            avatar: payload.user.avatar ?? '',
            banner: payload.user.banner ?? '',
            bio: payload.user.bio ?? '',
            location: payload.user.location ?? '',
            followers: payload.user.followers ?? 0,
            following: payload.user.following ?? 0,
            posts: payload.user.posts ?? 0,
            at: payload.user.at ?? 0
          };
        }
        const list: NativePost[] = parsePosts(this.profileJson);
        this.posts = list;
        this.source.setList(list);
      } catch (err) {
      }
    }
    this.refreshing = false;
    this.loadingMore = false;
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
  header() {
    Column({ space: 0 }) {
      // Banner: real image when the account has one, system fill otherwise.
      Stack() {
        if (this.user !== undefined && this.user.banner !== '') {
          Image(this.user.banner)
            .width('100%')
            .height(120)
            .objectFit(ImageFit.Cover)
        } else {
          Column()
            .width('100%')
            .height(120)
            .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        }
      }
      .width('100%')
      .height(120)
      Column({ space: S4 }) {
        Row({ space: S12 }) {
          Stack() {
            Circle()
              .width(68)
              .height(68)
              .fill($r('sys.color.ohos_id_color_emphasize'))
            Text(this.initials(this.user !== undefined ? this.user.name : ''))
              .fontSize(22)
              .fontFamily(FONT_FAMILY)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.ohos_id_color_foreground_contrary'))
            if (this.user !== undefined && this.user.avatar !== '') {
              Image(this.user.avatar)
                .width(68)
                .height(68)
                .borderRadius(34)
                .objectFit(ImageFit.Cover)
            }
          }
          .width(68)
          .height(68)
          .margin({ top: -34 })
          .border({ width: 3, color: $r('sys.color.ohos_id_color_background') })
          .borderRadius(34)
          Blank()
          if (this.isOwnProfile) {
            Button($r('app.string.profile_edit'))
              .type(ButtonType.Capsule)
              .fontFamily(FONT_FAMILY)
              .fontSize(14)
              .onClick(() => {
                this.onEditProfile();
              })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
        if (this.user !== undefined) {
          Text(this.user.name !== '' ? this.user.name : '@' + this.user.handle)
            .fontSize(20)
            .fontFamily(FONT_FAMILY)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
          Text('@' + this.user.handle)
            .fontSize(14)
            .fontFamily(FONT_FAMILY)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          if (this.user.bio !== '') {
            Text(this.user.bio)
              .fontSize(14)
              .fontFamily(FONT_FAMILY)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
          }
          Row({ space: S16 }) {
            Row({ space: S4 }) {
              Text(formatCount(this.user.following) === '' ? '0' : formatCount(this.user.following))
                .fontSize(14)
                .fontFamily(FONT_FAMILY)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
              Text($r('app.string.profile_following'))
                .fontSize(13)
                .fontFamily(FONT_FAMILY)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            }
            Row({ space: S4 }) {
              Text(formatCount(this.user.followers) === '' ? '0' : formatCount(this.user.followers))
                .fontSize(14)
                .fontFamily(FONT_FAMILY)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
              Text($r('app.string.profile_followers'))
                .fontSize(13)
                .fontFamily(FONT_FAMILY)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            }
          }
          .padding({ top: S4 })
        }
      }
      .width('100%')
      .padding({ left: S20, right: S20, bottom: S12 })
      .alignItems(HorizontalAlign.Start)
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.ohos_id_color_list_separator'))
    }
    .width('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }

  build() {
    Column({ space: 0 }) {
      if (this.profileState === 'signed-out') {
        NativeSignIn({
          onSignIn: () => {
            this.onSignIn();
          }
        })
      } else if (this.profileState === 'loading' && this.user === undefined) {
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
      } else if ((this.profileState === 'error' || this.profileState.indexOf('http-') === 0 ||
        this.profileState === 'no-bearer' || this.profileState === 'unexpected') && this.user === undefined) {
        this.statePanel($r('sys.symbol.exclamationmark_circle_fill'),
          $r('app.string.profile_unavailable_title'),
          $r('app.string.profile_unavailable_message'), true)
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: 0 }) {
            ListItem() {
              this.header()
            }
            LazyForEach(this.source, (item: NativePost) => {
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
            if (this.posts.length === 0) {
              ListItem() {
                Column({ space: S8 }) {
                  SymbolGlyph($r('sys.symbol.message_fill'))
                    .fontSize(36)
                    .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                  Text($r('app.string.profile_no_posts'))
                    .fontSize(14)
                    .fontFamily(FONT_FAMILY)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                }
                .width('100%')
                .padding(S20)
                .alignItems(HorizontalAlign.Center)
              }
            }
          }
          .layoutWeight(1)
          .width('100%')
          .cachedCount(4)
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
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
