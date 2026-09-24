import {
  FONT_FAMILY, RADIUS_SM, ROW_HEIGHT, S12, S16, S2, S20, S4, S8, TOOL_BUTTON
} from '../common/Theme';
import { NativeSignIn } from './NativeSignIn';

export interface NativeChatMessage {
  id: string;
  text: string;
  outgoing: boolean;
  kind: 'text' | 'post';
  mediaUrl: string;
  mediaAlt: string;
  time: string;
  at: number;
}

export interface NativeChatAttachment {
  name: string;
  size: number;
  mimeType: string;
  preview: string;
}

export interface NativeDmMediaResult {
  conversationId: string;
  payload: string;
  nonce: string;
  localMessageId: string;
}

interface DmMediaPayload {
  state: string;
  name?: string;
  size?: number;
  mimeType?: string;
  preview?: string;
  previewUri?: string;
  messageId?: string;
  localMessageId?: string;
}

export interface NativeChatConversation {
  id: string;
  name: string;
  handle: string;
  avatar: string;
  uid: string;
  preview: string;
  time: string;
  at: number;
  unread: number;
  muted: boolean;
  messages: NativeChatMessage[];
}

// The shape the DM bridge reports. Nothing in this file invents a conversation:
// what the account actually has is what is drawn, and an empty or signed-out
// account says so.
interface DmPayloadConversation {
  id: string;
  name: string;
  handle: string;
  avatar: string;
  uid: string;
  text: string;
  out: boolean;
  at: number;
  muted: boolean;
  unread: number;
  mediaUrl: string;
  mediaAlt: string;
}

interface DmPayload {
  state: string;
  conversations?: DmPayloadConversation[];
  message?: string;
}

interface DmThreadMessage {
  id: string;
  text: string;
  out: boolean;
  at: number;
  mediaUrl: string;
  mediaAlt: string;
}

interface DmThreadPayload {
  state: string;
  id?: string;
  messages?: DmThreadMessage[];
}

interface SendStatePayload {
  state: string;
  messageId: string;
}

// The composer's emoji panel. A fixed single screen of glyphs keeps the panel
// from turning into a scrolling wall on a phone.
const EMOJI: string[] = [
  '\u{1F44D}', '\u{1F602}', '\u{1F525}', '\u{1F64C}', '\u{1F60D}', '\u{1F440}', '\u{1F389}',
  '\u{2764}\u{FE0F}', '\u{1F4AF}', '\u{1F62E}', '\u{1F60E}', '\u{1F914}', '\u{1F64F}', '\u{2728}',
  '\u{1F4AA}', '\u{1F60A}', '\u{1F605}', '\u{1F923}', '\u{1F970}', '\u{1F973}', '\u{1F44C}',
  '\u{1F680}', '\u{1F4A1}', '\u{1F4AC}', '\u{1F4F8}', '\u{1F3AF}', '\u{1F918}', '\u{1F4A5}'
];

// Inbox filters. "Unread" is the one filter the session can honour honestly:
// verified / people-you-follow are account-graph facts that only exist once the
// real DM list has been read off the page.
const FILTER_ALL: number = 0;
const FILTER_UNREAD: number = 1;

// Native push feels immediate but not instant; HarmonyOS's own page transition
// runs at roughly this length on a phone.
const PUSH_MS: number = 260;
const POP_MS: number = 220;

function message(id: string, text: string, outgoing: boolean, time: string,
  at: number, kind: 'text' | 'post' = 'text', mediaUrl: string = '',
  mediaAlt: string = ''): NativeChatMessage {
  return { id, text, outgoing, kind, mediaUrl, mediaAlt, time, at };
}

function messagePreview(item: NativeChatMessage): string {
  if (item.text !== '') {
    return item.text;
  }
  return item.mediaUrl === '' ? '' : 'Photo';
}

function takeServerEcho(item: NativeChatMessage, serverTexts: Record<string, number[]>,
  serverMediaTimes: number[]): boolean {
  const text: string = item.text.trim();
  if (text !== '') {
    const times: number[] = serverTexts[text] ?? [];
    for (let i: number = 0; i < times.length; i++) {
      if (times[i] >= item.at) {
        times.splice(i, 1);
        return true;
      }
    }
    return false;
  }
  if (item.kind !== 'post') {
    return false;
  }
  for (let i: number = 0; i < serverMediaTimes.length; i++) {
    if (serverMediaTimes[i] >= item.at) {
      serverMediaTimes.splice(i, 1);
      return true;
    }
  }
  return false;
}

