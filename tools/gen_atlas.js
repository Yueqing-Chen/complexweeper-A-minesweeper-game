/* 把 assets/ 里的 PNG 打包成一个图集（atlas.bin）+ 生成 Zig 侧的索引表（src/assets.zig）。
   图集格式（小端）：
     magic  "CSAT"      4 字节
     u16 version = 1
     u16 count
     u16 width, u16 height
     count 项：u16 x, u16 y, u16 w, u16 h
     像素数据：width*height*4 字节，BGRA8（GDI 的 32bpp DIB 顺序），行内自顶向下
   素材只有这一种来源：assets/atlas.png + assets/atlas.json（槽位名 → 矩形，数组顺序就是槽位号）。
   早期那套"61 张单张 PNG 按文件名映射后货架打包"的做法已作废：改素材就直接改那张大图，
   槽位表用 tools/dump_atlas.js 生成/维护；放大交给程序做整数倍最近邻（素材只保留原生尺寸）。
   这里只做校验：名字不重、矩形不越界、24 个显示值贴图齐不齐。

   用法: node tools/gen_atlas.js [--out-bin 路径] [--out-zig 路径] */
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const { VALUES: HYPER_VALUES } = require('./hyper_values.js');

const root = path.resolve(__dirname, '..');                // 项目根
const assetDir = path.join(root, 'assets');
const outDir = root;
const argv = process.argv.slice(2);
const argValue = (name) => { const i = argv.indexOf(name); return i >= 0 ? argv[i + 1] : null; };
const binPath = argValue('--out-bin') ? path.resolve(argValue('--out-bin')) : path.join(outDir, 'src', 'atlas.bin');
const zigPath = argValue('--out-zig') ? path.resolve(argValue('--out-zig')) : path.join(outDir, 'src', 'assets.zig');
const PACKED_PNG = path.join(assetDir, 'atlas.png');
const PACKED_JSON = path.join(assetDir, 'atlas.json');
// 黑白贴图（可选）：同一套尺寸与槽位，只是画成黑白。作者可以单独画一张放这儿
const BW_PNG = path.join(assetDir, 'atlas-bw.png');
const BW_BIN = path.join(outDir, 'src', 'atlas-bw.bin');

/* ---------------- 最小 PNG 解码（够用即可：支持 8 位 RGBA / RGB / 调色板） ---------------- */
function readPNG(file){
  const buf = fs.readFileSync(file);
  let off = 8, w = 0, h = 0, bitDepth = 0, colorType = 0, interlace = 0;
  const idat = []; let palette = null, trns = null;
  while (off < buf.length){
    const len = buf.readUInt32BE(off);
    const type = buf.toString('ascii', off + 4, off + 8);
    const data = buf.subarray(off + 8, off + 8 + len);
    if (type === 'IHDR'){
      w = data.readUInt32BE(0); h = data.readUInt32BE(4);
      bitDepth = data[8]; colorType = data[9]; interlace = data[12];
    } else if (type === 'PLTE') palette = Buffer.from(data);
    else if (type === 'tRNS') trns = Buffer.from(data);
    else if (type === 'IDAT') idat.push(Buffer.from(data));
    else if (type === 'IEND') break;
    off += 12 + len;
  }
  if (bitDepth !== 8) throw new Error(file + ': 只支持 8 位色深，实际 ' + bitDepth);
  if (interlace) throw new Error(file + ': 不支持隔行扫描');
  const channels = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[colorType];
  if (!channels) throw new Error(file + ': 不支持的颜色类型 ' + colorType);
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = w * channels;
  const out = Buffer.alloc(stride * h);
  let pos = 0;
  for (let y = 0; y < h; y++){
    const ft = raw[pos++];
    const line = raw.subarray(pos, pos + stride); pos += stride;
    const cur = out.subarray(y * stride, (y + 1) * stride);
    const prev = y > 0 ? out.subarray((y - 1) * stride, y * stride) : Buffer.alloc(stride);
    for (let i = 0; i < stride; i++){
      const a = i >= channels ? cur[i - channels] : 0, b = prev[i], c = i >= channels ? prev[i - channels] : 0;
      let v = line[i];
      if (ft === 1) v += a; else if (ft === 2) v += b; else if (ft === 3) v += (a + b) >> 1;
      else if (ft === 4){ const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
        v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c); }
      cur[i] = v & 0xff;
    }
  }
  // 统一成 RGBA
  const rgba = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++){
    const s = y * stride + x * channels, d = (y * w + x) * 4;
    if (colorType === 6) { rgba[d] = out[s]; rgba[d+1] = out[s+1]; rgba[d+2] = out[s+2]; rgba[d+3] = out[s+3]; }
    else if (colorType === 2) { rgba[d] = out[s]; rgba[d+1] = out[s+1]; rgba[d+2] = out[s+2]; rgba[d+3] = 255; }
    else if (colorType === 0) { rgba[d] = rgba[d+1] = rgba[d+2] = out[s]; rgba[d+3] = 255; }
    else if (colorType === 4) { rgba[d] = rgba[d+1] = rgba[d+2] = out[s]; rgba[d+3] = out[s+1]; }
    else { const i = out[s]; rgba[d] = palette[i*3]; rgba[d+1] = palette[i*3+1]; rgba[d+2] = palette[i*3+2];
           rgba[d+3] = trns && i < trns.length ? trns[i] : 255; }
  }
  return { w, h, rgba };
}

