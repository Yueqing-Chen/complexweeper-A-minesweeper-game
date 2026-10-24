/* 素材导出的验收脚本（素材只有整图这一种来源）：
     1) src/atlas.bin 的矩形表必须与 assets/atlas.json 完全一致（防"改了素材没重建"）
     2) src/atlas.bin 的像素必须与 assets/atlas.png 逐像素一致（防"图集是用旧大图建的"）
     3) 导出的散图（build/asset-export/sprites/*.png）必须与图集逐像素一致（防导出写坏）
   用法: node tools/check_export.js [导出目录] [图集文件]
   默认: build/asset-export 与 src/atlas.bin。退出码 0 = 全部一致 */
const fs = require('fs');
const path = require('path');
const { readPNG, diffRGBA } = require('./png.js');

const root = path.join(__dirname, '..');
const assetsDir = path.join(root, 'assets');
const SHEET_PNG = path.join(assetsDir, 'atlas.png');
const SHEET_JSON = path.join(assetsDir, 'atlas.json');
const OUT = process.argv[2] || path.join(root, 'build', 'asset-export');
const ATLAS = process.argv[3] || path.join(root, 'src', 'atlas.bin');

let bad = 0;
const fail = (msg) => { console.log(msg); bad++; };

/* ---- 读图集 ---- */
const bin = fs.readFileSync(ATLAS);
const at = bin.indexOf('CSAT', 0, 'ascii');
if (at < 0) { console.error('找不到图集魔数 CSAT：' + ATLAS); process.exit(2); }
const count = bin.readUInt16LE(at + 6), W = bin.readUInt16LE(at + 8), H = bin.readUInt16LE(at + 10);
const pix = at + 12 + count * 8;
const atlas = Buffer.alloc(W * H * 4);
for (let i = 0; i < W * H; i++) {
  atlas[i * 4] = bin[pix + i * 4 + 2]; atlas[i * 4 + 1] = bin[pix + i * 4 + 1];
  atlas[i * 4 + 2] = bin[pix + i * 4]; atlas[i * 4 + 3] = bin[pix + i * 4 + 3];
}
const rects = [];
for (let i = 0; i < count; i++) {
  const o = at + 12 + i * 8;
  rects.push({ i, x: bin.readUInt16LE(o), y: bin.readUInt16LE(o + 2), w: bin.readUInt16LE(o + 4), h: bin.readUInt16LE(o + 6) });
}
const crop = (buf, bw, r) => {
  const out = Buffer.alloc(r.w * r.h * 4);
  for (let y = 0; y < r.h; y++) buf.copy(out, y * r.w * 4, ((r.y + y) * bw + r.x) * 4, ((r.y + y) * bw + r.x + r.w) * 4);
  return out;
};

/* ---- 1) 矩形表 vs assets/atlas.json ---- */
const meta = JSON.parse(fs.readFileSync(SHEET_JSON, 'utf8'));
if (meta.width !== W || meta.height !== H) fail(`尺寸不一致：图集 ${W}×${H}，assets/atlas.json ${meta.width}×${meta.height}`);
if (meta.slots.length !== count) fail(`槽位数量不一致：图集 ${count}，assets/atlas.json ${meta.slots.length}`);
meta.slots.forEach((s, i) => {
  const r = rects[i];
  if (!r) return;
  if (s.name === undefined || s.x !== r.x || s.y !== r.y || s.w !== r.w || s.h !== r.h) {
    fail(`第 ${i} 个槽位与图集不符：json ${s.name} (${s.x},${s.y} ${s.w}×${s.h}) vs 图集 (${r.x},${r.y} ${r.w}×${r.h})`);
  }
});

/* ---- 2) 图集像素 vs assets/atlas.png ---- */
const sheet = readPNG(SHEET_PNG);
if (sheet.w !== W || sheet.h !== H) fail(`assets/atlas.png 尺寸与图集不符：${sheet.w}×${sheet.h} vs ${W}×${H}`);
else {
  // 复刻 gen_atlas.js 的规则：除 icon 外，槽位内 alpha<255 的像素按 #C0C0C0 补实；
  // 槽位外一律保持透明。直接拿原图逐像素比会把这条已知变换误报成"素材不一致"。
  const expected = Buffer.from(sheet.rgba);
  const inside = new Uint8Array(W * H);
  meta.slots.forEach((s, i) => {
    const r = rects[i];
    if (!r) return;
    for (let y = r.y; y < r.y + r.h; y++) for (let x = r.x; x < r.x + r.w; x++) {
      inside[y * W + x] = 1;
      if (s.name === 'icon') continue;
      const o = (y * W + x) * 4;
      const a = expected[o + 3];
      if (a >= 255) continue;
      const t = a / 255;
      expected[o] = Math.round(expected[o] * t + 192 * (1 - t));
      expected[o + 1] = Math.round(expected[o + 1] * t + 192 * (1 - t));
      expected[o + 2] = Math.round(expected[o + 2] * t + 192 * (1 - t));
      expected[o + 3] = 255;
    }
  });
  let outside = 0;
  for (let i = 0; i < W * H; i++) {
    if (inside[i]) continue;
    if (atlas[i * 4] || atlas[i * 4 + 1] || atlas[i * 4 + 2] || atlas[i * 4 + 3]) outside++;
  }
  if (outside) fail(`图集槽位外有 ${outside} 个非透明像素（应全部透明）`);
  const d = diffRGBA(expected, atlas);
  if (d.n) fail(`图集与 assets/atlas.png 不一致（${d.n} 像素，最大差 ${d.worst}）—— 多半是改了素材没重建`);
}

/* ---- 3) 导出散图 vs 图集 ---- */
let checked = 0;
const listingPath = path.join(OUT, 'sprites.txt');
if (fs.existsSync(listingPath)) {
  for (const line of fs.readFileSync(listingPath, 'utf8').trim().split(/\r?\n/)) {
    const m = /^(\d+)\s+(\S+)\s+(\d+)×(\d+)\s+@\(\s*(\d+),\s*(\d+)\)$/.exec(line.trim());
    if (!m) { fail('解析不了这行: ' + line); continue; }
    const [, idx, name, w0, h0, x0, y0] = m;
    const r = rects[Number(idx)];
    if (!r) { fail(`导出清单里有不存在的槽位号 ${idx}`); continue; }
    if (Number(w0) !== r.w || Number(h0) !== r.h || Number(x0) !== r.x || Number(y0) !== r.y) { fail(`尺寸/位置对不上: ${name}`); continue; }
    const im = readPNG(path.join(OUT, 'sprites', name + '.png'));
    if (im.w !== r.w || im.h !== r.h) { fail(`导出散图尺寸不对: ${name}`); continue; }
    const d = diffRGBA(crop(atlas, W, r), im.rgba);
    checked++;
    if (d.n) fail(`导出散图与图集不一致: ${name}（${d.n} 像素）`);
  }
} else {
  console.log(`（没有 ${listingPath}，跳过散图核对；跑一次 tools/dump_atlas.js 就有了）`);
}

console.log(`矩形表核对 ${meta.slots.length} 项，像素核对 1 张整图 + ${checked} 张散图，问题 ${bad} 处`);
process.exit(bad ? 1 : 0);
