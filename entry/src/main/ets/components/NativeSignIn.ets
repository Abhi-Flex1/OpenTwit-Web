import { FONT_FAMILY, S12, S16, S2, S20, S4, S8 } from '../common/Theme';

// The sign-in screen. Shown instead of an empty list wherever the account is
// signed out. It explains what signing in unlocks and hands off to the real
// x.com login flow; the shell reveals the session WebView for that and hides
// it again once the account appears. Nothing here collects credentials — the
// app never sees a password.
@Component
export struct NativeSignIn {
  onSignIn: () => void = () => {
  };

  @Builder
  benefit(symbol: Resource, title: Resource, message: Resource) {
    Row({ space: S12 }) {
      Stack() {
        Circle()
          .width(44)
          .height(44)
          .fill($r('sys.color.ohos_id_color_sub_background'))
        SymbolGlyph(symbol)
          .fontSize(20)
          .fontColor([$r('sys.color.ohos_id_color_emphasize')])
          .accessibilityLevel('no')
      }
      .width(44)
      .height(44)
      Column({ space: S2 }) {
        Text(title)
          .fontSize(15)
          .fontFamily(FONT_FAMILY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
        Text(message)
          .fontSize(13)
          .fontFamily(FONT_FAMILY)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column({ space: 0 }) {
      Blank()
      Image($r('app.media.app_icon'))
        .width(72)
        .height(72)
        .borderRadius(16)
      Text($r('app.string.signin_title'))
        .fontSize(22)
        .fontFamily(FONT_FAMILY)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ top: S16 })
      Text($r('app.string.signin_message'))
        .fontSize(14)
        .fontFamily(FONT_FAMILY)
        .textAlign(TextAlign.Center)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .margin({ top: S8, bottom: S20 })
      Column({ space: S12 }) {
        this.benefit($r('sys.symbol.house_fill'),
          $r('app.string.signin_benefit_home'), $r('app.string.signin_benefit_home_desc'))
        this.benefit($r('sys.symbol.bell_fill'),
          $r('app.string.signin_benefit_notif'), $r('app.string.signin_benefit_notif_desc'))
        this.benefit($r('sys.symbol.envelope_fill'),
          $r('app.string.signin_benefit_messages'), $r('app.string.signin_benefit_messages_desc'))
      }
      .width('100%')
      .padding({ left: S20, right: S20 })
      Button($r('app.string.signin_button'))
        .type(ButtonType.Capsule)
        .width('calc(100% - 40vp)')
        .height(48)
        .fontSize(17)
        .fontFamily(FONT_FAMILY)
        .fontWeight(FontWeight.Medium)
        .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
        .margin({ top: S20 })
        .onClick(() => {
          this.onSignIn();
        })
      Text($r('app.string.signin_note'))
        .fontSize(12)
        .fontFamily(FONT_FAMILY)
        .textAlign(TextAlign.Center)
        .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        .margin({ top: S12 })
        .padding({ left: S20, right: S20 })
      Blank()
    }
    .width('100%')
    .height('100%')
    .padding({ left: S20, right: S20, top: S12, bottom: S12 })
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
