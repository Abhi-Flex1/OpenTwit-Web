if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Login_Params {
    handle?: string;
    savedHandle?: string;
}
import preferences from "@ohos:data.preferences";
import router from "@ohos:router";
export class Login extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__handle = new ObservedPropertySimplePU('', this, "handle");
        this.__savedHandle = new ObservedPropertySimplePU('', this, "savedHandle");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Login_Params) {
        if (params.handle !== undefined) {
            this.handle = params.handle;
        }
        if (params.savedHandle !== undefined) {
            this.savedHandle = params.savedHandle;
        }
    }
    updateStateVars(params: Login_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__handle.purgeDependencyOnElmtId(rmElmtId);
        this.__savedHandle.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__handle.aboutToBeDeleted();
        this.__savedHandle.aboutToBeDeleted();
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
    private __savedHandle: ObservedPropertySimplePU<string>;
    get savedHandle() {
        return this.__savedHandle.get();
    }
    set savedHandle(newValue: string) {
        this.__savedHandle.set(newValue);
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 12 });
            Column.width('100%');
            Column.height('100%');
            Column.padding(16);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ placeholder: 'Handle', text: this.handle });
            TextInput.onChange((value: string) => {
                this.handle = value;
            });
        }, TextInput);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('View timeline');
            Button.onClick(async () => {
                const store: preferences.Preferences = await preferences.getPreferences(getContext(this), 'opentwit_auth');
                await store.put('twitter_handle', this.handle);
                await store.flush();
                this.savedHandle = this.handle;
                router.pushUrl({ url: 'pages/MainTabs' });
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.savedHandle !== '') {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.savedHandle);
                        Text.fontSize(14);
                        Text.fontColor(Color.Gray);
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
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "Login";
    }
}
registerNamedRoute(() => new Login(undefined, {}), "", { bundleName: "com.example.opentwit", moduleName: "entry", pagePath: "pages/Login", pageFullPath: "entry/src/main/ets/pages/Login", integratedHsp: "false", moduleType: "followWithHap" });