/* ---------------- 素材来源：assets/atlas.png + assets/atlas.json（唯一来源） ---------------- */
const ACHIEVABLE = [0,1,2,4,5,8,9,10,13,16,17,18,20,25,26,29,32,34,36,37,40,49,50,64];
if (!fs.existsSync(PACKED_PNG) || !fs.existsSync(PACKED_JSON)) {
  throw new Error('缺少 assets/atlas.png 或 assets/atlas.json —— 素材只有这一种来源（散图模式已作废）');
}

let W, H, placed;
const meta = JSON.parse(fs.readFileSync(PACKED_JSON, 'utf8'));
if (meta.version !== 1) throw new Error('atlas.json 的 version 不认识：' + meta.version);
W = meta.width; H = meta.height;
const sheet = readPNG(PACKED_PNG);
if (sheet.w !== W || sheet.h !== H) throw new Error(`整图尺寸与 json 不符：png ${sheet.w}×${sheet.h}，json ${W}×${H}`);
const seen = new Set();
placed = meta.slots.map((s, i) => {
  if (!s || typeof s.name !== 'string' || !s.name) throw new Error('第 ' + i + ' 个槽位没有名字');
  if (seen.has(s.name)) throw new Error('槽位重名：' + s.name);
  seen.add(s.name);
  if (!(s.w > 0) || !(s.h > 0) || s.x < 0 || s.y < 0 || s.x + s.w > W || s.y + s.h > H) {
    throw new Error(`槽位越界或尺寸非法：${s.name} (${s.x},${s.y} ${s.w}×${s.h})`);
  }
  const rgba = Buffer.alloc(s.w * s.h * 4);
  for (let ry = 0; ry < s.h; ry++) {
    sheet.rgba.copy(rgba, ry * s.w * 4, ((s.y + ry) * W + s.x) * 4, ((s.y + ry) * W + s.x + s.w) * 4);
  }
  return { name: s.name, x: s.x, y: s.y, w: s.w, h: s.h, im: { w: s.w, h: s.h, rgba } };
});
for (const D of ACHIEVABLE) if (!seen.has('num_' + D)) throw new Error('整图里缺少 D=' + D + ' 的贴图（num_' + D + '）');
const numCount = [...seen].filter(n => /^num_\d+$/.test(n)).length;
if (numCount !== ACHIEVABLE.length) throw new Error('整图里的数字贴图数量不对：' + numCount);
// 闵可夫斯基模式的显示值：显示文本与圆复数模式不同的那 27 个各有一张自己的贴图（hnum_*）；
// 文本相同的 12 个（0 1 2 √5 2√2 3 4 5 4√2 6 7 8）直接复用圆复数模式的 num_<D>，
// 图集里不为它们另留槽位——少一份重复素材，也就少一处要同步的地方。
const hyperSprite = new Map();   // D -> 贴图槽位名
for (const v of HYPER_VALUES) {
  if (seen.has(v.name)) {
    hyperSprite.set(v.D, v.name);
  } else if (v.D >= 0 && ACHIEVABLE.includes(v.D)) {
    hyperSprite.set(v.D, 'num_' + v.D);
  } else {
    throw new Error(`整图里缺少闵可夫斯基模式 ${v.D}（${v.text}）的贴图（${v.name}），也没有可复用的 num_*`);
  }
}
for (const n of ['led_i', 'led_j']) if (!seen.has(n)) throw new Error('整图里缺少计雷器单位贴图（' + n + '）');
const reuseCount = [...hyperSprite.values()].filter((n) => n.startsWith('num_')).length;
console.log(`素材来源：整图（atlas.png + atlas.json，${placed.length} 个槽位，${W}×${H}）`);
console.log(`闵可夫斯基模式 39 个显示值：自带贴图 ${hyperSprite.size - reuseCount} 张 + 复用圆复数模式 ${reuseCount} 张`);

