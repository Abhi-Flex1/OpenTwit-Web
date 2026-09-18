import router from '@ohos.router';
import { TokenStore } from '../common/TokenStore';
import { FONT_FAMILY } from '../common/Theme';

@Component
export struct Profile {
  @State handle: string = '';

  async loadHandle(): Promise<void> {
    try {
      this.handle = await TokenStore.loadHandle(getContext(this));
    } catch (e) {
      this.handle = '';
    }
  }

  aboutToAppear(): void {
    this.loadHandle();
  }

  build() {
    Navigation() {
      Column({ space: 0 }) {
        Stack({ alignContent: Alignment.BottomStart }) {
          Column()
            .width('100%')
            .height(120)
            .backgroundColor($r('app.color.hw_primary'));
          Row({ space: 12 }) {
            Stack({ alignContent: Alignment.Center }) {
              Circle({ width: 72, height: 72 })
                .fill($r('app.color.hw_primary'))
                .border({ width: 3, color: Color.White })
              Text(this.handle.length > 1 ? this.handle.charAt(1).toUpperCase() : '')
                .fontSize(28)
                .fontColor(Color.White)
                .fontFamily(FONT_FAMILY);
            }
          }
          .padding({ left: 16, bottom: 12 })
          .align(Alignment.BottomStart);
        }
        .width('100%')
        .height(140);

        Column({ space: 6 }) {
          if (this.handle === '') {
            Text('Not signed in')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontFamily(FONT_FAMILY);
          } else {
            Text(this.handle)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontFamily(FONT_FAMILY);
            Text(this.handle)
              .fontSize(14)
              .fontColor($r('app.color.hw_text_grey'))
              .fontFamily(FONT_FAMILY);
          }
          Button('Sign in')
            .fontFamily(FONT_FAMILY)
            .margin({ top: 12 })
            .backgroundColor($r('app.color.hw_primary'))
            .onClick(() => {
              router.pushUrl({ url: 'pages/Login' });
            });
          if (this.handle === '') {
            Text('Sign in to load your profile')
              .fontSize(15)
              .fontColor($r('app.color.hw_text_grey'))
              .fontFamily(FONT_FAMILY)
              .margin({ top: 16 });
          }
        }
        .width('100%')
        .padding(16)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.hw_bg_light'));
    }
    .title('Profile')
    .titleMode(NavigationTitleMode.Full)
    .backgroundColor($r('app.color.hw_bg_light'));
  }
}
