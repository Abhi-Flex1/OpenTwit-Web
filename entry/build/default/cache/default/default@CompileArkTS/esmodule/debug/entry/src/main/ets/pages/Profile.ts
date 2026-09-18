if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Profile_Params {
    handle?: string;
}
import router from "@ohos:router";
import { TokenStore } from "@bundle:com.example.opentwit/entry/ets/common/TokenStore";
import { FONT_FAMILY } from "@bundle:com.example.opentwit/entry/ets/common/Theme";
export class Profile extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__handle = new ObservedPropertySimplePU('', this, "handle");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Profile_Params) {
        if (params.handle !== undefined) {
            this.handle = params.handle;
        }
    }
    updateStateVars(params: Profile_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__handle.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__handle.aboutToBeDeleted();
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
    async loadHandle(): Promise<void> {
        try {
            this.handle = await TokenStore.loadHandle(getContext(this));
        }
        catch (e) {
            this.handle = '';
        }
    }
    aboutToAppear(): void {
        this.loadHandle();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Navigation.create(new NavPathStack(), { moduleName: "entry", pagePath: "entry/src/main/ets/pages/Profile", isUserCreateStack: false });
            Navigation.title('Profile');
            Navigation.titleMode(NavigationTitleMode.Full);
            Navigation.backgroundColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
        }, Navigation);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 0 });
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.BottomStart });
            Stack.width('100%');
            Stack.height(140);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.height(120);
            Column.backgroundColor({ "id": 16777229, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
        }, Column);
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 12 });
            Row.padding({ left: 16, bottom: 12 });
            Row.align(Alignment.BottomStart);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.Center });
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Circle.create({ width: 72, height: 72 });
            Circle.fill({ "id": 16777229, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
            Circle.border({ width: 3, color: Color.White });
        }, Circle);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.handle.length > 1 ? this.handle.charAt(1).toUpperCase() : '');
            Text.fontSize(28);
            Text.fontColor(Color.White);
            Text.fontFamily(FONT_FAMILY);
        }, Text);
        Text.pop();
        Stack.pop();
        Row.pop();
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 6 });
            Column.width('100%');
            Column.padding(16);
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.handle === '') {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('Not signed in');
                        Text.fontSize(20);
                        Text.fontWeight(FontWeight.Bold);
                        Text.fontFamily(FONT_FAMILY);
                    }, Text);
                    Text.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.handle);
                        Text.fontSize(20);
                        Text.fontWeight(FontWeight.Bold);
                        Text.fontFamily(FONT_FAMILY);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.handle);
                        Text.fontSize(14);
                        Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                        Text.fontFamily(FONT_FAMILY);
                    }, Text);
                    Text.pop();
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('Sign in');
            Button.fontFamily(FONT_FAMILY);
            Button.margin({ top: 12 });
            Button.backgroundColor({ "id": 16777229, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
            Button.onClick(() => {
                router.pushUrl({ url: 'pages/Login' });
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.handle === '') {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('Sign in to load your profile');
                        Text.fontSize(15);
                        Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                        Text.fontFamily(FONT_FAMILY);
                        Text.margin({ top: 16 });
                    }, Text);
                    Text.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        Column.pop();
        Column.pop();
        Navigation.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
