if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Detail_Params {
    handle?: string;
    tweetId?: string;
    tweet?: TweetRecord | undefined;
}
import router from "@ohos:router";
import { TweetDetail } from "@bundle:com.example.opentwit/entry/ets/services/TweetDetail";
import type { TweetRecord } from "@bundle:com.example.opentwit/entry/ets/services/TweetDetail";
import { TweetCard } from "@bundle:com.example.opentwit/entry/ets/components/TweetCard";
import { FONT_FAMILY } from "@bundle:com.example.opentwit/entry/ets/common/Theme";
export class Detail extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__handle = new ObservedPropertySimplePU('', this, "handle");
        this.__tweetId = new ObservedPropertySimplePU('', this, "tweetId");
        this.__tweet = new ObservedPropertyObjectPU(undefined, this, "tweet");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Detail_Params) {
        if (params.handle !== undefined) {
            this.handle = params.handle;
        }
        if (params.tweetId !== undefined) {
            this.tweetId = params.tweetId;
        }
        if (params.tweet !== undefined) {
            this.tweet = params.tweet;
        }
    }
    updateStateVars(params: Detail_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__handle.purgeDependencyOnElmtId(rmElmtId);
        this.__tweetId.purgeDependencyOnElmtId(rmElmtId);
        this.__tweet.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__handle.aboutToBeDeleted();
        this.__tweetId.aboutToBeDeleted();
        this.__tweet.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __handle: ObservedPropertySimplePU<string>;
    get handle() {
        return this.__handle.get();
    }
    set handle(newValue: string) {
        this.__handle.set(newValue);
    }
    private __tweetId: ObservedPropertySimplePU<string>;
    get tweetId() {
        return this.__tweetId.get();
    }
    set tweetId(newValue: string) {
        this.__tweetId.set(newValue);
    }
    private __tweet: ObservedPropertyObjectPU<TweetRecord | undefined>;
    get tweet() {
        return this.__tweet.get();
    }
    set tweet(newValue: TweetRecord | undefined) {
        this.__tweet.set(newValue);
    }
    async loadDetail(): Promise<void> {
        if (this.handle === '' || this.tweetId === '') {
            return;
        }
        try {
            this.tweet = await TweetDetail.fetchOne(this.handle, this.tweetId);
        }
        catch (e) {
            this.tweet = undefined;
        }
    }
    aboutToAppear(): void {
        let params = router.getParams() as Record<string, string>;
        if (params && params['handle']) {
            this.handle = params['handle'];
        }
        if (params && params['tweetId']) {
            this.tweetId = params['tweetId'];
        }
        this.loadDetail();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Navigation.create(new NavPathStack(), { moduleName: "entry", pagePath: "entry/src/main/ets/pages/Detail", isUserCreateStack: false });
            Navigation.title('Post');
            Navigation.titleMode(NavigationTitleMode.Full);
            Navigation.backgroundColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
        }, Navigation);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 8 });
            Column.width('100%');
            Column.height('100%');
            Column.padding(8);
            Column.backgroundColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 4 });
            Row.width('100%');
            Row.alignItems(VerticalAlign.Center);
            Row.onClick(() => {
                router.back();
            });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832663, "type": 40000, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
            SymbolGlyph.fontSize(22);
            SymbolGlyph.fontColor([{ "id": 16777229, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" }]);
        }, SymbolGlyph);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('Back');
            Text.fontSize(16);
            Text.fontColor({ "id": 16777229, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
            Text.fontFamily(FONT_FAMILY);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.tweet) {
                this.ifElseBranchUpdateFunction(0, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new TweetCard(this, {
                                    userName: (this.tweet as TweetRecord).userName,
                                    handle: (this.tweet as TweetRecord).handle,
                                    time: (this.tweet as TweetRecord).time,
                                    content: (this.tweet as TweetRecord).content,
                                    likes: (this.tweet as TweetRecord).likes,
                                    reposts: (this.tweet as TweetRecord).reposts,
                                    replies: (this.tweet as TweetRecord).replies,
                                    avatarUrl: (this.tweet as TweetRecord).avatarUrl,
                                    tweetId: (this.tweet as TweetRecord).tweetId
                                }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Detail.ets", line: 53, col: 11 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        userName: (this.tweet as TweetRecord).userName,
                                        handle: (this.tweet as TweetRecord).handle,
                                        time: (this.tweet as TweetRecord).time,
                                        content: (this.tweet as TweetRecord).content,
                                        likes: (this.tweet as TweetRecord).likes,
                                        reposts: (this.tweet as TweetRecord).reposts,
                                        replies: (this.tweet as TweetRecord).replies,
                                        avatarUrl: (this.tweet as TweetRecord).avatarUrl,
                                        tweetId: (this.tweet as TweetRecord).tweetId
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {
                                    userName: (this.tweet as TweetRecord).userName,
                                    handle: (this.tweet as TweetRecord).handle,
                                    time: (this.tweet as TweetRecord).time,
                                    content: (this.tweet as TweetRecord).content,
                                    likes: (this.tweet as TweetRecord).likes,
                                    reposts: (this.tweet as TweetRecord).reposts,
                                    replies: (this.tweet as TweetRecord).replies,
                                    avatarUrl: (this.tweet as TweetRecord).avatarUrl,
                                    tweetId: (this.tweet as TweetRecord).tweetId
                                });
                            }
                        }, { name: "TweetCard" });
                    }
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create((this.tweet as TweetRecord).replies.toString() + ' replies');
                        Text.fontSize(14);
                        Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                        Text.fontFamily(FONT_FAMILY);
                        Text.width('100%');
                        Text.padding({ left: 12, top: 8 });
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('No replies yet');
                        Text.fontSize(15);
                        Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                        Text.fontFamily(FONT_FAMILY);
                        Text.width('100%');
                        Text.textAlign(TextAlign.Center);
                        Text.margin({ top: 24 });
                    }, Text);
                    Text.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('Loading post...');
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
        }, If);
        If.pop();
        Column.pop();
        Navigation.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "Detail";
    }
}
registerNamedRoute(() => new Detail(undefined, {}), "", { bundleName: "com.example.opentwit", moduleName: "entry", pagePath: "pages/Detail", pageFullPath: "entry/src/main/ets/pages/Detail", integratedHsp: "false", moduleType: "followWithHap" });
