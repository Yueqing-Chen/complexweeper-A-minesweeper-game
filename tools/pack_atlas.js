/* 把画好的单张 PNG 收进大图集（assets/atlas.png + atlas.json），并把整张图按种类重排。
   图集是唯一画布：既可以整张直接画，也可以把单张丢进 assets/hyperbolic-additions/ 让这个脚本收进去。

   单张图的命名：中文名（见下面 MAP）或者直接写槽位名，两种都认。
   落到图集里的排布按种类分段，段内从左到右、满一行换行，中间不留格线：
     数字（复数 num_* + 闵可夫斯基 hnum_*）
     格子（闭格/空白/旗/雷/踩中，含闵可夫斯基专用的 h*_3、h*_4）
     判定（标错雷/标对雷/标错空格/标对旗/标错旗）
     数码管（led_*）
     人脸（face_*）
     图标（icon）
   槽位名没在名单里的，接在最后一段，一张都不会丢。

   用法: node tools/pack_atlas.js [--dry] [--width 208] */
const fs = require('fs');
const path = require('path');
const { readPNG, writePNG } = require('./png.js');
const { VALUES } = require('./hyper_values.js');

const root = path.resolve(__dirname, '..');
const SHEET = path.join(root, 'assets', 'atlas.png');
const META = path.join(root, 'assets', 'atlas.json');
const LOOSE = path.join(root, 'assets', 'hyperbolic-additions');
const argv = process.argv.slice(2);
const dry = argv.includes('--dry');
const wi = argv.indexOf('--width');
const W = wi >= 0 ? Number(argv[wi + 1]) : 208;

/* 中文文件名 → 槽位名。h 前缀 = 闵可夫斯基模式专用（1/2 两种实雷两个模式共用，所以只有 3/4 有 h 版） */
const MAP = {
  正类时雷: 'hmine_3', 负类时雷: 'hmine_4',
  正类时旗: 'hflag_3', 负类时旗: 'hflag_4',
  踩中正类时雷: 'hboom_3', 踩中负类时雷: 'hboom_4',
  标错正类时雷: 'hwrong_3', 标错负类时雷: 'hwrong_4',
  标对正实雷: 'right_1', 标对负实雷: 'right_2', 标对正虚雷: 'right_3', 标对负虚雷: 'right_4',
  标对正类时雷: 'hright_3', 标对负类时雷: 'hright_4',
  标对正实旗: 'rightflag_1', 标对负实旗: 'rightflag_2', 标对正虚旗: 'rightflag_3', 标对负虚旗: 'rightflag_4',
  标对正类时旗: 'hrightflag_3', 标对负类时旗: 'hrightflag_4',
  标错正实旗: 'wrongflag_1', 标错负实旗: 'wrongflag_2', 标错正虚旗: 'wrongflag_3', 标错负虚旗: 'wrongflag_4',
  标错正类时旗: 'hwrongflag_3', 标错负类时旗: 'hwrongflag_4',
  标错空格子: 'wrongblank',
};
/* 改名前的叫法是「双曲雷 / 双曲旗」，磁盘上现存的单图文件名还是那一套，
   所以两种写法都收：不改文件名也能收进来，改成新名字也照样认。 */
for (const [k, v] of Object.entries(MAP)) {
  const alt = k.replace(/类时/g, '双曲');
  if (alt !== k && !MAP[alt]) MAP[alt] = v;
}

/* ---------- 读图集与单张 ---------- */
const meta = JSON.parse(fs.readFileSync(META, 'utf8'));
const sheet = readPNG(SHEET);
if (sheet.w !== meta.width || sheet.h !== meta.height) throw new Error('图集尺寸与 json 不符');
const byName = new Map(meta.slots.map((s) => [s.name, s]));
function slotPixels(s) {
  const buf = Buffer.alloc(s.w * s.h * 4);
  for (let r = 0; r < s.h; r++) sheet.rgba.copy(buf, r * s.w * 4, ((s.y + r) * sheet.w + s.x) * 4, ((s.y + r) * sheet.w + s.x + s.w) * 4);
  return buf;
}

let added = 0;
let replaced = 0;
const unmapped = [];
if (fs.existsSync(LOOSE)) {
  for (const f of fs.readdirSync(LOOSE).filter((n) => /\.png$/i.test(n)).sort()) {
    const base = f.replace(/\.png$/i, '');
    const name = MAP[base] || (byName.has(base) ? base : null);
    if (!name) { unmapped.push(f); continue; }
    const im = readPNG(path.join(LOOSE, f));
    if (!byName.has(name)) {
      meta.slots.push({ name, x: 0, y: 0, w: im.w, h: im.h });   // 位置由下面的重排决定
      byName.set(name, meta.slots[meta.slots.length - 1]);
      meta.slots[meta.slots.length - 1]._new = { w: im.w, h: im.h, rgba: im.rgba };
      added += 1;
      console.log(`  新增 ${f.padEnd(18)} → ${name}（${im.w}×${im.h}）`);
    } else {
      const s = byName.get(name);
      if (s.w !== im.w || s.h !== im.h) { console.log(`  跳过（尺寸不符）：${f} 是 ${im.w}×${im.h}，槽位要 ${s.w}×${s.h}`); continue; }
      s._new = { w: im.w, h: im.h, rgba: im.rgba };
      replaced += 1;
      console.log(`  替换 ${f.padEnd(18)} → ${name}`);
    }
  }
}
for (const u of unmapped) console.log(`  跳过（认不出槽位名）：${u}`);

