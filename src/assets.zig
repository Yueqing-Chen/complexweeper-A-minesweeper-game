// 本文件由 tools/gen_atlas.js 自动生成，不要手改。
// 图集来自 assets/ 目录，格式见 tools/gen_atlas.js 顶部注释。

pub const blob = @embedFile("atlas.bin");
/// 黑白贴图（灰度，1 字节/像素，格式 CSBW）："颜色"关掉时用它
pub const blob_bw = @embedFile("atlas-bw.bin");
pub const atlas_w: u16 = 208;
pub const atlas_h: u16 = 207;
pub const count: u16 = 116;

pub const Rect = struct { x: u16, y: u16, w: u16, h: u16 };
pub const rects = [_]Rect{
    .{ .x = 0, .y = 175, .w = 32, .h = 32 }, // 0 icon
    .{ .x = 0, .y = 151, .w = 24, .h = 24 }, // 1 face_normal
    .{ .x = 24, .y = 151, .w = 24, .h = 24 }, // 2 face_down
    .{ .x = 96, .y = 151, .w = 24, .h = 24 }, // 3 face_dead
    .{ .x = 72, .y = 151, .w = 24, .h = 24 }, // 4 face_win
    .{ .x = 48, .y = 151, .w = 24, .h = 24 }, // 5 face_scan
    .{ .x = 26, .y = 128, .w = 13, .h = 23 }, // 6 led_0
    .{ .x = 39, .y = 128, .w = 13, .h = 23 }, // 7 led_1
    .{ .x = 52, .y = 128, .w = 13, .h = 23 }, // 8 led_2
    .{ .x = 65, .y = 128, .w = 13, .h = 23 }, // 9 led_3
    .{ .x = 78, .y = 128, .w = 13, .h = 23 }, // 10 led_4
    .{ .x = 91, .y = 128, .w = 13, .h = 23 }, // 11 led_5
    .{ .x = 104, .y = 128, .w = 13, .h = 23 }, // 12 led_6
    .{ .x = 117, .y = 128, .w = 13, .h = 23 }, // 13 led_7
    .{ .x = 130, .y = 128, .w = 13, .h = 23 }, // 14 led_8
    .{ .x = 143, .y = 128, .w = 13, .h = 23 }, // 15 led_9
    .{ .x = 0, .y = 128, .w = 13, .h = 23 }, // 16 led_blank
    .{ .x = 13, .y = 128, .w = 13, .h = 23 }, // 17 led_minus
    .{ .x = 156, .y = 128, .w = 13, .h = 23 }, // 18 led_i
    .{ .x = 0, .y = 0, .w = 16, .h = 16 }, // 19 num_0
    .{ .x = 16, .y = 0, .w = 16, .h = 16 }, // 20 num_1
    .{ .x = 32, .y = 0, .w = 16, .h = 16 }, // 21 num_2
    .{ .x = 48, .y = 0, .w = 16, .h = 16 }, // 22 num_4
    .{ .x = 64, .y = 0, .w = 16, .h = 16 }, // 23 num_5
    .{ .x = 80, .y = 0, .w = 16, .h = 16 }, // 24 num_8
    .{ .x = 96, .y = 0, .w = 16, .h = 16 }, // 25 num_9
    .{ .x = 112, .y = 0, .w = 16, .h = 16 }, // 26 num_10
    .{ .x = 128, .y = 0, .w = 16, .h = 16 }, // 27 num_13
    .{ .x = 144, .y = 0, .w = 16, .h = 16 }, // 28 num_16
    .{ .x = 160, .y = 0, .w = 16, .h = 16 }, // 29 num_17
    .{ .x = 176, .y = 0, .w = 16, .h = 16 }, // 30 num_18
    .{ .x = 192, .y = 0, .w = 16, .h = 16 }, // 31 num_20
    .{ .x = 0, .y = 16, .w = 16, .h = 16 }, // 32 num_25
    .{ .x = 16, .y = 16, .w = 16, .h = 16 }, // 33 num_26
    .{ .x = 32, .y = 16, .w = 16, .h = 16 }, // 34 num_29
    .{ .x = 48, .y = 16, .w = 16, .h = 16 }, // 35 num_32
    .{ .x = 64, .y = 16, .w = 16, .h = 16 }, // 36 num_34
    .{ .x = 80, .y = 16, .w = 16, .h = 16 }, // 37 num_36
    .{ .x = 96, .y = 16, .w = 16, .h = 16 }, // 38 num_37
    .{ .x = 112, .y = 16, .w = 16, .h = 16 }, // 39 num_40
    .{ .x = 128, .y = 16, .w = 16, .h = 16 }, // 40 num_49
    .{ .x = 144, .y = 16, .w = 16, .h = 16 }, // 41 num_50
    .{ .x = 160, .y = 16, .w = 16, .h = 16 }, // 42 num_64
    .{ .x = 0, .y = 64, .w = 16, .h = 16 }, // 43 closed
    .{ .x = 16, .y = 64, .w = 16, .h = 16 }, // 44 blank
    .{ .x = 32, .y = 64, .w = 16, .h = 16 }, // 45 flag_1
    .{ .x = 128, .y = 64, .w = 16, .h = 16 }, // 46 mine_1
    .{ .x = 16, .y = 80, .w = 16, .h = 16 }, // 47 boom_1
    .{ .x = 0, .y = 96, .w = 16, .h = 16 }, // 48 wrong_1
    .{ .x = 48, .y = 64, .w = 16, .h = 16 }, // 49 flag_2
    .{ .x = 144, .y = 64, .w = 16, .h = 16 }, // 50 mine_2
    .{ .x = 32, .y = 80, .w = 16, .h = 16 }, // 51 boom_2
    .{ .x = 16, .y = 96, .w = 16, .h = 16 }, // 52 wrong_2
    .{ .x = 64, .y = 64, .w = 16, .h = 16 }, // 53 flag_3
    .{ .x = 160, .y = 64, .w = 16, .h = 16 }, // 54 mine_3
    .{ .x = 48, .y = 80, .w = 16, .h = 16 }, // 55 boom_3
    .{ .x = 32, .y = 96, .w = 16, .h = 16 }, // 56 wrong_3
    .{ .x = 80, .y = 64, .w = 16, .h = 16 }, // 57 flag_4
    .{ .x = 176, .y = 64, .w = 16, .h = 16 }, // 58 mine_4
    .{ .x = 64, .y = 80, .w = 16, .h = 16 }, // 59 boom_4
    .{ .x = 48, .y = 96, .w = 16, .h = 16 }, // 60 wrong_4
    .{ .x = 176, .y = 16, .w = 16, .h = 16 }, // 61 hnum_3
    .{ .x = 192, .y = 16, .w = 16, .h = 16 }, // 62 hnum_7
    .{ .x = 0, .y = 32, .w = 16, .h = 16 }, // 63 hnum_12
    .{ .x = 16, .y = 32, .w = 16, .h = 16 }, // 64 hnum_15
    .{ .x = 32, .y = 32, .w = 16, .h = 16 }, // 65 hnum_21
    .{ .x = 48, .y = 32, .w = 16, .h = 16 }, // 66 hnum_24
    .{ .x = 64, .y = 32, .w = 16, .h = 16 }, // 67 hnum_35
    .{ .x = 80, .y = 32, .w = 16, .h = 16 }, // 68 hnum_48
    .{ .x = 176, .y = 48, .w = 16, .h = 16 }, // 69 hnum_64_i
    .{ .x = 160, .y = 48, .w = 16, .h = 16 }, // 70 hnum_49_i
    .{ .x = 144, .y = 48, .w = 16, .h = 16 }, // 71 hnum_48_i
    .{ .x = 128, .y = 48, .w = 16, .h = 16 }, // 72 hnum_36_i
    .{ .x = 112, .y = 48, .w = 16, .h = 16 }, // 73 hnum_35_i
    .{ .x = 96, .y = 48, .w = 16, .h = 16 }, // 74 hnum_32_i
    .{ .x = 80, .y = 48, .w = 16, .h = 16 }, // 75 hnum_25_i
    .{ .x = 64, .y = 48, .w = 16, .h = 16 }, // 76 hnum_24_i
    .{ .x = 48, .y = 48, .w = 16, .h = 16 }, // 77 hnum_21_i
    .{ .x = 32, .y = 48, .w = 16, .h = 16 }, // 78 hnum_16_i
    .{ .x = 16, .y = 48, .w = 16, .h = 16 }, // 79 hnum_15_i
    .{ .x = 0, .y = 48, .w = 16, .h = 16 }, // 80 hnum_12_i
    .{ .x = 192, .y = 32, .w = 16, .h = 16 }, // 81 hnum_9_i
    .{ .x = 176, .y = 32, .w = 16, .h = 16 }, // 82 hnum_8_i
    .{ .x = 160, .y = 32, .w = 16, .h = 16 }, // 83 hnum_7_i
    .{ .x = 144, .y = 32, .w = 16, .h = 16 }, // 84 hnum_5_i
    .{ .x = 128, .y = 32, .w = 16, .h = 16 }, // 85 hnum_4_i
    .{ .x = 112, .y = 32, .w = 16, .h = 16 }, // 86 hnum_3_i
    .{ .x = 96, .y = 32, .w = 16, .h = 16 }, // 87 hnum_1_i
    .{ .x = 169, .y = 128, .w = 13, .h = 23 }, // 88 led_j
    .{ .x = 64, .y = 112, .w = 16, .h = 16 }, // 89 hrightflag_3
    .{ .x = 160, .y = 96, .w = 16, .h = 16 }, // 90 hright_3
    .{ .x = 96, .y = 96, .w = 16, .h = 16 }, // 91 right_1
    .{ .x = 128, .y = 96, .w = 16, .h = 16 }, // 92 right_3
    .{ .x = 80, .y = 112, .w = 16, .h = 16 }, // 93 hrightflag_4
    .{ .x = 176, .y = 96, .w = 16, .h = 16 }, // 94 hright_4
    .{ .x = 112, .y = 96, .w = 16, .h = 16 }, // 95 right_2
    .{ .x = 144, .y = 96, .w = 16, .h = 16 }, // 96 right_4
    .{ .x = 160, .y = 112, .w = 16, .h = 16 }, // 97 hwrongflag_3
    .{ .x = 64, .y = 96, .w = 16, .h = 16 }, // 98 hwrong_3
    .{ .x = 192, .y = 96, .w = 16, .h = 16 }, // 99 wrongblank
    .{ .x = 176, .y = 112, .w = 16, .h = 16 }, // 100 hwrongflag_4
    .{ .x = 80, .y = 96, .w = 16, .h = 16 }, // 101 hwrong_4
    .{ .x = 96, .y = 64, .w = 16, .h = 16 }, // 102 hflag_3
    .{ .x = 192, .y = 64, .w = 16, .h = 16 }, // 103 hmine_3
    .{ .x = 112, .y = 64, .w = 16, .h = 16 }, // 104 hflag_4
    .{ .x = 0, .y = 80, .w = 16, .h = 16 }, // 105 hmine_4
    .{ .x = 80, .y = 80, .w = 16, .h = 16 }, // 106 hboom_3
    .{ .x = 96, .y = 80, .w = 16, .h = 16 }, // 107 hboom_4
    .{ .x = 0, .y = 112, .w = 16, .h = 16 }, // 108 rightflag_1
    .{ .x = 32, .y = 112, .w = 16, .h = 16 }, // 109 rightflag_3
    .{ .x = 16, .y = 112, .w = 16, .h = 16 }, // 110 rightflag_2
    .{ .x = 48, .y = 112, .w = 16, .h = 16 }, // 111 rightflag_4
    .{ .x = 96, .y = 112, .w = 16, .h = 16 }, // 112 wrongflag_1
    .{ .x = 128, .y = 112, .w = 16, .h = 16 }, // 113 wrongflag_3
    .{ .x = 112, .y = 112, .w = 16, .h = 16 }, // 114 wrongflag_2
    .{ .x = 144, .y = 112, .w = 16, .h = 16 }, // 115 wrongflag_4
};

