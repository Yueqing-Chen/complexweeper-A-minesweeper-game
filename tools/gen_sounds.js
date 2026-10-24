/* 把 assets/sounds/ 里的 wav 打包成一个二进制（src/sounds.bin）+ 生成 Zig 侧的枚举与取用函数（src/sounds.zig）。
   容器格式（小端）：
     magic "CSSN"        4 字节
     u16 version = 1
     u16 count
     u32 data_off              数据区起点
     count 项：u32 off, u32 len, u32 rate, u16 bits, u16 ch, u32 ms   （每项 20 字节）
     数据区：每段 wav 的原始字节（含标准头，PlaySound 的 SND_MEMORY 要的就是这个）

   用法:
     node tools/gen_sounds.js                        # 从 assets/sounds/ 生成（默认）
     node tools/gen_sounds.js --extract <目录>       # 反向：把图里的音效导回成 wav 文件
   之所以能反向导出：这样仓库里只带 sounds.bin 也够用，谁想换音效就导出来改、再打包回去。 */
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');                // 项目根
const assetDir = path.join(root, 'assets', 'sounds');
const outDir = root;
const binPath = path.join(outDir, 'src', 'sounds.bin');
const zigPath = path.join(outDir, 'src', 'sounds.zig');

// 槽位顺序就是 Sounds 枚举的顺序，别随便调
const SLOTS = [
  { name: 'mine_1', file: '1_正实雷.wav', note: '正实雷' },
  { name: 'mine_2', file: '2_负实雷.wav', note: '负实雷' },
  { name: 'mine_3', file: '3_正虚雷.wav', note: '正虚雷' },
  { name: 'mine_4', file: '4_负虚雷.wav', note: '负虚雷' },
  { name: 'win', file: 'win.wav', note: '胜利' },
  { name: 'tick', file: 'tick.wav', note: '计时每秒一下' },
];

/* ---- 解析 wav 头，顺便做校验 ---- */
function parseWav(buf, file) {
  if (buf.length < 44) throw new Error(`${file} 太小，不像 wav`);
  if (buf.toString('ascii', 0, 4) !== 'RIFF') throw new Error(`${file} 不是 RIFF`);
  if (buf.toString('ascii', 8, 12) !== 'WAVE') throw new Error(`${file} 不是 WAVE`);
  let off = 12, fmt = null, dataLen = 0;
  while (off + 8 <= buf.length) {
    const id = buf.toString('ascii', off, off + 4);
    const size = buf.readUInt32LE(off + 4);
    const body = off + 8;
    if (id === 'fmt ') {
      fmt = {
        format: buf.readUInt16LE(body),
        channels: buf.readUInt16LE(body + 2),
        rate: buf.readUInt32LE(body + 4),
        bits: buf.readUInt16LE(body + 14),
      };
    } else if (id === 'data') {
      dataLen = Math.min(size, buf.length - body);
    }
    off = body + size + (size % 2); // 块按偶数字节对齐
  }
  if (!fmt) throw new Error(`${file} 没有 fmt 块`);
  if (fmt.format !== 1) throw new Error(`${file} 不是 PCM（format=${fmt.format}）`);
  if (!dataLen) throw new Error(`${file} 没有 data 块`);
  const bytesPerSec = fmt.rate * fmt.channels * (fmt.bits / 8);
  return { ...fmt, dataLen, ms: Math.round(dataLen / bytesPerSec * 1000) };
}

/* ---- 反向：把 bin 里的音效导回 wav ---- */
const exIdx = process.argv.indexOf('--extract');
if (exIdx >= 0) {
  const outDirArg = process.argv[exIdx + 1];
  if (!outDirArg) { console.error('用法: node tools/gen_sounds.js --extract <目录>'); process.exit(2); }
  const bin = fs.readFileSync(binPath);
  if (bin.toString('ascii', 0, 4) !== 'CSSN') { console.error('sounds.bin 魔数不对'); process.exit(3); }
  const count = bin.readUInt16LE(6), dataOff = bin.readUInt32LE(8);
  fs.mkdirSync(outDirArg, { recursive: true });
  const names = [];
  for (let i = 0; i < count; i++) {
    const e = 12 + i * 20; // 表紧跟在 12 字节文件头后面，不在数据区里
    const off = bin.readUInt32LE(e), len = bin.readUInt32LE(e + 4);
    const name = (SLOTS[i] && SLOTS[i].file) || `sound_${i}.wav`;
    fs.writeFileSync(path.join(outDirArg, name), bin.subarray(dataOff + off, dataOff + off + len));
    names.push(`${i} ${name}  ${len} 字节`);
  }
  console.log(`导出 ${count} 段到 ${outDirArg}`);
  names.forEach(n => console.log('  ' + n));
  process.exit(0);
}