// 占位图提醒：新增区的占位素材字色是紫红 160,0,160（见双曲复数模式设计文档）。真素材里不会出现它，
// 所以哪一格还带着这个颜色，就是"还没画"。这里只提醒、不拦构建。
const PLACEHOLDER = [160, 0, 160];
const pending = [];
for (const [name, im] of placed.map((p) => [p.name, p.im])) {
  if (!/^hnum_|^led_j$/.test(name)) continue;
  for (let i = 0; i < im.rgba.length; i += 4) {
    if (im.rgba[i] === PLACEHOLDER[0] && im.rgba[i + 1] === PLACEHOLDER[1] && im.rgba[i + 2] === PLACEHOLDER[2]) {
      pending.push(name);
      break;
    }
  }
}
console.log(pending.length
  ? `还差 ${pending.length} 张是占位图（紫红 160,0,160）：${pending.join(' ')}\n` +
    '（计雷器的 led_j 是照 led_i 改的红色 j，不带紫红，所以不在上面这份名单里，要单独看）'
  : '闵可夫斯基模式的新增贴图已经全是真素材了 ✓（led_j 也确认一下：它是红色 j，不带紫红）');

const pix = Buffer.alloc(W * H * 4);      // 0 = 透明黑
// 计时/计数的 LED 素材里，"未点亮的段"是用 128,0,0 与黑交替点阵画出来的（半色调虚段）。
// 13×23 原尺寸下看着像淡淡的残影，但游戏里贴图要放大到 2×/3×，每个点变成 2×2/3×3 的方块，
// 整块数字就变成一片噪点、像被压扁了。这里把虚段的暗红像素抹成黑，只留点亮的段，
// 放大后就是干净的经典 LED。想保留虚段效果把这一行改成 false。
const CLEAN_LED_GHOST_SEGMENTS = false;
// 游戏贴图走 GDI（BitBlt），**不看 alpha**，槽位里透明的地方就按它自己的 RGB 画出来
// （编辑器擦掉一个像素通常留下 0,0,0,0 → 屏幕上就是一颗黑点）。所以除图标外，
// 槽位内凡是 alpha < 255 的像素一律按底色 #C0C0C0 补实；图集空白处保持透明不影响游戏，
// 作者只保证"槽位矩形里的画是完整的"就够了。
let healed = 0;
const healedSlots = new Map();
for (const p of placed){
  const is_led = CLEAN_LED_GHOST_SEGMENTS && p.name.startsWith('led_');
  for (let ry = 0; ry < p.h; ry++){
    for (let rx = 0; rx < p.w; rx++){
      const s = (ry * p.w + rx) * 4, d = ((p.y + ry) * W + (p.x + rx)) * 4;
      let r = p.im.rgba[s], g = p.im.rgba[s + 1], b = p.im.rgba[s + 2];
      let a = p.im.rgba[s + 3];
      if (is_led && r > 40 && r < 200 && g < 40 && b < 40){ r = 0; g = 0; b = 0; }
      if (p.name !== 'icon' && a < 255){
        const t = a / 255;
        r = Math.round(r * t + 192 * (1 - t));
        g = Math.round(g * t + 192 * (1 - t));
        b = Math.round(b * t + 192 * (1 - t));
        a = 255;
        healed += 1;
        healedSlots.set(p.name, (healedSlots.get(p.name) || 0) + 1);
      }
      pix[d]     = b;                     // B
      pix[d + 1] = g;                     // G
      pix[d + 2] = r;                     // R
      pix[d + 3] = a;                     // A
    }
  }
}
if (healed) {
  const list = [...healedSlots].map(([n, c]) => n + '×' + c).join(' ');
  console.log(`槽位里的透明像素按底色补实了 ${healed} 个：${list}（GDI 不看 alpha，不补会画成黑点）`);
}

