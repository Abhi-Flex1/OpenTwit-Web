if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface MainTabs_Params {
    currentIndex?: number;
}
import { Home } from "@bundle:com.example.opentwit/entry/ets/pages/Home";
import { Explore } from "@bundle:com.example.opentwit/entry/ets/pages/Explore";
import { Notify } from "@bundle:com.example.opentwit/entry/ets/pages/Notify";
import { Messages } from "@bundle:com.example.opentwit/entry/ets/pages/Messages";
import { Profile } from "@bundle:com.example.opentwit/entry/ets/pages/Profile";
import { LIGHT_THEME_COLOR } from "@bundle:com.example.opentwit/entry/ets/common/Theme";
class MainTabs extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__currentIndex = new ObservedPropertySimplePU(0, this, "currentIndex");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: MainTabs_Params) {
        if (params.currentIndex !== undefined) {
            this.currentIndex = params.currentIndex;
        }
    }
    updateStateVars(params: MainTabs_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__currentIndex.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__currentIndex.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __currentIndex: ObservedPropertySimplePU<number>;
    get currentIndex() {
        return this.__currentIndex.get();
    }
    set currentIndex(newValue: number) {
        this.__currentIndex.set(newValue);
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Tabs.create({ barPosition: BarPosition.End, index: this.currentIndex });
            Tabs.width('100%');
            Tabs.height('100%');
            Tabs.barMode(BarMode.Fixed);
            Tabs.barBackgroundColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
            Tabs.backgroundColor(LIGHT_THEME_COLOR);
            Tabs.onChange((index: number) => {
                this.currentIndex = index;
            });
        }, Tabs);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TabContent.create(() => {
                {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        if (isInitialRender) {
                            let componentCall = new Home(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/MainTabs.ets", line: 16, col: 9 });
                            ViewPU.create(componentCall);
                            let paramsLambda = () => {
                                return {};
                            };
                            componentCall.paramsGenerator_ = paramsLambda;
                        }
                        else {
                            this.updateStateVarsOfChildByElmtId(elmtId, {});
                        }
                    }, { name: "Home" });
                }
            });
            TabContent.tabBar('Home');
        }, TabContent);
        TabContent.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TabContent.create(() => {
                {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        if (isInitialRender) {
                            let componentCall = new Explore(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/MainTabs.ets", line: 20, col: 9 });
                            ViewPU.create(componentCall);
                            let paramsLambda = () => {
                                return {};
                            };
                            componentCall.paramsGenerator_ = paramsLambda;
                        }
                        else {
                            this.updateStateVarsOfChildByElmtId(elmtId, {});
                        }
                    }, { name: "Explore" });
                }
            });
            TabContent.tabBar('Explore');
        }, TabContent);
        TabContent.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TabContent.create(() => {
                {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        if (isInitialRender) {
                            let componentCall = new Notify(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/MainTabs.ets", line: 24, col: 9 });
                            ViewPU.create(componentCall);
                            let paramsLambda = () => {
                                return {};
                            };
                            componentCall.paramsGenerator_ = paramsLambda;
                        }
                        else {
                            this.updateStateVarsOfChildByElmtId(elmtId, {});
                        }
                    }, { name: "Notify" });
                }
            });
            TabContent.tabBar('Notify');
        }, TabContent);
        TabContent.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TabContent.create(() => {
                {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        if (isInitialRender) {
                            let componentCall = new Messages(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/MainTabs.ets", line: 28, col: 9 });
                            ViewPU.create(componentCall);
                            let paramsLambda = () => {
                                return {};
                            };
                            componentCall.paramsGenerator_ = paramsLambda;
                        }
                        else {
                            this.updateStateVarsOfChildByElmtId(elmtId, {});
                        }
                    }, { name: "Messages" });
                }
            });
            TabContent.tabBar('Messages');
        }, TabContent);
        TabContent.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TabContent.create(() => {
                {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        if (isInitialRender) {
                            let componentCall = new Profile(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/MainTabs.ets", line: 32, col: 9 });
                            ViewPU.create(componentCall);
                            let paramsLambda = () => {
                                return {};
                            };
                            componentCall.paramsGenerator_ = paramsLambda;
                        }
                        else {
                            this.updateStateVarsOfChildByElmtId(elmtId, {});
                        }
                    }, { name: "Profile" });
                }
            });
            TabContent.tabBar('Profile');
        }, TabContent);
        TabContent.pop();
        Tabs.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "MainTabs";
    }
}
registerNamedRoute(() => new MainTabs(undefined, {}), "", { bundleName: "com.example.opentwit", moduleName: "entry", pagePath: "pages/MainTabs", pageFullPath: "entry/src/main/ets/pages/MainTabs", integratedHsp: "false", moduleType: "followWithHap" });