// The native Messages surface renders whatever the account actually has. The DM
// bridge (WebChrome.dmInboxScript) reads the signed-in inbox out of the page's
// own session and reports it as JSON; this turns that into the list model. There
// is no seeded fallback: an empty account shows an empty state, and a signed-out
// one asks the user to sign in, because inventing conversations would be a lie.
export function parseDmPayload(json: string): NativeChatConversation[] {
  if (json === '') {
    return [];
  }
  let payload: DmPayload | undefined = undefined;
  try {
    payload = JSON.parse(json) as DmPayload;
  } catch (err) {
    return [];
  }
  if (payload === undefined || payload.state !== 'ok' || payload.conversations === undefined) {
    return [];
  }
  const source: DmPayloadConversation[] = payload.conversations;
  const out: NativeChatConversation[] = [];
  for (let i: number = 0; i < source.length; i++) {
    const item: DmPayloadConversation = source[i];
    const name: string = item.name !== '' ? item.name : item.handle;
    const mediaUrl: string = item.mediaUrl ?? '';
    const mediaAlt: string = item.mediaAlt ?? 'Image';
    const preview: string = item.text !== '' ? item.text : (mediaUrl !== '' ? 'Photo' : '');
    out.push({
      id: item.id,
      name: name,
      handle: item.handle,
      avatar: item.avatar,
      uid: item.uid ?? '',
      preview: item.out ? 'You: ' + preview : preview,
      time: relativeTime(item.at),
      at: item.at,
      unread: item.unread ?? 0,
      muted: item.muted === true,
      // The inbox carries the newest message per conversation, so the thread
      // opens on the real one rather than on an empty page. Full history
      // arrives separately through the thread payload (see onThreadChanged).
      messages: item.text === '' && mediaUrl === ''
        ? []
        : [message(
          'dm-' + item.id + '-0',
          item.text,
          item.out,
          relativeTime(item.at),
          item.at,
          mediaUrl === '' ? 'text' : 'post',
          mediaUrl,
          mediaAlt
        )]
    });
  }
  return out;
}

export function parseDmThread(json: string): DmThreadPayload {
  if (json === '') {
    return { state: 'loading' };
  }
  try {
    const payload = JSON.parse(json) as DmThreadPayload;
    if (!payload || !payload.state) {
      return { state: 'error' };
    }
    return payload;
  } catch (err) {
    return { state: 'error' };
  }
}

// Timestamps arrive as epoch milliseconds. The list shows the same shorthand the
// What the bridge said about the account, as a small closed set the surface can
// branch on. Anything unrecognised is treated as an error rather than as empty,
// so a broken read never looks like an empty inbox.
export function dmStateOf(json: string): string {
  if (json === '') {
    return 'loading';
  }
  let payload: DmPayload | undefined = undefined;
  try {
    payload = JSON.parse(json) as DmPayload;
  } catch (err) {
    return 'error';
  }
  if (payload === undefined || payload.state === undefined || payload.state === '') {
    return 'error';
  }
  return payload.state;
}

// Timestamps arrive as epoch milliseconds. The list shows the same shorthand the
// stock client does rather than a raw date.
function relativeTime(at: number): string {
  if (at <= 0) {
    return '';
  }
  const seconds: number = Math.floor((Date.now() - at) / 1000);
  if (seconds < 60) {
    return 'now';
  }
  const minutes: number = Math.floor(seconds / 60);
  if (minutes < 60) {
    return minutes.toString() + 'm';
  }
  const hours: number = Math.floor(minutes / 60);
  if (hours < 24) {
    return hours.toString() + 'h';
  }
  const days: number = Math.floor(hours / 24);
  if (days < 7) {
    return days.toString() + 'd';
  }
  const date: Date = new Date(at);
  return (date.getMonth() + 1).toString() + '/' + date.getDate().toString();
}


@Component
export struct NativeMessages {
  @Prop @Watch('onOpenChanged') open: boolean = false;
  // What the DM bridge last reported, verbatim. Parsing it here keeps the shell
  // free of any opinion about how a conversation is drawn.
  @Prop @Watch('onDmChanged') dmJson: string = '';
  // Full history for the open conversation, verbatim from dmThreadScript.
  @Prop @Watch('onThreadChanged') threadJson: string = '';
  @Prop @Watch('onSendStateChanged') sendStateJson: string = '';
  @Prop @Watch('onDmMediaChanged') dmMediaResultJson: string = '';
  @State conversations: NativeChatConversation[] = [];
  // What the bridge said about the account, so the surface can be honest about
  // why there is nothing to show.
  @State dmState: string = '';
  @State threadState: string = '';
  @State selectedId: string = '';
  @State activeMessages: NativeChatMessage[] = [];
  @State searchText: string = '';
  @State composerText: string = '';
  @State sending: boolean = false;
  @State attachment: NativeChatAttachment = {
    name: '',
    size: 0,
    mimeType: '',
    preview: ''
  };
  // Drives the inbox <-> thread push. It lives here rather than in the shell so
  // the slide runs even when the shell only flips its own title state, which is
  // what the header back arrow and the system back gesture both do.
  @State inConversation: boolean = false;
  @State emojiOpen: boolean = false;
  @State filterIndex: number = FILTER_ALL;
  private threadScroller: Scroller = new Scroller();
  private readCutoffs: Map<string, number> = new Map<string, number>();
  onConversationChange: (open: boolean, title: string) => void = () => {
  };
  // The shell owns the WebView, so history and sending go through it.
  onRequestThread: (id: string) => void = () => {
  };
  onSendMessage: (id: string, uid: string, text: string, messageId: string) => void = () => {
  };
  onRequestMedia: (id: string) => void = () => {
  };
  onSendMedia: (id: string, text: string, messageId: string) => void = () => {
  };
  onRemoveAttachment: (id: string) => void = () => {
  };
  onMuteConversation: (id: string, muted: boolean) => void = () => {
  };
  onSignIn: () => void = () => {
  };

