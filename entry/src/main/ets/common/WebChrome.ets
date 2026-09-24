// OpenTwit-Web runs the real x.com web app inside a native HarmonyOS shell.
// "Native" means the shell owns every piece of app chrome: title bar, menus,
// search field, tab bar / rail, compose sheet, progress, error and empty states.
// The scripts below remove x.com's own copy of that chrome (its top nav, its
// bottom nav and its floating compose button) so the two never double up, and
// they report page state back to the shell.
//
// All scripts are injected as strings through WebviewController.runJavaScript.

import { pageBridgeScript } from './PageBridge';

// CSS injected once per page. Tab roots lose X's own navigation rows; the
// floating compose button is always dropped because the shell provides a native
// one (only rendered while signed in).
// HarmonyOS Sans for every text node the web page draws. The shell is a
// HarmonyOS app, so X's own webfont (Chirp) is not used: the page inherits the
// platform family. Emoji, CJK and symbol fallbacks still resolve through the
// system stack behind HarmonyOS Sans.
const FONT_CSS: string =
  "*{font-family:'HarmonyOS Sans','HarmonyOS Sans SC','HarmonyOS Sans TC'," +
  "'HarmonyOS Sans Naskh Arabic UI',sans-serif!important}";

const CHROME_CSS: string =
  "nav[aria-label='Primary']{display:none!important}" +
  "[data-testid='FloatingActionButtons_Tweet_Button']{display:none!important}" +
  // Wide layouts: x.com renders its desktop side navigation, whose account
  // button sits in the corner the shell's own rail occupies.
  "[data-testid='SideNav_AccountSwitcher_Button']{display:none!important}" +
  FONT_CSS;

// Handle of the account the page is signed in as, or ''. Exposed by the
// observer below as window.__otOwn(), which re-scans on every DOM mutation:
// x.com hydrates the navigation client-side, so the account links do not exist
// yet when onPageEnd fires and a single synchronous read always comes back
// empty on the mobile web.
export const OWN_HANDLE_SCRIPT: string = '(window.__otOwn?window.__otOwn():"")';

// ArkWeb reports navigator.onLine as false on some images even while the page
// is being served over a working connection (reproduced on both the foldable
// and the 2in1 emulator: navigator.connection said "4g" and every request
// succeeded while navigator.onLine stayed false). x.com believes the flag:
// the Chat inbox answered "Disconnected" and rendered "Empty inbox" with no
// conversations until it was told the browser was online again.
//
// The shell is the side that actually knows: a document that was served is, by
// definition, being served. So the flag is rewritten at document start, before
// any page script reads it, and the shell can still correct it downwards with
// window.__otOnline = false when the main frame really fails (see MainTabs).
export const ONLINE_PATCH: string =
  '(function(){try{' +
  'var otIsOnline=function(){try{return window.__otOnline!==false;}catch(e){return true;}};' +
  'try{Object.defineProperty(Navigator.prototype,"onLine",' +
  '{configurable:true,get:otIsOnline});}catch(e){}' +
  'try{Object.defineProperty(window.navigator,"onLine",' +
  '{configurable:true,get:otIsOnline});}catch(e){}' +
  '}catch(e){}})();';

// The shell's title bar and tab bar float over the page so content scrolls
// underneath them and blurs — that layering is the whole point of the frosted
// bars. For that the page's own content has to start below the bar and end above
// it, which only the page's box model can do: insetting the WebView's viewport
// instead would stop content from ever passing under the bars.
//
// Values are CSS pixels. ArkWeb reports one CSS pixel per vp on these devices
// (device px / densityPixels), so the shell can pass its vp metrics straight in.
export function immersiveInsetScript(topCssPx: number, bottomCssPx: number): string {
  return '(function(top,bottom){try{' +
    'var s=document.getElementById(\'ot-inset\');' +
    'if(!s){s=document.createElement(\'style\');s.id=\'ot-inset\';' +
    '(document.head||document.documentElement).appendChild(s);}' +
    's.textContent=\'#react-root{padding-top:\'+top+\'px !important;' +
    'padding-bottom:\'+bottom+\'px !important;box-sizing:border-box !important}\';' +
    '}catch(e){}})(' + Math.round(topCssPx) + ',' + Math.round(bottomCssPx) + ');';
}

// ---------------------------------------------------------------------------
// Direct messages, read out of the page's own session.
//
// The shell never holds a token. It runs this inside the x.com origin, where the
// session cookies already apply, so the account's real inbox is what comes back.
// The bearer token the web client uses for its own API calls is the only thing
// missing, and that is discovered once from the page's own scripts and cached on
// the window — it is the same public web token every x.com browser session
// already carries.
//
// Everything here is defensive: signed out, rate limited, a rotated endpoint or
// a changed bundle all end as a state the native surface can render honestly
// instead of an exception.
// ---------------------------------------------------------------------------
// Direct messages, read out of the page's own session.
//
// The shell never holds a token. It runs this inside the x.com origin, where the
// session cookies already apply, so the account's real inbox is what comes back.
// The bearer token the web client uses for its own API calls is the only thing
// missing, and that is discovered once from the page's own scripts and cached on
// the window — it is the same public web token every x.com browser session
// already carries.
//
// Everything here is defensive: signed out, rate limited, a rotated endpoint or
// a changed bundle all end as a state the native surface can render honestly
// instead of an exception.
export function dmInboxScript(): string {
  return pageBridgeScript(
    'var r=await otGet("/i/api/1.1/dm/inbox_initial_state.json' +
    '?include_conversation_info=true&include_inbox_timelines=true&include_groups=true");' +
    'if(r.error)return JSON.stringify({state:r.error});' +
    'var st=r.data&&r.data.inbox_initial_state;' +
    'if(!st)return JSON.stringify({state:"unexpected"});' +
    'var users=st.users||{};var convs=st.conversations||{};' +
    'var accountId=otAccountFromConvs(convs);' +
    // Newest message per conversation. The conversation id lives on the message
    // envelope, not inside message_data.
    'var byId={};' +
    'var ent=(st.entries||[]);' +
    'for(var e=0;e<ent.length;e++){var en=ent[e]||{};var msg=en.message||null;' +
    'var mid=(msg&&msg.message_data)||null;' +
    'if(!mid||!msg.conversation_id)continue;' +
    'var cid=msg.conversation_id;var at=Number(msg.time)||0;' +
    'var prev=byId[cid];' +
    'if(!prev||at>prev.at){' +
    'byId[cid]={at:at,text:otText(mid.text).slice(0,140),mediaUrl:otDmMediaUrl(mid),mediaAlt:otDmMediaAlt(mid),' +
    'out:(String(mid.sender_id||"")===String(accountId))};}}' +
    'var out=[];' +
    'Object.keys(convs).forEach(function(k){var c=convs[k];if(!c)return;' +
    'var last=byId[k]||null;' +
    'var name="",handle="",avatar="",uid="";' +
    // A named conversation is a group DM and carries its own title and picture;
    // everything else is named after the other participant.
    'if(c.name){name=c.name;avatar=c.avatar_image_https||"";}' +
    'else{' +
    'var parts=(c.participants||[]).map(function(p){return users[p.user_id]||null;})' +
    '.filter(function(u){return u&&String(u.id_str||u.rest_id||"")!==String(accountId);});' +
    'if(!parts.length)return;' +
    'var u=parts[0];name=u.name||u.screen_name||"";' +
    'handle=u.screen_name||"";' +
    'uid=String(u.id_str||u.rest_id||"");' +
    'avatar=(u.profile_image_url_https||"").replace("_normal","_bigger");}' +
    'if(!name&&!handle)return;' +
    'var lastRead=String(c.last_read_event_id||"");var maxEntry=String(c.max_entry_id||"");' +
    'var unread=(lastRead!==""&&maxEntry!==""&&maxEntry!==lastRead)?1:0;' +
    'out.push({id:k,name:name,handle:handle,avatar:avatar,uid:uid,' +
    'text:last?last.text:"",mediaUrl:last?last.mediaUrl:"",mediaAlt:last?last.mediaAlt:"",out:last?last.out:false,at:last?last.at:0,' +
    'muted:!!c.muted,unread:unread});});' +
    'out.sort(function(a,b){return (b.at||0)-(a.at||0);});' +
    'return JSON.stringify({state:"ok",conversations:out.slice(0,40)});');
}

