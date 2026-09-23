import { FONT_FAMILY, RADIUS_SM, S12, S16, S20, S4, S8 } from '../common/Theme';
import { NativePost, formatCount } from '../common/NativeModels';

// One post everywhere: Home, Profile, Explore results and quoted mentions all
// draw the same row, so a timeline looks like one product rather than four.
@Component
export struct NativePostCard {
  @Prop post: NativePost = {
    id: '', name: '', handle: '', avatar: '', text: '', at: 0, time: '',
    likes: 0, reposts: 0, replies: 0, liked: false, reposted: false, media: ''
  };
  onAction: (kind: string, id: string) => void = () => {
  };

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
  avatar() {
    Stack() {
      Circle()
        .width(40)
        .height(40)
        .fill($r('sys.color.ohos_id_color_emphasize'))
      Text(this.initials(this.post.name))
        .fontSize(14)
        .fontFamily(FONT_FAMILY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_foreground_contrary'))
      if (this.post.avatar !== '') {
        Image(this.post.avatar)
          .width(40)
          .height(40)
          .borderRadius(20)
          .objectFit(ImageFit.Cover)
          .alt($r('sys.color.ohos_id_color_sub_background'))
      }
    }
    .width(40)
    .height(40)
    .accessibilityLevel('no')
  }

  @Builder
  actionButton(symbol: Resource, count: number, active: boolean, label: Resource, kind: string) {
    Row({ space: S4 }) {
      SymbolGlyph(symbol)
        .fontSize(17)
        .fontColor([active
          ? $r('sys.color.ohos_id_color_emphasize')
          : $r('sys.color.ohos_id_color_text_secondary')])
        .accessibilityLevel('no')
      if (count > 0) {
        Text(formatCount(count))
          .fontSize(13)
          .fontFamily(FONT_FAMILY)
          .fontColor(active
            ? $r('sys.color.ohos_id_color_emphasize')
            : $r('sys.color.ohos_id_color_text_secondary'))
      }
    }
    .padding({ top: S4, bottom: S4, right: S8 })
    .accessibilityText(label)
    .accessibilityLevel('yes')
    .onClick(() => {
      this.onAction(kind, this.post.id);
    })
  }

  build() {
    Column({ space: S8 }) {
      Row({ space: S12 }) {
        this.avatar()
        Column({ space: S4 }) {
          Row({ space: S4 }) {
            Text(this.post.name !== '' ? this.post.name : '@' + this.post.handle)
              .fontSize(15)
              .fontFamily(FONT_FAMILY)
              .fontWeight(FontWeight.Medium)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .layoutWeight(1)
            if (this.post.time !== '') {
              Text(this.post.time)
                .fontSize(13)
                .fontFamily(FONT_FAMILY)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          if (this.post.handle !== '') {
            Text('@' + this.post.handle)
              .fontSize(13)
              .fontFamily(FONT_FAMILY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
          if (this.post.text !== '') {
            Text(this.post.text)
              .fontSize(15)
              .fontFamily(FONT_FAMILY)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .width('100%')
          }
          if (this.post.media !== '') {
            Image(this.post.media)
              .width('100%')
              .aspectRatio(16 / 9)
              .borderRadius(RADIUS_SM)
              .objectFit(ImageFit.Cover)
              .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
          }
          Row({ space: S16 }) {
            this.actionButton($r('sys.symbol.message_fill'), this.post.replies, false,
              $r('app.string.post_reply'), 'reply')
            this.actionButton($r('sys.symbol.repeat'), this.post.reposts, this.post.reposted,
              $r('app.string.post_repost'), this.post.reposted ? 'unrepost' : 'repost')
            this.actionButton($r('sys.symbol.heart_fill'), this.post.likes, this.post.liked,
              $r('app.string.post_like'), this.post.liked ? 'unlike' : 'like')
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding({ top: S4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding({ left: S20, right: S20, top: S12, bottom: S12 })
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
