if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface ThemeProvider_Params {
    themeColor?: Resource;
    fontFamily?: string;
}
// HarmonyOS visual system tokens for OpenTwit-Web.
// Uses HarmonyOS Sans as the app-wide font family.
export const FONT_FAMILY: string = 'HarmonyOS Sans';
export const FONT_TITLE: number = 20;
export const FONT_BODY: number = 16;
export const RADIUS: number = 16;
export const S4: number = 4;
export const S8: number = 8;
export const S12: number = 12;
export const S16: number = 16;
export const LIGHT_THEME_COLOR: string = '#FFFFFF';
export const DARK_THEME_COLOR: string = '#000000';
export class ThemeProvider extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__themeColor = new ObservedPropertyObjectPU({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" }, this, "themeColor");
        this.addProvidedVar("themeColor", this.__themeColor, false);
        this.__fontFamily = new ObservedPropertySimplePU(FONT_FAMILY, this, "fontFamily");
        this.addProvidedVar("fontFamily", this.__fontFamily, false);
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: ThemeProvider_Params) {
        if (params.themeColor !== undefined) {
            this.themeColor = params.themeColor;
        }
        if (params.fontFamily !== undefined) {
            this.fontFamily = params.fontFamily;
        }
    }
    updateStateVars(params: ThemeProvider_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__themeColor.purgeDependencyOnElmtId(rmElmtId);
        this.__fontFamily.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__themeColor.aboutToBeDeleted();
        this.__fontFamily.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __themeColor: ObservedPropertyObjectPU<Resource>;
    get themeColor() {
        return this.__themeColor.get();
    }
    set themeColor(newValue: Resource) {
        this.__themeColor.set(newValue);
    }
    private __fontFamily: ObservedPropertySimplePU<string>;
    get fontFamily() {
        return this.__fontFamily.get();
    }
    set fontFamily(newValue: string) {
        this.__fontFamily.set(newValue);
    }
    initialRender() {
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "ThemeProvider";
    }
}
// Apply light theme tokens. Caller stores the returned color via @Provide.
export function applyLight(): Resource {
    return { "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" };
}
// Apply dark theme tokens. Caller stores the returned color via @Provide.
export function applyDark(): Resource {
    return { "id": 16777226, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" };
}
registerNamedRoute(() => new ThemeProvider(undefined, {}), "", { bundleName: "com.example.opentwit", moduleName: "entry", pagePath: "common/Theme", pageFullPath: "entry/src/main/ets/common/Theme", integratedHsp: "false", moduleType: "followWithHap" });