// Identity read straight off the page session, with no DOM involved. The inbox
// names its participants, so the account present in the most one-to-one
// conversations is the signed-in user, and its own entry carries the handle
// and picture. This works on every page — verified on x.com/settings/profile,
// which renders no account navigation at all, so the DOM paths (nav link,
// account menu) both come up empty there. Returns the handle straight away;
// the profile script itself still needs the DOM because it shows posts.
export function sessionIdentityScript(): string {
  return pageBridgeScript(
    'var r=await otGet("/i/api/1.1/dm/inbox_initial_state.json' +
    '?include_conversation_info=true&include_groups=true");' +
    'if(r.error)return JSON.stringify({state:r.error});' +
    'var st=r.data&&r.data.inbox_initial_state;if(!st)return JSON.stringify({state:"unexpected"});' +
    'var me=otAccountFromInbox(st);' +
    'if(!me||!me.handle)return JSON.stringify({state:"empty"});' +
    'return JSON.stringify({state:"ok",id:me.id,handle:me.handle,name:me.name,avatar:me.avatar});');
}

// Injected at document start. x.com renders the account entry after hydration
// and removes it on some routes entirely, so a signed-in page cannot be
// trusted to announce itself through its own DOM. The session cookie is
// synchronous and exact, so the page watches it and tells the native shell the
// moment a session appears — that is what closes "logged in on the page, app
// still says signed out" on routes like settings where no other signal fires.
export const SESSION_WATCHER: string =
  '(function(){try{' +
  'if(window.__otSessionWatch)return;window.__otSessionWatch=1;' +
  'var had=false;' +
  'window.__otSessionSeen=function(){try{' +
  'var now=/(?:^|;\\s*)ct0=/.test(document.cookie);' +
  'if(now&&!had){had=true;' +
  'try{if(window.otNative&&window.otNative.onSessionAppeared)window.otNative.onSessionAppeared();}catch(e){}}' +
  'else if(!now){had=false;}}catch(e){}};' +
  'try{document.addEventListener("cookieChanged",window.__otSessionSeen);}catch(e){}' +
  'try{new MutationObserver(function(){window.__otSessionSeen();}).observe(document.documentElement,{attributes:true});}catch(e){}' +
  'window.__otSessionSeen();' +
  'setInterval(window.__otSessionSeen,1000);' +
  '}catch(e){}})();';

// Full thread history for one conversation. Verified live against a signed-in
// session: `conversation_timeline` carries `entries`, `users` and
// `conversations`; message entries are flat
// `{id,time,sender_id,recipient_id,text}` while system entries
// (`participants_leave`, cursors) carry no text and are skipped. Falls back to
// filtering the inbox timeline. Returns newest-last so the native thread can
// render bottom-anchored without re-sorting.
export function dmThreadScript(conversationId: string): string {
  const safe: string = JSON.stringify(conversationId);
  return pageBridgeScript(
    'var cid=' + safe + ';' +
    'var r=await otGet("/i/api/1.1/dm/conversation/"+encodeURIComponent(cid)+".json' +
    '?include_conversation_info=true");' +
    'var msgs=[];var accountId="";' +
    'if(!r.error&&r.data){' +
    'var tl=r.data.conversation_timeline||r.data;' +
    'var users=tl.users||r.data.users||{};' +
    'var convs=tl.conversations||r.data.conversations||{};accountId=otAccountFromConvs(convs);' +
    'var entries=tl.entries||tl.timeline||[];' +
    'for(var i=0;i<entries.length;i++){var en=entries[i]||{};var m=en.message||en;var md=m.message_data||m;if(!md)continue;' +
    'var txt=otText(md.text);var mediaUrl=otDmMediaUrl(md);if(!txt&&!mediaUrl)continue;' +
    'var at=otTime(m.time||m.created_at||md.time);' +
    'var sender=String(m.sender_id||md.sender_id||"");' +
    'msgs.push({id:String(m.id||md.id||(cid+"-"+i)),text:txt.slice(0,500),mediaUrl:mediaUrl,mediaAlt:otDmMediaAlt(md),out:accountId?sender===String(accountId):false,at:at});}}' +
    'if(!msgs.length){' +
    'var b=await otGet("/i/api/1.1/dm/inbox_initial_state.json' +
    '?include_conversation_info=true&include_inbox_timelines=true");' +
    'if(b.error)return JSON.stringify({state:b.error});' +
    'var st=b.data&&b.data.inbox_initial_state;if(!st)return JSON.stringify({state:"unexpected"});' +
    'accountId=otAccountFromConvs(st.conversations||{});' +
    'var ent=(st.entries||[]);' +
    'for(var e=0;e<ent.length;e++){var en2=ent[e]||{};var mm=en2.message||null;if(!mm||mm.conversation_id!==cid)continue;' +
    'var dd=mm.message_data||{};var t2=otText(dd.text);var m2=otDmMediaUrl(dd);if(!t2&&!m2)continue;' +
    'msgs.push({id:String(mm.id||(cid+"-"+e)),text:t2.slice(0,500),mediaUrl:m2,mediaAlt:otDmMediaAlt(dd),' +
    'out:String(dd.sender_id||"")===String(accountId),at:Number(mm.time)||0});}' +
    'if(!msgs.length)return JSON.stringify({state:"empty"});}' +
    'msgs.sort(function(a,b){return (a.at||0)-(b.at||0);});' +
    'return JSON.stringify({state:"ok",id:cid,messages:msgs.slice(-60)});');
}

// Real DM send through the page session. The inbox supplies `uid` (the other
// participant) for one-to-one conversations; group sends address the
// conversation instead. Anything the API will not accept ends as a state, never
// as an exception.
export function dmSendScript(recipientId: string, text: string, conversationId: string): string {
  const rid: string = JSON.stringify(recipientId);
  const cid: string = JSON.stringify(conversationId);
  const body: string = JSON.stringify(text.slice(0, 1000));
  return pageBridgeScript(
    'var rid=' + rid + ';var cid=' + cid + ';var txt=' + body + ';' +
    'if(!txt||!txt.trim())return JSON.stringify({state:"empty"});' +
    'var target=rid?{recipient_id:rid}:{conversation_id:cid};' +
    'if(!rid&&!cid)return JSON.stringify({state:"empty"});' +
    'var r=await otPost("/i/api/1.1/direct_messages/events/new.json",' +
    '{event:{type:"message_create",message_create:{target:target,message_data:{text:txt}}}});' +
    'if(r.error)return JSON.stringify({state:r.error});' +
    'return JSON.stringify({state:"ok"});');
}

// MD5 is required by the upload endpoint for image DMs. Web Crypto does not
// expose MD5 on every ArkWeb build, so the small pure-JS implementation is a
// compatibility fallback for the browser File object we already own.
const DM_MD5_HELPER: string =
  'if(!window.otMd5){window.otMd5=async function(input){' +
  'var bytes=input instanceof Uint8Array?input:new Uint8Array(input);' +
  'try{if(window.crypto&&window.crypto.subtle){' +
  'var digest=await window.crypto.subtle.digest("MD5",bytes);var view=new Uint8Array(digest);' +
  'var out="";for(var di=0;di<view.length;di++)out+=("0"+view[di].toString(16)).slice(-2);return out;}}catch(_){}' +
  'var shifts=[7,12,17,22,7,12,17,22,7,12,17,22,7,12,17,22,' +
  '5,9,14,20,5,9,14,20,5,9,14,20,5,9,14,20,' +
  '4,11,16,23,4,11,16,23,4,11,16,23,4,11,16,23,' +
  '6,10,15,21,6,10,15,21,6,10,15,21,6,10,15,21];' +
  'var constants=[];for(var ci=0;ci<64;ci++)constants[ci]=Math.floor(Math.abs(Math.sin(ci+1))*4294967296);' +
  'function rol(value,shift){return (value<<shift)|(value>>>(32-shift));}' +
  'var paddedLength=((bytes.length+9+63)>>6)<<6;var padded=new Uint8Array(paddedLength);padded.set(bytes);' +
  'padded[bytes.length]=128;var bitLength=bytes.length*8;var low=bitLength>>>0;var high=Math.floor(bitLength/4294967296)>>>0;' +
  'var lengthOffset=paddedLength-8;padded[lengthOffset]=low&255;padded[lengthOffset+1]=(low>>>8)&255;' +
  'padded[lengthOffset+2]=(low>>>16)&255;padded[lengthOffset+3]=(low>>>24)&255;' +
  'padded[lengthOffset+4]=high&255;padded[lengthOffset+5]=(high>>>8)&255;' +
  'padded[lengthOffset+6]=(high>>>16)&255;padded[lengthOffset+7]=(high>>>24)&255;' +
  'var a0=0x67452301,b0=0xefcdab89,c0=0x98badcfe,d0=0x10325476;var words=new Uint32Array(16);' +
  'for(var block=0;block<paddedLength;block+=64){' +
  'for(var wi=0;wi<16;wi++){var at=block+wi*4;words[wi]=(padded[at]|(padded[at+1]<<8)|(padded[at+2]<<16)|(padded[at+3]<<24))>>>0;}' +
  'var a=a0,b=b0,c=c0,d=d0;for(var round=0;round<64;round++){var f;var g;var shift=shifts[round];' +
  'if(round<16){f=(b&c)|((~b)&d);g=round;}' +
  'else if(round<32){f=(d&b)|((~d)&c);g=(5*round+1)%16;}' +
  'else if(round<48){f=b^c^d;g=(3*round+5)%16;}' +
  'else{f=c^(b|((~d)&0xffffffff));g=(7*round)%16;}' +
  'var next=d;d=c;c=b;var sum=(a+f+constants[round]+words[g])>>>0;b=(b+rol(sum,shift))>>>0;a=next;}' +
  'a0=(a0+a)>>>0;b0=(b0+b)>>>0;c0=(c0+c)>>>0;d0=(d0+d)>>>0;}' +
  'var values=[a0,b0,c0,d0];var result="";for(var vi=0;vi<values.length;vi++){var value=values[vi];' +
  'for(var shift2=0;shift2<4;shift2++)result+=("0"+((value>>>(shift2*8))&255).toString(16)).slice(-2);}return result;};}';

