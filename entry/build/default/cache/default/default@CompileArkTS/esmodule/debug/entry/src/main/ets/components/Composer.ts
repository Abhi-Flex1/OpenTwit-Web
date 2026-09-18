if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Composer_Params {
    draft?: string;
    placeholder?: string;
    onPost?: (content: string) => void;
}
import { FONT_FAMILY } from "@bundle:com.example.opentwit/entry/ets/common/Theme";
const MAX_LENGTH: number = 280;
export class Composer extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__draft = new ObservedPropertySimplePU('', this, "draft");
        this.__placeholder = new SynchedPropertySimpleOneWayPU(params.placeholder, this, "placeholder");
        this.onPost = undefined;
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Composer_Params) {
        if (params.draft !== undefined) {
            this.draft = params.draft;
        }
        if (params.placeholder === undefined) {
            this.__placeholder.set('');
        }
        if (params.onPost !== undefined) {
            this.onPost = params.onPost;
        }
    }
    updateStateVars(params: Composer_Params) {
        this.__placeholder.reset(params.placeholder);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__draft.purgeDependencyOnElmtId(rmElmtId);
        this.__placeholder.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__draft.aboutToBeDeleted();
        this.__placeholder.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __draft: ObservedPropertySimplePU<string>;
    get draft() {
        return this.__draft.get();
    }
    set draft(newValue: string) {
        this.__draft.set(newValue);
    }
    private __placeholder: SynchedPropertySimpleOneWayPU<string>;
    get placeholder() {
        return this.__placeholder.get();
    }
    set placeholder(newValue: string) {
        this.__placeholder.set(newValue);
    }
    private onPost?: (content: string) => void;
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 8 });
            Column.width('100%');
            Column.padding(16);
            Column.borderRadius({ topLeft: 16, topRight: 16 });
            Column.backgroundColor({ "id": 16777227, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextArea.create({ placeholder: this.placeholder, text: this.draft });
            TextArea.placeholderFont({ family: FONT_FAMILY });
            TextArea.fontFamily(FONT_FAMILY);
            TextArea.fontSize(15);
            TextArea.width('100%');
            TextArea.height(120);
            TextArea.onChange((value: string) => {
                this.draft = value;
            });
        }, TextArea);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.alignItems(VerticalAlign.Center);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.draft.length.toString() + ' / ' + MAX_LENGTH.toString());
            Text.fontSize(13);
            Text.fontColor({ "id": 16777233, "type": 10001, params: [], "bundleName": "com.example.opentwit", "moduleName": "entry" });
            Text.fontFamily(FONT_FAMILY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('Post');
            Button.fontFamily(FONT_FAMILY);
            Button.enabled(this.draft.trim().length > 0);
            Button.onClick(() => {
                const text: string = this.draft.trim();
                if (text.length > 0) {
                    if (this.onPost) {
                        this.onPost(text);
                    }
                    this.draft = '';
                }
            });
        }, Button);
        Button.pop();
        Row.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
