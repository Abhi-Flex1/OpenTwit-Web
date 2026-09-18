if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface LiveTweetList_Params {
    tweets?: LiveTweetItem[];
    isLoading?: boolean;
    onRetry?: () => void;
}
import { TweetCard } from "@bundle:com.example.opentwit/entry/ets/components/TweetCard";
import { FONT_FAMILY } from "@bundle:com.example.opentwit/entry/ets/common/Theme";
export interface LiveTweetItem {
    userName: string;
    handle: string;
    time: string;
    content: string;
    replies: number;
    reposts: number;
    likes: number;
    avatarUrl?: string;
    tweetId?: string;
}
export class LiveTweetList extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__tweets = new SynchedPropertyObjectOneWayPU(params.tweets, this, "tweets");
        this.__isLoading = new SynchedPropertySimpleOneWayPU(params.isLoading, this, "isLoading");
        this.onRetry = undefined;
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: LiveTweetList_Params) {
        if (params.tweets === undefined) {
            this.__tweets.set([]);
        }
        if (params.isLoading === undefined) {
            this.__isLoading.set(false);
        }
        if (params.onRetry !== undefined) {
            this.onRetry = params.onRetry;
        }
    }
    updateStateVars(params: LiveTweetList_Params) {
        this.__tweets.reset(params.tweets);
        this.__isLoading.reset(params.isLoading);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__tweets.purgeDependencyOnElmtId(rmElmtId);
        this.__isLoading.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__tweets.aboutToBeDeleted();
        this.__isLoading.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __tweets: SynchedPropertySimpleOneWayPU<LiveTweetItem[]>;
    get tweets() {
        return this.__tweets.get();
    }
    set tweets(newValue: LiveTweetItem[]) {
        this.__tweets.set(newValue);
    }
    private __isLoading: SynchedPropertySimpleOneWayPU<boolean>;
    get isLoading() {
        return this.__isLoading.get();
    }
    set isLoading(newValue: boolean) {
        this.__isLoading.set(newValue);
    }
    private onRetry?: () => void;
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.isLoading) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create({ space: 12 });
                        Column.width('100%');
                        Column.padding(24);
                        Column.alignItems(HorizontalAlign.Center);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        LoadingProgress.create();
                        LoadingProgress.width(48);
                        LoadingProgress.height(48);
                        LoadingProgress.color({ "id": 16777229, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                    }, LoadingProgress);
                    Column.pop();
                });
            }
            else if (this.tweets.length === 0) {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create({ space: 12 });
                        Column.width('100%');
                        Column.padding(24);
                        Column.alignItems(HorizontalAlign.Center);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('Nothing here yet');
                        Text.fontSize(15);
                        Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                        Text.fontFamily(FONT_FAMILY);
                        Text.width('100%');
                        Text.textAlign(TextAlign.Center);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('Retry');
                        Button.fontFamily(FONT_FAMILY);
                        Button.onClick(() => {
                            if (this.onRetry) {
                                this.onRetry();
                            }
                        });
                    }, Button);
                    Button.pop();
                    Column.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(2, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        List.create({ space: 8 });
                        List.width('100%');
                        List.height('100%');
                        List.backgroundColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                    }, List);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = _item => {
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
                                                    replies: item.replies,
                                                    reposts: item.reposts,
                                                    likes: item.likes,
                                                    avatarUrl: item.avatarUrl,
                                                    tweetId: item.tweetId
                                                }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/components/LiveTweetList.ets", line: 56, col: 13 });
                                                ViewPU.create(componentCall);
                                                let paramsLambda = () => {
                                                    return {
                                                        userName: item.userName,
                                                        handle: item.handle,
                                                        time: item.time,
                                                        content: item.content,
                                                        replies: item.replies,
                                                        reposts: item.reposts,
                                                        likes: item.likes,
                                                        avatarUrl: item.avatarUrl,
                                                        tweetId: item.tweetId
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
                                                    replies: item.replies,
                                                    reposts: item.reposts,
                                                    likes: item.likes,
                                                    avatarUrl: item.avatarUrl,
                                                    tweetId: item.tweetId
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
                        this.forEachUpdateFunction(elmtId, this.tweets, forEachItemGenFunction, (item: LiveTweetItem) => item.handle + item.time + item.content, false, false);
                    }, ForEach);
                    ForEach.pop();
                    List.pop();
                });
            }
        }, If);
        If.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
