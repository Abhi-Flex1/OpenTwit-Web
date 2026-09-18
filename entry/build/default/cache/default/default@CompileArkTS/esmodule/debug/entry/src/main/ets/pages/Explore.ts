if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Explore_Params {
    query?: string;
    selectedTab?: number;
    tweets?: TweetData[];
    handle?: string;
}
import { WebTimeline } from "@bundle:com.example.opentwit/entry/ets/services/WebTimeline";
import { TokenStore } from "@bundle:com.example.opentwit/entry/ets/common/TokenStore";
import { FONT_FAMILY } from "@bundle:com.example.opentwit/entry/ets/common/Theme";
import { TweetCard } from "@bundle:com.example.opentwit/entry/ets/components/TweetCard";
import type { TweetData } from "@bundle:com.example.opentwit/entry/ets/services/WebTimeline";
export class Explore extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__query = new ObservedPropertySimplePU('', this, "query");
        this.__selectedTab = new ObservedPropertySimplePU(0, this, "selectedTab");
        this.__tweets = new ObservedPropertyObjectPU([], this, "tweets");
        this.__handle = new ObservedPropertySimplePU('', this, "handle");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Explore_Params) {
        if (params.query !== undefined) {
            this.query = params.query;
        }
        if (params.selectedTab !== undefined) {
            this.selectedTab = params.selectedTab;
        }
        if (params.tweets !== undefined) {
            this.tweets = params.tweets;
        }
        if (params.handle !== undefined) {
            this.handle = params.handle;
        }
    }
    updateStateVars(params: Explore_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__query.purgeDependencyOnElmtId(rmElmtId);
        this.__selectedTab.purgeDependencyOnElmtId(rmElmtId);
        this.__tweets.purgeDependencyOnElmtId(rmElmtId);
        this.__handle.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__query.aboutToBeDeleted();
        this.__selectedTab.aboutToBeDeleted();
        this.__tweets.aboutToBeDeleted();
        this.__handle.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __query: ObservedPropertySimplePU<string>;
    get query() {
        return this.__query.get();
    }
    set query(newValue: string) {
        this.__query.set(newValue);
    }
    private __selectedTab: ObservedPropertySimplePU<number>;
    get selectedTab() {
        return this.__selectedTab.get();
    }
    set selectedTab(newValue: number) {
        this.__selectedTab.set(newValue);
    }
    private __tweets: ObservedPropertyObjectPU<TweetData[]>;
    get tweets() {
        return this.__tweets.get();
    }
    set tweets(newValue: TweetData[]) {
        this.__tweets.set(newValue);
    }
    private __handle: ObservedPropertySimplePU<string>;
    get handle() {
        return this.__handle.get();
    }
    set handle(newValue: string) {
        this.__handle.set(newValue);
    }
    async loadLive(): Promise<void> {
        try {
            const saved: string = await TokenStore.loadHandle(getContext(this));
            this.handle = saved;
            if (saved !== '') {
                this.tweets = await WebTimeline.fetchByHandle(saved);
            }
            else {
                this.tweets = [];
            }
        }
        catch (e) {
            this.tweets = [];
        }
    }
    aboutToAppear(): void {
        this.loadLive();
    }
    getForYou(): TweetData[] {
        const q: string = this.query.trim().toLowerCase();
        if (q === '') {
            return this.tweets;
        }
        return this.tweets.filter((t: TweetData) => {
            return t.content.toLowerCase().indexOf(q) >= 0 || t.handle.toLowerCase().indexOf(q) >= 0;
        });
    }
    getTrending(): TweetData[] {
        const q: string = this.query.trim().toLowerCase();
        return this.tweets.filter((t: TweetData) => {
            const isTrend: boolean = t.content.indexOf('#') >= 0;
            if (!isTrend) {
                return false;
            }
            if (q === '') {
                return true;
            }
            return t.content.toLowerCase().indexOf(q) >= 0 || t.handle.toLowerCase().indexOf(q) >= 0;
        });
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Navigation.create(new NavPathStack(), { moduleName: "entry", pagePath: "entry/src/main/ets/pages/Explore", isUserCreateStack: false });
            Navigation.title('Explore');
            Navigation.titleMode(NavigationTitleMode.Full);
            Navigation.backgroundColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
        }, Navigation);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 8 });
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Search.create({ value: this.query, placeholder: 'Search posts' });
            Search.width('92%');
            Search.margin({ top: 8 });
            Search.backgroundColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
            Search.onChange((value: string) => {
                this.query = value;
            });
            Search.onSubmit((value: string) => {
                this.query = value;
            });
        }, Search);
        Search.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Tabs.create({ barPosition: BarPosition.Start, index: this.selectedTab });
            Tabs.width('100%');
            Tabs.layoutWeight(1);
            Tabs.backgroundColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
            Tabs.onChange((index: number) => {
                this.selectedTab = index;
            });
        }, Tabs);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TabContent.create(() => {
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Column.create();
                    Column.width('100%');
                    Column.height('100%');
                }, Column);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    If.create();
                    if (this.getForYou().length === 0) {
                        this.ifElseBranchUpdateFunction(0, () => {
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(this.handle === '' ? 'Sign in to load live posts' : 'No results yet');
                                Text.fontSize(15);
                                Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                                Text.fontFamily(FONT_FAMILY);
                                Text.width('100%');
                                Text.textAlign(TextAlign.Center);
                                Text.margin({ top: 32 });
                            }, Text);
                            Text.pop();
                        });
                    }
                    else {
                        this.ifElseBranchUpdateFunction(1, () => {
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                List.create({ space: 0 });
                                List.width('100%');
                                List.layoutWeight(1);
                            }, List);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                ForEach.create();
                                const forEachItemGenFunction = (_item, index: number) => {
                                    const item = _item;
                                    {
                                        const itemCreation = (elmtId, isInitialRender) => {
                                            ViewStackProcessor.StartGetAccessRecordingFor(elmtId);
                                            ListItem.create(deepRenderFunction, true);
                                            if (!isInitialRender) {
                                                ListItem.pop();
                                            }
                                            ViewStackProcessor.StopGetAccessRecording();
                                        };
                                        const itemCreation2 = (elmtId, isInitialRender) => {
                                            ListItem.create(deepRenderFunction, true);
                                        };
                                        const deepRenderFunction = (elmtId, isInitialRender) => {
                                            itemCreation(elmtId, isInitialRender);
                                            {
                                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                                    if (isInitialRender) {
                                                        let componentCall = new TweetCard(this, {
                                                            userName: item.userName,
                                                            handle: item.handle,
                                                            time: item.time,
                                                            content: item.content,
                                                            likes: item.likes,
                                                            reposts: item.reposts
                                                        }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Explore.ets", line: 84, col: 23 });
                                                        ViewPU.create(componentCall);
                                                        let paramsLambda = () => {
                                                            return {
                                                                userName: item.userName,
                                                                handle: item.handle,
                                                                time: item.time,
                                                                content: item.content,
                                                                likes: item.likes,
                                                                reposts: item.reposts
                                                            };
                                                        };
                                                        componentCall.paramsGenerator_ = paramsLambda;
                                                    }
                                                    else {
                                                        this.updateStateVarsOfChildByElmtId(elmtId, {
                                                            userName: item.userName,
                                                            handle: item.handle,
                                                            time: item.time,
                                                            content: item.content,
                                                            likes: item.likes,
                                                            reposts: item.reposts
                                                        });
                                                    }
                                                }, { name: "TweetCard" });
                                            }
                                            ListItem.pop();
                                        };
                                        this.observeComponentCreation2(itemCreation2, ListItem);
                                        ListItem.pop();
                                    }
                                };
                                this.forEachUpdateFunction(elmtId, this.getForYou(), forEachItemGenFunction, (item: TweetData, index: number) => item.handle + item.time + item.content + index.toString(), true, true);
                            }, ForEach);
                            ForEach.pop();
                            List.pop();
                        });
                    }
                }, If);
                If.pop();
                Column.pop();
            });
            TabContent.tabBar('For You');
        }, TabContent);
        TabContent.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TabContent.create(() => {
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Column.create();
                    Column.width('100%');
                    Column.height('100%');
                }, Column);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    If.create();
                    if (this.getTrending().length === 0) {
                        this.ifElseBranchUpdateFunction(0, () => {
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(this.handle === '' ? 'Sign in to load live trends' : 'No trending posts yet');
                                Text.fontSize(15);
                                Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                                Text.fontFamily(FONT_FAMILY);
                                Text.width('100%');
                                Text.textAlign(TextAlign.Center);
                                Text.margin({ top: 32 });
                            }, Text);
                            Text.pop();
                        });
                    }
                    else {
                        this.ifElseBranchUpdateFunction(1, () => {
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                List.create({ space: 0 });
                                List.width('100%');
                                List.layoutWeight(1);
                            }, List);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                ForEach.create();
                                const forEachItemGenFunction = (_item, index: number) => {
                                    const item = _item;
                                    {
                                        const itemCreation = (elmtId, isInitialRender) => {
                                            ViewStackProcessor.StartGetAccessRecordingFor(elmtId);
                                            ListItem.create(deepRenderFunction, true);
                                            if (!isInitialRender) {
                                                ListItem.pop();
                                            }
                                            ViewStackProcessor.StopGetAccessRecording();
                                        };
                                        const itemCreation2 = (elmtId, isInitialRender) => {
                                            ListItem.create(deepRenderFunction, true);
                                        };
                                        const deepRenderFunction = (elmtId, isInitialRender) => {
                                            itemCreation(elmtId, isInitialRender);
                                            {
                                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                                    if (isInitialRender) {
                                                        let componentCall = new TweetCard(this, {
                                                            userName: item.userName,
                                                            handle: item.handle,
                                                            time: item.time,
                                                            content: item.content,
                                                            likes: item.likes,
                                                            reposts: item.reposts
                                                        }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Explore.ets", line: 117, col: 23 });
                                                        ViewPU.create(componentCall);
                                                        let paramsLambda = () => {
                                                            return {
                                                                userName: item.userName,
                                                                handle: item.handle,
                                                                time: item.time,
                                                                content: item.content,
                                                                likes: item.likes,
                                                                reposts: item.reposts
                                                            };
                                                        };
                                                        componentCall.paramsGenerator_ = paramsLambda;
                                                    }
                                                    else {
                                                        this.updateStateVarsOfChildByElmtId(elmtId, {
                                                            userName: item.userName,
                                                            handle: item.handle,
                                                            time: item.time,
                                                            content: item.content,
                                                            likes: item.likes,
                                                            reposts: item.reposts
                                                        });
                                                    }
                                                }, { name: "TweetCard" });
                                            }
                                            ListItem.pop();
                                        };
                                        this.observeComponentCreation2(itemCreation2, ListItem);
                                        ListItem.pop();
                                    }
                                };
                                this.forEachUpdateFunction(elmtId, this.getTrending(), forEachItemGenFunction, (item: TweetData, index: number) => item.handle + item.time + item.content + index.toString(), true, true);
                            }, ForEach);
                            ForEach.pop();
                            List.pop();
                        });
                    }
                }, If);
                If.pop();
                Column.pop();
            });
            TabContent.tabBar('Trending');
        }, TabContent);
        TabContent.pop();
        Tabs.pop();
        Column.pop();
        Navigation.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