// Opens a page-owned image input. ArkWeb's existing onShowFileSelector hook
// turns this into the system picker, while the browser keeps the real File
// object on the page side. The native shell only receives the selected URI for
// its preview; the bytes are never serialized through the JavaScript proxy.
export function dmMediaPickScript(conversationId: string): string {
  const cid: string = JSON.stringify(conversationId);
  return pageBridgeScript(
    'var cid=' + cid + ';' +
    'try{' +
    'if(!window.otNative||!window.otNative.onDmMediaRequest)return JSON.stringify({state:"bridge-unavailable"});' +
    'window.otNative.onDmMediaRequest(cid);' +
    'var old=document.getElementById("__ot_dm_media_input");if(old)old.remove();' +
    'var input=document.createElement("input");input.id="__ot_dm_media_input";' +
    'input.type="file";input.accept="image/jpeg,image/png,image/webp,image/gif";' +
    'input.style.display="none";input.multiple=false;' +
    'input.onchange=function(){var f=input.files&&input.files[0];' +
    'if(!f){if(window.otNative&&window.otNative.onDmMediaResult)window.otNative.onDmMediaResult(cid,JSON.stringify({state:"cancelled"}));return;}' +
    'if(!window.__otDmFiles)window.__otDmFiles={};if(window.__otDmFiles[cid])delete window.__otDmFiles[cid];' +
    'window.__otDmFiles[cid]=f;' +
    'if(!window.__otDmPreviews)window.__otDmPreviews={};if(window.__otDmPreviews[cid]){try{window.URL.revokeObjectURL(window.__otDmPreviews[cid]);}catch(_){}}' +
    'var preview=window.URL.createObjectURL(f);window.__otDmPreviews[cid]=preview;' +
    'if(window.otNative&&window.otNative.onDmMediaResult)window.otNative.onDmMediaResult(cid,JSON.stringify({state:"selected",name:f.name,size:f.size,mimeType:f.type,preview:preview}));};' +
    'document.body.appendChild(input);input.click();return JSON.stringify({state:"picker-requested"});' +
    '}catch(e){return JSON.stringify({state:"error",message:String(e).slice(0,120)});}');
}

// Uploads a page-owned File through the x.com session and sends it with the
// legacy REST DM contract. This is intentionally separate from dmSendScript:
// media messages must use dm/new2.json and a media_id, never the text-only
// direct_messages/events/new.json endpoint.
export function dmMediaUploadScript(conversationId: string, text: string): string {
  const cid: string = JSON.stringify(conversationId);
  const caption: string = JSON.stringify(text.slice(0, 1000));
  return pageBridgeScript(
    DM_MD5_HELPER + 'var cid=' + cid + ';var caption=' + caption + ';' +
    'var upload="https://upload.x.com/i/media/upload.json";var sendPath="/i/api/1.1/dm/new2.json";' +
    'function wait(ms){return new Promise(function(resolve){setTimeout(resolve,ms);});}' +
    'var headers={"authorization":"Bearer "+bearer,"x-csrf-token":ct0,' +
    '"x-twitter-auth-type":"OAuth2Session","x-twitter-active-user":"yes",' +
    '"x-twitter-client-language":"en"};' +
    'async function req(url,options){try{var o=Object.assign({},options||{});o.credentials="include";o.referrer="https://x.com/messages/"+encodeURIComponent(cid);o.headers=Object.assign({},headers,o.headers||{});' +
    'var res=await fetch(url,o);var data=null;try{data=await res.json();}catch(e){}' +
    'return {ok:res.ok,status:res.status,data:data};}catch(e){return {ok:false,status:0,data:null};}}' +
    'try{var f=window.__otDmFiles&&window.__otDmFiles[cid];' +
    'if(!f||!f.size)return JSON.stringify({state:"empty"});' +
    'if(f.size>25*1024*1024)return JSON.stringify({state:"too-large"});' +
    'var type=String(f.type||"");if(type.indexOf("image/")!==0)return JSON.stringify({state:"unsupported"});' +
    'var category=type==="image/gif"?"dm_gif":"dm_image";' +
    'var bytes=new Uint8Array(await f.arrayBuffer());var digest=await window.otMd5(bytes);' +
    'var init=await req(upload+"?command=INIT&total_bytes="+encodeURIComponent(String(f.size))+' +
    '"&media_type="+encodeURIComponent(type)+"&media_category="+encodeURIComponent(category),{method:"POST"});' +
    'if(!init.ok||!init.data||!init.data.media_id_string)return JSON.stringify({state:"init-failed"});' +
    'var mediaId=String(init.data.media_id_string);' +
    'for(var offset=0;offset<f.size;offset+=1024*1024){var chunk=f.slice(offset,Math.min(offset+1024*1024,f.size));' +
    'var form=new FormData();form.append("media",chunk,"blob");' +
    'var append=await req(upload+"?command=APPEND&media_id="+encodeURIComponent(mediaId)+"&segment_index="+Math.floor(offset/(1024*1024)),{method:"POST",body:form});' +
    'if(!append.ok)return JSON.stringify({state:"append-failed"});}' +
    'var fin=await req(upload+"?command=FINALIZE&media_id="+encodeURIComponent(mediaId)+"&original_md5="+encodeURIComponent(digest),{method:"POST"});' +
    'if(!fin.ok)return JSON.stringify({state:"finalize-failed"});' +
    'var info=fin.data&&fin.data.processing_info;var started=Date.now();' +
    'if(info&&(info.state==="failed"||info.state==="failure"))return JSON.stringify({state:"processing-failed"});' +
    'while(info&&(info.state==="pending"||info.state==="in_progress")){if(Date.now()-started>20000)return JSON.stringify({state:"processing-timeout"});' +
    'await wait(Math.max(250,(Number(info.check_after_secs)||1)*1000));var st=await req(upload+"?command=STATUS&media_id="+encodeURIComponent(mediaId),{});' +
    'if(!st.ok||!st.data)return JSON.stringify({state:"status-failed"});info=st.data.processing_info;' +
    'if(info&&(info.state==="failed"||info.state==="failure"))return JSON.stringify({state:"processing-failed"});}' +
    'var requestId=(window.crypto&&window.crypto.randomUUID?window.crypto.randomUUID():' +
    'String(Date.now())+"-"+String(Math.random()).slice(2)).toUpperCase();' +
    'var body={cards_platform:"Web-12",conversation_id:cid,include_cards:1,include_quote_count:true,' +
    'dm_users:false,media_id:mediaId,recipient_ids:"false",request_id:requestId,text:caption};' +
    'var sent=await req(sendPath,{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(body)});' +
    'if(!sent.ok)return JSON.stringify({state:"send-failed"});' +
    'if(!sent.data)return JSON.stringify({state:"ok",messageId:""});' +
    'var id="";var entries=sent.data.entries||[];if(entries.length&&entries[0].message)id=String(entries[0].message.id||"");' +
    'delete window.__otDmFiles[cid];return JSON.stringify({state:"ok",messageId:id});' +
    '}catch(e){var err={state:"error",message:String(e).slice(0,120)};return JSON.stringify(err);}');
}

export function dmMediaClearScript(conversationId: string): string {
  const cid: string = JSON.stringify(conversationId);
  return '(function(){try{var cid=' + cid + ';if(window.__otDmFiles&&window.__otDmFiles[cid])delete window.__otDmFiles[cid];' +
    'if(window.__otDmPreviews&&window.__otDmPreviews[cid]){try{window.URL.revokeObjectURL(window.__otDmPreviews[cid]);}catch(_){}delete window.__otDmPreviews[cid];}' +
    'var input=document.getElementById("__ot_dm_media_input");if(input)input.remove();return JSON.stringify({state:"cleared"});' +
    'catch(e){return JSON.stringify({state:"error"});}})()';
}

