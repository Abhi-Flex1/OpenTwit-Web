if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Home_Params {
    tweets?: LiveTweetItem[];
    isRefreshing?: boolean;
    isLoading?: boolean;
    showComposer?: boolean;
    searchText?: string;
    currentHandle?: string;
}
import { LiveTweetList } from "@bundle:com.example.opentwit/entry/ets/components/LiveTweetList";
import type { LiveTweetItem } from "@bundle:com.example.opentwit/entry/ets/components/LiveTweetList";
import { Composer } from "@bundle:com.example.opentwit/entry/ets/components/Composer";
import { WebCache } from "@bundle:com.example.opentwit/entry/ets/viewmodels/WebCache";
import { WebTimeline } from "@bundle:com.example.opentwit/entry/ets/services/WebTimeline";
import { TokenStore } from "@bundle:com.example.opentwit/entry/ets/common/TokenStore";
import { LIGHT_THEME_COLOR } from "@bundle:com.example.opentwit/entry/ets/common/Theme";
export class Home extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__tweets = new ObservedPropertyObjectPU([], this, "tweets");
        this.__isRefreshing = new ObservedPropertySimplePU(false, this, "isRefreshing");
        this.__isLoading = new ObservedPropertySimplePU(true, this, "isLoading");
        this.__showComposer = new ObservedPropertySimplePU(false, this, "showComposer");
        this.__searchText = new ObservedPropertySimplePU('', this, "searchText");
        this.__currentHandle = new ObservedPropertySimplePU('', this, "currentHandle");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Home_Params) {
        if (params.tweets !== undefined) {
            this.tweets = params.tweets;
        }
        if (params.isRefreshing !== undefined) {
            this.isRefreshing = params.isRefreshing;
        }
        if (params.isLoading !== undefined) {
            this.isLoading = params.isLoading;
        }
        if (params.showComposer !== undefined) {
            this.showComposer = params.showComposer;
        }
        if (params.searchText !== undefined) {
            this.searchText = params.searchText;
        }
        if (params.currentHandle !== undefined) {
            this.currentHandle = params.currentHandle;
        }
    }
    updateStateVars(params: Home_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__tweets.purgeDependencyOnElmtId(rmElmtId);
        this.__isRefreshing.purgeDependencyOnElmtId(rmElmtId);
        this.__isLoading.purgeDependencyOnElmtId(rmElmtId);
        this.__showComposer.purgeDependencyOnElmtId(rmElmtId);
        this.__searchText.purgeDependencyOnElmtId(rmElmtId);
        this.__currentHandle.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__tweets.aboutToBeDeleted();
        this.__isRefreshing.aboutToBeDeleted();
        this.__isLoading.aboutToBeDeleted();
        this.__showComposer.aboutToBeDeleted();
        this.__searchText.aboutToBeDeleted();
        this.__currentHandle.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __tweets: ObservedPropertyObjectPU<LiveTweetItem[]>;
    get tweets() {
        return this.__tweets.get();
    }
    set tweets(newValue: LiveTweetItem[]) {
        this.__tweets.set(newValue);
    }
    private __isRefreshing: ObservedPropertySimplePU<boolean>;
    get isRefreshing() {
        return this.__isRefreshing.get();
    }
    set isRefreshing(newValue: boolean) {
        this.__isRefreshing.set(newValue);
    }
    private __isLoading: ObservedPropertySimplePU<boolean>;
    get isLoading() {
        return this.__isLoading.get();
    }
    set isLoading(newValue: boolean) {
        this.__isLoading.set(newValue);
    }
    private __showComposer: ObservedPropertySimplePU<boolean>;
    get showComposer() {
        return this.__showComposer.get();
    }
    set showComposer(newValue: boolean) {
        this.__showComposer.set(newValue);
    }
    private __searchText: ObservedPropertySimplePU<string>;
    get searchText() {
        return this.__searchText.get();
    }
    set searchText(newValue: string) {
        this.__searchText.set(newValue);
    }
    private __currentHandle: ObservedPropertySimplePU<string>;
    get currentHandle() {
        return this.__currentHandle.get();
    }
    set currentHandle(newValue: string) {
        this.__currentHandle.set(newValue);
    }
    async loadTimeline() {
        try {
            // Everything from Twitter web: no API key, no mock data.
            // With no saved handle, load verified live posts from the web.
            const handle: string = await TokenStore.loadHandle(getContext(this));
            if (handle !== '') {
                this.currentHandle = handle;
                this.tweets = await WebCache.loadWeb(handle);
                if (this.tweets.length > 0) {
                    return;
                }
            }
            // Handle lookup came back empty: show verified live posts instead.
            this.tweets = await WebTimeline.fetchStarterTimeline();
        }
        catch (e) {
            this.tweets = [];
        }
        this.isLoading = false;
    }
    aboutToAppear() {
        this.loadTimeline();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Navigation.create(new NavPathStack(), { moduleName: "entry", pagePath: "entry/src/main/ets/pages/Home", isUserCreateStack: false });
            Navigation.width('100%');
            Navigation.height('100%');
            Navigation.title('OpenTwit');
            Navigation.backgroundColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
        }, Navigation);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.BottomEnd });
            Stack.width('100%');
            Stack.height('100%');
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 8 });
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor(LIGHT_THEME_COLOR);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // SearchBar on top of the timeline
            Search.create({ value: { value: this.searchText, changeEvent: newValue => { this.searchText = newValue; } } });
            // SearchBar on top of the timeline
            Search.width('100%');
            // SearchBar on top of the timeline
            Search.onSubmit(() => {
            });
            // SearchBar on top of the timeline
            Search.onChange((value: string) => {
                this.searchText = value;
            });
        }, Search);
        // SearchBar on top of the timeline
        Search.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Pull-to-refresh timeline driven by live data only
            Refresh.create({ refreshing: { value: this.isRefreshing, changeEvent: newValue => { this.isRefreshing = newValue; } }, friction: 62 });
            // Pull-to-refresh timeline driven by live data only
            Refresh.width('100%');
            // Pull-to-refresh timeline driven by live data only
            Refresh.layoutWeight(1);
            // Pull-to-refresh timeline driven by live data only
            Refresh.onRefreshing(() => {
                this.isRefreshing = true;
                this.loadTimeline().finally(() => {
                    this.isRefreshing = false;
                });
            });
        }, Refresh);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new LiveTweetList(this, {
                        tweets: this.tweets,
                        isLoading: this.isLoading,
                        onRetry: () => {
                            this.isLoading = true;
                            this.loadTimeline();
                        }
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Home.ets", line: 56, col: 13 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            tweets: this.tweets,
                            isLoading: this.isLoading,
                            onRetry: () => {
                                this.isLoading = true;
                                this.loadTimeline();
                            }
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        tweets: this.tweets,
                        isLoading: this.isLoading
                    });
                }
            }, { name: "LiveTweetList" });
        }
        // Pull-to-refresh timeline driven by live data only
        Refresh.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Floating Compose button (icon only, no text)
            Button.createWithChild();
            // Floating Compose button (icon only, no text)
            Button.width(56);
            // Floating Compose button (icon only, no text)
            Button.height(56);
            // Floating Compose button (icon only, no text)
            Button.borderRadius(28);
            // Floating Compose button (icon only, no text)
            Button.margin({ right: 16, bottom: 16 });
            // Floating Compose button (icon only, no text)
            Button.onClick(() => {
                this.showComposer = !this.showComposer;
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125831481, "type": 40000, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
            SymbolGlyph.fontSize(24);
        }, SymbolGlyph);
        // Floating Compose button (icon only, no text)
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.showComposer) {
                this.ifElseBranchUpdateFunction(0, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new Composer(this, {
                                    onPost: (content: string) => {
                                        const mine: LiveTweetItem = {
                                            userName: this.currentHandle,
                                            handle: this.currentHandle,
                                            time: new Date().toLocaleTimeString(),
                                            content: content,
                                            likes: 0,
                                            reposts: 0,
                                            replies: 0
                                        };
                                        this.tweets.unshift(mine);
                                        this.showComposer = false;
                                    }
                                }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Home.ets", line: 92, col: 11 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        onPost: (content: string) => {
                                            const mine: LiveTweetItem = {
                                                userName: this.currentHandle,
                                                handle: this.currentHandle,
                                                time: new Date().toLocaleTimeString(),
                                                content: content,
                                                likes: 0,
                                                reposts: 0,
                                                replies: 0
                                            };
                                            this.tweets.unshift(mine);
                                            this.showComposer = false;
                                        }
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {});
                            }
                        }, { name: "Composer" });
                    }
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        Stack.pop();
        Navigation.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