/* ---------------- 黑白贴图（灰度，1 字节/像素） ---------------- */
/* 作者可以画一张同尺寸的黑白图集；没画或者导出成空图，就退回"把彩色图集去饱和"。
   去饱和用 Rec.601 亮度公式；槽位内 alpha<255 的像素按底色 192 补实（和彩色图集同一条规则）。 */
const grayOf = (r, g, b) => Math.round(0.299 * r + 0.587 * g + 0.114 * b);
let bwGray = new Uint8Array(W * H);
let bwSource = '去饱和（彩色图集）';
{
  let custom = null;
  if (fs.existsSync(BW_PNG)) {
    const im = readPNG(BW_PNG);
    if (im.w !== W || im.h !== H) throw new Error(`atlas-bw.png 尺寸不对：${im.w}×${im.h}，应为 ${W}×${H}`);
    let opaque = 0;
    for (let i = 0; i < im.w * im.h; i++) if (im.rgba[i * 4 + 3] > 0) opaque += 1;
    if (opaque > 0) custom = im;
    else console.log('atlas-bw.png 整张是全透明的空图（0 个不透明像素）→ 这次先退回"彩色图集去饱和"，请重新导出');
  } else {
    console.log('没有 atlas-bw.png → 黑白贴图由彩色图集去饱和生成');
  }
  for (const p of placed) {
    for (let ry = 0; ry < p.h; ry++) {
      for (let rx = 0; rx < p.w; rx++) {
        const o = (ry * p.w + rx) * 4;
        let r = p.im.rgba[o], g = p.im.rgba[o + 1], b = p.im.rgba[o + 2];
        let a = p.im.rgba[o + 3];
        if (custom) {
          const q = ((p.y + ry) * custom.w + (p.x + rx)) * 4;
          r = custom.rgba[q]; g = custom.rgba[q + 1]; b = custom.rgba[q + 2]; a = custom.rgba[q + 3];
        }
        if (p.name !== 'icon' && a < 255) {           // 和彩色图集一样：槽位内的透明按底色补实
          const t = a / 255;
          r = Math.round(r * t + 192 * (1 - t));
          g = Math.round(g * t + 192 * (1 - t));
          b = Math.round(b * t + 192 * (1 - t));
        }
        bwGray[(p.y + ry) * W + (p.x + rx)] = grayOf(r, g, b);
      }
    }
  }
  if (custom) bwSource = 'atlas-bw.png';
  const head = Buffer.alloc(12);
  head.write('CSBW', 0, 'ascii');
  head.writeUInt16LE(1, 4);
  head.writeUInt16LE(W, 6);
  head.writeUInt16LE(H, 8);
  head.writeUInt16LE(bwGray.length & 0xffff, 10);
  fs.writeFileSync(BW_BIN, Buffer.concat([head, Buffer.from(bwGray)]));
  console.log(`黑白贴图：来源 ${bwSource}，灰度 ${W}×${H}，bin ${fs.statSync(BW_BIN).size} 字节`);
}

