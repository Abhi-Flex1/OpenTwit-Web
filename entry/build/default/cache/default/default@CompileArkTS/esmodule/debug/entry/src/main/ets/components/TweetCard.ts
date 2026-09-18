if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface TweetCard_Params {
    userName?: string;
    handle?: string;
    time?: string;
    content?: string;
    replies?: number;
    reposts?: number;
    likes?: number;
}
import { FONT_FAMILY } from "@bundle:com.example.opentwit/entry/ets/common/Theme";
export class TweetCard extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__userName = new SynchedPropertySimpleOneWayPU(params.userName, this, "userName");
        this.__handle = new SynchedPropertySimpleOneWayPU(params.handle, this, "handle");
        this.__time = new SynchedPropertySimpleOneWayPU(params.time, this, "time");
        this.__content = new SynchedPropertySimpleOneWayPU(params.content, this, "content");
        this.__replies = new SynchedPropertySimpleOneWayPU(params.replies, this, "replies");
        this.__reposts = new SynchedPropertySimpleOneWayPU(params.reposts, this, "reposts");
        this.__likes = new SynchedPropertySimpleOneWayPU(params.likes, this, "likes");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: TweetCard_Params) {
        if (params.replies === undefined) {
            this.__replies.set(0);
        }
    }
    updateStateVars(params: TweetCard_Params) {
        this.__userName.reset(params.userName);
        this.__handle.reset(params.handle);
        this.__time.reset(params.time);
        this.__content.reset(params.content);
        this.__replies.reset(params.replies);
        this.__reposts.reset(params.reposts);
        this.__likes.reset(params.likes);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__userName.purgeDependencyOnElmtId(rmElmtId);
        this.__handle.purgeDependencyOnElmtId(rmElmtId);
        this.__time.purgeDependencyOnElmtId(rmElmtId);
        this.__content.purgeDependencyOnElmtId(rmElmtId);
        this.__replies.purgeDependencyOnElmtId(rmElmtId);
        this.__reposts.purgeDependencyOnElmtId(rmElmtId);
        this.__likes.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__userName.aboutToBeDeleted();
        this.__handle.aboutToBeDeleted();
        this.__time.aboutToBeDeleted();
        this.__content.aboutToBeDeleted();
        this.__replies.aboutToBeDeleted();
        this.__reposts.aboutToBeDeleted();
        this.__likes.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __userName: SynchedPropertySimpleOneWayPU<string>;
    get userName() {
        return this.__userName.get();
    }
    set userName(newValue: string) {
        this.__userName.set(newValue);
    }
    private __handle: SynchedPropertySimpleOneWayPU<string>;
    get handle() {
        return this.__handle.get();
    }
    set handle(newValue: string) {
        this.__handle.set(newValue);
    }
    private __time: SynchedPropertySimpleOneWayPU<string>;
    get time() {
        return this.__time.get();
    }
    set time(newValue: string) {
        this.__time.set(newValue);
    }
    private __content: SynchedPropertySimpleOneWayPU<string>;
    get content() {
        return this.__content.get();
    }
    set content(newValue: string) {
        this.__content.set(newValue);
    }
    private __replies: SynchedPropertySimpleOneWayPU<number>;
    get replies() {
        return this.__replies.get();
    }
    set replies(newValue: number) {
        this.__replies.set(newValue);
    }
    private __reposts: SynchedPropertySimpleOneWayPU<number>;
    get reposts() {
        return this.__reposts.get();
    }
    set reposts(newValue: number) {
        this.__reposts.set(newValue);
    }
    private __likes: SynchedPropertySimpleOneWayPU<number>;
    get likes() {
        return this.__likes.get();
    }
    set likes(newValue: number) {
        this.__likes.set(newValue);
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.padding(12);
            Column.borderRadius(16);
            Column.backgroundColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 12 });
            Row.width('100%');
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
            Text.create(this.userName.charAt(0));
            Text.fontSize(20);
            Text.fontColor(Color.White);
            Text.fontFamily(FONT_FAMILY);
        }, Text);
        Text.pop();
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 6 });
            Column.layoutWeight(1);
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 6 });
            Row.width('100%');
            Row.alignItems(VerticalAlign.Center);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.userName);
            Text.fontSize(15);
            Text.fontWeight(FontWeight.Bold);
            Text.fontFamily(FONT_FAMILY);
            Text.maxLines(1);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.handle);
            Text.fontSize(13);
            Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
            Text.fontFamily(FONT_FAMILY);
            Text.maxLines(1);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.time);
            Text.fontSize(13);
            Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
            Text.fontFamily(FONT_FAMILY);
            Text.maxLines(1);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.content);
            Text.fontSize(15);
            Text.fontFamily(FONT_FAMILY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 24 });
            Row.width('100%');
            Row.margin({ top: 4 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.replies.toString());
            Text.fontSize(13);
            Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
            Text.fontFamily(FONT_FAMILY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.reposts.toString());
            Text.fontSize(13);
            Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
            Text.fontFamily(FONT_FAMILY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.likes.toString());
            Text.fontSize(13);
            Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
            Text.fontFamily(FONT_FAMILY);
        }, Text);
        Text.pop();
        Row.pop();
        Column.pop();
        Row.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
