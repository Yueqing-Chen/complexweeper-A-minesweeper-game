/* 从 assets/atlas.png 的 icon 槽位导出 AppImage 用的 PNG 图标。
   像素画按整数倍最近邻放大，不做平滑。
   用法: node tools/extract_icon.js <输出.png> [边长=256] */
const fs = require('fs');
const path = require('path');
const { readPNG, writePNG } = require('./png.js');

const [out, sizeArg] = process.argv.slice(2);
if (!out) { console.error('用法: node tools/extract_icon.js <输出.png> [边长=256]'); process.exit(2); }
const size = Number.parseInt(sizeArg || '256', 10);
if (!Number.isInteger(size) || size <= 0) { console.error('边长必须是正整数'); process.exit(2); }

const root = path.resolve(__dirname, '..');
const meta = JSON.parse(fs.readFileSync(path.join(root, 'assets', 'atlas.json'), 'utf8'));
const slot = meta.slots.find((s) => s.name === 'icon');
if (!slot) { console.error('assets/atlas.json 里没有 icon 槽位'); process.exit(3); }

const atlas = readPNG(path.join(root, 'assets', 'atlas.png'));
const outRGBA = Buffer.alloc(size * size * 4);
for (let y = 0; y < size; y++) {
  const sy = slot.y + Math.min(slot.h - 1, Math.floor(y * slot.h / size));
  for (let x = 0; x < size; x++) {
    const sx = slot.x + Math.min(slot.w - 1, Math.floor(x * slot.w / size));
    const s = (sy * atlas.w + sx) * 4;
    const d = (y * size + x) * 4;
    atlas.rgba.copy(outRGBA, d, s, s + 4);
  }
}
fs.mkdirSync(path.dirname(path.resolve(out)), { recursive: true });
const bytes = writePNG(out, size, size, outRGBA);
console.log(`图标：${out}（${size}×${size}，${bytes} 字节，源槽位 ${slot.w}×${slot.h}）`);