// X's current web client mutes a DM conversation through these two session
// routes. The field is named `tweet_id` in the client even for conversations;
// keeping that shape is important because the endpoint rejects a guessed
// `conversation_id` field.
export function dmMuteScript(conversationId: string, muted: boolean): string {
  const cid: string = JSON.stringify(conversationId);
  const path: string = muted
    ? '/i/api/1.1/mutes/conversations/create.json'
    : '/i/api/1.1/mutes/conversations/destroy.json';
  return pageBridgeScript(
    'var cid=' + cid + ';' +
    'if(!cid)return JSON.stringify({state:"empty"});' +
    'var r=await otPost("' + path + '",{tweet_id:cid});' +
    'if(r.error)return JSON.stringify({state:r.error});' +
    'return JSON.stringify({state:"ok"});');
}

// Notifications list. Verified live against a signed-in session: the v2
// endpoint answers `{globalObjects:{users,tweets},timeline:{instructions}}`
// where each `addEntries` instruction carries `notification-<id>` entries shaped
// `{item:{content:{notification:{id,fromUsers[],targetTweets[]}},clientEventInfo:{element}}}`.
// The kind comes from `clientEventInfo.element` (`users_liked_your_tweet`,
// `users_retweeted_your_tweet`, `user_replied_to_your_tweet`,
// `follow_from_recommended_user`, `user_mentioned_you`, …) and the time from
// the entry's `sortIndex`. Cursor entries (`content.operation`) are skipped.
export function notificationsScript(): string {
  return pageBridgeScript(
    'var r=await otGet("/i/api/2/notifications/all.json?count=40");' +
    'if(r.error)return JSON.stringify({state:r.error});' +
    'var d=r.data||{};var glob=d.globalObjects||{};var users=glob.users||{};var tweets=glob.tweets||{};' +
    'var ins=(d.timeline&&d.timeline.instructions)||[];var out=[];' +
    'function av(u){return ((u&&u.profile_image_url_https)||"").replace("_normal","_bigger");}' +
    'for(var i=0;i<ins.length&&out.length<40;i++){' +
    'var en=(((ins[i]||{}).addEntries)||{}).entries||[];' +
    'for(var j=0;j<en.length&&out.length<40;j++){var e=en[j]||{};' +
    'var it=(e.content&&e.content.item)||null;if(!it)continue;' +
    'var nn=(it.content&&it.content.notification)||null;if(!nn)continue;' +
    'var el=String((it.clientEventInfo&&it.clientEventInfo.element)||"").toLowerCase();' +
    'var kind="mention";' +
    'if(el.indexOf("like")>=0)kind="like";' +
    'else if(el.indexOf("retweet")>=0)kind="repost";' +
    'else if(el.indexOf("repl")>=0)kind="reply";' +
    'else if(el.indexOf("follow")>=0)kind="follow";' +
    'else if(el.indexOf("mention")>=0)kind="mention";' +
    'var fu=nn.fromUsers||[];var u=fu.length?users[String(fu[0])]:null;' +
    'var tt=nn.targetTweets||[];var tw=tt.length?tweets[String(tt[0])]:null;' +
    'var txt=tw?otText(tw.full_text||tw.text).slice(0,180):"";' +
    'var nm=u?(u.name||u.screen_name||""):"";' +
    'if(!nm&&!txt)continue;' +
    'out.push({id:String(nn.id||e.entryId||(i+"-"+j)),targetId:tt.length?String(tt[0]):"",' +
    'kind:kind,name:nm,handle:u?(u.screen_name||""):"",avatar:av(u),text:txt,at:otTime(e.sortIndex)});}}' +
    'if(!out.length)return JSON.stringify({state:"empty"});' +
    'return JSON.stringify({state:"ok",items:out});');
}

// Shared tweet shaping used by Home, Profile and Search. Kept in one place so
// the three surfaces render the same post the same way.
const TWEET_SHAPE_JS: string =
  'function otTweet(t,users){' +
  'if(!t)return null;var u=t.user||users[t.user_id_str]||users[t.user_id]||{};' +
  'var txt=otText(t.full_text||t.text).slice(0,500);if(!txt&&!t.id_str&&!t.id)return null;' +
  'var id=String(t.id_str||t.id||"");if(!id)return null;' +
  'var media="",mediaWidth=0,mediaHeight=0,mediaType="";' +
  'try{var m=(t.extended_entities&&t.extended_entities.media)||(t.entities&&t.entities.media)||[];' +
  'if(m&&m.length){var one=m[0]||{};media=String(one.media_url_https||one.media_url||"");' +
  'mediaWidth=Number(one.width||0);mediaHeight=Number(one.height||0);' +
  'mediaType=String(one.type||"photo");}}catch(e){}' +
  'return {id:id,name:String(u.name||t.name||""),handle:String(u.screen_name||""),' +
  'avatar:String((u.profile_image_url_https||"")).replace("_normal","_bigger"),' +
  'text:txt,at:otTime(t.created_at),' +
  'likes:Number(t.favorite_count||0),reposts:Number(t.retweet_count||0),' +
  'replies:Number(t.reply_count||0),' +
  'liked:!!t.favorited,reposted:!!t.retweeted,bookmarked:!!t.bookmarked,media:media,' +
  'mediaWidth:mediaWidth,mediaHeight:mediaHeight,mediaType:mediaType};}';

// Home timeline with cursor paging. Verified live against a signed-in session:
// v1.1 `statuses/home_timeline` answers 200 with an empty body (dead), while
// v2 `timeline/home.json` answers `{globalObjects:{tweets,users},timeline:{instructions}}`
// with `tweet-<id>` entries pointing at `content.item.content.tweet.id` and a
// `cursor-bottom-*` entry carrying the next page cursor. `cursor` is that value,
// or '' for the first page. Paging verified overlap-free across pages.
export function homeTimelineScript(cursor: string): string {
  const safe: string = JSON.stringify(cursor);
  return pageBridgeScript(
    TWEET_SHAPE_JS +
    'var domBookmarked=function(id){try{' +
    'var arts=document.querySelectorAll("article[data-testid=tweet]");' +
    'for(var i=0;i<arts.length;i++){var links=arts[i].querySelectorAll("a[href]");' +
    'for(var j=0;j<links.length;j++){if((links[j].getAttribute("href")||"").indexOf("/status/"+id)>=0)' +
    'return !!arts[i].querySelector("[data-testid=removeBookmark]");}}}' +
    'catch(e){}return false;};' +
    'var cur=' + safe + ';' +
    'var path="/i/api/2/timeline/home.json?count=30";' +
    'if(cur)path+="&cursor="+encodeURIComponent(cur);' +
    'var r=await otGet(path);' +
    'if(r.error)return JSON.stringify({state:r.error});' +
    'var d=r.data||{};var glob=d.globalObjects||{};var users=glob.users||{};var tweets=glob.tweets||{};' +
    'var ins=(d.timeline&&d.timeline.instructions)||[];var out=[];var next="";' +
    'for(var i=0;i<ins.length;i++){var en=(((ins[i]||{}).addEntries)||{}).entries||[];' +
    'for(var j=0;j<en.length;j++){var e=en[j]||{};var eid=String(e.entryId||"");' +
    'if(eid.indexOf("cursor-bottom")===0){try{next=e.content.operation.cursor.value||"";}catch(x){}continue;}' +
    'if(eid.indexOf("tweet-")!==0)continue;' +
    'var item=(e.content&&e.content.item)||null;' +
    'var tref=item&&item.content&&item.content.tweet||null;' +
    'var tid=tref?tref.id:"";var t=tid?tweets[String(tid)]:null;if(!t)continue;' +
    'var p=otTweet(t,users);if(p){p.bookmarked=domBookmarked(p.id);out.push(p);}}}' +
    'if(!out.length)return JSON.stringify({state:"empty"});' +
    'return JSON.stringify({state:"ok",posts:out.slice(0,40),next:next});');
}

