if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Messages_Params {
    tweets?: TweetData[];
    handle?: string;
}
import { WebTimeline } from "@bundle:com.example.opentwit/entry/ets/services/WebTimeline";
import { TokenStore } from "@bundle:com.example.opentwit/entry/ets/common/TokenStore";
import { FONT_FAMILY } from "@bundle:com.example.opentwit/entry/ets/common/Theme";
import type { TweetData } from "@bundle:com.example.opentwit/entry/ets/services/WebTimeline";
export class Messages extends ViewPU {
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
    setInitiallyProvidedValue(params: Messages_Params) {
        if (params.tweets !== undefined) {
            this.tweets = params.tweets;
        }
        if (params.handle !== undefined) {
            this.handle = params.handle;
        }
    }
    updateStateVars(params: Messages_Params) {
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
    getConversations(): TweetData[] {
        const seen: Record<string, boolean> = {};
        const result: TweetData[] = [];
        for (let i: number = 0; i < this.tweets.length; i++) {
            const t: TweetData = this.tweets[i];
            if (!seen[t.handle]) {
                seen[t.handle] = true;
                result.push(t);
            }
        }
        return result;
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Navigation.create(new NavPathStack(), { moduleName: "entry", pagePath: "entry/src/main/ets/pages/Messages", isUserCreateStack: false });
            Navigation.title('Messages');
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
            if (this.getConversations().length === 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.handle === '' ? 'Sign in to load messages' : 'No messages yet');
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
                        List.backgroundColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
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
                                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                                        Row.create({ space: 12 });
                                        Row.width('100%');
                                        Row.padding(12);
                                        Row.alignItems(VerticalAlign.Top);
                                    }, Row);
                                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                                        Stack.create({ alignContent: Alignment.Center });
                                    }, Stack);
                                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                                        Circle.create({ width: 44, height: 44 });
                                        Circle.fill({ "id": 16777229, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                                    }, Circle);
                                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                                        Text.create(item.handle.length > 1 ? item.handle.charAt(1).toUpperCase() : '');
                                        Text.fontSize(20);
                                        Text.fontColor(Color.White);
                                        Text.fontFamily(FONT_FAMILY);
                                    }, Text);
                                    Text.pop();
                                    Stack.pop();
                                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                                        Column.create({ space: 4 });
                                        Column.layoutWeight(1);
                                        Column.alignItems(HorizontalAlign.Start);
                                    }, Column);
                                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                                        Text.create(item.handle);
                                        Text.fontSize(15);
                                        Text.fontWeight(FontWeight.Medium);
                                        Text.fontFamily(FONT_FAMILY);
                                        Text.maxLines(1);
                                    }, Text);
                                    Text.pop();
                                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                                        Text.create(item.content);
                                        Text.fontSize(14);
                                        Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                                        Text.fontFamily(FONT_FAMILY);
                                        Text.maxLines(1);
                                        Text.textOverflow({ overflow: TextOverflow.Ellipsis });
                                    }, Text);
                                    Text.pop();
                                    Column.pop();
                                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                                        Text.create(item.time);
                                        Text.fontSize(12);
                                        Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                                        Text.fontFamily(FONT_FAMILY);
                                    }, Text);
                                    Text.pop();
                                    Row.pop();
                                    ListItem.pop();
                                };
                                this.observeComponentCreation2(itemCreation2, ListItem);
                                ListItem.pop();
                            }
                        };
                        this.forEachUpdateFunction(elmtId, this.getConversations(), forEachItemGenFunction, (item: TweetData, index: number) => item.handle + index.toString(), true, true);
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