/* ---- 正向：打包 ---- */
const sounds = SLOTS.map(s => {
  const p = path.join(assetDir, s.file);
  if (!fs.existsSync(p)) throw new Error('素材缺失：' + s.file);
  const buf = fs.readFileSync(p);
  return { ...s, buf, fmt: parseWav(buf, s.file) };
});

const dataOff = 12 + sounds.length * 20;
const header = Buffer.alloc(dataOff);
header.write('CSSN', 0, 'ascii');
header.writeUInt16LE(1, 4);
header.writeUInt16LE(sounds.length, 6);
header.writeUInt32LE(dataOff, 8);
let off = 0;
sounds.forEach((s, i) => {
  const e = 12 + i * 20;
  header.writeUInt32LE(off, e);
  header.writeUInt32LE(s.buf.length, e + 4);
  header.writeUInt32LE(s.fmt.rate, e + 8);
  header.writeUInt16LE(s.fmt.bits, e + 12);
  header.writeUInt16LE(s.fmt.channels, e + 14);
  header.writeUInt32LE(s.fmt.ms, e + 16);
  off += s.buf.length;
});
fs.mkdirSync(path.dirname(binPath), { recursive: true });
fs.writeFileSync(binPath, Buffer.concat([header, ...sounds.map(s => s.buf)]));

/* ---- 生成 sounds.zig ---- */
const lines = [];
lines.push('// 本文件由 tools/gen_sounds.js 自动生成，不要手改。');
lines.push('// 音效来自 assets/sounds/（四种踩雷 + 胜利 + 计时），原样内嵌。');
lines.push('');
lines.push('pub const blob = @embedFile("sounds.bin");');
lines.push('pub const count: u16 = ' + sounds.length + ';');
lines.push('');
lines.push('pub const Sounds = enum(u16) {');
sounds.forEach((s, i) => {
  lines.push(`    ${s.name} = ${i}, // ${s.note}  ${s.fmt.ms}ms  ${s.fmt.rate}Hz ${s.fmt.bits}bit ${s.fmt.channels}ch`);
});
lines.push('');
lines.push('    /// 四种雷的踩中音，下标 1..4 与 Game.mine 的类型编号一致');
lines.push('    pub fn mineOf(t: u8) Sounds {');
lines.push('        return switch (t) {');
lines.push('            1 => .mine_1,');
lines.push('            2 => .mine_2,');
lines.push('            3 => .mine_3,');
lines.push('            4 => .mine_4,');
lines.push('            else => .mine_1,');
lines.push('        };');
lines.push('    }');
lines.push('};');
lines.push('');
lines.push('/// 第 i 段音效的 wav 原始字节（含标准头，可直接交给 PlaySound 的 SND_MEMORY）');
lines.push('pub fn wav(i: usize) []const u8 {');
lines.push('    if (i >= count) return wav(0);');
lines.push('    const data_off: usize = 12 + count * 20;');
lines.push('    const e = 12 + i * 20;');
lines.push('    const off = readU32(e);');
lines.push('    const len = readU32(e + 4);');
lines.push('    return blob[data_off + off ..][0..len];');
lines.push('}');
lines.push('');
lines.push('fn readU32(at: usize) usize {');
lines.push('    return @as(usize, blob[at]) | (@as(usize, blob[at + 1]) << 8) |');
lines.push('        (@as(usize, blob[at + 2]) << 16) | (@as(usize, blob[at + 3]) << 24);');
lines.push('}');
lines.push('');
fs.mkdirSync(path.dirname(zigPath), { recursive: true });
fs.writeFileSync(zigPath, lines.join('\n'));

console.log(`音效: ${sounds.length} 段，bin ${fs.statSync(binPath).size} 字节`);
sounds.forEach((s, i) => {
  console.log(`  ${i} ${s.name.padEnd(7)} ${String(s.buf.length).padStart(6)} 字节  ${s.fmt.ms}ms  ${s.fmt.rate}Hz ${s.fmt.bits}bit ${s.fmt.channels}ch  ← ${s.file}`);
});
console.log('写出 ' + binPath);
console.log('写出 ' + zigPath);