pub fn rect(i: u16) Rect {
    return rects[i];
}

pub const icon: u16 = 0;
pub const face_normal: u16 = 1;
pub const face_down: u16 = 2;
pub const face_dead: u16 = 3;
pub const face_win: u16 = 4;
pub const face_scan: u16 = 5;
pub const led_0: u16 = 6;
pub const led_1: u16 = 7;
pub const led_2: u16 = 8;
pub const led_3: u16 = 9;
pub const led_4: u16 = 10;
pub const led_5: u16 = 11;
pub const led_6: u16 = 12;
pub const led_7: u16 = 13;
pub const led_8: u16 = 14;
pub const led_9: u16 = 15;
pub const led_blank: u16 = 16;
pub const led_minus: u16 = 17;
pub const led_i: u16 = 18;
pub const num_0: u16 = 19;
pub const num_1: u16 = 20;
pub const num_2: u16 = 21;
pub const num_4: u16 = 22;
pub const num_5: u16 = 23;
pub const num_8: u16 = 24;
pub const num_9: u16 = 25;
pub const num_10: u16 = 26;
pub const num_13: u16 = 27;
pub const num_16: u16 = 28;
pub const num_17: u16 = 29;
pub const num_18: u16 = 30;
pub const num_20: u16 = 31;
pub const num_25: u16 = 32;
pub const num_26: u16 = 33;
pub const num_29: u16 = 34;
pub const num_32: u16 = 35;
pub const num_34: u16 = 36;
pub const num_36: u16 = 37;
pub const num_37: u16 = 38;
pub const num_40: u16 = 39;
pub const num_49: u16 = 40;
pub const num_50: u16 = 41;
pub const num_64: u16 = 42;
pub const closed: u16 = 43;
pub const blank: u16 = 44;
pub const flag_1: u16 = 45;
pub const mine_1: u16 = 46;
pub const boom_1: u16 = 47;
pub const wrong_1: u16 = 48;
pub const flag_2: u16 = 49;
pub const mine_2: u16 = 50;
pub const boom_2: u16 = 51;
pub const wrong_2: u16 = 52;
pub const flag_3: u16 = 53;
pub const mine_3: u16 = 54;
pub const boom_3: u16 = 55;
pub const wrong_3: u16 = 56;
pub const flag_4: u16 = 57;
pub const mine_4: u16 = 58;
pub const boom_4: u16 = 59;
pub const wrong_4: u16 = 60;
pub const hnum_3: u16 = 61;
pub const hnum_7: u16 = 62;
pub const hnum_12: u16 = 63;
pub const hnum_15: u16 = 64;
pub const hnum_21: u16 = 65;
pub const hnum_24: u16 = 66;
pub const hnum_35: u16 = 67;
pub const hnum_48: u16 = 68;
pub const hnum_64_i: u16 = 69;
pub const hnum_49_i: u16 = 70;
pub const hnum_48_i: u16 = 71;
pub const hnum_36_i: u16 = 72;
pub const hnum_35_i: u16 = 73;
pub const hnum_32_i: u16 = 74;
pub const hnum_25_i: u16 = 75;
pub const hnum_24_i: u16 = 76;
pub const hnum_21_i: u16 = 77;
pub const hnum_16_i: u16 = 78;
pub const hnum_15_i: u16 = 79;
pub const hnum_12_i: u16 = 80;
pub const hnum_9_i: u16 = 81;
pub const hnum_8_i: u16 = 82;
pub const hnum_7_i: u16 = 83;
pub const hnum_5_i: u16 = 84;
pub const hnum_4_i: u16 = 85;
pub const hnum_3_i: u16 = 86;
pub const hnum_1_i: u16 = 87;
pub const led_j: u16 = 88;
pub const hrightflag_3: u16 = 89;
pub const hright_3: u16 = 90;
pub const right_1: u16 = 91;
pub const right_3: u16 = 92;
pub const hrightflag_4: u16 = 93;
pub const hright_4: u16 = 94;
pub const right_2: u16 = 95;
pub const right_4: u16 = 96;
pub const hwrongflag_3: u16 = 97;
pub const hwrong_3: u16 = 98;
pub const wrongblank: u16 = 99;
pub const hwrongflag_4: u16 = 100;
pub const hwrong_4: u16 = 101;
pub const hflag_3: u16 = 102;
pub const hmine_3: u16 = 103;
pub const hflag_4: u16 = 104;
pub const hmine_4: u16 = 105;
pub const hboom_3: u16 = 106;
pub const hboom_4: u16 = 107;
pub const rightflag_1: u16 = 108;
pub const rightflag_3: u16 = 109;
pub const rightflag_2: u16 = 110;
pub const rightflag_4: u16 = 111;
pub const wrongflag_1: u16 = 112;
pub const wrongflag_3: u16 = 113;
pub const wrongflag_2: u16 = 114;
pub const wrongflag_4: u16 = 115;

