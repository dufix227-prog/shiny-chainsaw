"""Build the animated illustration from original, repository-owned art."""
from copy import deepcopy
from pathlib import Path
import xml.etree.ElementTree as ET

HERE = Path(__file__).parent
ET.register_namespace("", "http://www.w3.org/2000/svg")
angular = ET.parse(HERE / "angular.svg")
soft = ET.parse(HERE / "scene.svg")


def original(tree, name):
    return deepcopy(next(node for node in tree.iter() if node.get("id") == name))


defs = []
for name in ("grass", "paving", "soil", "leaf-block", "tree", "stone", "fence"):
    node = original(angular, name)
    if name == "tree":
        canopy = ET.Element("{http://www.w3.org/2000/svg}g", {"class": "canopy"})
        for child in list(node):
            if child.tag.endswith("}use"):
                node.remove(child)
                canopy.append(child)
        node.append(canopy)
    defs.append(ET.tostring(node, encoding="unicode"))
for name in ("berry", "plant"):
    node = original(soft, name)
    node.set("id", "garden-" + name)
    for child in node.iter():
        if child.get("href") == "#berry":
            child.set("href", "#garden-berry")
    defs.append(ET.tostring(node, encoding="unicode"))

svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="800" viewBox="0 0 640 400" role="img" aria-labelledby="title desc">
<title id="title">Проба 04: прямая дорога и живое окружение</title>
<desc id="desc">Анимированная иллюстрация, не игра. Крупный пиксельный кот с треугольными ушами, широкая прямая дорога, озеро, грядки, объёмные деревья и обзорная карта всего пролога. Позиции на карте условны, кроме 100 и 189 метров.</desc>
<style>
@keyframes wind {0%,12%,58%,100%{transform:translate(0,0)}23%{transform:translate(1.5px,-.5px)}33%{transform:translate(-.6px,.2px)}44%{transform:translate(.6px,-.2px)}}
@keyframes ripple {0%,100%{transform:translateX(-3px);opacity:.35}50%{transform:translateX(4px);opacity:.85}}
.canopy,.foliage{animation:wind 12s ease-in-out var(--wind-delay,0s) infinite}.ripples{animation:ripple 3.4s ease-in-out infinite}.ripples.late{animation-delay:-1.7s}
.lids{opacity:0}
.paused *{animation-play-state:paused!important}
@media(prefers-reduced-motion:reduce){*{animation:none!important}}
</style><defs>'''
svg += "".join(defs)
svg += '''
<linearGradient id="water" x2="0" y2="1"><stop stop-color="#92c6bd"/><stop offset=".45" stop-color="#5a9f9e"/><stop offset="1" stop-color="#427a82"/></linearGradient>
<clipPath id="world-clip"><rect width="512" height="400"/></clipPath>
<clipPath id="lake-clip"><path d="M27 203l21-27 61-18 53 13 27 30-8 40-30 20-73 6-43-21z"/></clipPath>
<g id="big-bush"><path d="M0 13l8-16 19-7 17 3 15-4 21 10 10 17-10 15-26 5-17-5-23 3-15-10z" fill="#456f47"/><path d="M4 9l10-12 14-4 16 5 15-5 15 7 6 9-24 1-20 6-15-8z" fill="#85a561"/><path d="M13 6l11-5m30 4l9-3m-33 22l13-3m20 4l9-3" stroke="#afbd73" stroke-width="3"/><path d="M12 23l7 3m37 4l8-3" stroke="#315940" stroke-width="3"/></g>
<g id="detailed-cat" shape-rendering="crispEdges">
 <g class="tail"><path d="M31 37h9V24h4v16h-4v4h-9z" fill="#34392f"/><path d="M33 38h8V26h2v13h-10z" fill="#a39b80"/><path d="M41 27h2v4h-2z" fill="#696e5c"/></g>
 <g class="paw-left"><path d="M10 41h9v13H7v-5h3z" fill="#34392f"/><path d="M12 43h5v9H9v-2h3z" fill="#a69e82"/><path d="M9 50h7v2H9z" fill="#dfd1ab"/></g>
 <g class="paw-right"><path d="M24 41h9v8h3v5H24z" fill="#34392f"/><path d="M26 43h5v8h3v1h-8z" fill="#aba386"/><path d="M27 50h7v2h-7z" fill="#dfd1ab"/></g>
 <g class="body"><path d="M11 29h20v4h4v14h-5V37h-1v9H14V37h-1v10H7V34h4z" fill="#34392f"/><path d="M12 32h18v13H15V36h-4v9H9v-9h3z" fill="#aca58a"/><path d="M17 32h10v10H17z" fill="#e8d8b4"/><path d="M7 42h6v3H7z" fill="#b75548"/>
 <path d="M4 1h3v3h3v3h3v3h4V9h9v1h3V7h3V4h3V1h3v6h2v5h2v13h-3v4h-5v3H12v-3H6v-4H3V12h1z" fill="#34392f"/>
 <path d="M6 4h1v3h3v3h3v3h5v-2h8v2h5v-3h3V7h2V4h1v9h3v11h-3v3h-5v3H13v-3H8v-3H5V13h1z" fill="#bbb095"/>
 <path d="M6 7h2v3h3v3H7v-3H6zm30 0h-2v3h-3v3h5z" fill="#d68e7f"/><path d="M7 9h1v2h2v1H8zm27 1h1v2h-3v-1h2z" fill="#edb39a"/>
 <path d="M17 11h3v5h-3zm6 0h3v4h-3zM7 16h3v3H7zm28 0h4v3h-4z" fill="#7b7c66"/>
 <path d="M7 22h9v2h12v-2h10v4h-5v3H13v-3H7z" fill="#ecdfbd"/>
 <g class="eyes"><path d="M11 17h7v6h-7zm17 0h7v6h-7z" fill="#344035"/><path d="M12 17h3v2h-3zm17 0h3v2h-3z" fill="#fff4d2"/><path d="M15 21h2v1h-2zm17 0h2v1h-2z" fill="#aeb779"/></g>
 <g class="lids"><path d="M11 20h7v2h-7zm17 0h7v2h-7z" fill="#344035"/></g>
 <path d="M21 23h4v2h-4zm1 2h2v2h-2zm-3 2h3v1h-3zm5 0h3v1h-3z" fill="#7d5545"/>
 <path d="M4 23H0v1h4zm1 4H1v1h4zm34-4h5v1h-5zm-1 4h5v1h-5z" fill="#5e6654"/>
 </g>