  aboutToAppear(): void {
    this.onConversationChange(false, '');
    this.onDmChanged();
    this.onThreadChanged();
  }

  // A refresh from the shell never costs the user what they typed and sent in
  // this session: local replies on the open conversation are re-appended to the
  // fresh inbox data.
  onDmChanged(): void {
    const list: NativeChatConversation[] = parseDmPayload(this.dmJson);
    // Preserve per-conversation local state across inbox polls: unsent/sent
    // bubbles, mute toggles and the uid the send path needs.
    for (let i: number = 0; i < list.length; i++) {
      const prev: NativeChatConversation | undefined = this.conversations.find(
        (item: NativeChatConversation) => item.id === list[i].id);
      if (prev === undefined) {
        continue;
      }
      const mine: NativeChatMessage[] = prev.messages.filter(
        (m: NativeChatMessage) => m.id.indexOf('sent-') === 0);
      if (mine.length > 0) {
        // Drop optimistic bubbles the server has since echoed back, so a real
        // send does not appear twice.
        const serverTexts: Record<string, number[]> = {};
        const serverMediaTimes: number[] = [];
        for (let s: number = 0; s < list[i].messages.length; s++) {
          const server: NativeChatMessage = list[i].messages[s];
          if (server.outgoing && server.text.trim() !== '') {
            const key: string = server.text.trim();
            const times: number[] = serverTexts[key] ?? [];
            times.push(server.at);
            serverTexts[key] = times;
          }
          if (server.outgoing && server.kind === 'post') {
            serverMediaTimes.push(server.at);
          }
        }
        const fresh: NativeChatMessage[] = [];
        for (let m: number = 0; m < mine.length; m++) {
          if (!takeServerEcho(mine[m], serverTexts, serverMediaTimes)) {
            fresh.push(mine[m]);
          }
        }
        list[i].messages = list[i].messages.concat(fresh);
      }
      if (list[i].uid === '' && prev.uid !== '') {
        list[i].uid = prev.uid;
      }
      const readAt: number = this.readCutoffs.get(list[i].id) ?? 0;
      if (readAt > 0 && list[i].messages.length > 0 &&
        list[i].messages[list[i].messages.length - 1].at <= readAt) {
        list[i].unread = 0;
      }
    }
    this.dmState = dmStateOf(this.dmJson);
    this.conversations = list;
    if (this.inConversation) {
      const active: NativeChatConversation | undefined = this.currentConversation();
      if (active !== undefined && this.threadState !== 'ok') {
        this.activeMessages = active.messages.slice();
        this.scrollThreadToEnd();
      }
    }
  }

  // Real thread history for the open conversation. Server messages replace the
  // inbox preview; optimistic `sent-` bubbles survive unless the server has
  // echoed the same text back.
  onThreadChanged(): void {
    const parsed: DmThreadPayload = parseDmThread(this.threadJson);
    this.threadState = parsed.state;
    if (parsed.state !== 'ok' || !parsed.messages || parsed.id !== this.selectedId) {
      return;
    }
    const conversation: NativeChatConversation | undefined = this.currentConversation();
    if (conversation === undefined) {
      return;
    }
    const server: NativeChatMessage[] = [];
    const src = parsed.messages;
    for (let i: number = 0; i < src.length; i++) {
      const m = src[i];
      if (!m || (!m.text && !m.mediaUrl)) {
        continue;
      }
      server.push(message(
        'srv-' + m.id,
        m.text,
        m.out,
        relativeTime(m.at),
        m.at,
        m.mediaUrl === '' ? 'text' : 'post',
        m.mediaUrl,
        m.mediaAlt
      ));
    }
    const mine: NativeChatMessage[] = conversation.messages.filter(
      (m: NativeChatMessage) => m.id.indexOf('sent-') === 0);
    const serverTexts: Record<string, number[]> = {};
    const serverMediaTimes: number[] = [];
    for (let s: number = 0; s < server.length; s++) {
      if (server[s].outgoing && server[s].text.trim() !== '') {
        const key: string = server[s].text.trim();
        const times: number[] = serverTexts[key] ?? [];
        times.push(server[s].at);
        serverTexts[key] = times;
      }
      if (server[s].outgoing && server[s].kind === 'post') {
        serverMediaTimes.push(server[s].at);
      }
    }
    const fresh: NativeChatMessage[] = [];
    for (let m: number = 0; m < mine.length; m++) {
      if (!takeServerEcho(mine[m], serverTexts, serverMediaTimes)) {
        fresh.push(mine[m]);
      }
    }
    const merged: NativeChatMessage[] = server.concat(fresh);
    conversation.messages = merged;
    this.activeMessages = merged.slice();
    if (merged.length > 0) {
      const last: NativeChatMessage = merged[merged.length - 1];
      const preview: string = messagePreview(last);
      conversation.preview = (last.outgoing ? 'You: ' : '') + preview;
      conversation.time = last.time;
    }
    this.conversations = this.conversations.slice();
    this.scrollThreadToEnd();
  }