// Profile header plus recent posts, read off the rendered profile page the
// shell already loads underneath (the v1.1 user endpoints answer 404 / empty
// on a live session, verified). Selectors verified live against a signed-in
// profile: `[data-testid="UserName"]` for name/@handle,
// `[data-testid="UserDescription"]` for the bio, `img[src*="profile_images"]`
// (largest near the top) for the avatar, `img[src*="profile_banners"]` for the
// banner, `/following` + `/followers` links for the counts, and
// `article[data-testid="tweet"]` with its `/status/<id>` link, `time[datetime]`
// and action aria-labels ("9 Replies. Reply", "1 repost. Repost",
// "37 Likes. Like", "Unlike" / "Undo repost" when active).
//
// `more` scrolls the page once and waits, so paging reads what the page
// rendered next; the shell merges de-duplicated by id. Anything that is not
// the requested profile is `{"state":"..."}`: `signed-out` for a login wall,
// `loading` when the page has not rendered yet (the shell retries once),
// `empty` for a rendered page with no header.
// Profile header plus recent posts, read off the rendered profile page the
// shell already loads underneath (the v1.1 user endpoints answer 404 / empty
// on a live session, verified). Selectors verified live against a signed-in
// profile: `[data-testid="UserName"]` for name/@handle,
// `[data-testid="UserDescription"]` for the bio, `img[src*="profile_images"]`
// (largest near the top) for the avatar, `img[src*="profile_banners"]` for the
// banner, `/following` + `/followers` links for the counts, and
// `article[data-testid="tweet"]` with its `/status/<id>` link, `time[datetime]`
// and action aria-labels ("9 Replies. Reply", "1 repost. Repost",
// "37 Likes. Like", "Unlike" / "Undo repost" when active).
//
// `more` scrolls the page once and waits, so paging reads what the page
// rendered next; the shell merges de-duplicated by id. Anything that is not
// the requested profile is `{"state":"..."}`: `signed-out` for a login wall,
// `loading` when the page has not rendered yet (the shell retries once),
// `empty` for a rendered page with no header.
// Profile header plus recent posts, read off the rendered profile page the
// shell already loads underneath (the v1.1 user endpoints answer 404 / empty
// on a live session, verified). Selectors verified live against a signed-in
// profile: UserName testid for name/@handle, UserDescription for the bio,
// profile_images (largest near the top) for the avatar, profile_banners for
// the banner, /following + /followers links for the counts, and
// article tweets with their /status/<id> link, time datetime and action
// aria-labels. `more` scrolls once and waits so paging reads what the page
// rendered next; the shell merges de-duplicated by id. Anything else is a
// state string: signed-out for a login wall, loading when not yet rendered
// (the shell retries once), empty for a rendered page with no header.
export function profileScript(handle: string, more: string): string {
  const h: string = JSON.stringify(handle.replace('@', ''));
  const m: string = JSON.stringify(more);
  return pageBridgeScript(
    'var want=' + h + ';var more=' + m + ';' +
    'if(more){try{window.scrollTo(0,document.body.scrollHeight);' +
    'await new Promise(function(res){setTimeout(res,1600);});}catch(e){}}' +
    'function num(t){var s=String(t||"");var di="";var i=0;' +
    'while(i<s.length&&((s.charAt(i)>="0"&&s.charAt(i)<="9")||s.charAt(i)==="."||s.charAt(i)===","))' +
    '{if(s.charAt(i)!==",")di+=s.charAt(i);i++;}' +
    'var n=parseFloat(di);if(isNaN(n))return 0;' +
    'var u=s.charAt(i)||"";if(u==="K"||u==="k")n=n*1000;' +
    'else if(u==="M"||u==="m")n=n*1000000;return Math.round(n);}' +
    'var nameEl=document.querySelector("[data-testid=UserName]");' +
    'if(!nameEl){' +
    'if(document.querySelector("input[type=password]"))return JSON.stringify({state:"signed-out"});' +
    'return JSON.stringify({state:"loading"});}' +
    'var nx=nameEl.innerText||"";var nl=nx.indexOf(String.fromCharCode(10));' +
    'var nm=(nl<0?nx:nx.substring(0,nl)).trim();' +
    'var hm=want;var ai=nx.indexOf("@");' +
    'if(ai>=0){var hh2="";for(var k=ai+1;k<nx.length&&hh2.length<15;k++)' +
    '{var c=nx.charAt(k);var ok=(c>="a"&&c<="z")||(c>="A"&&c<="Z")||(c>="0"&&c<="9")||c==="_";' +
    'if(!ok)break;hh2+=c;}if(hh2)hm=hh2;}' +
    'var avatar="";try{var ims=document.querySelectorAll("img[src*=profile_images]");' +
    'var best=0;for(var g=0;g<ims.length;g++){var r=ims[g].getBoundingClientRect();' +
    'if(r.top<600&&r.width>best){best=r.width;avatar=ims[g].src||"";}}}catch(e){}' +
    'var banner="";try{var bn=document.querySelector("img[src*=profile_banners]");' +
    'if(bn)banner=bn.src||"";}catch(e){}' +
    'var bio="";try{var bd=document.querySelector("[data-testid=UserDescription]");' +
    'if(bd)bio=(bd.innerText||"").slice(0,280);}catch(e){}' +
    'var fing=0,fers=0;try{var lks=document.querySelectorAll("a[href]");' +
    'for(var li=0;li<lks.length;li++){var u2=lks[li].getAttribute("href")||"";' +
    'if(u2.charAt(u2.length-1)==="/")u2=u2.slice(0,-1);' +
    'if(u2.length>=10&&u2.substring(u2.length-10)==="/following")fing=num(lks[li].innerText);' +
    'else if(u2.length>=10&&u2.substring(u2.length-10)==="/followers")fers=num(lks[li].innerText);' +
    'else if(u2.length>=19&&u2.substring(u2.length-19)==="/verified_followers")fers=num(lks[li].innerText);}}catch(e){}' +
    'var posts=[];try{var arts=document.querySelectorAll("article[data-testid=tweet]");' +
    'for(var pi=0;pi<arts.length&&posts.length<25;pi++){var a=arts[pi];' +
    'var ah="";try{var links=a.querySelectorAll("a[href]");' +
    'for(var qi=0;qi<links.length;qi++){var lhh=links[qi].getAttribute("href")||"";' +
    'var si=lhh.indexOf("/status/");' +
    'if(si>=0){var dd="";for(var z=si+8;z<lhh.length&&dd.length<24;z++)' +
    '{var cc=lhh.charAt(z);if(cc<"0"||cc>"9")break;dd+=cc;}' +
    'if(dd){ah=dd;break;}}}}catch(e){}' +
    'if(!ah)continue;' +
    'var tx="";try{var tt=a.querySelector("div[data-testid=tweetText]");' +
    'tx=((tt?tt.innerText:"")||"").slice(0,500);}catch(e){}' +
    'if(!tx)continue;' +
    'var tm="";try{var tmEl=a.querySelector("time");if(tmEl)tm=tmEl.getAttribute("datetime")||"";}catch(e){}' +
    'var rp=0,rt=0,lk=0,liked=false,reposted=false,bookmarked=false;' +
    'try{var btns=a.querySelectorAll("button,[role=button]");' +
    'for(var bi=0;bi<btns.length;bi++){var lb=(btns[bi].getAttribute("aria-label")||"").toLowerCase();' +
    'if(lb.indexOf("repl")>=0)rp=num(lb);' +
    'else if(lb.indexOf("repost")>=0){rt=num(lb);if(lb.indexOf("undo")>=0)reposted=true;}' +
    'else if(lb.indexOf("like")>=0){lk=num(lb);if(lb.indexOf("unlike")>=0)liked=true;}' +
    'if((btns[bi].getAttribute("data-testid")||"")==="removeBookmark"||lb.indexOf("bookmarked")>=0)bookmarked=true;}}catch(e){}' +
    'posts.push({id:ah,name:nm,handle:hm,avatar:avatar,text:tx,at:otTime(tm),' +
    'likes:lk,reposts:rt,replies:rp,liked:liked,reposted:reposted,bookmarked:bookmarked,media:""});}}catch(e){}' +
    'if(!nm&&!posts.length)return JSON.stringify({state:"empty"});' +
    'return JSON.stringify({state:"ok",user:{name:nm,handle:hm,avatar:avatar,banner:banner,' +
    'bio:bio,location:"",followers:fers,following:fing,posts:0,at:0},' +
    'posts:posts,next:(posts.length>=25?"more":"")});');
}
// Trends for Explore. Returns named topics with optional volume.
export function trendsScript(): string {
  return pageBridgeScript(
    'var r=await otGet("/i/api/1.1/trends/place.json?id=1");' +
    'if(r.error)return JSON.stringify({state:r.error});' +
    'var d=r.data;if(d instanceof Array)d=d[0];' +
    'var arr=(d&&d.trends)||[];' +
    'var out=[];for(var i=0;i<arr.length&&out.length<20;i++){var t=arr[i]||{};' +
    'var nm=String(t.name||"");if(!nm)continue;' +
    'out.push({name:nm,posts:t.tweet_volume?String(t.tweet_volume):""});}' +
    'if(!out.length)return JSON.stringify({state:"empty"});' +
    'return JSON.stringify({state:"ok",trends:out});');
}

