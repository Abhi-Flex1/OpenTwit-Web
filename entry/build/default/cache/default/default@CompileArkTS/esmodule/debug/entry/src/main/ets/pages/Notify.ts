if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Notify_Params {
    tweets?: TweetData[];
    handle?: string;
}
import { WebTimeline } from "@bundle:com.example.opentwit/entry/ets/services/WebTimeline";
import { TokenStore } from "@bundle:com.example.opentwit/entry/ets/common/TokenStore";
import { FONT_FAMILY } from "@bundle:com.example.opentwit/entry/ets/common/Theme";
import { TweetCard } from "@bundle:com.example.opentwit/entry/ets/components/TweetCard";
import type { TweetData } from "@bundle:com.example.opentwit/entry/ets/services/WebTimeline";
export class Notify extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__tweets = new ObservedPropertyObjectPU([], this, "tweets");
        this.__handle = new ObservedPropertySimplePU('', this, "handle");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Notify_Params) {
        if (params.tweets !== undefined) {
            this.tweets = params.tweets;
        }
        if (params.handle !== undefined) {
            this.handle = params.handle;
        }
    }
    updateStateVars(params: Notify_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__tweets.purgeDependencyOnElmtId(rmElmtId);
        this.__handle.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__tweets.aboutToBeDeleted();
        this.__handle.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
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
                const live: TweetData[] = await WebTimeline.fetchByHandle(saved);
                this.tweets = live.filter((t: TweetData) => t.content.indexOf('@') >= 0);
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
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Navigation.create(new NavPathStack(), { moduleName: "entry", pagePath: "entry/src/main/ets/pages/Notify", isUserCreateStack: false });
            Navigation.title('Notifications');
            Navigation.titleMode(NavigationTitleMode.Full);
            Navigation.backgroundColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
        }, Navigation);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.tweets.length === 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.handle === '' ? 'Sign in to load notifications' : 'No notifications yet');
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
                                                }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Notify.ets", line: 46, col: 17 });
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
                        this.forEachUpdateFunction(elmtId, this.tweets, forEachItemGenFunction, (item: TweetData, index: number) => item.handle + item.time + item.content + index.toString(), true, true);
                    }, ForEach);
                    ForEach.pop();
                    List.pop();
                });
            }
        }, If);
        If.pop();
        Column.pop();
        Navigation.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
