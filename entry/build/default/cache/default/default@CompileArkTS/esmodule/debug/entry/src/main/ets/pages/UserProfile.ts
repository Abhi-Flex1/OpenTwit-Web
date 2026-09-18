if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface UserProfile_Params {
    handle?: string;
    profile?: UserProfileData | undefined;
    isLoading?: boolean;
}
import router from "@ohos:router";
import { UserApi } from "@bundle:com.example.opentwit/entry/ets/services/UserApi";
import type { UserProfileData } from "@bundle:com.example.opentwit/entry/ets/services/UserApi";
import { FONT_FAMILY } from "@bundle:com.example.opentwit/entry/ets/common/Theme";
export class UserProfile extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__handle = new ObservedPropertySimplePU('', this, "handle");
        this.__profile = new ObservedPropertyObjectPU(undefined, this, "profile");
        this.__isLoading = new ObservedPropertySimplePU(true, this, "isLoading");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: UserProfile_Params) {
        if (params.handle !== undefined) {
            this.handle = params.handle;
        }
        if (params.profile !== undefined) {
            this.profile = params.profile;
        }
        if (params.isLoading !== undefined) {
            this.isLoading = params.isLoading;
        }
    }
    updateStateVars(params: UserProfile_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__handle.purgeDependencyOnElmtId(rmElmtId);
        this.__profile.purgeDependencyOnElmtId(rmElmtId);
        this.__isLoading.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__handle.aboutToBeDeleted();
        this.__profile.aboutToBeDeleted();
        this.__isLoading.aboutToBeDeleted();
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
    private __profile: ObservedPropertyObjectPU<UserProfileData | undefined>;
    get profile() {
        return this.__profile.get();
    }
    set profile(newValue: UserProfileData | undefined) {
        this.__profile.set(newValue);
    }
    private __isLoading: ObservedPropertySimplePU<boolean>;
    get isLoading() {
        return this.__isLoading.get();
    }
    set isLoading(newValue: boolean) {
        this.__isLoading.set(newValue);
    }
    async loadUser(): Promise<void> {
        try {
            let params = router.getParams() as Record<string, any>;
            if (params && params['handle']) {
                this.handle = params['handle'] as string;
            }
            if (this.handle === '') {
                this.isLoading = false;
                return;
            }
            this.profile = await UserApi.fetchUser(this.handle);
        }
        catch (e) {
            this.profile = undefined;
        }
        this.isLoading = false;
    }
    aboutToAppear(): void {
        this.loadUser();
    }
    private static initialOf(handle: string): string {
        if (handle === '') {
            return '';
        }
        let name: string = handle.startsWith('@') ? handle.substring(1) : handle;
        if (name === '') {
            return '';
        }
        return name.charAt(0).toUpperCase();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Navigation.create(new NavPathStack(), { moduleName: "entry", pagePath: "entry/src/main/ets/pages/UserProfile", isUserCreateStack: false });
            Navigation.title(this.handle === '' ? 'Profile' : this.handle);
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
            Row.create({ space: 4 });
            Row.width('100%');
            Row.padding({ left: 8, top: 4 });
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
            Stack.create({ alignContent: Alignment.BottomStart });
            Stack.width('100%');
            Stack.height(140);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.profile && this.profile.bannerUrl !== '') {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Image.create(this.profile.bannerUrl);
                        Image.width('100%');
                        Image.height(120);
                        Image.objectFit(ImageFit.Cover);
                        Image.alt({ "id": 16777221, "type": 20000, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                    }, Image);
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.width('100%');
                        Column.height(120);
                        Column.backgroundColor({ "id": 16777229, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                    }, Column);
                    Column.pop();
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 12 });
            Row.padding({ left: 16, bottom: 12 });
            Row.align(Alignment.BottomStart);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.Center });
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Circle.create({ width: 80, height: 80 });
            Circle.fill(Color.White);
        }, Circle);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.profile && this.profile.avatarUrl !== '') {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Image.create(this.profile.avatarUrl);
                        Image.width(72);
                        Image.height(72);
                        Image.borderRadius(36);
                        Image.objectFit(ImageFit.Cover);
                        Image.alt({ "id": 16777221, "type": 20000, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                    }, Image);
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Circle.create({ width: 72, height: 72 });
                        Circle.fill({ "id": 16777229, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                    }, Circle);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(UserProfile.initialOf(this.handle));
                        Text.fontSize(28);
                        Text.fontColor(Color.White);
                        Text.fontFamily(FONT_FAMILY);
                    }, Text);
                    Text.pop();
                });
            }
        }, If);
        If.pop();
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
            if (this.isLoading) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('Loading profile...');
                        Text.fontSize(15);
                        Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                        Text.fontFamily(FONT_FAMILY);
                    }, Text);
                    Text.pop();
                });
            }
            else if (this.profile) {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.profile.name);
                        Text.fontSize(20);
                        Text.fontWeight(FontWeight.Bold);
                        Text.fontFamily(FONT_FAMILY);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.profile.handle);
                        Text.fontSize(14);
                        Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                        Text.fontFamily(FONT_FAMILY);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.profile.bio);
                        Text.fontSize(15);
                        Text.fontFamily(FONT_FAMILY);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 16 });
                        Row.margin({ top: 8 });
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.profile.followers + ' Followers');
                        Text.fontSize(14);
                        Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                        Text.fontFamily(FONT_FAMILY);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.profile.following + ' Following');
                        Text.fontSize(14);
                        Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                        Text.fontFamily(FONT_FAMILY);
                    }, Text);
                    Text.pop();
                    Row.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('No posts yet — timeline is empty');
                        Text.fontSize(15);
                        Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                        Text.fontFamily(FONT_FAMILY);
                        Text.margin({ top: 16 });
                    }, Text);
                    Text.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(2, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.handle);
                        Text.fontSize(20);
                        Text.fontWeight(FontWeight.Bold);
                        Text.fontFamily(FONT_FAMILY);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('Could not load this profile');
                        Text.fontSize(15);
                        Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                        Text.fontFamily(FONT_FAMILY);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('No posts yet — timeline is empty');
                        Text.fontSize(15);
                        Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
                        Text.fontFamily(FONT_FAMILY);
                        Text.margin({ top: 16 });
                    }, Text);
                    Text.pop();
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
    static getEntryName(): string {
        return "UserProfile";
    }
}
registerNamedRoute(() => new UserProfile(undefined, {}), "", { bundleName: "com.example.opentwit", moduleName: "entry", pagePath: "pages/UserProfile", pageFullPath: "entry/src/main/ets/pages/UserProfile", integratedHsp: "false", moduleType: "followWithHap" });