/* ---------------- 写出 atlas.bin ---------------- */
const header = Buffer.alloc(12 + placed.length * 8);
header.write('CSAT', 0, 'ascii');
header.writeUInt16LE(1, 4);
header.writeUInt16LE(placed.length, 6);
header.writeUInt16LE(W, 8);
header.writeUInt16LE(H, 10);
placed.forEach((p, i) => {
  const o = 12 + i * 8;
  header.writeUInt16LE(p.x, o); header.writeUInt16LE(p.y, o + 2);
  header.writeUInt16LE(p.w, o + 4); header.writeUInt16LE(p.h, o + 6);
});
fs.mkdirSync(path.dirname(binPath), { recursive: true });
fs.writeFileSync(binPath, Buffer.concat([header, pix]));

/* ---------------- 写出 src/assets.zig ---------------- */
const idx = new Map(placed.map((p, i) => [p.name, i]));
const lines = [];
lines.push('// 本文件由 tools/gen_atlas.js 自动生成，不要手改。');
lines.push('// 图集来自 assets/ 目录，格式见 tools/gen_atlas.js 顶部注释。');
lines.push('');
lines.push('pub const blob = @embedFile("atlas.bin");');
lines.push('/// 黑白贴图（灰度，1 字节/像素，格式 CSBW）：\"颜色\"关掉时用它');
lines.push('pub const blob_bw = @embedFile("atlas-bw.bin");');
lines.push('pub const atlas_w: u16 = ' + W + ';');
lines.push('pub const atlas_h: u16 = ' + H + ';');
lines.push('pub const count: u16 = ' + placed.length + ';');
lines.push('');
lines.push('pub const Rect = struct { x: u16, y: u16, w: u16, h: u16 };');
lines.push('pub const rects = [_]Rect{');
placed.forEach((p, i) => {
  lines.push('    .{ .x = ' + p.x + ', .y = ' + p.y + ', .w = ' + p.w + ', .h = ' + p.h + ' }, // ' + i + ' ' + p.name);
});
lines.push('};');
lines.push('');
lines.push('pub fn rect(i: u16) Rect {');
lines.push('    return rects[i];');
lines.push('}');
lines.push('');
for (const [name, i] of idx) lines.push('pub const ' + name + ': u16 = ' + i + ';');
lines.push('');
lines.push('/// 显示值 D = |S|^2 -> 数字贴图（圆复数模式）；表外为 0xFFFF（不该出现）');
lines.push('pub const num_by_D = blk: {');
lines.push('    var t = [_]u16{0xFFFF} ** 65;');
for (const D of ACHIEVABLE) lines.push('    t[' + D + '] = num_' + D + ';');
lines.push('    break :blk t;');
lines.push('};');
lines.push('');
lines.push('/// 显示值 D = a^2 - b^2（-64 … 64）-> 数字贴图（闵可夫斯基模式）；');
lines.push('/// 下标是 D + 64，表外为 0xFFFF（不该出现）。39 个值的来历见 tools/hyper_values.js，');
lines.push('/// 其中显示文本与圆复数模式相同的 12 个直接指向 num_<D>（不重复出图）。');
lines.push('pub const hnum_by_D = blk: {');
lines.push('    var t = [_]u16{0xFFFF} ** 129;');
for (const v of HYPER_VALUES) lines.push('    t[' + (v.D + 64) + '] = ' + hyperSprite.get(v.D) + '; // ' + v.D + ' → ' + v.text);
lines.push('    break :blk t;');
lines.push('};');
lines.push('');

/* 每种雷（1..4）在各模式下的贴图。1/2 是两种实雷（闵可夫斯基模式下叫类空雷），两个模式共用贴图；
   3/4 在圆复数模式是 ±虚雷、在闵可夫斯基模式是 ±闵可夫斯基雷，各画各的（h 前缀 = 闵可夫斯基专用）。
   判定那几张（标对/标错）还没画全的，先退回已有贴图，画好丢进图集就自动接上。 */
