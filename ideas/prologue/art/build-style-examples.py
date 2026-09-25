from pathlib import Path
import subprocess

HERE = Path(__file__).parent


def svg(style, title, scene):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="960" height="600" viewBox="0 0 960 600" shape-rendering="crispEdges">
<title>{title}</title>
<desc>Визуальная проба стиля, не игра и не финальный арт.</desc>
<rect width="960" height="600" fill="#1f302b"/>
<rect x="0" y="0" width="760" height="600" fill="#789254"/>
<path d="M0 470L180 390 390 430 560 350 760 410V600H0Z" fill="#5c7547"/>
<path d="M0 80L150 20 330 80 500 25 760 100V220L570 180 370 230 160 180 0 230Z" fill="#879e5e"/>
<path d="M330 0h150v600H330z" fill="#697a4a"/>
<path d="M350 0h110v600H350z" fill="#c9ad70"/>
<path d="M365 0h80v600H365z" fill="#dfc687"/>
{scene}
<rect x="0" y="0" width="960" height="34" fill="#20362e"/>
<text x="18" y="23" fill="#f2e7c2" font-family="sans-serif" font-size="16" letter-spacing="2">ВИЗУАЛЬНАЯ ПРОБА · {style}</text>
<rect x="760" y="34" width="200" height="566" fill="#22382f"/>
<text x="780" y="70" fill="#f2e7c2" font-family="sans-serif" font-size="17">КАРТА</text>
<text x="780" y="94" fill="#a9be96" font-family="sans-serif" font-size="11">Текущая точка · 100 м</text>
<path d="M800 130v270" stroke="#6c8257" stroke-width="16"/><path d="M800 130v270" stroke="#e0c783" stroke-width="7"/>
<circle cx="800" cy="220" r="10" fill="#d86b59" stroke="#f5dfaa" stroke-width="3"/>
<g fill="#e8d5a2" font-family="sans-serif"><circle cx="800" cy="130" r="6"/><text x="820" y="135" font-size="13">Дом · 0 м</text><circle cx="800" cy="220" r="6"/><text x="820" y="225" font-size="13">Стинт · 100 м</text><circle cx="800" cy="305" r="6"/><text x="820" y="310" font-size="13">Братишкин · 189 м</text><circle cx="800" cy="400" r="6"/><text x="820" y="405" font-size="13">Озеро</text></g>
<text x="780" y="465" fill="#a9be96" font-family="sans-serif" font-size="11">Будущие места скрыты</text>
<text x="780" y="482" fill="#a9be96" font-family="sans-serif" font-size="11">до обнаружения.</text>
</svg>'''


def voxel():
    return '''<g stroke="#3a4938" stroke-width="4"><path d="M100 370l70-40 70 40-70 40z" fill="#b9a66e"/><path d="M100 370v65l70 40v-65z" fill="#877b57"/><path d="M240 370v65l-70 40v-65z" fill="#675e48"/><path d="M90 155h70v75H90z" fill="#486c45"/><path d="M160 155h70v75h-70z" fill="#36573d"/><path d="M125 105h70v70h-70z" fill="#5e824d"/></g><g fill="#c7b17a" stroke="#3a4938" stroke-width="4"><path d="M370 355h54v68h-54z"/><path d="M424 355h54v68h-54z"/><path d="M370 423h54v54h-54z"/><path d="M424 423h54v54h-54z"/></g><g fill="#d8c18b" stroke="#394438" stroke-width="4"><path d="M270 300h32v32h-32z"/><path d="M302 300h32v32h-32z"/><path d="M270 332h32v32h-32z"/><path d="M302 332h32v32h-32z"/><path d="M278 270h18v30h-18z"/><path d="M308 270h18v30h-18z"/></g><text x="80" y="540" fill="#eef0c4" font-family="sans-serif" font-size="18">Мир и кот из крупных блоков</text>'''


def lowpoly():
    return '''<g><path d="M80 380l80-55 90 45-84 58z" fill="#b7a36b"/><path d="M160 325v58l84-13v-45z" fill="#7f7753"/><path d="M80 380v58l80 39v-58z" fill="#95875b"/><path d="M105 120l54-34 65 28-55 39z" fill="#648c54"/><path d="M105 120v88l64 32v-87z" fill="#456d48"/><path d="M169 139l55-25v86l-55 30z" fill="#355c42"/><path d="M360 350l105-30 55 52-106 36z" fill="#bd9c63"/><path d="M360 350v64l54 30v-66z" fill="#7c694b"/><path d="M414 378l106-56v64l-106 58z" fill="#665741"/></g><g fill="#c7ae80" stroke="#384438" stroke-width="3"><path d="M275 330l28-16 30 16-28 16z"/><path d="M275 330v62l30 17v-63z"/><path d="M305 346l28-16v63l-28 16z"/><path d="M292 280l15-9 16 8-15 10z"/><path d="M292 289v41l16 8v-41z"/><path d="M308 289l15-10v41l-15 10z"/></g><text x="80" y="540" fill="#eef0c4" font-family="sans-serif" font-size="18">Угловатый low-poly 3D с пиксельной палитрой</text>'''


def sprite():
    return '''<g><path d="M80 380l80-55 90 45-84 58z" fill="#b7a36b"/><path d="M160 325v58l84-13v-45z" fill="#7f7753"/><path d="M80 380v58l80 39v-58z" fill="#95875b"/><path d="M105 120l54-34 65 28-55 39z" fill="#648c54"/><path d="M105 120v88l64 32v-87z" fill="#456d48"/><path d="M169 139l55-25v86l-55 30z" fill="#355c42"/><path d="M360 350l105-30 55 52-106 36z" fill="#bd9c63"/><path d="M360 350v64l54 30v-66z" fill="#7c694b"/><path d="M414 378l106-56v64l-106 58z" fill="#665741"/></g><g transform="translate(275 265)" stroke="#34392f" stroke-width="5"><path d="M20 40h44v90H20z" fill="#b7aa8d"/><path d="M8 40l12-35 22 19 22-19 12 35z" fill="#c0b394"/><path d="M20 130h16v35H20zM48 130h16v35H48z" fill="#b7aa8d"/><path d="M31 72h8v9h-8zm22 0h8v9h-8z" fill="#303d36"/><path d="M35 97h20" fill="none"/></g><text x="80" y="540" fill="#eef0c4" font-family="sans-serif" font-size="18">3D-мир + плоский 2D-спрайт кота</text>'''

examples = [("01-voxel.svg", "VOXEL / КУБИЧЕСКИЙ 3D", voxel()), ("02-lowpoly.svg", "LOW-POLY 3D · ПИКСЕЛЬНЫЕ ТЕКСТУРЫ", lowpoly()), ("03-sprite.svg", "3D-МИР · 2D-КОТ", sprite())]
for filename, title, scene in examples:
    path = HERE / filename
    path.write_text(svg(title, title, scene), encoding="utf-8")
    subprocess.run(["rsvg-convert", "-w", "1920", "-h", "1200", str(path), "-o", str(path.with_suffix(".png"))], check=True)
print("Built three style examples")