/// 显示值 D = |S|^2 -> 数字贴图（圆复数模式）；表外为 0xFFFF（不该出现）
pub const num_by_D = blk: {
    var t = [_]u16{0xFFFF} ** 65;
    t[0] = num_0;
    t[1] = num_1;
    t[2] = num_2;
    t[4] = num_4;
    t[5] = num_5;
    t[8] = num_8;
    t[9] = num_9;
    t[10] = num_10;
    t[13] = num_13;
    t[16] = num_16;
    t[17] = num_17;
    t[18] = num_18;
    t[20] = num_20;
    t[25] = num_25;
    t[26] = num_26;
    t[29] = num_29;
    t[32] = num_32;
    t[34] = num_34;
    t[36] = num_36;
    t[37] = num_37;
    t[40] = num_40;
    t[49] = num_49;
    t[50] = num_50;
    t[64] = num_64;
    break :blk t;
};

/// 显示值 D = a^2 - b^2（-64 … 64）-> 数字贴图（闵可夫斯基模式）；
/// 下标是 D + 64，表外为 0xFFFF（不该出现）。39 个值的来历见 tools/hyper_values.js，
/// 其中显示文本与圆复数模式相同的 12 个直接指向 num_<D>（不重复出图）。
pub const hnum_by_D = blk: {
    var t = [_]u16{0xFFFF} ** 129;
    t[0] = hnum_64_i; // -64 → 8i
    t[15] = hnum_49_i; // -49 → 7i
    t[16] = hnum_48_i; // -48 → 4√3i
    t[28] = hnum_36_i; // -36 → 6i
    t[29] = hnum_35_i; // -35 → √35i
    t[32] = hnum_32_i; // -32 → 4√2i
    t[39] = hnum_25_i; // -25 → 5i
    t[40] = hnum_24_i; // -24 → 2√6i
    t[43] = hnum_21_i; // -21 → √21i
    t[48] = hnum_16_i; // -16 → 4i
    t[49] = hnum_15_i; // -15 → √15i
    t[52] = hnum_12_i; // -12 → 2√3i
    t[55] = hnum_9_i; // -9 → 3i
    t[56] = hnum_8_i; // -8 → 2√2i
    t[57] = hnum_7_i; // -7 → √7i
    t[59] = hnum_5_i; // -5 → √5i
    t[60] = hnum_4_i; // -4 → 2i
    t[61] = hnum_3_i; // -3 → √3i
    t[63] = hnum_1_i; // -1 → i
    t[64] = num_0; // 0 → 0
    t[65] = num_1; // 1 → 1
    t[67] = hnum_3; // 3 → √3
    t[68] = num_4; // 4 → 2
    t[69] = num_5; // 5 → √5
    t[71] = hnum_7; // 7 → √7
    t[72] = num_8; // 8 → 2√2
    t[73] = num_9; // 9 → 3
    t[76] = hnum_12; // 12 → 2√3
    t[79] = hnum_15; // 15 → √15
    t[80] = num_16; // 16 → 4
    t[85] = hnum_21; // 21 → √21
    t[88] = hnum_24; // 24 → 2√6
    t[89] = num_25; // 25 → 5
    t[96] = num_32; // 32 → 4√2
    t[99] = hnum_35; // 35 → √35
    t[100] = num_36; // 36 → 6
    t[112] = hnum_48; // 48 → 4√3
    t[113] = num_49; // 49 → 7
    t[128] = num_64; // 64 → 8
    break :blk t;
};