// Explore search. Verified live: v2 `search/adaptive` answers 200 with an
// empty body and v1.1 `search/tweets` is equally empty, so full tweet search
// has no working endpoint in this session. What does work is v1.1
// `search/typeahead` (`topics` with `topic` + token breakdown), which is what
// the client itself uses for suggestions — so Explore search returns real
// topic suggestions in the same `{trends}` shape as the trends list, and the
// surface renders them as tappable rows instead of fabricated tweet results.
export function searchTweetsScript(query: string, cursor: string): string {
  const q: string = JSON.stringify(query);
  return pageBridgeScript(
    'var qq=' + q + ';' +
    'if(!qq||!qq.trim())return JSON.stringify({state:"empty"});' +
    'var r=await otGet("/i/api/1.1/search/typeahead.json?q="+encodeURIComponent(qq)' +
    '+"&result_type=topics%2Cusers&count=12");' +
    'if(r.error)return JSON.stringify({state:r.error});' +
    'var arr=(r.data&&r.data.topics)||[];var out=[];' +
    'for(var i=0;i<arr.length&&out.length<12;i++){var nm=String(arr[i].topic||"");' +
    'if(nm)out.push({name:nm,posts:""});}' +
    'if(!out.length)return JSON.stringify({state:"empty"});' +
    'return JSON.stringify({state:"ok",trends:out});');
}

// Like / unlike / repost / unrepost through the page session. Bookmarking uses
// x.com's rendered control when that article is on the current page. When it
// is not, the shell stages the post route in the hidden WebView and runs this
// same script again; the web client owns the authenticated mutation and token.
export function postActionScript(kind: string, tweetId: string, staged: boolean = false): string {
  const k: string = JSON.stringify(kind);
  const tid: string = JSON.stringify(tweetId);
  const stagedArg: string = staged ? 'true' : 'false';
  return pageBridgeScript(
    'var kind=' + k + ';var tid=' + tid + ';var staged=' + stagedArg + ';' +
    'if(!tid)return JSON.stringify({state:"empty"});' +
    'if(kind==="bookmark"||kind==="unbookmark"){' +
    'var arts=document.querySelectorAll("article[data-testid=tweet]");var target=null;' +
    'for(var i=0;i<arts.length;i++){' +
    'var links=arts[i].querySelectorAll("a[href]");' +
    'for(var j=0;j<links.length;j++){' +
    'var href=links[j].getAttribute("href")||"";var marker="/status/"+tid;' +
    'var at=href.indexOf(marker);var end=at+marker.length;' +
    'if(at>=0&&(end===href.length||href.charAt(end)==="?"||href.charAt(end)==="/")){target=arts[i];break;}' +
    '}' +
    'if(target)break;' +
    '}' +
    'var wanted=kind==="bookmark"?"bookmark":"removeBookmark";' +
    'var expected=kind==="bookmark"?"removeBookmark":"bookmark";' +
    'if(target){' +
    'var button=target.querySelector("[data-testid="+wanted+"]");' +
    'if(!button)return JSON.stringify({state:staged?"staged":"unexpected"});' +
    'button.click();' +
    'for(var wait=0;wait<80;wait++){' +
    'var next=target.querySelector("[data-testid=bookmark],[data-testid=removeBookmark]");' +
    'if(next&&next.getAttribute("data-testid")===expected)return JSON.stringify({state:"ok"});' +
    'await new Promise(function(resolve){setTimeout(resolve,100);});' +
    '}' +
    'return JSON.stringify({state:"unexpected"});' +
    '}' +
    'var route=String((window.location&&window.location.pathname)||"");' +
    'if(staged&&route.indexOf("/status/")>=0&&route.indexOf("/status/"+tid)<0)' +
    'return JSON.stringify({state:"unexpected"});' +
    'return JSON.stringify({state:"staged"});}' +
    'var path="";' +
    'if(kind==="like")path="/i/api/1.1/favorites/create.json?id="+encodeURIComponent(tid);' +
    'else if(kind==="unlike")path="/i/api/1.1/favorites/destroy.json?id="+encodeURIComponent(tid);' +
    'else if(kind==="repost")path="/i/api/1.1/statuses/retweet/"+encodeURIComponent(tid)+".json";' +
    'else if(kind==="unrepost")path="/i/api/1.1/statuses/unretweet/"+encodeURIComponent(tid)+".json";' +
    'else return JSON.stringify({state:"unexpected"});' +
    'var r=await otPost(path,{});' +
    'if(r.error)return JSON.stringify({state:r.error});' +
    'return JSON.stringify({state:"ok"});');
}


// How often the chrome pass may re-run when it is reacting to page mutations.
// The first pass stays immediate (no double chrome on first paint); only the
// re-runs are paced. x.com mutates its DOM continuously — timelines, and far
// more so on the chat screen — and every pass walks the document and forces
// layout, so an unpaced observer is a lot of work for nothing.
const CHROME_OBSERVER_MS: number = 250;

