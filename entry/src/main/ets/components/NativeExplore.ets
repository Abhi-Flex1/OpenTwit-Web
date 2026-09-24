import { FONT_FAMILY, S12, S16, S20, S4, S8, TOOL_BUTTON } from '../common/Theme';
import { NativeTrend, stateOf } from '../common/NativeModels';
import { NativeSignIn } from './NativeSignIn';

interface BridgeTrend {
  name: string;
  posts: string;
}

interface BridgeTrendsPayload {
  state: string;
  trends?: BridgeTrend[];
}

// Explore: trends plus real search suggestions. Trends refresh on a slow tick
// while on screen; typing keeps trends up and submitting runs the page's own
// typeahead through the session. Full tweet search has no working endpoint in
// this session (verified: adaptive answers 200 empty), so results are genuine
// topic suggestions rendered as tappable rows — never fabricated tweets.
@Component
export struct NativeExplore {
  @Prop @Watch('onTrendsChanged') trendsJson: string = '';
  @Prop @Watch('onResultsChanged') searchJson: string = '';
  @Prop searchText: string = '';
  @State trends: NativeTrend[] = [];
  @State trendsState: string = 'loading';
  @State results: NativeTrend[] = [];
  @State resultsState: string = '';
  @State refreshing: boolean = false;
  onRefreshTrends: () => void = () => {
  };
  onSearch: (query: string) => void = () => {
  };
  onOpenTrend: (name: string) => void = () => {
  };
  onOpenFullSearch: (query: string) => void = () => {
  };
  onSignIn: () => void = () => {
  };

  aboutToAppear(): void {
    this.onTrendsChanged();
    this.onResultsChanged();
  }

  onTrendsChanged(): void {
    const state: string = stateOf(this.trendsJson);
    this.trendsState = state;
    if (state === 'ok') {
      try {
        const payload = JSON.parse(this.trendsJson) as BridgeTrendsPayload;
        const out: NativeTrend[] = [];
        const src: BridgeTrend[] = payload.trends ?? [];
        for (let i: number = 0; i < src.length; i++) {
          if (src[i] && src[i].name !== '') {
            out.push({ name: src[i].name, posts: src[i].posts ?? '' });
          }
        }
        this.trends = out;
      } catch (err) {
        this.trends = [];
      }
    }
    this.refreshing = false;
  }

  private parseSuggestions(json: string): NativeTrend[] {
    try {
      const payload = JSON.parse(json) as BridgeTrendsPayload;
      const out: NativeTrend[] = [];
      const src: BridgeTrend[] = payload.trends ?? [];
      for (let i: number = 0; i < src.length; i++) {
        if (src[i] && src[i].name !== '') {
          out.push({ name: src[i].name, posts: src[i].posts ?? '' });
        }
      }
      return out;
    } catch (err) {
      return [];
    }
  }

  onResultsChanged(): void {
    if (!this.searchJson || this.searchJson === '') {
      this.resultsState = '';
      this.results = [];
      return;
    }
    const state: string = stateOf(this.searchJson);
    this.resultsState = state;
    if (state === 'ok') {
      this.results = this.parseSuggestions(this.searchJson);
    } else if (state === 'empty') {
      this.results = [];
    }
  }

  private hasQuery(): boolean {
    return this.searchText.trim() !== '';
  }

  // Results show only after a search was submitted (searchJson set by the
  // shell). Typing alone keeps trends on screen instead of a spinner.
  private hasResults(): boolean {
    return this.searchJson !== '';
  }

  @Builder
  fullSearchAction() {
    if (this.hasQuery()) {
      Button($r('app.string.explore_view_all_results'))
        .type(ButtonType.Capsule)
        .fontFamily(FONT_FAMILY)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
        .width('100%')
        .margin({ top: S12, bottom: S8 })
        .accessibilityText($r('app.string.explore_view_all_results'))
        .accessibilityLevel('yes')
        .onClick(() => {
          this.onOpenFullSearch(this.searchText.trim());
        })
    }
  }

  @Builder
  statePanel(symbol: Resource, title: Resource, message: Resource) {
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
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(S16)
  }

  @Builder
  trendRow(item: NativeTrend, index: number) {
    ListItem() {
      Row({ space: S12 }) {
        Text((index + 1).toString())
          .fontSize(13)
          .fontFamily(FONT_FAMILY)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .width(24)
          .textAlign(TextAlign.End)
        Column({ space: S4 }) {
          Text(item.name)
            .fontSize(15)
            .fontFamily(FONT_FAMILY)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
          if (item.posts !== '') {
            Text(item.posts)
              .fontSize(13)
              .fontFamily(FONT_FAMILY)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
          .accessibilityLevel('no')
      }
      .width('100%')
      .constraintSize({ minHeight: 56 })
      .padding({ left: S20, right: S20, top: S8, bottom: S8 })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.onOpenTrend(item.name);
        this.onSearch(item.name);
      })
    }
  }

  build() {
    Column({ space: 0 }) {
      if (!this.hasResults()) {
        // Trends list.
        if (this.trendsState === 'signed-out') {
          NativeSignIn({
            onSignIn: () => {
              this.onSignIn();
            }
          })
        } else if (this.trendsState === 'loading' && this.trends.length === 0) {
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
        } else if (this.trends.length === 0) {
          this.statePanel($r('sys.symbol.compass_circle_fill'),
            $r('app.string.explore_empty_title'),
            $r('app.string.explore_empty_message'))
        } else {
          Refresh({ refreshing: $$this.refreshing }) {
            List({ space: 0 }) {
              ListItem() {
                Text($r('app.string.explore_trends_title'))
                  .fontSize(17)
                  .fontFamily(FONT_FAMILY)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .width('100%')
                  .padding({ left: S20, right: S20, top: S12, bottom: S4 })
              }
              ForEach(this.trends, (item: NativeTrend, index: number) => {
                this.trendRow(item, index)
              }, (item: NativeTrend) => item.name)
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ bottom: S8 })
            .edgeEffect(EdgeEffect.Spring)
          }
          .width('100%')
          .layoutWeight(1)
          .pullToRefresh(true)
          .onRefreshing(() => {
            this.refreshing = true;
            this.onRefreshTrends();
          })
        }
      } else {
        // Suggestions for the submitted query, as tappable rows that refine it.
        if (this.resultsState === '' || this.resultsState === 'loading') {
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
        } else if (this.resultsState === 'signed-out') {
          NativeSignIn({
            onSignIn: () => {
              this.onSignIn();
            }
          })
        } else if (this.results.length === 0) {
          this.statePanel($r('sys.symbol.magnifyingglass'),
            $r('app.string.explore_no_results_title'),
            $r('app.string.explore_no_results_message'))
        } else {
          Column({ space: 0 }) {
            List({ space: 0 }) {
              ForEach(this.results, (item: NativeTrend, index: number) => {
                this.trendRow(item, index)
              }, (item: NativeTrend) => item.name)
            }
            .layoutWeight(1)
            .width('100%')
            .edgeEffect(EdgeEffect.Spring)
            this.fullSearchAction()
          }
          .layoutWeight(1)
          .width('100%')
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