/* ---------- 分段顺序 ---------- */
const ACHIEVABLE = [0, 1, 2, 4, 5, 8, 9, 10, 13, 16, 17, 18, 20, 25, 26, 29, 32, 34, 36, 37, 40, 49, 50, 64];
const numNames = ACHIEVABLE.map((D) => 'num_' + D).filter((n) => byName.has(n));
const hPos = VALUES.filter((v) => v.D > 0).sort((a, b) => a.D - b.D).map((v) => v.name);
const hNeg = VALUES.filter((v) => v.D < 0).sort((a, b) => b.D - a.D).map((v) => v.name);
const T = [1, 2, 3, 4];
const groups = [
  { title: '数字', names: [...numNames, ...hPos, ...hNeg] },
  { title: '格子', names: ['closed', 'blank', ...T.map((t) => 'flag_' + t), 'hflag_3', 'hflag_4',
                           ...T.map((t) => 'mine_' + t), 'hmine_3', 'hmine_4',
                           ...T.map((t) => 'boom_' + t), 'hboom_3', 'hboom_4'] },
  { title: '判定', names: [...T.map((t) => 'wrong_' + t), 'hwrong_3', 'hwrong_4',
                           ...T.map((t) => 'right_' + t), 'hright_3', 'hright_4', 'wrongblank',
                           ...T.map((t) => 'rightflag_' + t), 'hrightflag_3', 'hrightflag_4',
                           ...T.map((t) => 'wrongflag_' + t), 'hwrongflag_3', 'hwrongflag_4'] },
  { title: '数码管', names: ['led_blank', 'led_minus', ...Array.from({ length: 10 }, (_, i) => 'led_' + i), 'led_i', 'led_j'] },
  { title: '人脸', names: ['face_normal', 'face_down', 'face_scan', 'face_win', 'face_dead'] },
  { title: '图标', names: ['icon'] },
];
const named = new Set(groups.flatMap((g) => g.names));
const leftovers = meta.slots.map((s) => s.name).filter((n) => !named.has(n));
if (leftovers.length) groups.push({ title: '其它', names: leftovers });

/* ---------- 重排 ---------- */
const spot = new Map();
let y = 0;
const report = [];
for (const g of groups) {
  const present = g.names.filter((n) => byName.has(n));
  if (!present.length) continue;
  const y0 = y;
  let x = 0, rowH = 0, rows = 1;
  for (const n of present) {
    const s = byName.get(n);
    if (x + s.w > W) { y += rowH; x = 0; rowH = 0; rows += 1; }
    spot.set(n, { x, y });
    x += s.w;
    rowH = Math.max(rowH, s.h);
  }
  y += rowH;
  report.push(`${g.title}：${present.length} 张，y=${y0}..${y - 1}，${rows} 行`);
}
const NEW_H = y;

/* ---------- 画新画布 ---------- */
// 空白处保持全透明（作者现在就是这么画的：图集只留贴图，底子透明，看着干净）。
// 槽位里的透明像素由 gen_atlas.js 按底色补实，游戏走 GDI 不看 alpha。
const big = Buffer.alloc(W * NEW_H * 4);   // 全 0 = 全透明
for (const s of meta.slots) {
  const to = spot.get(s.name);
  if (!to) throw new Error('有槽位没排到：' + s.name);
  const px = s._new ? Buffer.from(s._new.rgba) : slotPixels(s);
  delete s._new;
  for (let r = 0; r < s.h; r++) px.copy(big, ((to.y + r) * W + to.x) * 4, r * s.w * 4, (r + 1) * s.w * 4);
  s.x = to.x;
  s.y = to.y;
}

/* ---------- 自检 ---------- */
let bad = 0;
for (const s of meta.slots) {
  if (s.x < 0 || s.y < 0 || s.x + s.w > W || s.y + s.h > NEW_H) { console.log('越界：' + s.name); bad += 1; }
}
for (let i = 0; i < meta.slots.length; i++) {
  for (let j = i + 1; j < meta.slots.length; j++) {
    const a = meta.slots[i], b = meta.slots[j];
    if (a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h) { console.log('重叠：' + a.name + ' × ' + b.name); bad += 1; }
  }
}
if (bad) throw new Error('排布有问题，没有写盘');

if (!dry) {
  writePNG(SHEET, W, NEW_H, big);
  meta.width = W;
  meta.height = NEW_H;
  fs.writeFileSync(META, JSON.stringify(meta, null, 2) + '\n', 'utf8');
}
console.log(`\n图集 ${SHEET.replace(root, '')}：${sheet.w}×${sheet.h} → ${W}×${NEW_H}，${meta.slots.length} 个槽位（新增 ${added}、替换 ${replaced}）${dry ? '（--dry 没写盘）' : ''}`);
for (const r of report) console.log('  ' + r);