export function chromeScript(ownHandle: string, tabRoot: boolean, band: number): string {
  // The shell draws the header on every page, so the page's own header rows are
  // always removed. "band" is how far down the page its header can sit — the
  // same row is near the top on a phone and much lower on a wide layout.
  return '(function(root,handle,B){try{' +
    'window.__otHandle=handle;window.__otBand=B;' +
    'var css=document.getElementById(\'ot-hidenav\');' +
    'if(!css){css=document.createElement(\'style\');css.id=\'ot-hidenav\';' +
    'css.textContent="' + CHROME_CSS + '";document.head.appendChild(css);}' +
    'window.__otApplyTop=function(){try{' +
    'var b=window.__otBand||B;' +
    'function H(e){try{if(!e||e.hasAttribute(\'data-ot-hide\'))return;' +
    'e.style.display=\'none\';e.setAttribute(\'data-ot-hide\',\'1\');}catch(_){}}' +
    'function R(e){try{return e.getBoundingClientRect();}catch(_){return null;}}' +
    'function T(e){var r=R(e);return r&&r.top<=b&&r.height>0&&r.height<160;}' +
    'function Q(s){try{return document.querySelector(s);}catch(_){return null;}}' +
    'function QA(s){try{return document.querySelectorAll(s);}catch(_){return [];}}' +
    'var hid=QA(\'[data-ot-hide]\');' +
    'var need=!hid||!hid.length;' +
    'if(!need){' +
    'var probes=[\'[data-testid^="SearchBox"]\',\'form[role="search"]\',\'a[href^="/settings"]\',' +
    '\'a[href="/messages/compose"]\',\'a[href="/home"]\',\'a[href="/"]\',' +
    '\'svg[aria-label="X"]\',\'a[aria-label="X"]\',\'a[aria-label="Home"]\',' +
    '\'a[href^="/premium"]\',\'a[href^="/i/premium"]\',\'a[href="/login"]\',' +
    '\'div[data-testid="TopNavBar"]\',\'[aria-label="TopNavBar"]\'];' +
    'for(var p=0;p<probes.length;p++){var pe=Q(probes[p]);if(!pe)continue;' +
    'var pr=R(pe);' +
    'if(pr&&pr.top<=b&&pr.height>8&&pr.width>0&&pe.style.display!==\'none\'){need=1;break;}}}' +
    'if(!need)return;' +
    'for(var u=0;u<hid.length;u++){try{hid[u].style.display=\'\';hid[u].removeAttribute(\'data-ot-hide\');}catch(_){}}' +
    'var tnb=Q(\'div[data-testid="TopNavBar"]\')||Q(\'[aria-label="TopNavBar"]\');' +
    'if(tnb){var tnt=0;try{tnt=tnb.querySelector(\'[role="tablist"]\')?1:0;}catch(_){} if(!tnt&&T(tnb))H(tnb);}' +
    'var s=Q(\'[data-testid^="SearchBox"]\')||Q(\'form[role="search"]\')||Q(\'[role="combobox"]\');' +
    // On a tab root the shell owns search, so the page's own search box goes
    // whatever row it landed in (it sits much lower on a wide layout than the
    // phone-tuned top band would cover).
    // Hiding the field alone leaves its pill behind as an empty rounded
    // rectangle, so the row that holds it goes too. The walk up stops at
    // anything taller than a search row, narrower than one, or already
    // holding the tab strip — those are containers the shell does not own.
    'if(s&&(root||T(s))){' +
    'var se=s.parentElement,g2=0,bestS=null;' +
    'while(se&&se!==document.body&&g2++<8){var sr=R(se);' +
    'if(!sr||sr.width<200||sr.width>620||sr.height>90)break;' +
    'try{if(se.querySelector(\'[role="tablist"]\'))break;}catch(_){}' +
    'if(sr.height>=30)bestS=se;' +
    'se=se.parentElement;}' +
    'if(bestS)H(bestS);' +
    'H(s);}' +
    'var links=QA(\'a[href^="/settings"],a[href="/messages/compose"],a[href^="/premium"],a[href^="/i/premium"],a[href="/login"]\');' +
    // Only icon-only chrome goes: this rule exists for the header's own gear
    // and pencil, which carry no text. A *settings page* puts its own rows in
    // the same shape near the top (x.com's "Filters" / "Preferences" pivots),
    // and hiding those left the page showing nothing but its description.
    'for(var i=0;i<links.length;i++){try{' +
    'var lt=(links[i].innerText||\'\').replace(/\\s+/g,\'\');' +
    'if(lt.length===0&&T(links[i]))H(links[i]);}catch(_){}}' +
    'var logo=Q(\'a[href="/home"]\')||Q(\'a[href="/"]\')||Q(\'svg[aria-label="X"]\')||Q(\'a[aria-label="X"]\')||Q(\'a[aria-label="Home"]\');' +
    'if(logo){var lk=logo;try{lk=logo.closest(\'a\')||logo;}catch(_){}' +
    'if(root||T(lk))H(lk);}' +
    'if(window.__otHandle){' +
    'var als=QA(\'a[href]\');' +
    'for(var j=0;j<als.length;j++){try{var h=als[j].getAttribute(\'href\');' +
    'if(!h||h.toLowerCase()!==\'/\'+window.__otHandle)continue;' +
    'if(!als[j].querySelector(\'img\'))continue;' +
    'if(T(als[j]))H(als[j]);}catch(_){}}}' +
    'var ac=Q(\'[data-testid^="SearchBox"]\')||Q(\'form[role="search"]\')||Q(\'a[href="/home"]\')||Q(\'a[href="/"]\')||Q(\'svg[aria-label="X"]\');' +
    'if(ac){var ce=ac,guard=0,best=null;' +
    'while(ce&&ce!==document.body&&guard++<10){var cr=R(ce);' +
    'if(!cr||cr.height<=0||cr.height>=220||cr.top>b)break;' +
    'try{if(ce.querySelector(\'[role="tablist"]\'))break;}catch(_){}' +
    'try{if((ce.innerText||\'\').replace(/\\s+/g,\'\').length<60)best=ce;}catch(_){}' +
    'ce=ce.parentElement;}' +
    'if(best)H(best);}' +
    'var hdrs=QA(\'header,div[role="banner"]\');' +
    'for(var hb=0;hb<hdrs.length;hb++){try{' +
    // A banner that is as tall as the page and sits against the left edge is
    // not a header row at all: it is x.com's own navigation column (the desktop
    // side nav, and the whole left rail on x.com/i/chat). Its inner nav is
    // already removed by the stylesheet, which would otherwise leave the column
    // standing with only its X logo and its empty width behind it. The shell's
    // rail is that navigation, so the column goes with it.
    'var cb=R(hdrs[hb]);' +
    'if(cb&&cb.height>=200&&cb.width<=360&&cb.left<=8){H(hdrs[hb]);continue;}' +
    'if(hdrs[hb].querySelector(\'[role="tablist"]\'))continue;' +
    'var htxt=(hdrs[hb].innerText||\'\').replace(/\\s+/g,\'\');' +
    'if(htxt.length>=100)continue;' +
    'if(T(hdrs[hb]))H(hdrs[hb]);}catch(_){}}' +
    // The page's own back bar (wide layouts keep one that sits outside the
    // header/banner rules). Its row goes; the tab row under it stays.
    'var bk=Q(\'[data-testid="app-bar-back"]\');' +
    'if(bk){var bp=bk.parentElement;if(bp&&T(bp))H(bp);}' +
    'var heads=QA(\'h1,h2\');' +
    'for(var m=0;m<heads.length;m++){try{var t=(heads[m].textContent||\'\').trim().toLowerCase();' +
    'if(t!==\'home\'&&t!==\'explore\'&&t!==\'notifications\'&&t!==\'messages\'&&t!==\'profile\')continue;' +
    'var hr=R(heads[m]);' +
    'if(hr&&hr.top<=b&&hr.height>8&&hr.height<160)H(heads[m]);}catch(_){}}' +
    '}catch(e){}};' +
    // Own-account handle. The page renders its navigation after hydration, so
    // this is installed here and re-run by the observer below instead of being
    // read once when the page first reports that it finished loading.
    'window.__otOwn=function(){try{' +
    // Once the handle is known there is nothing left to look for, and this runs
    // on every page mutation otherwise.
    'if(window.__otHandleValue){return window.__otHandleValue;}' +
    'var as=document.querySelectorAll("a[href]");' +
    'for(var i=0;i<as.length;i++){' +
    'var k=as[i].getAttribute("data-testid")||"";' +
    'if(k!=="AppTabBar_Profile_Link"&&k!=="DashButton_ProfileIcon_Link"&&k!=="SideNav_AccountSwitcher_Button")continue;' +
    'var h=as[i].getAttribute("href")||"";' +
    'if(h.charAt(0)!=="/"||h.length<2||h.length>16)continue;' +
    'var ok=1;' +
    'for(var j=1;j<h.length;j++){var c=h.charCodeAt(j);' +
    'if(!((c>=97&&c<=122)||(c>=65&&c<=90)||(c>=48&&c<=57)||c===95)){ok=0;break;}}' +
    'if(ok){window.__otHandleValue=h.substring(1);return window.__otHandleValue;}}' +
    '}catch(e){}return window.__otHandleValue||"";};' +
    // x.com navigates like an app (history.pushState), which does not reload
    // the page and therefore never reaches the shell through the Web component
    // callbacks. Hook the history API and report every change to the native
    // bridge so the header, tab bar and back button stay in step.
    'if(!window.__otHist){window.__otHist=1;' +
    'function otTell(){try{if(window.otNative&&window.otNative.onUrlChange){' +
    'window.otNative.onUrlChange(String(window.location.href));}}catch(_){}}' +
    'var otPush=history.pushState;' +
    'history.pushState=function(){var r=otPush.apply(this,arguments);otTell();return r;};' +
    'var otRep=history.replaceState;' +
    'history.replaceState=function(){var r=otRep.apply(this,arguments);otTell();return r;};' +
    'window.addEventListener("popstate",function(){otTell();});' +
    'window.addEventListener("hashchange",function(){otTell();});}' +
    'window.__otHideTop=true;' +
    'if(!window.__otObs){window.__otPend=0;' +
    'window.__otPass=function(){window.__otPend=0;try{' +
    'window.__otApplyTop&&window.__otApplyTop();' +
    'window.__otOwn&&window.__otOwn();}catch(e){}};' +
    'window.__otObs=new MutationObserver(function(){' +
    'if(window.__otPend){return;}window.__otPend=1;' +
    'setTimeout(window.__otPass,' + CHROME_OBSERVER_MS + ');});' +
    'try{window.__otObs.observe(document.documentElement,{childList:true,subtree:true});}catch(e){}}' +
    'window.__otApplyTop();' +
    'window.__otOwn();' +
    '}catch(e){}})(' + (tabRoot ? 'true' : 'false') + ',\'' + ownHandle + '\',' + band + ');';
}

// Cheap follow-up used on in-page (SPA) navigations, which do not always fire
// onPageEnd: flips the tab-root flag and re-runs the removal pass.
export function chromeFlagScript(tabRoot: boolean, band: number): string {
  return '(function(f,B){try{window.__otHideTop=f;window.__otBand=B;' +
    'window.__otApplyTop&&window.__otApplyTop();}catch(e){}})(' +
    (tabRoot ? 'true' : 'false') + ',' + band + ');';
}

export function scrollToTopScript(): string {
  return 'window.scrollTo({top:0,behavior:"smooth"});';
}

// The shell draws the "For you / Following" switcher natively on Home. x.com
// keeps its own tab row in the DOM (the shell hides it), so switching is a
// programmatic click on the matching tab rather than a route change: the page
// swaps timelines in place, exactly as it does when its own row is used.
export function selectHomeTabScript(index: number): string {
  return '(function(i){try{' +
    'var tl=document.querySelector(\'[data-testid="ScrollSnap-List"]\')||' +
    'document.querySelector(\'[role="tablist"]\');' +
    'if(!tl)return "missing";' +
    'var t=tl.querySelectorAll(\'[role="tab"]\');' +
    'if(!t||!t.length)return "notabs";' +
    'if(t.length<=i)return "short";' +
    'if(t[i].getAttribute(\'aria-selected\')===\'true\')return "same";' +
    't[i].click();return "ok";}catch(e){return "error";}})(' + index + ');';
}

