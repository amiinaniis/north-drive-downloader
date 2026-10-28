#!/bin/zsh
# North Frame Toolkit — local CEP merger (macOS, no Xcode required)
# Place this file beside all SIX original North *.zip packages and double-click.
set -euo pipefail
setopt NULL_GLOB
BASE="$(cd "$(dirname "$0")" && pwd)"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BUILD="$BASE/North Frame Toolkit Build $STAMP"
APP="$BUILD/North Frame Toolkit"
mkdir -p "$APP/CSXS" "$APP/modules" "$APP/host"
log(){ print -r -- "[North Frame] $1"; }
fail(){ print -u2 -r -- "ERROR: $1"; exit 1; }
json(){ /usr/bin/perl -MJSON::PP -e 'print JSON::PP->new->utf8->encode($ARGV[0])' "$1"; }
strip_dot(){ print -r -- "${1#./}"; }
TITLES=(Downloader Ease Presets SFX Texts Transitions)
SLUGS=(downloader ease presets sfx texts transitions)
ZIPS=()
for ((i=1;i<=6;i++)); do
  title="$TITLES[i]"
  found="$(find "$BASE" -maxdepth 1 -type f -iname "North $title*.zip" -print -quit)"
  [[ -n "$found" ]] || fail "Missing North $title ZIP beside this script."
  ZIPS+=("$found")
done
log "Found six source packages. Original ZIPs will not be changed."
print -r -- 'window.NORTH_TOOLS = [' > "$APP/modules.js"
FLAGS="$BUILD/cef-flags.txt"
printf '%s\n' '--enable-nodejs' '--mixed-context' > "$FLAGS"
REPORT="$BUILD/INTEGRATION-REPORT.txt"
print -r -- 'NORTH FRAME TOOLKIT — Integration inventory' > "$REPORT"
print -r -- 'Source packages extracted without flattening or renaming their internal assets.' >> "$REPORT"

