/* 闵可夫斯基模式（j² = +1）的 39 个显示值，以及每个值对应的贴图槽位名。
   约束 |a| + |b| ≤ 8（8 邻域最多八颗雷），显示值 D = a² − b²，取值 −64 … 64。
   负数（D < 0）按规则显示成"根式 + i 单位"：−4 → 2i、−7 → √7i。

   约定：贴图名 = hnum_<|D|>（D ≥ 0）/ hnum_<|D|>_i（D < 0），和圆复数模式的 num_<D> 同一个路子。
   这份枚举与双曲复数模式设计文档里的逐值对照表是同一个来源；Zig 那边的自检会自己再枚举一遍
   495 种邻域组合作交叉核对，所以这里写错会被构建挡住。 */
'use strict';

/** 最简根式：12 → 2√3，9 → 3，7 → √7 */
function radicalText(n) {
  for (let k = 8; k >= 2; k--) {
    if (n % (k * k) === 0) {
      const r = n / (k * k);
      return k + (r === 1 ? '' : '√' + r);
    }
  }
  return '√' + n;
}

/** 39 个显示值：{ D, name, text }，按 D 升序 */
const VALUES = (() => {
  const Ds = new Set();
  for (let a = 0; a <= 8; a++) for (let b = 0; b <= 8 - a; b++) Ds.add(a * a - b * b);
  return [...Ds].sort((x, y) => x - y).map((D) => {
    if (D === 0) return { D, name: 'hnum_0', text: '0' };
    const mag = Math.abs(D) === 1 ? '1' : radicalText(Math.abs(D));
    return {
      D,
      name: 'hnum_' + Math.abs(D) + (D < 0 ? '_i' : ''),
      text: D < 0 ? (D === -1 ? 'i' : mag + 'i') : mag,
    };
  });
})();

if (VALUES.length !== 39) throw new Error('闵可夫斯基模式的显示值应是 39 个，实得 ' + VALUES.length);

module.exports = { VALUES, HYPER_Ds: VALUES.map((v) => v.D), radicalText };