  private removePendingMessage(messageId: string, restoreComposer: boolean): void {
    let restored: string = '';
    for (let ci: number = 0; ci < this.conversations.length; ci++) {
      const conversation: NativeChatConversation = this.conversations[ci];
      const remaining: NativeChatMessage[] = [];
      for (let mi: number = 0; mi < conversation.messages.length; mi++) {
        if (conversation.messages[mi].id === messageId) {
          restored = conversation.messages[mi].text;
        } else {
          remaining.push(conversation.messages[mi]);
        }
      }
      if (remaining.length !== conversation.messages.length) {
        conversation.messages = remaining;
      }
    }
    if (restoreComposer && restored !== '' && this.composerText === '') {
      this.composerText = restored;
    }
    const active: NativeChatMessage[] = [];
    for (let i: number = 0; i < this.activeMessages.length; i++) {
      if (this.activeMessages[i].id !== messageId) {
        active.push(this.activeMessages[i]);
      }
    }
    this.activeMessages = active;
    this.conversations = this.conversations.slice();
  }

  private onSendStateChanged(): void {
    if (this.sendStateJson === '') {
      return;
    }
    try {
      const payload = JSON.parse(this.sendStateJson) as SendStatePayload;
      if (payload.state === 'error') {
        this.removePendingMessage(payload.messageId, true);
        this.sending = false;
      } else if (payload.state === 'ok' || payload.state === 'accepted') {
        this.sending = false;
      }
    } catch (err) {
    }
  }

  // The shell closes a thread from its back arrow and from the system back
  // gesture; both only flip `open`, so the pop transition is driven from here.
  onOpenChanged(): void {
    if (!this.open && this.inConversation) {
      this.popConversation();
    }
  }

  onDmMediaChanged(): void {
    if (this.dmMediaResultJson === '') {
      return;
    }
    try {
      const result: NativeDmMediaResult = JSON.parse(this.dmMediaResultJson) as NativeDmMediaResult;
      if (result.conversationId !== this.selectedId) {
        return;
      }
      const payload: DmMediaPayload = JSON.parse(result.payload) as DmMediaPayload;
      if (payload.state === 'selected') {
        this.attachment = {
          name: payload.name ?? 'Image',
          size: payload.size ?? 0,
          mimeType: payload.mimeType ?? '',
          preview: payload.previewUri ?? ''
        };
        this.toast($r('app.string.messages_attachment_selected'));
      } else if (payload.state === 'ok') {
        if (result.localMessageId !== undefined && result.localMessageId !== '') {
          this.removePendingMessage(result.localMessageId, false);
        }
        this.attachment = { name: '', size: 0, mimeType: '', preview: '' };
        this.sending = false;
        this.composerText = '';
      } else if (payload.state === 'cancelled' ||
        payload.state === 'navigation-cancelled') {
        if (result.localMessageId !== undefined && result.localMessageId !== '') {
          this.removePendingMessage(result.localMessageId, false);
        }
        this.attachment = { name: '', size: 0, mimeType: '', preview: '' };
        this.sending = false;
      } else {
        if (result.localMessageId !== undefined && result.localMessageId !== '') {
          this.removePendingMessage(result.localMessageId, true);
        }
        this.sending = false;
        this.toast($r('app.string.messages_send_unavailable'));
      }
    } catch (err) {
    }
  }

  private popConversation(): void {
    if (this.selectedId !== '') {
      this.onRemoveAttachment(this.selectedId);
    }
    this.attachment = { name: '', size: 0, mimeType: '', preview: '' };
    this.sending = false;
    this.emojiOpen = false;
    this.threadState = '';
    this.getUIContext().animateTo({ duration: POP_MS, curve: Curve.FastOutSlowIn }, () => {
      this.inConversation = false;
    });
    this.selectedId = '';
  }

  private currentConversation(): NativeChatConversation | undefined {
    return this.conversations.find((item: NativeChatConversation) => item.id === this.selectedId);
  }

  private filteredConversations(): NativeChatConversation[] {
    let list: NativeChatConversation[] = this.conversations;
    if (this.filterIndex === FILTER_UNREAD) {
      list = list.filter((item: NativeChatConversation) => item.unread > 0);
    }
    const query: string = this.searchText.trim().toLowerCase();
    if (query === '') {
      return list;
    }
    return list.filter((item: NativeChatConversation) =>
      item.name.toLowerCase().indexOf(query) >= 0 ||
        item.preview.toLowerCase().indexOf(query) >= 0);
  }