for ((i=1;i<=6;i++)); do
  title="$TITLES[i]"
  slug="$SLUGS[i]"
  archive="$ZIPS[i]"
  dst="$APP/modules/$slug"
  mkdir -p "$dst"
  log "Extracting $title..."
  /usr/bin/ditto -x -k "$archive" "$dst"
  manifest=""
  while IFS= read -r candidate; do
    parent="$(basename "$(dirname "$candidate")")"
    if [[ "$parent" == [Cc][Ss][Xx][Ss] ]]; then manifest="$candidate"; break; fi
  done < <(find "$dst" -type f -iname manifest.xml -print)
  source_root="$dst"
  main=""
  jsx=""
  original_id=""
  if [[ -n "$manifest" ]]; then
    source_root="$(dirname "$(dirname "$manifest")")"
    main="$(/usr/bin/perl -0777 -ne 'if (/<MainPath>\s*([^<]+?)\s*<\/MainPath>/si){print $1;exit}' "$manifest")"
    jsx="$(/usr/bin/perl -0777 -ne 'if (/<ScriptPath>\s*([^<]+?)\s*<\/ScriptPath>/si){print $1;exit}' "$manifest")"
    original_id="$(/usr/bin/perl -0777 -ne 'if (/<ExtensionList\b.*?<Extension\b[^>]*\bId="([^"]+)"/si){print $1;exit}' "$manifest")"
    while IFS= read -r flag; do
      [[ -z "$flag" ]] && continue
      grep -Fqx -- "$flag" "$FLAGS" || print -r -- "$flag" >> "$FLAGS"
    done < <(/usr/bin/perl -0777 -ne 'while (/<Parameter>\s*([^<]+?)\s*<\/Parameter>/sig){print "$1\n"}' "$manifest")
  fi
  main="$(strip_dot "$main")"
  jsx="$(strip_dot "$jsx")"
  entry=""
  if [[ -n "$main" && -f "$source_root/$main" ]]; then entry="$source_root/$main"; fi
  if [[ -z "$entry" ]]; then entry="$(find "$dst" -type f -iname index.html -print -quit)"; fi
  if [[ -z "$entry" ]]; then entry="$(find "$dst" -type f -iname '*.html' -print -quit)"; fi
  [[ -n "$entry" ]] || fail "$title has no HTML entry point. See extracted files in $dst."
  entry_rel="${entry#$APP/}"
  module_root="${source_root#$APP/}"
  jsx_rel=""
  if [[ -n "$jsx" && -f "$source_root/$jsx" ]]; then
    jsx_rel="${source_root#$APP/}/$jsx"
  fi

  # Inject only a thin CEP bridge at the START of the copied HTML entry.
  # All original JS, JSX, CSS, media, and folder contents stay in place.
  MODULE_ROOT_JSON="$(json "$module_root")"
  SHIM="$BUILD/shim-$slug.js"
  cat > "$SHIM" <<EOF
(function(){
  try {
    var p=window.parent;
    if (!p || p===window) return;
    var native=window.__adobe_cep__ || p.__adobe_cep__;
    if (!native) return;
    var facade=Object.create(native);
    var names=['evalScript','invokeSync','invokeAsync','dispatchEvent','addEventListener','removeEventListener','getHostEnvironment','getExtensionId','requestOpenExtension','closeExtension','getHostCapabilities','resizeContent','getScaleFactor','setScaleFactor','getWindowID','getCurrentApiVersion','openURLInDefaultBrowser'];
    for(var i=0;i<names.length;i++){
      (function(key){
        if(typeof native[key]==='function'){
          facade[key]=function(){return native[key].apply(native,arguments);};
        }
      })(names[i]);
    }
    var sourceRoot=$MODULE_ROOT_JSON;
    facade.getSystemPath=function(type){
      var base=native.getSystemPath.call(native,type);
      if(type==='extension' && base) return base.replace(/\\/$/,'')+'/'+sourceRoot;
      return base;
    };
    window.__adobe_cep__=facade;
    if(!window.cep && p.cep) window.cep=p.cep;
    if(!window.cep_node && p.cep_node) window.cep_node=p.cep_node;
  }catch(err){ /* Original CEP globals are used when bridging is unavailable. */ }
})();
EOF
  NORTH_SHIM="$SHIM" /usr/bin/perl -0777 -i -pe '
    BEGIN { local $/; open my $in, "<", $ENV{"NORTH_SHIM"} or die $!; $shim = <$in>; close $in; }
    $inject = "<script>\n" . $shim . "\n</script>\n";
    if (/<head\b[^>]*>/i) { s{(<head\b[^>]*>)}{$1 . "\n" . $inject}ie; }
    else { $_ = $inject . $_; }
  ' "$entry"

  print -r -- "$title | entry=$entry_rel | hostJSX=$jsx_rel | originalCEPId=$original_id" >> "$REPORT"
  print -r -- '  {id:'"$(json "$slug")"', name:'"$(json "$title")"', entry:'"$(json "$entry_rel")"', jsx:'"$(json "$jsx_rel")"', root:'"$(json "$module_root")"', originalId:'"$(json "$original_id")"'},' >> "$APP/modules.js"
done
print -r -- '];' >> "$APP/modules.js"
cat > "$APP/host/bootstrap.jsx" <<'EOF'
// Shared CEP engine bootstrap. Original host JSX files are loaded on module selection.
var NORTH_FRAME_TOOLKIT_VERSION = '1.0.0';
EOF
{
cat <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<ExtensionManifest Version="7.0" ExtensionBundleId="com.northframe.toolkit"
  ExtensionBundleVersion="1.0.0" ExtensionBundleName="North Frame Toolkit">
  <ExtensionList>
    <Extension Id="com.northframe.toolkit.panel" Version="1.0.0"/>
  </ExtensionList>
  <ExecutionEnvironment>
    <HostList><Host Name="PPRO" Version="[14.0,99.9]"/></HostList>
    <LocaleList><Locale Code="All"/></LocaleList>
    <RequiredRuntimeList><RequiredRuntime Name="CSXS" Version="9.0"/></RequiredRuntimeList>
  </ExecutionEnvironment>
  <DispatchInfoList>
    <Extension Id="com.northframe.toolkit.panel">
      <DispatchInfo>
        <Resources>
          <MainPath>./index.html</MainPath>
          <ScriptPath>./host/bootstrap.jsx</ScriptPath>
          <CEFCommandLine>
EOF
while IFS= read -r flag; do
  case "$flag" in
    --*) printf '            <Parameter>%s</Parameter>\n' "$flag" ;;
  esac
done < "$FLAGS"
cat <<'EOF'
          </CEFCommandLine>
        </Resources>
        <Lifecycle><AutoVisible>true</AutoVisible></Lifecycle>
        <UI>
          <Type>Panel</Type>
          <Menu>North Frame Toolkit</Menu>
          <Geometry>
            <Size><Width>460</Width><Height>640</Height></Size>
            <MinSize><Width>250</Width><Height>260</Height></MinSize>
            <MaxSize><Width>2600</Width><Height>2200</Height></MaxSize>
          </Geometry>
        </UI>
      </DispatchInfo>
    </Extension>
  </DispatchInfoList>
</ExtensionManifest>
EOF
} > "$APP/CSXS/manifest.xml"