</g>
</defs>
<g id="world" clip-path="url(#world-clip)">
 <rect width="512" height="400" fill="url(#grass)"/>
 <path d="M0 50h100v15h52v20h38v20H0zm512 243h-95v30h-62v47h-29v40h186z" fill="#708951"/>
 <path d="M223 0h86v400h-86z" fill="#697b48"/>
 <path d="M227 0h78v400h-78z" fill="url(#paving)"/>
 <path d="M228 0v400m75-400v400" stroke="#e5ca8c" stroke-width="2"/>
 <path d="M236 21h9m39 25h10m-38 75h8m-22 67h8m31 38h8m-48 54h9m26 49h10" stroke="#e7ce94" stroke-width="2"/>
 <path d="M18 202l24-32 64-20 61 14 33 35-8 50-35 21-80 7-49-24z" fill="#b6b686"/>
 <path d="M27 203l21-27 61-18 53 13 27 30-8 40-30 20-73 6-43-21z" fill="url(#water)"/>
 <g clip-path="url(#lake-clip)"><path d="M32 201l25-20 49-14 50 14 19 20-4 17-37-21-45-3-35 15z" fill="#b2d2bf" opacity=".48"/>
 <path d="M62 234l34-15 42 5 26 18-27 18-51 1z" fill="#3f7480" opacity=".4"/>
 <g class="ripples" fill="none" stroke="#d4e5cb" stroke-width="2"><path d="M43 202h24m15-20h18m24 22h31M64 232h31m22 20h23"/></g>
 <g class="ripples late" fill="none" stroke="#add2c1" stroke-width="2"><path d="M97 213h26m-68 35h19m62-20h26M32 217h16"/></g>
 <path d="M42 227l3-7m3 21l3-5m112-50l4 5" stroke="#dddcaf" stroke-width="2"/></g>
 <g stroke="#547047" stroke-width="2"><path d="M26 218v-19m6 19v-14m146 43v-22m5 18v-13"/></g>
 <g id="lake-steps" fill="#a88658" stroke="#715d40" stroke-width="1">
  <path d="M181 220h30v5h-30z"/>
  <path d="M187 227h30v5h-30z"/>
  <path d="M193 234h30v5h-30z"/>
  <path d="M199 241h30v5h-30z"/>
 </g>
 <path d="M204 214l-5-26m0 0l-19 36" fill="none" stroke="#7d6446" stroke-width="2"/>
 <path d="M327 167l78-31 89 49-77 36z" fill="#6f8450"/>
 <path d="M329 166l15-6 73 42-16 7zm23-10l16-6 73 42-16 7zm25-10l16-6 73 42-16 7z" fill="url(#soil)" stroke="#b09b65" stroke-width="2"/>
 <g class="foliage" style="--wind-delay:-2s">'''
for row in range(3):
    for col in range(4):
        svg += f'<use href="#garden-plant" transform="translate({340 + row * 24 + col * 18} {164 - row * 10 + col * 10}) scale(.5)"/>'
svg += '''</g>
 <use href="#fence" x="328" y="153"/><use href="#fence" x="399" y="124"/>
 <path d="M374 101l66-27 61 32-66 29z" fill="#426040" opacity=".3"/>
 <path d="M364 73l57 29v39l-57-28z" fill="#d8c9a0"/><path d="M421 102l56-26v39l-56 26z" fill="#aaa381"/>
 <path d="M355 72l27-39 59-23 43 40-63 54z" fill="#9c6b4b"/><path d="M355 72l27-39 39 71z" fill="#c18a57"/><path d="M355 72v5l66 33 63-54v-6l-63 54z" fill="#61503c"/>
 <path d="M389 39l53-24m-46 34l54-25m-48 36l57-27m-51 38l59-28M403 25l35 38m-18-45l34 33" fill="none" stroke="#c09461" stroke-width="2"/>
 <path d="M385 101l13 7v22l-13-6z" fill="#776247"/><path d="M369 87l9 5v12l-9-5zm64 17l15-7v13l-15 7z" fill="#608680" stroke="#e9dbb1" stroke-width="2"/>
 <use href="#tree" transform="translate(70 107) scale(.9)"/><use href="#tree" transform="translate(168 123) scale(.8)"/><use href="#tree" transform="translate(325 71) scale(.65)"/><use href="#tree" transform="translate(493 159) scale(.85)"/>
 <g class="foliage" style="--wind-delay:-4s"><use href="#big-bush" transform="translate(126 302) scale(.9)"/></g>
 <g class="foliage" style="--wind-delay:-5.5s"><use href="#big-bush" transform="translate(330 263) scale(.9)"/></g>
 <use href="#stone" x="204" y="270"/><use href="#stone" x="323" y="315"/>
 <path d="M244 328h48v5h-7v3h-33v-3h-8z" fill="#7b714d" opacity=".4"/>
 <use id="hero-preview" href="#detailed-cat" transform="translate(231 247) scale(1.5)"/>
 <use href="#tree" transform="translate(37 421) scale(1.2)"/><use href="#tree" transform="translate(493 414) scale(1.15)"/>
