import { preferences } from '@kit.ArkData';
import router from '@ohos.router';

@Entry
@Component
export struct Login {
  @State handle: string = '';
  @State savedHandle: string = '';

  build() {
    Column({ space: 12 }) {
      TextInput({ placeholder: 'Handle', text: this.handle })
        .onChange((value: string) => {
          this.handle = value;
        })
      Button('View timeline')
        .onClick(async () => {
          const store: preferences.Preferences =
            await preferences.getPreferences(getContext(this), 'opentwit_auth');
          await store.put('twitter_handle', this.handle);
          await store.flush();
          this.savedHandle = this.handle;
          router.pushUrl({ url: 'pages/MainTabs' });
        })
      if (this.savedHandle !== '') {
        Text(this.savedHandle)
          .fontSize(14)
          .fontColor(Color.Gray)
      }
    }
    .width('100%')
    .height('100%')
    .padding(16)
  }
}