const T4 = [1, 2, 3, 4];
const has = (n) => seen.has(n);
const pickSlot = (...names) => names.find(has);
const FAMILIES = [
  { name: 'mine', c: ['mine_1', 'mine_2', 'mine_3', 'mine_4'], h: ['mine_1', 'mine_2', 'hmine_3', 'hmine_4'], why: '雷' },
  { name: 'flag', c: ['flag_1', 'flag_2', 'flag_3', 'flag_4'], h: ['flag_1', 'flag_2', 'hflag_3', 'hflag_4'], why: '旗' },
  { name: 'boom', c: ['boom_1', 'boom_2', 'boom_3', 'boom_4'], h: ['boom_1', 'boom_2', 'hboom_3', 'hboom_4'], why: '踩中雷' },
  { name: 'wrong', c: ['wrong_1', 'wrong_2', 'wrong_3', 'wrong_4'], h: ['wrong_1', 'wrong_2', 'hwrong_3', 'hwrong_4'], why: '标错雷' },
  { name: 'right', c: ['right_1', 'right_2', 'right_3', 'right_4'], h: ['right_1', 'right_2', 'hright_3', 'hright_4'], why: '标对雷' },
  { name: 'rightflag', c: ['rightflag_1', 'rightflag_2', 'rightflag_3', 'rightflag_4'], h: ['rightflag_1', 'rightflag_2', 'hrightflag_3', 'hrightflag_4'], fb: ['flag_1', 'flag_2', 'flag_3', 'flag_4'], why: '标对旗' },
  { name: 'wrongflag', c: ['wrongflag_1', 'wrongflag_2', 'wrongflag_3', 'wrongflag_4'], h: ['wrongflag_1', 'wrongflag_2', 'hwrongflag_3', 'hwrongflag_4'], fb: ['wrong_1', 'wrong_2', 'wrong_3', 'wrong_4'], why: '标错旗' },
];
const usingFallback = [];   // 还没画、先退回上一档的那些"槽位名"（就是作者要补的清单）
for (const f of FAMILIES) {
  for (const [prefix, list] of [['', f.c], ['h', f.h]]) {
    const slots = T4.map((t, k) => pickSlot(list[k], f.fb && f.fb[k]));
    slots.forEach((s, k) => { if (s && f.fb && list[k] !== s && !has(list[k])) usingFallback.push(list[k]); });
    const missing = slots.some((s) => !s);
    if (missing) throw new Error(`${f.why}贴图缺得太多（${prefix}${f.name}_*），图集里连可退回的都没有`);
    lines.push(`/// ${f.why}：下标是雷的类型（1 正实雷·正类空雷 / 2 负实雷·负类空雷 / 3 正虚雷·正双曲虚雷 / 4 负虚雷·负双曲虚雷），0 空着`);
    lines.push(`pub const ${prefix}${f.name}_T = [5]u16{ 0, ${slots.join(', ')} };`);
  }
}
lines.push('');
const wb = pickSlot('wrongblank', 'blank');
lines.push('/// 标错空格子：给不是雷的格子插了旗，失败后显示它（画好之前先退回空白格）');
lines.push('pub const wrongblank_sprite: u16 = ' + wb + ';');
if (usingFallback.length) {
  const uniq = [...new Set(usingFallback)];
  console.log(`判定贴图还没画（先退回上一档）：${uniq.join(' ')} —— 画好丢进图集就自动接上`);
}
fs.mkdirSync(path.dirname(zigPath), { recursive: true });
fs.writeFileSync(zigPath, lines.join('\n') + '\n');

const total = placed.reduce((a, p) => a + p.w * p.h, 0);
console.log('图集: ' + W + 'x' + H + '，' + placed.length + ' 张，' +
  '像素 ' + total + '，bin ' + (fs.statSync(binPath).size) + ' 字节');
console.log('写出 ' + binPath);
console.log('写出 ' + zigPath);