// Index of the selected Home timeline tab, or -1 when the page is not Home.
export const HOME_TAB_SCRIPT: string =
  '(function(){try{' +
  'var tl=document.querySelector(\'[data-testid="ScrollSnap-List"]\');' +
  'if(!tl)return -1;' +
  'var t=tl.querySelectorAll(\'[role="tab"]\');' +
  'for(var i=0;i<t.length;i++){if(t[i].getAttribute(\'aria-selected\')===\'true\')return i;}' +
  'return -1;}catch(e){return -1;}})()';

// Signed-in avatar, read off the account's own profile page. Timeline avatars
// are much smaller, so the size test keeps those out.
export const AVATAR_SCRIPT: string =
  '(function(){try{' +
  'var im=document.querySelectorAll(\'img[src*="profile_images"]\');' +
  'for(var i=0;i<im.length;i++){' +
  'var r=im[i].getBoundingClientRect();' +
  'if(r.width>=60){return String(im[i].getAttribute("src")||"");}}' +
  'return "";}catch(e){return "";}})()';

// Unread counters for the shell's own tab bar and for the launcher badge.
//
// The counts belong to x.com, and the page already publishes them twice, so the
// shell reads rather than guesses: every navigation entry carries the number in
// its accessible label — x.com's own templates are "Notifications (%d unread
// notifications)" and "Direct Messages (%d unread conversations)" — and the
// tabs that draw a numeric badge put the same number in a text node. The
// wording follows the page language while the number stays a number, so this
// parses the digits out of either form. The title is the last resort for
// notifications, which x.com prefixes on every route: "(3) Home / X".
//
// Returns "<notifications>/<messages>". A count is 0 when the page has that
// navigation entry and nothing unread, and **-1 when there is no such entry at
// all** — a page that is still loading or has not hydrated its navigation yet.
// The shell keeps the last known count on -1 rather than treating "not yet" as
// "nothing unread", which is what made the badges drop out while moving between
// tabs.
export const UNREAD_COUNTS_SCRIPT: string =
  '(function(){try{' +
  // An Arabic page formats counts with Arabic-Indic digits; normalise before
  // parsing so the number survives a localised page.
  'function dg(v){return String(v)' +
  '.replace(/[\\u0660-\\u0669]/g,function(c){return String(c.charCodeAt(0)-1632);})' +
  '.replace(/[\\u06f0-\\u06f9]/g,function(c){return String(c.charCodeAt(0)-1776);});}' +
  'function cnt(sel){' +
  'var ns=document.querySelectorAll(sel);' +
  'if(!ns.length){return -1;}' +
  'for(var i=0;i<ns.length;i++){' +
  'var lab=dg(ns[i].getAttribute("aria-label")||"");' +
  'var m=lab.match(/\\(\\s*(\\d{1,4})/)||lab.match(/^\\s*(\\d{1,4})\\s*$/);' +
  'if(!m){' +
  'var kids=ns[i].querySelectorAll("*");' +
  'for(var k=0;k<kids.length;k++){' +
  'var t=dg((kids[k].textContent||"").trim());' +
  'if(/^\\d{1,4}$/.test(t)){m=[t,t];break;}}}' +
  'if(m){var n=parseInt(m[1],10);if(n>0){return n;}}}' +
  'return 0;}' +
  // The mobile web puts both counts on its own (hidden) tab row; the desktop
  // layout keeps them on the side navigation. Both are matched by href so a
  // renamed test id cannot break the read.
  'var n=cnt(\'a[href="/notifications"],[data-testid="AppTabBar_Notifications_Link"]\');' +
  'var m=cnt(\'a[href="/messages"],a[href="/i/chat"],' +
  '[data-testid="AppTabBar_DirectMessage_Link"],[data-testid="AppTabBar_Messages_Link"]\');' +
  // x.com prefixes the notification count on every route it knows about:
  // "(3) Home / X". Only consulted when the navigation entry itself is missing.
  'if(n<0){var tm=dg(document.title||"").match(/^\\((\\d{1,4})\\)/);if(tm){n=parseInt(tm[1],10);}}' +
  'return n+"/"+m;' +
  '}catch(e){return "";}})()';

// Native "Post" action for the compose sheet: clicks x.com's own submit button.
// Returns 'missing' when the page has not rendered one yet, so the shell can
// tell the user instead of failing silently.
export const CLICK_POST_BUTTON_SCRIPT: string =
  '(function(){try{' +
  'var b=document.querySelector(\'[data-testid="tweetButton"]\')||' +
  'document.querySelector(\'[data-testid="tweetButtonInline"]\')||' +
  'document.querySelector(\'button[data-testid="tweetButton"]\');' +
  'if(!b)return \'missing\';' +
  'if(b.getAttribute(\'aria-disabled\')===\'true\'||b.disabled)return \'disabled\';' +
  'b.click();return \'ok\';}catch(e){return \'error\';}})()';

// Pushes the text typed in the native composer into x.com's own editor, so the
// native sheet posts through the real web session (DraftJS state, character
// counting, threads, per-account length rules) without the user ever seeing the
// web composer.
//
// Returns 'ok' when the editor reports the text back, 'missing' when the
// composer has not rendered yet — the shell then falls back to the web sheet so
// nothing the user typed is lost.
export function fillComposerScript(text: string): string {
  return '(function(t){try{' +
    'var e=document.querySelector(\'[data-testid^="tweetTextarea_0"]\')||' +
    'document.querySelector(\'div[role="textbox"][contenteditable="true"]\')||' +
    'document.querySelector(\'[contenteditable="true"]\');' +
    'if(!e)return \'missing\';' +
    'e.focus();' +
    'try{var s=window.getSelection();var r=document.createRange();' +
    'r.selectNodeContents(e);s.removeAllRanges();s.addRange(r);}catch(_){}' +
    'var ok=false;' +
    'try{ok=document.execCommand(\'insertText\',false,t);}catch(_){ok=false;}' +
    'if(!ok){e.textContent=t;' +
    'try{e.dispatchEvent(new InputEvent(\'input\',{bubbles:true,inputType:\'insertText\',data:t}));}catch(_){}}' +
    'var got=(e.innerText||e.textContent||\'\');' +
    'var head=t.substring(0,t.length>8?8:t.length);' +
    'return (head===\'\'||got.indexOf(head)>=0)?\'ok\':\'empty\';' +
    '}catch(err){return \'error\';}})(' + JSON.stringify(text) + ');';
}

// The mobile web renders the account entry as a button with no href, so the
// handle only exists inside the account menu that button opens. This opens the
// menu, reads the handle, closes it again, and leaves the answer in
// window.__otBoot. The shell covers the page with a native panel while it runs,
// so the user sees a HarmonyOS spinner rather than a menu flashing open.
export const PROFILE_BOOTSTRAP_SCRIPT: string =
  '(function(){try{' +
  'var btn=null;' +
  'var ds=document.querySelectorAll("[data-testid]");' +
  'for(var i=0;i<ds.length;i++){' +
  'if((ds[i].getAttribute("data-testid")||"")==="DashButton_ProfileIcon_Link"){btn=ds[i];break;}}' +
  'window.__otBoot="";' +
  'if(!btn){return "nobutton";}' +
  'try{btn.click();}catch(e){return "noclick";}' +
  'setTimeout(function(){try{' +
  'var r={"/home":1,"/explore":1,"/notifications":1,"/messages":1,"/i":1,"/grok":1,' +
  '"/communities":1,"/premium":1,"/jobs":1,"/login":1,"/signup":1,"/settings":1,' +
  '"/logout":1,"/compose":1,"/search":1,"/tos":1,"/privacy":1,"/about":1,"/intent":1};' +
  'var as=document.querySelectorAll("a[href]");' +
  'for(var j=0;j<as.length;j++){' +
  'var h=as[j].getAttribute("href")||"";' +
  'if(h.charAt(0)!=="/"||h.length<2||h.length>16){continue;}' +
  'if(r[h]){continue;}' +
  'var ok=1;' +
  'for(var k=1;k<h.length;k++){var c=h.charCodeAt(k);' +
  'if(!((c>=97&&c<=122)||(c>=65&&c<=90)||(c>=48&&c<=57)||c===95)){ok=0;break;}}' +
  'if(ok){window.__otBoot=h.substring(1);break;}}' +
  'window.__otBootAll=(window.__otBoot||"none")+"/"+as.length;' +
  'try{btn.click();}catch(e){}' +
  '}catch(e){window.__otBoot="";}},1500);' +
  'return "armed";' +
  '}catch(e){window.__otBoot="";return "err";}})()';
