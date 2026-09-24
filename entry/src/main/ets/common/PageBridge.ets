// Reading the account's own data out of the page it is already signed in to.
//
// There is no API key behind this app, so every native surface reads from the
// web page's session instead: the script runs on the x.com origin, which means
// the session cookies apply and the app never holds a credential of its own.
//
// Only the fragile part is shared — finding the session and the web client's
// bearer token, and the header set its own API calls use. Everything a specific
// surface wants (endpoint, parameters, the shape it returns) is passed in, so
// adding a surface does not mean copying this again.

// Session token and bearer discovery. The bearer is the public web token every
// x.com browser session already carries; it is read out of the page's own
// scripts once and cached on the window for the life of the document, so the
// cost is paid on the first read of a page rather than on every poll.
const SESSION_SETUP: string =
  'if(!/(?:^|;\\s*)ct0=/.test(document.cookie))' +
  'return JSON.stringify({state:"signed-out"});' +
  'var ct0=(document.cookie.match(/(?:^|;\\s*)ct0=([^;]+)/)||[])[1]||"";' +
  'var bearer=window.__otBearer||"";' +
  'if(!bearer){' +
  'var srcs=[];document.querySelectorAll("script[src]").forEach(function(s){' +
  'if(/\\.js(\\?|$)/.test(s.src)&&srcs.length<6)srcs.push(s.src);});' +
  'for(var i=0;i<srcs.length&&!bearer;i++){try{' +
  'var txt=await (await fetch(srcs[i])).text();' +
  'var m=txt.match(/Bearer\\s+([A-Za-z0-9%_\\-]{60,})/);' +
  'if(m)bearer=decodeURIComponent(m[1]);' +
  '}catch(e){}}' +
  'window.__otBearer=bearer;}' +
  'if(!bearer)return JSON.stringify({state:"no-bearer"});';