  private initials(name: string): string {
    let result: string = '';
    const words: string[] = name.split(' ');
    for (let i: number = 0; i < words.length && result.length < 2; i++) {
      const word: string = words[i].trim();
      if (word.length > 0) {
        result += word.charAt(0).toUpperCase();
      }
    }
    return result === '' ? '?' : result;
  }

  private openConversation(id: string): void {
    const conversation: NativeChatConversation | undefined =
      this.conversations.find((item: NativeChatConversation) => item.id === id);
    if (conversation === undefined) {
      return;
    }
    this.selectedId = id;
    this.readCutoffs.set(id, conversation.at);
    this.activeMessages = conversation.messages.slice();
    this.threadState = 'loading';
    this.composerText = '';
    this.emojiOpen = false;
    if (conversation.unread > 0) {
      conversation.unread = 0;
      this.conversations = this.conversations.slice();
    }
    this.getUIContext().animateTo({ duration: PUSH_MS, curve: Curve.FastOutSlowIn }, () => {
      this.inConversation = true;
    });
    this.onConversationChange(true, conversation.name);
    this.onRequestThread(id);
    this.scrollThreadToEnd();
  }

  private scrollThreadToEnd(): void {
    // The new node is not laid out until the frame after the state change.
    setTimeout(() => {
      try {
        this.threadScroller.scrollEdge(Edge.Bottom);
      } catch (err) {
      }
    }, 90);
  }

  private sendMessage(): void {
    const text: string = this.composerText.trim();
    const conversation: NativeChatConversation | undefined = this.currentConversation();
    if (conversation === undefined || this.sending) {
      return;
    }
    if (text === '' && this.attachment.name === '') {
      return;
    }
    this.sending = true;
    const messageId: string = 'sent-' + Date.now().toString();
    const pending: NativeChatMessage = message(
      messageId,
      text,
      true,
      this.clockNow(),
      Date.now(),
      this.attachment.name === '' ? 'text' : 'post',
      this.attachment.preview,
      this.attachment.name
    );
    conversation.messages = conversation.messages.concat([pending]);
    this.activeMessages = this.activeMessages.concat([pending]);
    const preview: string = text !== '' ? text : 'Photo';
    conversation.preview = 'You: ' + preview;
    conversation.time = 'now';
    this.conversations = this.conversations.slice();
    if (this.attachment.name === '') {
      this.composerText = '';
    }
    this.emojiOpen = false;
    this.scrollThreadToEnd();
    if (this.attachment.name === '') {
      this.onSendMessage(conversation.id, conversation.uid, text, messageId);
    } else {
      this.onSendMedia(conversation.id, text, messageId);
    }
  }

  private addAttachment(): void {
    const conversation: NativeChatConversation | undefined = this.currentConversation();
    if (conversation === undefined || this.sending) {
      return;
    }
    this.emojiOpen = false;
    this.onRequestMedia(conversation.id);
  }

  private removeAttachment(): void {
    if (this.sending) {
      return;
    }
    const conversation: NativeChatConversation | undefined = this.currentConversation();
    if (conversation !== undefined) {
      this.onRemoveAttachment(conversation.id);
    }
    this.attachment = { name: '', size: 0, mimeType: '', preview: '' };
  }

  private clockNow(): string {
    const now: Date = new Date();
    const hours: string = now.getHours() < 10 ? '0' + now.getHours() : now.getHours().toString();
    const minutes: string = now.getMinutes() < 10 ? '0' + now.getMinutes() : now.getMinutes().toString();
    return hours + ':' + minutes;
  }

  private toggleMute(id: string): void {
    const conversation: NativeChatConversation | undefined =
      this.conversations.find((item: NativeChatConversation) => item.id === id);
    if (conversation === undefined) {
      return;
    }
    this.onMuteConversation(id, !conversation.muted);
  }