cat > "$APP/index.html" <<'EOF'
<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>North Frame Toolkit</title>
<style>
:root{color-scheme:dark;--bg:#0d0d12;--rail:#101015;--panel:#121218;--line:#29252f;--text:#ebe8ef;--sub:#898391;--pink:#ec8bb7;--pink2:#f8bfd8;--highlight:#2e202d;font:12px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
*{box-sizing:border-box}
html,body{margin:0;width:100%;height:100%;overflow:hidden;background:var(--bg);color:var(--text)}
button{font:inherit;color:inherit;cursor:pointer;-webkit-appearance:none;appearance:none}
button:focus-visible{outline:2px solid var(--pink);outline-offset:2px}
.app{display:flex;width:100%;height:100%;min-width:0;min-height:0;overflow:hidden}
.rail{flex:0 0 171px;display:flex;flex-direction:column;min-height:0;background:#0e0e14;border-right:1px solid var(--line);transition:flex-basis .12s}
.brand{min-height:75px;display:flex;align-items:center;gap:10px;padding:15px}
.mark{width:30px;height:30px;border:1px solid #84516c;border-radius:9px;display:flex;align-items:center;justify-content:center;color:var(--pink);background:linear-gradient(135deg,#372638,#17141c);box-shadow:0 0 21px #ec8bb718;flex:none}
.mark svg{width:19px;height:19px}
.brandwords{min-width:0}
.brandwords b{display:block;letter-spacing:1.1px;font-size:10px;white-space:nowrap}
.brandwords small{display:block;font-size:8px;letter-spacing:1.6px;color:#b37a9b;margin-top:3px}
.navlabel{font-size:9px;font-weight:750;color:#776e7d;letter-spacing:1.2px;padding:5px 14px 10px}
.nav{padding:0 7px;display:flex;flex-direction:column;gap:4px;overflow-y:auto;min-height:0;scrollbar-width:thin}
.navbtn{width:100%;height:39px;display:flex;align-items:center;gap:11px;text-align:left;border:1px solid transparent;border-radius:8px;padding:0 10px;background:transparent;color:#9d97a6;white-space:nowrap;transition:background .15s,border-color .15s}
.navbtn svg{width:16px;height:16px;flex:none}
.navbtn:hover{background:#1c1b24;color:#f2e7ef}
.navbtn.active{border-color:#5c354c;background:#30212d;color:#f7afd0}
.navbtn span{overflow:hidden;text-overflow:ellipsis}
.railbottom{margin-top:auto;border-top:1px solid var(--line);font-size:9px;color:#8a7989;margin-left:11px;margin-right:11px;padding:14px 3px;display:flex;align-items:center;gap:7px}
.dot{background:var(--pink);box-shadow:0 0 8px #ec8bb790;border-radius:50%;width:6px;height:6px;flex:none}
.main{display:flex;flex-direction:column;flex:1;min-height:0;min-width:0;background:var(--panel)}
.toolbar{flex:none;min-height:62px;border-bottom:1px solid var(--line);display:flex;align-items:center;justify-content:space-between;gap:12px;padding:12px 19px}
.path{font-weight:750;letter-spacing:1.5px;color:#ba819e;font-size:8px}
.current{font-size:16px;font-weight:750;letter-spacing:-.4px;margin-top:2px}
.actions{display:flex;align-items:center;gap:8px;flex:none}
.iconbtn{width:30px;height:30px;border:1px solid #3c303e;border-radius:8px;background:#221d28;color:#c69bb1;display:flex;align-items:center;justify-content:center;font-size:16px}
.iconbtn:hover{background:#382639}
.viewport{position:relative;flex:1;min-width:0;min-height:0;overflow:hidden;background:radial-gradient(ellipse at 85% 0%,#82405e15,transparent 44%),#111116}
.frame{position:absolute;inset:0;border:0;width:100%;height:100%;display:block;background:#101116;visibility:hidden;pointer-events:none}
.frame.active{visibility:visible;pointer-events:auto}
.overview{position:absolute;inset:0;overflow-y:auto;padding:23px;scrollbar-color:#4f3546 transparent;scrollbar-width:thin}
.eyebrow{font-size:9px;font-weight:750;letter-spacing:1.6px;color:#d48bae}
h1{font-size:28px;line-height:1.1;letter-spacing:-1px;margin:12px 0 9px;font-weight:760}
.lead{color:#9a91a1;margin:0;line-height:1.65;max-width:450px;font-size:11px}
.hero{border:1px solid #51334a;border-radius:11px;padding:17px;margin-top:24px;background:linear-gradient(115deg,#352334,#1a1822);display:flex;justify-content:space-between;align-items:center;gap:12px}
.hero b{font-size:13px}
.hero p{margin:6px 0 0;font-size:10px;color:#b19bac}
.spark{font-size:27px;color:#df91b7}
.sect{display:flex;justify-content:space-between;align-items:center;gap:8px;margin:24px 0 12px;font-size:11px;font-weight:750}
.sect small{font-size:9px;color:#817a88;letter-spacing:.8px}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(137px,1fr));gap:10px}
.card{min-height:121px;background:linear-gradient(140deg,#1c1b23,#15151b);border:1px solid #322c37;text-align:left;border-radius:10px;display:flex;flex-direction:column;align-items:flex-start;padding:14px;gap:6px;min-width:0}
.card:hover{border-color:#88516f;background:#28212c}
.cardicon{width:29px;height:29px;border-radius:8px;color:#eca1c2;background:#3a2835;display:flex;align-items:center;justify-content:center;margin-bottom:8px}
.cardicon svg{width:16px;height:16px}
.card b{font-size:11px}
.card small{color:#8c8392;font-size:10px}
.notice{position:absolute;bottom:17px;left:17px;right:17px;z-index:5;border:1px solid #584054;background:#2b202b;color:#ffd6e7;border-radius:8px;padding:11px 13px;box-shadow:0 10px 27px #0008;font-size:11px;display:none;overflow-wrap:anywhere}
.notice.show{display:block}
.footer{height:25px;flex:none;background:#0c0c11;border-top:1px solid #292631;display:flex;align-items:center;justify-content:space-between;gap:9px;color:#837a89;padding:0 13px;font-size:9px;white-space:nowrap;overflow:hidden}
.footer span{overflow:hidden;text-overflow:ellipsis}
button:disabled{opacity:.6;cursor:wait}
body.compact .rail{flex-basis:53px}
body.compact .brand{padding:11px 10px;min-height:59px}
body.compact .brandwords,body.compact .navlabel,body.compact .navbtn span,body.compact .railbottom .label{display:none}
body.compact .nav{padding:0 5px}
body.compact .navbtn{justify-content:center;padding:0;height:42px}
body.compact .railbottom{justify-content:center}
body.compact .toolbar{padding:10px 13px;min-height:54px}
body.compact .overview{padding:16px}
body.compact h1{font-size:22px}
body.narrow .card{min-height:95px}
body.narrow .cards{grid-template-columns:1fr}
body.narrow .spark{display:none}
body.narrow .hero{padding:12px}
body.narrow .toolbar{padding:8px}
body.narrow .current{font-size:13px}
body.narrow .footer span:last-child{display:none}
@media(prefers-reduced-motion:reduce){*{transition:none!important}}
</style>
</head><body>
<div class="app" id="app">
  <aside class="rail">
    <div class="brand">
      <div class="mark"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3"><path d="M5 19V5l14 14V5"/></svg></div>
      <div class="brandwords"><b>NORTH FRAME</b><small>TOOLKIT / CEP</small></div>
    </div>
    <div class="navlabel">WORKSPACES</div><nav class="nav" id="nav"></nav>
    <div class="railbottom"><span class="dot"></span><span class="label">NORTH / V1.0</span></div>
  </aside>
  <main class="main">
    <header class="toolbar">
      <div><div class="path" id="path">NORTH / WORKSPACE</div><div class="current" id="title">Creative workspace</div></div>
      <div class="actions"><button class="iconbtn" id="reload" title="Reload current module" aria-label="Reload module">↻</button></div>
    </header>
    <section class="viewport" id="viewport">
      <div class="overview" id="overview">
        <span class="eyebrow">THE NORTH WORKSPACE</span>
        <h1>Everything in frame.</h1>
        <p class="lead">Six creative tools. One focused workspace inside your editing timeline.</p>
        <div class="hero"><div><span class="eyebrow">ONE TOOLKIT / SIX ENGINES</span><p><b>Build faster, stay focused.</b></p><p>Pick a module to open its original working interface.</p></div><div class="spark">✳</div></div>
        <div class="sect"><b>Your tools</b><small>06 MODULES</small></div>
        <div class="cards" id="cards"></div>
      </div>
      <div class="notice" id="notice" role="status"></div>
    </section>
    <footer class="footer"><span id="status">Studio Rail ready</span><span>CEP / NORTH FRAME</span></footer>
  </main>
</div>
<script src="./modules.js"></script>
<script>
(function(){
'use strict';
var modules=window.NORTH_TOOLS||[];
var map={overview:'<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',presets:'<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M8 8h8M8 12h8M8 16h5"/>',transitions:'<rect x="2" y="5" width="8" height="14" rx="1"/><rect x="14" y="5" width="8" height="14" rx="1"/><path d="M8 12h8m-3-3 3 3-3 3"/>',ease:'<path d="M3 20h18M4 20V4"/><path d="M5 18C14 18 10 6 19 6"/><circle cx="5" cy="18" r="1.5"/><circle cx="19" cy="6" r="1.5"/>',sfx:'<path d="M2 13h2l2-6 3 11 3-14 3 15 3-9 2 3h2"/>',texts:'<path d="M3 6V4h18v2M12 4v16m-5 0h10"/>',downloader:'<path d="M12 3v13m-5-5 5 5 5-5M4 17v3h16v-3"/>'};
var descriptions={presets:'Custom effect stacks',transitions:'Motion between edits',ease:'Keyframe curves',sfx:'Sound effects',texts:'Typography presets',downloader:'External media'};
function ico(id){return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.7" aria-hidden="true">'+(map[id]||map.overview)+'</svg>'}
var nav=document.getElementById('nav'),cards=document.getElementById('cards'),overview=document.getElementById('overview'),viewport=document.getElementById('viewport'),notice=document.getElementById('notice'),title=document.getElementById('title'),path=document.getElementById('path'),status=document.getElementById('status');
var frames={},loadedJSX={},active='overview',pending=0;
function makeBtn(id,name){
 var b=document.createElement('button');
 b.type='button';b.className='navbtn';b.dataset.id=id;b.title=name;b.innerHTML=ico(id)+'<span></span>';b.querySelector('span').textContent=name;
 b.onclick=function(){select(id)};return b;
}
nav.appendChild(makeBtn('overview','Overview'));
modules.forEach(function(m){
 nav.appendChild(makeBtn(m.id,m.name));
 var b=document.createElement('button');b.className='card';b.type='button';
 b.innerHTML='<span class="cardicon">'+ico(m.id)+'</span><b></b><small></small>';
 b.querySelector('b').textContent=m.name;
 b.querySelector('small').textContent=descriptions[m.id]||'Creative module';
 b.onclick=function(){select(m.id)};
 cards.appendChild(b);
});
function resize(){
 var width=document.documentElement.clientWidth;
 document.body.classList.toggle('compact',width<600);
 document.body.classList.toggle('narrow',width<365);
}
window.addEventListener('resize',resize);
if(window.ResizeObserver) new ResizeObserver(resize).observe(document.getElementById('app'));
resize();
function showNotice(message){
 notice.textContent=message;notice.classList.add('show');
 window.clearTimeout(showNotice.t);showNotice.t=window.setTimeout(function(){notice.classList.remove('show')},6500);
}
function extRoot(){
 try{
  var p=window.__adobe_cep__.getSystemPath('extension')||'';
  if(p.indexOf('file://')===0)p=p.replace(/^file:\/\//,'');
  return decodeURI(p).replace(/\/$/,'');
 }catch(e){return '';}
}
function loadHost(m,done){
 if(!m.jsx||loadedJSX[m.id]){done();return}
 var cep=window.__adobe_cep__;
 if(!cep||typeof cep.evalScript!=='function'){
  showNotice('CEP bridge unavailable. Open this panel inside Premiere Pro.');
  done();return;
 }
 var abs=extRoot()+'/'+m.jsx;
 var expression='try{$.evalFile(new File('+JSON.stringify(abs)+'));"NORTH_OK"}catch(e){"NORTH_ERROR: "+e.toString()}';
 try{
  cep.evalScript(expression,function(result){
   if(String(result).indexOf('NORTH_ERROR:')===0||String(result)==='EvalScript error.'){
     showNotice('Host script: '+String(result));
   }else{
     loadedJSX[m.id]=true;
   }
   done();
  });
 }catch(e){showNotice('Host script could not load: '+e.message);done()}
}
function select(id){
 var m=null;
 if(id!=='overview'){
  for(var i=0;i<modules.length;i++)if(modules[i].id===id){m=modules[i];break}
  if(!m)return;
 }
 active=id;
 Array.prototype.forEach.call(nav.querySelectorAll('.navbtn'),function(n){n.classList.toggle('active',n.dataset.id===id)});
 overview.style.display=id==='overview'?'block':'none';
 for(var key in frames)frames[key].classList.toggle('active',key===id);
 path.textContent='NORTH / '+(id==='overview'?'WORKSPACE':id.toUpperCase());
 title.textContent=m?m.name:'Creative workspace';
 status.textContent=m?'Opening '+m.name+'…':'Studio Rail ready';
 if(!m)return;
 if(frames[id]){status.textContent=m.name+' · Active';return}
 var token=++pending;
 loadHost(m,function(){
  if(frames[id])return;
  var frame=document.createElement('iframe');
  frame.className='frame';
  frame.title=m.name;
  frame.setAttribute('enable-nodejs','');
  frame.setAttribute('allow','clipboard-read; clipboard-write');
  frame.onload=function(){
    if(active===id){status.textContent=m.name+' · Active';frame.classList.add('active')}
  };
  frame.onerror=function(){if(active===id)showNotice(m.name+' HTML failed to load')};
  frames[id]=frame;
  viewport.appendChild(frame);
  frame.src='./'+m.entry.split('/').map(encodeURIComponent).join('/');
  frame.classList.toggle('active',active===id);
  if(active===id)status.textContent=m.name+' · Loading interface…';
 });
}
document.getElementById('reload').onclick=function(){
 if(active==='overview'){select('overview');return}
 var m=modules.filter(function(x){return x.id===active})[0];
 if(!m)return;
 if(frames[active]){
  frames[active].src='./'+m.entry.split('/').map(encodeURIComponent).join('/')+'?north_reload='+Date.now();
  status.textContent='Reloading '+m.name+'…';
 }else{select(active)}
};
document.addEventListener('keydown',function(e){
 if((e.metaKey||e.ctrlKey)&&e.keyCode>=49&&e.keyCode<=54){
  var m=modules[e.keyCode-49];if(m){e.preventDefault();select(m.id)}
 }
});
select('overview');
})();
</script></body></html>
EOF

cat > "$BUILD/README - INSTALL.txt" <<'EOF'
NORTH FRAME TOOLKIT — Studio Rail V1.0
=======================================
Built from the six source ZIP packages in this folder.
Original ZIPs were not edited.

OPEN IN PREMIERE PRO:
  Window > Extensions (Legacy) > North Frame Toolkit
  (Menu wording varies with Premiere version.)

INSTALL:
  The builder offers to copy the assembled panel into:
  ~/Library/Application Support/Adobe/CEP/extensions/com.northframe.toolkit.panel

DEVELOPER MODE:
  If unsigned CEP extensions do not appear, enable CSXS PlayerDebugMode
  for your installed CEP runtime, then restart Premiere Pro.

IMPORTANT COMPATIBILITY NOTES:
  1. Each original HTML interface is isolated in its own iframe.
  2. The original CSS, JSX, JavaScript, and media asset libraries are retained.
  3. The entry HTML receives a small early CEP bridge shim.
  4. JSX startup scripts are loaded on demand in one shared CEP engine.
  5. The new shell resizes automatically, but any fixed-width legacy plugin
     screen may still need a module-specific responsive CSS adjustment.
  6. If original JSX globals or hardcoded CEP IDs overlap between modules,
     additional namespace migration is required. Do not sell or distribute
     before testing every module inside your target Premiere build.
EOF
log "Creating distributable ZIP (large media packages may take a while)..."
/usr/bin/ditto -c -k --keepParent "$APP" "$BUILD/North Frame Toolkit.zip"
log "Packaged: $BUILD/North Frame Toolkit.zip"
INSTALL_DIR="$HOME/Library/Application Support/Adobe/CEP/extensions"
printf '\nInstall North Frame Toolkit into the user CEP extensions folder? [Y/n] '
read -r answer
if [[ "$answer" == "" || "$answer" == [Yy]* ]]; then
  mkdir -p "$INSTALL_DIR"
  TARGET="$INSTALL_DIR/com.northframe.toolkit.panel"
  if [[ -e "$TARGET" ]]; then
    /bin/mv "$TARGET" "$TARGET.backup.$STAMP"
    log "Existing toolkit backed up."
  fi
  /usr/bin/ditto "$APP" "$TARGET"
  log "Installed. Restart Premiere Pro and open North Frame Toolkit."
else
  log "Not installed. The assembled ZIP and panel folder are saved in $BUILD"
fi
printf '\nBuild complete. Press Return to close. '
read -r _