// The request helpers every surface body uses. They return either the parsed
// JSON or a `state` string the native side already knows how to render, so a
// surface body never has to handle an HTTP failure itself.
const FETCH_HELPER: string =
  'var otGet=async function(path){' +
  'try{var res=await fetch("https://x.com"+path,{credentials:"include",headers:{' +
  '"authorization":"Bearer "+bearer,"x-csrf-token":ct0,' +
  '"x-twitter-auth-type":"OAuth2Session","x-twitter-active-user":"yes",' +
  '"x-twitter-client-language":"en"}});' +
  'if(res.status===401||res.status===403)return {error:"signed-out"};' +
  'if(!res.ok)return {error:"http-"+res.status};' +
  'try{return {data:await res.json()};}catch(e){return {error:"unexpected"};}}' +
  'catch(e){return {error:"error"};}};' +
  'var otPost=async function(path,body){' +
  'try{var res=await fetch("https://x.com"+path,{method:"POST",credentials:"include",headers:{' +
  '"authorization":"Bearer "+bearer,"x-csrf-token":ct0,' +
  '"x-twitter-auth-type":"OAuth2Session","x-twitter-active-user":"yes",' +
  '"x-twitter-client-language":"en","content-type":"application/json"},' +
  'body:JSON.stringify(body||{})});' +
  'if(res.status===401||res.status===403)return {error:"signed-out"};' +
  'if(!res.ok)return {error:"http-"+res.status};' +
  'try{return {data:await res.json()};}catch(e){return {data:{}};}}' +
  'catch(e){return {error:"error"};}};' +
  // The inbox never names the signed-in account, so it is derived the same way
  // everywhere: the participant present in the most one-to-one conversations.
  // Hoisted here so surfaces do not each invent their own derivation.
  'var otAccountFromConvs=function(convs){' +
  'var counts={};try{' +
  'Object.keys(convs||{}).forEach(function(k){var c=convs[k];' +
  'if(!c||c.type!=="ONE_TO_ONE")return;' +
  '(c.participants||[]).forEach(function(p){' +
  'var id=String(p.user_id||"");if(id)counts[id]=(counts[id]||0)+1;});});}catch(e){}' +
  'var accountId="",best=0;' +
  'try{Object.keys(counts).forEach(function(id){' +
  'if(counts[id]>best){best=counts[id];accountId=id;}});}catch(e){}' +
  'return accountId;};' +
  // Account identity without the DOM: the inbox names its participants, so the
  // signed-in user's own entry gives the handle and picture. This is the one
  // identity source that works on every page (settings, post detail, search),
  // where x.com renders no account navigation at all.
  'var otAccountFromInbox=function(st){' +
  'var id=otAccountFromConvs((st&&st.conversations)||{});if(!id)return null;' +
  'var users=(st&&st.users)||{};var u=users[id]||null;' +
  'if(!u){try{Object.keys(users).forEach(function(k){' +
  'if(String(k)===id||String(users[k]&&users[k].id_str)===id)u=users[k];});}catch(e){}}' +
  'if(!u)return null;' +
  'return {id:id,handle:String(u.screen_name||""),' +
  'name:String(u.name||u.screen_name||""),' +
  'avatar:String((u.profile_image_url_https||"")).replace("_normal","_bigger")};};' +
  // Epoch handling shared by surfaces: x.com mixes ms, seconds and ISO dates.
  'var otTime=function(v){' +
  'if(v===null||v===undefined)return 0;' +
  'if(typeof v==="number"){return v<1e12?Math.round(v*1000):Math.round(v);}' +
  'var s=String(v);if(/^[0-9]+$/.test(s)){var n=Number(s);return n<1e12?n*1000:n;}' +
  'var t=Date.parse(s);return isNaN(t)?0:t;};' +
  // API text arrives HTML-escaped ("worktrees &amp; moving" was rendered
  // literally on a real DM thread before this). Decode one level, ampersand
  // last so "&amp;lt;" becomes "&lt;" rather than being decoded twice.
  'var otText=function(s){' +
  'if(s===null||s===undefined)return "";' +
  'var t=String(s);if(t.indexOf("&")<0)return t;' +
  'try{var d=document.createElement("textarea");d.innerHTML=t;' +
  'var v=d.value||"";return v?v:t;}catch(e){}' +
  'return t.replace(/&lt;/g,"<").replace(/&gt;/g,">")' +
  '.replace(/&quot;/g,String.fromCharCode(34)).replace(/&apos;/g,String.fromCharCode(39))' +
  '.replace(/&#0?39;/g,String.fromCharCode(39)).replace(/&amp;/g,"&");};';

const DM_MEDIA_HELPER: string =
  'var otDmMedia=function(md){try{var a=md&&md.attachment;if(Array.isArray(a))a=a[0];if(a)return a;' +
  'var aa=md&&md.attachments;if(Array.isArray(aa)&&aa.length)return aa[0];return null;}catch(e){return null;}};' +
  'var otDmMediaUrl=function(md){try{var a=otDmMedia(md);if(!a)return "";' +
  'var x=a.photo||a.media||a.video||a.animated_gif;if(!x)return "";' +
  'return String(x.media_url_https||x.media_url||x.preview_image_url||x.url||x.display_url||"");}catch(e){return "";}};' +
  'var otDmMediaAlt=function(md){try{var a=otDmMedia(md);if(!a)return "Image";' +
  'var x=a.photo||a.media||a.video||a.animated_gif;return String((x&&x.alt_text)||md.alt_text||"Image");}catch(e){return "Image";}};';

/**
 * Wraps a per-surface body into a self-contained script for
 * `WebviewController.runJavaScript`.
 *
 * The body is inlined after [SESSION_SETUP] and [FETCH_HELPER], so it can use
 * `ct0`, `bearer`, `otGet(path)`, `otPost(path,body)`, `otAccountFromConvs(convs)`
 * and `otTime(v)` directly, and `await` at the top level. It must return a
 * JSON string; `{"state":"..."}` is the convention for anything that is not the
 * data the surface asked for.
 */
export function pageBridgeScript(body: string): string {
  return '(async function(){try{' + SESSION_SETUP + FETCH_HELPER + DM_MEDIA_HELPER + body +
    '}catch(e){return JSON.stringify({state:"error",message:String(e).slice(0,120)});}})()';
}