  private toast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1600 });
    } catch (err) {
    }
  }

  @Builder
  avatar(name: string, url: string, size: number) {
    Stack() {
      Circle()
        .width(size)
        .height(size)
        .fill($r('sys.color.ohos_id_color_emphasize'))
      Text(this.initials(name))
        .fontSize(size >= 44 ? 15 : 13)
        .fontFamily(FONT_FAMILY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_foreground_contrary'))
      // The account's real picture from the inbox payload. It sits over the
      // initials, so a picture that is missing or fails to load leaves a usable
      // avatar rather than an empty hole.
      if (url !== '') {
        Image(url)
          .width(size)
          .height(size)
          .borderRadius(size / 2)
          .objectFit(ImageFit.Cover)
          .alt($r('sys.color.ohos_id_color_sub_background'))
      }
    }
    .width(size)
    .height(size)
    // The display name sits right beside the disc, so the disc is decoration.
    .accessibilityLevel('no')
  }

  @Builder
  swipeAction(symbol: Resource, label: Resource, action: () => void) {
    Column({ space: S4 }) {
      Button({ type: ButtonType.Circle }) {
        // The disc is a Circle shape rather than the Button's own background:
        // a shape node rasterises identically on the emulator and on device,
        // where a filled circular Button background can drop out.
        Stack() {
          Circle()
            .width(TOOL_BUTTON)
            .height(TOOL_BUTTON)
            .fill($r('sys.color.ohos_id_color_sub_background'))
          SymbolGlyph(symbol)
            .fontSize(20)
            .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        }
        .width(TOOL_BUTTON)
        .height(TOOL_BUTTON)
      }
      .width(TOOL_BUTTON)
      .height(TOOL_BUTTON)
      .backgroundColor(Color.Transparent)
      .accessibilityText(label)
      .accessibilityLevel('yes')
      .onClick(action)
      Text(label)
        .fontSize(11)
        .fontFamily(FONT_FAMILY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
    .width(64)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  rowActions(item: NativeChatConversation) {
    Row({ space: S8 }) {
      this.swipeAction(item.muted ? $r('sys.symbol.bell_fill') : $r('sys.symbol.bell_slash_fill'),
        item.muted ? $r('app.string.messages_unmute') : $r('app.string.messages_mute'),
        () => {
          this.toggleMute(item.id);
        })
    }
    .height('100%')
    .padding({ left: S16, right: S20 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  conversationRow(item: NativeChatConversation) {
    ListItem() {
      Row({ space: S12 }) {
        this.avatar(item.name, item.avatar, 48)
        Column({ space: S2 }) {
          Row({ space: S4 }) {
            Text(item.name)
              .fontSize(16)
              .fontFamily(FONT_FAMILY)
              .fontWeight(item.unread > 0 ? FontWeight.Bold : FontWeight.Medium)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .layoutWeight(1)
            if (item.muted) {
              SymbolGlyph($r('sys.symbol.bell_slash_fill'))
                .fontSize(13)
                .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
                .accessibilityLevel('no')
            }
            Text(item.time)
              .fontSize(12)
              .fontFamily(FONT_FAMILY)
              .fontColor(item.unread > 0
                ? $r('sys.color.ohos_id_color_emphasize')
                : $r('sys.color.ohos_id_color_text_secondary'))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          Text(item.preview)
            .fontSize(14)
            .fontFamily(FONT_FAMILY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .constraintSize({ minHeight: ROW_HEIGHT })
      .padding({ left: S20, right: S20, top: S12, bottom: S12 })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.openConversation(item.id);
      })
    }
    .swipeAction({
      end: {
        builder: () => {
          this.rowActions(item)
        },
        actionAreaDistance: 72
      },
      edgeEffect: SwipeEdgeEffect.Spring
    })
  }

  @Builder
  messageBubble(item: NativeChatMessage) {
    Column({ space: S2 }) {
      if (item.kind === 'post') {
        if (item.mediaUrl !== '') {
          Image(item.mediaUrl)
            .width('78%')
            .aspectRatio(1.35)
            .objectFit(ImageFit.Contain)
            .borderRadius(RADIUS_SM)
            .clip(true)
            .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
            .accessibilityText(item.mediaAlt)
            .accessibilityLevel('yes')
        } else {
          Stack() {
            Circle()
              .width(96)
              .height(96)
              .fill($r('sys.color.ohos_id_color_emphasize'))
            SymbolGlyph($r('sys.symbol.picture_fill'))
              .fontSize(36)
              .fontColor([$r('sys.color.ohos_id_color_foreground_contrary')])
          }
          .width(96)
          .height(96)
          .accessibilityText(item.mediaAlt)
          .accessibilityLevel('yes')
        }
      }
      if (item.text !== '') {
        // The Row owns the fill and radius while the Text stays transparent.
        // This keeps one continuous surface for wrapped messages without the
        // emulator's faulty Text background paint path.
        Row() {
          Text(item.text)
            .fontSize(16)
            .fontFamily(FONT_FAMILY)
            .fontColor(item.outgoing
              ? $r('sys.color.ohos_id_color_foreground_contrary')
              : $r('sys.color.ohos_id_color_text_primary'))
        }
        .constraintSize({ maxWidth: '78%' })
        .padding({ left: S12, right: S12, top: S8, bottom: S8 })
        .borderRadius(RADIUS_SM)
        .backgroundColor(item.outgoing
          ? $r('sys.color.ohos_id_color_emphasize')
          : $r('sys.color.ohos_id_color_sub_background'))
      }
      Text(item.time)
        .fontSize(11)
        .fontFamily(FONT_FAMILY)
        .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
    }
    .width('100%')
    .alignItems(item.outgoing ? HorizontalAlign.End : HorizontalAlign.Start)
    .padding({ left: S16, right: S16, top: S4, bottom: S4 })
  }

  @Builder
  emojiPanel() {
    Grid() {
      ForEach(EMOJI, (item: string, index: number) => {
        GridItem() {
          Text(item)
            .fontSize(24)
            .width('100%')
            .height('100%')
            .textAlign(TextAlign.Center)
        }
        .height(44)
        .onClick(() => {
          this.composerText = this.composerText + item;
        })
      }, (item: string, index: number) => index.toString())
    }
    .columnsTemplate('repeat(7, 1fr)')
    .rowsGap(S4)
    .width('100%')
    .height(196)
    .padding({ left: S8, right: S8, top: S8, bottom: S8 })
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  composerBar() {
    Column({ space: 0 }) {
      if (this.attachment.name !== '') {
        Row({ space: S8 }) {
          if (this.attachment.preview !== '') {
            Image(this.attachment.preview)
              .width(52)
              .height(52)
              .objectFit(ImageFit.Cover)
              .borderRadius(RADIUS_SM)
              .clip(true)
          } else {
            Stack() {
              Circle()
                .width(52)
                .height(52)
                .fill($r('sys.color.ohos_id_color_emphasize'))
              SymbolGlyph($r('sys.symbol.picture_fill'))
                .fontSize(24)
                .fontColor([$r('sys.color.ohos_id_color_foreground_contrary')])
            }
            .width(52)
            .height(52)
          }
          Column({ space: S2 }) {
            Text(this.attachment.name)
              .fontSize(13)
              .fontFamily(FONT_FAMILY)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text($r('app.string.messages_attachment_selected'))
              .fontSize(11)
              .fontFamily(FONT_FAMILY)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(16)
              .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
          }
          .width(36)
          .height(36)
          .backgroundColor(Color.Transparent)
          .accessibilityText($r('app.string.messages_remove_attachment'))
          .accessibilityLevel('yes')
          .onClick(() => {
            this.removeAttachment();
          })
        }
        .width('100%')
        .padding({ left: S12, right: S12, top: S8, bottom: S4 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      }
      if (this.emojiOpen) {
        this.emojiPanel()
      }
      Row({ space: S4 }) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.picture'))
            .fontSize(22)
            .fontColor([this.sending
              ? $r('sys.color.ohos_id_color_text_tertiary')
              : $r('sys.color.ohos_id_color_text_secondary')])
        }
        .width(TOOL_BUTTON)
        .height(TOOL_BUTTON)
        .backgroundColor(Color.Transparent)
        .accessibilityText($r('app.string.messages_add_attachment'))
        .accessibilityLevel('yes')
        .onClick(() => {
          this.addAttachment();
        })

        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.face_smiling'))
            .fontSize(22)
            .fontColor([this.emojiOpen
              ? $r('sys.color.ohos_id_color_emphasize')
              : $r('sys.color.ohos_id_color_text_secondary')])
        }
        .width(TOOL_BUTTON)
        .height(TOOL_BUTTON)
        .backgroundColor(Color.Transparent)
        .accessibilityText($r('app.string.messages_emoji'))
        .accessibilityLevel('yes')
        .onClick(() => {
          this.emojiOpen = !this.emojiOpen;
        })

        TextInput({
          text: $$this.composerText,
          placeholder: $r('app.string.messages_composer_placeholder')
        })
          .layoutWeight(1)
          .height(TOOL_BUTTON)
          .fontSize(16)
          .fontFamily(FONT_FAMILY)
          .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
          .borderRadius(TOOL_BUTTON / 2)
          .padding({ left: S12, right: S12 })
          .enterKeyType(EnterKeyType.Send)
          .enabled(!this.sending)
          .onSubmit(() => {
            this.sendMessage();
          })

        Button({ type: ButtonType.Circle }) {
          Stack() {
            Circle()
              .width(TOOL_BUTTON)
              .height(TOOL_BUTTON)
              // HarmonyOS greys a control that cannot act instead of removing
              // it, so the send slot keeps its position and size in both states.
              .fill((this.composerText.trim() === '' && this.attachment.name === '') || this.sending
                ? $r('sys.color.ohos_id_color_button_normal')
                : $r('sys.color.ohos_id_color_emphasize'))
            SymbolGlyph($r('sys.symbol.paperplane_fill'))
              .fontSize(20)
              .fontColor([(this.composerText.trim() === '' && this.attachment.name === '') || this.sending
                ? $r('sys.color.ohos_id_color_text_secondary')
                : $r('sys.color.ohos_id_color_foreground_contrary')])
          }
          .width(TOOL_BUTTON)
          .height(TOOL_BUTTON)
        }
        .width(TOOL_BUTTON)
        .height(TOOL_BUTTON)
        .backgroundColor(Color.Transparent)
        .accessibilityText($r('app.string.messages_send'))
        .accessibilityLevel('yes')
        .onClick(() => {
          if ((this.composerText.trim() !== '' || this.attachment.name !== '') && !this.sending) {
            this.sendMessage();
          }
        })
      }
      .width('100%')
      .padding({ left: S8, right: S8, top: S4, bottom: S8 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }

  @Builder
  conversationView() {
    Column({ space: 0 }) {
      if (this.threadState === 'loading') {
        Row() {
          LoadingProgress()
            .width(24)
            .height(24)
            .color($r('sys.color.ohos_id_color_emphasize'))
          Text($r('app.string.messages_loading_thread'))
            .fontSize(13)
            .fontFamily(FONT_FAMILY)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: S8, bottom: S4 })
      }
      // A thread is bottom-anchored like every other chat surface: with only a
      // few messages the bubbles sit on the composer instead of floating at the
      // top of an empty page, and a long thread scrolls from the same edge.
      Scroll(this.threadScroller) {
        Column({ space: 0 }) {
          ForEach(this.activeMessages, (item: NativeChatMessage) => {
            this.messageBubble(item)
          }, (item: NativeChatMessage) => item.id)
        }
        .width('100%')
        .padding({ top: S8, bottom: S8 })
        .justifyContent(FlexAlign.End)
        .constraintSize({ minHeight: '100%' })
      }
      .layoutWeight(1)
      .width('100%')
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)

      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.ohos_id_color_list_separator'))

      this.composerBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    // A pushed screen enters from, and leaves to, the end edge. TransitionEdge
    // follows the layout direction, so this reads as a push in LTR and in RTL.
    .transition(TransitionEffect.move(TransitionEdge.END))
  }

  @Builder
  filterMenu() {
    Menu() {
      MenuItem({
        content: $r('app.string.messages_filter_all'),
        labelInfo: this.filterIndex === FILTER_ALL ? ' ' : ''
      })
        .onClick(() => {
          this.filterIndex = FILTER_ALL;
        })
      MenuItem({
        content: $r('app.string.messages_filter_unread'),
        labelInfo: this.filterIndex === FILTER_UNREAD ? ' ' : ''
      })
        .onClick(() => {
          this.filterIndex = FILTER_UNREAD;
        })
    }
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
  }

  // One shape for every reason the list can be empty, so the surface never shows
  // a blank page: the account is signed out, the read is still running, the read
  // failed, or the account genuinely has no conversations.
  @Builder
  statePanel(symbol: Resource, title: Resource, message: Resource) {
    Column({ space: S8 }) {
      SymbolGlyph(symbol)
        .fontSize(44)
        .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
      Text(title)
        .fontSize(17)
        .fontFamily(FONT_FAMILY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
      Text(message)
        .fontSize(14)
        .fontFamily(FONT_FAMILY)
        .textAlign(TextAlign.Center)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(S16)
  }

  @Builder
  inboxView() {
    Column({ space: 0 }) {
      Row({ space: S8 }) {
        Blank()
        // The filter is a menu trigger, so it carries the chevron the platform
        // puts on one instead of looking like a static pill.
        Row({ space: S2 }) {
          Text(this.filterIndex === FILTER_UNREAD
            ? $r('app.string.messages_filter_unread')
            : $r('app.string.messages_filter_all'))
            .fontSize(14)
            .fontFamily(FONT_FAMILY)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(12)
            .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
            .accessibilityLevel('no')
        }
        .padding({ left: S12, right: S8, top: S8, bottom: S8 })
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .borderRadius(16)
        .accessibilityText($r('app.string.messages_filter_title'))
        .accessibilityLevel('yes')
        .bindMenu(this.filterMenu)
      }
      .width('100%')
      .padding({ left: S20, right: S8, top: S8, bottom: S4 })
      .alignItems(VerticalAlign.Center)

      Search({
        value: $$this.searchText,
        placeholder: $r('app.string.messages_search_placeholder')
      })
        .width('calc(100% - 40vp)')
        .height(TOOL_BUTTON)
        .margin({ left: S20, right: S20, bottom: S8 })
        .placeholderFont({ size: 15, family: FONT_FAMILY })
        .textFont({ size: 15, family: FONT_FAMILY })

      if (this.dmState === 'signed-out') {
        NativeSignIn({
          onSignIn: () => {
            this.onSignIn();
          }
        })
      } else if (this.dmState === 'loading') {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color($r('sys.color.ohos_id_color_emphasize'))
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.dmState !== 'ok') {
        this.statePanel($r('sys.symbol.exclamationmark_circle_fill'),
          $r('app.string.messages_unavailable_title'),
          $r('app.string.messages_unavailable_message'))
      } else if (this.filteredConversations().length === 0) {
        this.statePanel($r('sys.symbol.message_fill'),
          $r('app.string.messages_empty_title'),
          $r('app.string.messages_empty_message'))
      } else {
        List({ space: 0 }) {
          ForEach(this.filteredConversations(), (item: NativeChatConversation) => {
            this.conversationRow(item)
          }, (item: NativeChatConversation) => item.id)
        }
        .layoutWeight(1)
        .width('100%')
        // Bottom breathing room: without it the last row sits hard against the
        // shell's tab bar and the list looks cut off.
        .padding({ bottom: S8 })
        .edgeEffect(EdgeEffect.Spring)
        .cachedCount(8)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    // The list the push came from, so it slides out towards the start edge and
    // slides back in when the thread pops.
    .transition(TransitionEffect.move(TransitionEdge.START))
  }

  build() {
    Stack() {
      if (this.inConversation) {
        this.conversationView()
      } else {
        this.inboxView()
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