</g>
<g id="ui" font-family="DejaVu Sans, sans-serif" fill="#e9e0c3">
 <rect width="640" height="23" fill="#263d32"/><text x="12" y="15" font-size="8.5" letter-spacing=".7">10 000 МЕТРОВ ДО ДОМА</text><text x="501" y="15" text-anchor="end" font-size="6">ПРОБА 04 · АНИМАЦИИ, НЕ ИГРА</text>
 <rect x="12" y="34" width="116" height="58" fill="#2e4436"/><rect x="16" y="38" width="34" height="31" fill="#586345"/><svg x="16" y="38" width="34" height="28" viewBox="0 0 44 33"><use href="#detailed-cat"/></svg>
 <text x="57" y="49" font-size="6" fill="#b9c494">ПРОЛОГ · 500 М</text><text x="57" y="62" font-size="8">За клубничкой</text><text x="21" y="82" font-size="6">Силы</text><rect x="47" y="76" width="68" height="5" fill="#62714a"/><rect x="47" y="76" width="51" height="5" fill="#b4c27d"/>
 <rect x="183" y="346" width="169" height="28" fill="#2d4334"/>
 <g fill="#4c5e42" stroke="#8c9c6f"><rect x="189" y="350" width="20" height="20"/><rect x="215" y="350" width="20" height="20"/><rect x="241" y="350" width="20" height="20"/><rect x="267" y="350" width="20" height="20"/></g>
 <path d="M194 366l10-11" stroke="#d3b787" stroke-width="3"/><use href="#garden-berry" transform="translate(225 358) scale(.7)"/><path d="M246 355l5-2 6 3v10l-6-2-5 2z" fill="#d0c18f"/><path d="M272 358h10v8h-10zm2-4h6v4h-6z" fill="#c6aa7b"/><text x="299" y="359" font-size="6">Tab</text><text x="299" y="367" font-size="5.5">Инвентарь</text>
 <rect x="512" y="23" width="128" height="377" fill="#23392f"/><path d="M514 23v377" stroke="#889468"/>
 <text x="527" y="45" font-size="9">КАРТА ПРОЛОГА</text><text x="527" y="59" font-size="6.5" fill="#b5c399">ТЕКУЩАЯ ТОЧКА · 100 м</text>
 <path d="M534 94V270" stroke="#718359" stroke-width="12"/><path d="M534 94V270" stroke="#d4bd83" stroke-width="5"/>
 <circle cx="534" cy="154" r="6" fill="#d96d59" stroke="#f1dfad" stroke-width="2"/><text x="548" y="157" font-size="6.5" fill="#f1dfad">СЕЙЧАС</text>
 <g font-size="7.5"><rect x="530" y="90" width="8" height="8" fill="#e8d5a2"/><text x="546" y="96">Дом</text><text x="546" y="107" font-size="5.7" fill="#a8ba91">Старт · 0 м</text>
 <rect x="530" y="150" width="8" height="8" fill="#e8d5a2"/><text x="546" y="156">Стинт</text><text x="546" y="167" font-size="5.7" fill="#a8ba91">100 м</text>
 <rect x="530" y="206" width="8" height="8" fill="#e8d5a2"/><text x="546" y="212">Братишкин</text><text x="546" y="223" font-size="5.7" fill="#a8ba91">189 м</text>
 <rect x="530" y="266" width="8" height="8" fill="#e8d5a2"/><text x="546" y="272">Озеро</text><text x="546" y="283" font-size="5.7" fill="#a8ba91">сбоку от пути</text></g>
 <text x="527" y="322" font-size="6" fill="#c7d1ae">Открыто: 0–189 м</text><text x="527" y="335" font-size="5.5" fill="#9fb18b">Новые места появятся</text><text x="527" y="344" font-size="5.5" fill="#9fb18b">после обнаружения.</text>
 <rect y="386" width="512" height="14" fill="#263d32"/><text x="256" y="395" text-anchor="middle" font-size="5.5">АНИМИРОВАННЫЙ МАКЕТ · ОБЪЁМ НАРИСОВАН · ДВИЖОК НЕ ВЫБРАН</text>
</g></svg>'''
root = ET.fromstring(svg)
tree_number = 0
for parent in list(root.iter()):
    for index, child in enumerate(list(parent)):
        if child.get("href") == "#tree":
            tree = original(ET.ElementTree(root), "tree")
            tree.attrib.pop("id")
            tree.set("transform", child.get("transform", ""))
            tree.set("style", f"--wind-delay:{-tree_number * .9}s")
            parent.remove(child)
            parent.insert(index, tree)
            tree_number += 1
root.find("{http://www.w3.org/2000/svg}defs").remove(
    next(node for node in root.iter() if node.get("id") == "tree")
)
output = ET.tostring(root, encoding="unicode")
(HERE / "living.svg").write_text(
    "\n".join(line.rstrip() for line in output.splitlines()) + "\n", encoding="utf-8"
)
print("Built living.svg (1280×800 CSS pixels)")
