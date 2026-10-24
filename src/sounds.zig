// 本文件由 tools/gen_sounds.js 自动生成，不要手改。
// 音效来自 assets/sounds/（四种踩雷 + 胜利 + 计时），原样内嵌。

pub const blob = @embedFile("sounds.bin");
pub const count: u16 = 6;

pub const Sounds = enum(u16) {
    mine_1 = 0, // 正实雷  1164ms  22050Hz 8bit 1ch
    mine_2 = 1, // 负实雷  1164ms  22050Hz 8bit 1ch
    mine_3 = 2, // 正虚雷  1164ms  22050Hz 8bit 1ch
    mine_4 = 3, // 负虚雷  1164ms  22050Hz 8bit 1ch
    win = 4, // 胜利  1720ms  22050Hz 8bit 1ch
    tick = 5, // 计时每秒一下  60ms  22050Hz 8bit 1ch

    /// 四种雷的踩中音，下标 1..4 与 Game.mine 的类型编号一致
    pub fn mineOf(t: u8) Sounds {
        return switch (t) {
            1 => .mine_1,
            2 => .mine_2,
            3 => .mine_3,
            4 => .mine_4,
            else => .mine_1,
        };
    }
};

/// 第 i 段音效的 wav 原始字节（含标准头，可直接交给 PlaySound 的 SND_MEMORY）
pub fn wav(i: usize) []const u8 {
    if (i >= count) return wav(0);
    const data_off: usize = 12 + count * 20;
    const e = 12 + i * 20;
    const off = readU32(e);
    const len = readU32(e + 4);
    return blob[data_off + off ..][0..len];
}

fn readU32(at: usize) usize {
    return @as(usize, blob[at]) | (@as(usize, blob[at + 1]) << 8) |
        (@as(usize, blob[at + 2]) << 16) | (@as(usize, blob[at + 3]) << 24);
}