/// 雷：下标是雷的类型（1 正实雷·正类空雷 / 2 负实雷·负类空雷 / 3 正虚雷·正双曲虚雷 / 4 负虚雷·负双曲虚雷），0 空着
pub const mine_T = [5]u16{ 0, mine_1, mine_2, mine_3, mine_4 };
/// 雷：下标是雷的类型（1 正实雷·正类空雷 / 2 负实雷·负类空雷 / 3 正虚雷·正双曲虚雷 / 4 负虚雷·负双曲虚雷），0 空着
pub const hmine_T = [5]u16{ 0, mine_1, mine_2, hmine_3, hmine_4 };
/// 旗：下标是雷的类型（1 正实雷·正类空雷 / 2 负实雷·负类空雷 / 3 正虚雷·正双曲虚雷 / 4 负虚雷·负双曲虚雷），0 空着
pub const flag_T = [5]u16{ 0, flag_1, flag_2, flag_3, flag_4 };
/// 旗：下标是雷的类型（1 正实雷·正类空雷 / 2 负实雷·负类空雷 / 3 正虚雷·正双曲虚雷 / 4 负虚雷·负双曲虚雷），0 空着
pub const hflag_T = [5]u16{ 0, flag_1, flag_2, hflag_3, hflag_4 };
/// 踩中雷：下标是雷的类型（1 正实雷·正类空雷 / 2 负实雷·负类空雷 / 3 正虚雷·正双曲虚雷 / 4 负虚雷·负双曲虚雷），0 空着
pub const boom_T = [5]u16{ 0, boom_1, boom_2, boom_3, boom_4 };
/// 踩中雷：下标是雷的类型（1 正实雷·正类空雷 / 2 负实雷·负类空雷 / 3 正虚雷·正双曲虚雷 / 4 负虚雷·负双曲虚雷），0 空着
pub const hboom_T = [5]u16{ 0, boom_1, boom_2, hboom_3, hboom_4 };
/// 标错雷：下标是雷的类型（1 正实雷·正类空雷 / 2 负实雷·负类空雷 / 3 正虚雷·正双曲虚雷 / 4 负虚雷·负双曲虚雷），0 空着
pub const wrong_T = [5]u16{ 0, wrong_1, wrong_2, wrong_3, wrong_4 };
/// 标错雷：下标是雷的类型（1 正实雷·正类空雷 / 2 负实雷·负类空雷 / 3 正虚雷·正双曲虚雷 / 4 负虚雷·负双曲虚雷），0 空着
pub const hwrong_T = [5]u16{ 0, wrong_1, wrong_2, hwrong_3, hwrong_4 };
/// 标对雷：下标是雷的类型（1 正实雷·正类空雷 / 2 负实雷·负类空雷 / 3 正虚雷·正双曲虚雷 / 4 负虚雷·负双曲虚雷），0 空着
pub const right_T = [5]u16{ 0, right_1, right_2, right_3, right_4 };
/// 标对雷：下标是雷的类型（1 正实雷·正类空雷 / 2 负实雷·负类空雷 / 3 正虚雷·正双曲虚雷 / 4 负虚雷·负双曲虚雷），0 空着
pub const hright_T = [5]u16{ 0, right_1, right_2, hright_3, hright_4 };
/// 标对旗：下标是雷的类型（1 正实雷·正类空雷 / 2 负实雷·负类空雷 / 3 正虚雷·正双曲虚雷 / 4 负虚雷·负双曲虚雷），0 空着
pub const rightflag_T = [5]u16{ 0, rightflag_1, rightflag_2, rightflag_3, rightflag_4 };
/// 标对旗：下标是雷的类型（1 正实雷·正类空雷 / 2 负实雷·负类空雷 / 3 正虚雷·正双曲虚雷 / 4 负虚雷·负双曲虚雷），0 空着
pub const hrightflag_T = [5]u16{ 0, rightflag_1, rightflag_2, hrightflag_3, hrightflag_4 };
/// 标错旗：下标是雷的类型（1 正实雷·正类空雷 / 2 负实雷·负类空雷 / 3 正虚雷·正双曲虚雷 / 4 负虚雷·负双曲虚雷），0 空着
pub const wrongflag_T = [5]u16{ 0, wrongflag_1, wrongflag_2, wrongflag_3, wrongflag_4 };
/// 标错旗：下标是雷的类型（1 正实雷·正类空雷 / 2 负实雷·负类空雷 / 3 正虚雷·正双曲虚雷 / 4 负虚雷·负双曲虚雷），0 空着
pub const hwrongflag_T = [5]u16{ 0, wrongflag_1, wrongflag_2, hwrongflag_3, hwrongflag_4 };

/// 标错空格子：给不是雷的格子插了旗，失败后显示它（画好之前先退回空白格）
pub const wrongblank_sprite: u16 = wrongblank;
