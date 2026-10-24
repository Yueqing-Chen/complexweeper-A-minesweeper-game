// 跨平台主程序：SDL3 + SDL3_ttf，界面全部画在软件画布上。
// 布局、贴图、判定、音效时机都沿用 1.3.0 的 Win32 实现；菜单、对话框、消息框
// 由本文件自绘，因此 Wayland 下不需要原生菜单支持。
const std = @import("std");
const c = @import("sdl.zig").c;
const g = @import("game.zig");
const A = @import("assets.zig");
const snd = @import("sounds.zig");
const cv = @import("canvas.zig");
const FontMod = @import("font.zig");
const prefsmod = @import("prefs.zig");
const audiomod = @import("audio.zig");

const Color = cv.Color;
const Canvas = cv.Canvas;

// ------------------------------------------------------------------ 命令 ID
const IDM_NEW: usize = 100;
const IDM_BEGINNER: usize = 101;
const IDM_INTERMEDIATE: usize = 102;
const IDM_EXPERT: usize = 103;
const IDM_CUSTOM: usize = 104;
const IDM_EXIT: usize = 105;
const IDM_BEST: usize = 106;
const IDM_SOUND: usize = 107;
const IDM_COLOR: usize = 108;
const IDM_ZOOM1: usize = 110;
const IDM_ZOOM2: usize = 111;
const IDM_ZOOM3: usize = 112;
const IDM_HYPER_BEGINNER: usize = 120;
const IDM_HYPER_INTERMEDIATE: usize = 121;
const IDM_HYPER_EXPERT: usize = 122;
const IDM_HYPER_CUSTOM: usize = 123;
const IDM_HYPER_BEST: usize = 124;
const IDM_HELP_HOW: usize = 200;
const IDM_HELP_ABOUT: usize = 202;

const APP_TITLE = "复扫雷 Complexweeper";
const APP_VERSION = "1.3.0";

// ------------------------------------------------------------------ 布局
pub const Layout = struct {
    z: i32,
    frame: i32,
    pad: i32,
    header_h: i32,
    gap: i32,
    box: i32,
    inner_w: i32,
    client_w: i32,
    client_h: i32,
    board_x: i32,
    board_y: i32,
    cell: i32,
    header_x: i32,
    header_y: i32,
    header_w: i32,
};

const REAL_DIGITS: i32 = 4;
const IMAG_DIGITS: i32 = 3;
const FACE_SIZE: i32 = 24;
const FACE_NUDGE: i32 = 2;
const FACE_FLASH_MS: u32 = 200;

pub const MENU_BAR_H: i32 = 22;

fn valueDigits(base: i32, v: ?i32) i32 {
    if (v == null) return base;
    const x = v.?;
    if (x >= 0) return if (x <= pow10i(base) - 1) base else base + 1;
    return if (x >= -(pow10i(base - 1) - 1)) base else base + 1;
}

fn panelValueDigits(imag: bool, v: ?i32) i32 {
    return valueDigits(if (imag) IMAG_DIGITS else REAL_DIGITS, v);
}

fn panelCells(imag: bool, v: ?i32) i32 {
    return panelValueDigits(imag, v) + (if (imag) @as(i32, 1) else 0);
}

fn counterWidth(z: i32, digits: i32) i32 {
    return 16 * z + 2 * z + digits * 13 * z + 2 * z;
}

fn counterValue(t: usize) i32 {
    const k = game.unmarked(t);
    return switch (t) {
        2, 4 => -k,
        else => k,
    };
}

fn counterShown(t: usize) ?i32 {
    if (!game.started) return null;
    return counterValue(t);
}

fn counterImag(t: usize) bool {
    return t == 3 or t == 4;
}

fn countersWidth(L: Layout) i32 {
    var widest: i32 = 0;
    for (1..5) |t| {
        widest = @max(widest, counterWidth(L.z, panelCells(counterImag(t), counterShown(t))));
    }
    return widest;
}

fn timerWidth(z: i32) i32 {
    return 4 * 13 * z + 2 * z;
}

fn headerContentWidth(z: i32) i32 {
    const col = counterWidth(z, 4);
    return 4 * z + col + 8 * z + FACE_SIZE * z + 8 * z + timerWidth(z) + 4 * z;
}

fn layout() Layout {
    const z = zoom;
    const frame = 3 * z;
    const pad = 6 * z;
    const gap = 6 * z;
    const box = 3 * z;
    const cell = 16 * z;
    const board_w = @as(i32, game.w) * cell + 2 * box;
    const hw = headerContentWidth(z);
    const inner_w = @max(board_w, hw);
    const client_w = inner_w + 2 * (frame + pad);
    const counters_h = 4 * (26 * z) + 3 * (2 * z);
    const header_h = 2 * (2 * z) + 2 * (3 * z) + counters_h;
    const client_h = 2 * (frame + pad) + header_h + gap + @as(i32, game.h) * cell + 2 * box;
    return .{
        .z = z,
        .frame = frame,
        .pad = pad,
        .header_h = header_h,
        .gap = gap,
        .box = box,
        .inner_w = inner_w,
        .client_w = client_w,
        .client_h = client_h,
        .board_x = frame + pad + @divTrunc(inner_w - board_w, 2) + box,
        .board_y = frame + pad + header_h + gap + box,
        .cell = cell,
        .header_x = frame + pad,
        .header_y = frame + pad,
        .header_w = inner_w,
    };
}

fn countersX(L: Layout) i32 {
    return L.header_x + 4 * L.z;
}
fn countersY(L: Layout) i32 {
    return L.header_y + 2 * L.z + 3 * L.z;
}

fn faceLeft(L: Layout) i32 {
    const size = FACE_SIZE * L.z;
    const counters_end = countersX(L) + countersWidth(L);
    const timer_start = timerX(L);
    const clearance = 6 * L.z;
    var fx = L.header_x + @divTrunc(L.header_w, 2) - @divTrunc(size, 2);
    if (fx < counters_end + clearance) fx = counters_end + clearance;
    if (fx + size > timer_start - clearance) fx = timer_start - clearance - size;
    if (fx < L.header_x) fx = L.header_x;
    return fx - FACE_NUDGE;
}

fn faceTop(L: Layout) i32 {
    return L.header_y + @divTrunc(L.header_h - FACE_SIZE * L.z, 2) - FACE_NUDGE;
}

fn timerX(L: Layout) i32 {
    return L.header_x + L.header_w - 4 * L.z - timerWidth(L.z);
}

fn timerY(L: Layout) i32 {
    return L.header_y + @divTrunc(L.header_h - 26 * L.z, 2);
}

// ------------------------------------------------------------------ 全局状态
pub var game: g.Game = .{};
var zoom: i32 = 2;
var cur_preset: i32 = -1;

fn hyper() bool {
    return game.mode == .hyper;
}

var face_down = false;
var face_armed = false;
var face_flash_until: u32 = 0;
var press_cell: i32 = -1;
var chord_cell: i32 = -1;
var l_down = false;
var r_down = false;
var m_down = false;
/// 菜单/弹窗吃掉按下后，后续松开也不能漏进棋盘
var swallow_mouse_up = false;

var sound_log: [snd.count]u32 = [_]u32{0} ** snd.count;
var over_sound_done: bool = false;
var tick_second: i32 = -1;
var arg_count: usize = 0;
var color_off: bool = false;
var sound_muted: bool = false;
var sound_off: bool = false;

var app_ready = false;
var quit_requested = false;

var canvas: Canvas = .{};
var font: ?FontMod.Font = null;
var atlas_img: ?cv.Image = null;
var atlas_bw: ?cv.Image = null;
var bw_loaded = false;
var icon_ok = false;

var prefs: prefsmod.Prefs = .{};
var prefs_ready = false;
var audio: audiomod.Audio = .{};

var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;
var texture: ?*c.SDL_Texture = null;
var tex_w: i32 = 0;
var tex_h: i32 = 0;
var sdl_inited = false;

var best_scores = [3]i32{ 0, 0, 0 };
var scores_persist = true;
var scores_quiet = false;

// ------------------------------------------------------------------ 菜单模型
const CheckKind = enum { none, preset, sound, color };

const MenuItem = struct {
    id: usize,
    label: []const u8,
    check: CheckKind = .none,
    preset: i32 = -1,
    hyper_mode: bool = false,
};

const SubMenu = struct {
    label: []const u8,
    entries: []const MenuEntry,
};

const MenuEntry = union(enum) {
    sep,
    item: MenuItem,
    sub: SubMenu,
};

const TopMenu = struct {
    label: []const u8,
    entries: []const MenuEntry,
};

const complex_entries = [_]MenuEntry{
    .{ .item = .{ .id = IDM_BEGINNER, .label = "初级(B)\t9×9 · 10 雷", .check = .preset, .preset = 0 } },
    .{ .item = .{ .id = IDM_INTERMEDIATE, .label = "中级(I)\t16×16 · 40 雷", .check = .preset, .preset = 1 } },
    .{ .item = .{ .id = IDM_EXPERT, .label = "高级(E)\t30×16 · 99 雷", .check = .preset, .preset = 2 } },
    .sep,
    .{ .item = .{ .id = IDM_BEST, .label = "最高分纪录(R)…" } },
    .{ .item = .{ .id = IDM_CUSTOM, .label = "自定义雷区(C)…" } },
};

const hyper_entries = [_]MenuEntry{
    .{ .item = .{ .id = IDM_HYPER_BEGINNER, .label = "初级(B)\t9×9 · 10 雷", .check = .preset, .preset = 0, .hyper_mode = true } },
    .{ .item = .{ .id = IDM_HYPER_INTERMEDIATE, .label = "中级(I)\t16×16 · 40 雷", .check = .preset, .preset = 1, .hyper_mode = true } },
    .{ .item = .{ .id = IDM_HYPER_EXPERT, .label = "高级(E)\t30×16 · 99 雷", .check = .preset, .preset = 2, .hyper_mode = true } },
    .sep,
    .{ .item = .{ .id = IDM_HYPER_BEST, .label = "最高分纪录(R)…" } },
    .{ .item = .{ .id = IDM_HYPER_CUSTOM, .label = "自定义雷区(C)…" } },
};

const game_entries = [_]MenuEntry{
    .{ .item = .{ .id = IDM_NEW, .label = "开局(N)\tF2" } },
    .sep,
    .{ .sub = .{ .label = "圆复数模式(C)", .entries = &complex_entries } },
    .{ .sub = .{ .label = "双曲复数模式（闵可夫斯基模式）(M)", .entries = &hyper_entries } },
    .sep,
    .{ .item = .{ .id = IDM_COLOR, .label = "颜色(Y)", .check = .color } },
    .{ .item = .{ .id = IDM_SOUND, .label = "声音(S)", .check = .sound } },
    .{ .item = .{ .id = IDM_ZOOM1, .label = "缩放 100%" } },
    .{ .item = .{ .id = IDM_ZOOM2, .label = "缩放 200%" } },
    .{ .item = .{ .id = IDM_ZOOM3, .label = "缩放 300%" } },
    .sep,
    .{ .item = .{ .id = IDM_EXIT, .label = "退出(X)" } },
};

const help_entries = [_]MenuEntry{
    .{ .item = .{ .id = IDM_HELP_HOW, .label = "玩法与操作(H)" } },
    .sep,
    .{ .item = .{ .id = IDM_HELP_ABOUT, .label = "关于复扫雷(A)…" } },
};

const top_menus = [_]TopMenu{
    .{ .label = "游戏(G)", .entries = &game_entries },
    .{ .label = "帮助(H)", .entries = &help_entries },
};

const MenuState = struct {
    open_top: i32 = -1,
    hot_top: i32 = -1,
    hot_item: i32 = -1,
    open_sub: i32 = -1,
    hot_sub: i32 = -1,
};
var menu: MenuState = .{};

fn itemChecked(it: MenuItem) bool {
    return switch (it.check) {
        .none => false,
        .sound => !sound_off,
        .color => !color_off,
        .preset => cur_preset == it.preset and hyper() == it.hyper_mode,
    };
}

fn topMenu(i: i32) ?TopMenu {
    if (i < 0 or i >= @as(i32, @intCast(top_menus.len))) return null;
    return top_menus[@intCast(i)];
}

fn entryAt(top: i32, idx: i32) ?MenuEntry {
    const tm = topMenu(top) orelse return null;
    if (idx < 0 or idx >= @as(i32, @intCast(tm.entries.len))) return null;
    return tm.entries[@intCast(idx)];
}

fn subAt(top: i32, sub_idx: i32) ?SubMenu {
    const e = entryAt(top, sub_idx) orelse return null;
    return switch (e) {
        .sub => |sm| sm,
        else => null,
    };
}

const LabelParts = struct { main: []const u8, shortcut: []const u8 };

fn splitLabel(label: []const u8) LabelParts {
    if (std.mem.indexOfScalar(u8, label, '\t')) |i| {
        return .{ .main = label[0..i], .shortcut = label[i + 1 ..] };
    }
    return .{ .main = label, .shortcut = "" };
}

// ------------------------------------------------------------------ 文字与绘图小工具
fn textWidth(text: []const u8, size: f32) i32 {
    if (font) |*f| return f.measure(text, size).w;
    return @as(i32, @intCast(text.len)) * 8;
}

fn textHeight(size: f32) i32 {
    if (font) |*f| return f.measure("Ag", size).h;
    return 16;
}

fn drawText(canv: *Canvas, text: []const u8, x: i32, y: i32, size: f32, color: Color) void {
    if (text.len == 0) return;
    if (font) |*f| _ = f.draw(canv, text, x, y, size, color);
}

fn drawTextCentered(canv: *Canvas, text: []const u8, cx: i32, y: i32, size: f32, color: Color) void {
    drawText(canv, text, cx - @divTrunc(textWidth(text, size), 2), y, size, color);
}

fn fillCircle(canv: *Canvas, cx: i32, cy: i32, r: i32, color: Color) void {
    var dy: i32 = -r;
    while (dy <= r) : (dy += 1) {
        var dx: i32 = -r;
        while (dx <= r) : (dx += 1) {
            if (dx * dx + dy * dy <= r * r) canv.set(cx + dx, cy + dy, color);
        }
    }
}

fn drawRadioDot(canv: *Canvas, cx: i32, cy: i32) void {
    fillCircle(canv, cx, cy, 5, cv.C_SHADOW);
    fillCircle(canv, cx, cy, 3, cv.C_WHITE);
    fillCircle(canv, cx, cy, 2, cv.C_BLACK);
}

fn drawSubArrow(canv: *Canvas, x: i32, cy: i32) void {
    var i: i32 = 0;
    while (i < 4) : (i += 1) {
        canv.fill(x + i, cy - i, 1, 1 + i * 2, cv.C_BLACK);
    }
}

const RectI = struct { x: i32, y: i32, w: i32, h: i32 };

fn inside(r: RectI, x: i32, y: i32) bool {
    return x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h;
}

// ------------------------------------------------------------------ 棋盘绘制
fn activeImage() ?*cv.Image {
    if (color_off and bw_loaded) return &atlas_bw.?;
    if (atlas_img) |*im| return im;
    return null;
}

fn blitSprite(canv: *Canvas, sprite: u16, x: i32, y: i32, dw: i32, dh: i32) void {
    const img = activeImage() orelse return;
    canv.blit(img.*, cv.spriteRect(sprite), x, y, dw, dh);
}

fn blitSpriteSq(canv: *Canvas, sprite: u16, x: i32, y: i32, size: i32) void {
    blitSprite(canv, sprite, x, y, size, size);
}

fn drawLed(canv: *Canvas, x: i32, y: i32, v: ?i32, digits: i32, z: i32) i32 {
    const lw = 13 * z;
    const lh = 23 * z;
    var cx = x;
    if (v == null) {
        var i: i32 = 0;
        while (i < digits) : (i += 1) {
            blitSprite(canv, A.led_blank, cx, y, lw, lh);
            cx += lw;
        }
        return cx - x;
    }
    const val = v.?;
    if (val < 0) {
        blitSprite(canv, A.led_minus, cx, y, lw, lh);
        cx += lw;
        var m = -val;
        const lim = pow10i(digits - 1) - 1;
        if (m > lim) m = lim;
        var buf: [4]u8 = undefined;
        const n = fmtDigits(&buf, @intCast(m), @intCast(digits - 1));
        for (buf[0..n]) |ch| {
            blitSprite(canv, digitSprite(ch), cx, y, lw, lh);
            cx += lw;
        }
    } else {
        var m = val;
        const lim = pow10i(digits) - 1;
        if (m > lim) m = lim;
        var buf: [4]u8 = undefined;
        const n = fmtDigits(&buf, @intCast(m), @intCast(digits));
        for (buf[0..n]) |ch| {
            blitSprite(canv, digitSprite(ch), cx, y, lw, lh);
            cx += lw;
        }
    }
    return cx - x;
}

fn pow10i(n: i32) i32 {
    var r: i32 = 1;
    var i: i32 = 0;
    while (i < n) : (i += 1) r *= 10;
    return r;
}

fn fmtDigits(buf: []u8, v: u32, digits: u32) usize {
    var i: usize = digits;
    var x = v;
    while (i > 0) {
        i -= 1;
        buf[i] = @intCast('0' + (x % 10));
        x /= 10;
    }
    return digits;
}

fn digitSprite(ch: u8) u16 {
    return switch (ch) {
        '0' => A.led_0,
        '1' => A.led_1,
        '2' => A.led_2,
        '3' => A.led_3,
        '4' => A.led_4,
        '5' => A.led_5,
        '6' => A.led_6,
        '7' => A.led_7,
        '8' => A.led_8,
        else => A.led_9,
    };
}

fn faceSprite() u16 {
    if (face_down) return A.face_down;
    if (game.over) return if (game.win) A.face_win else A.face_dead;
    if (boardHeld()) return A.face_scan;
    if (nowMs() < face_flash_until) return A.face_scan;
    return A.face_normal;
}

fn boardHeld() bool {
    return r_down or m_down or (l_down and !face_down);
}

fn mineSprite(t: u8) u16 {
    return (if (hyper()) A.hmine_T else A.mine_T)[@min(@as(usize, t), 4)];
}
fn flagSprite(t: u8) u16 {
    return (if (hyper()) A.hflag_T else A.flag_T)[@min(@as(usize, t), 4)];
}
fn boomSprite(t: u8) u16 {
    return (if (hyper()) A.hboom_T else A.boom_T)[@min(@as(usize, t), 4)];
}
fn wrongSprite(t: u8) u16 {
    return (if (hyper()) A.hwrong_T else A.wrong_T)[@min(@as(usize, t), 4)];
}
fn rightSprite(t: u8) u16 {
    return (if (hyper()) A.hright_T else A.right_T)[@min(@as(usize, t), 4)];
}
fn rightFlagSprite(t: u8) u16 {
    return (if (hyper()) A.hrightflag_T else A.rightflag_T)[@min(@as(usize, t), 4)];
}
fn wrongFlagSprite(t: u8) u16 {
    return (if (hyper()) A.hwrongflag_T else A.wrongflag_T)[@min(@as(usize, t), 4)];
}

fn chordable(cell: usize) bool {
    if (cell >= game.n) return false;
    if (game.over or game.open[cell] == 0 or game.mine[cell] != 0) return false;
    var buf: [8]usize = undefined;
    const k = game.nbrs(cell, &buf);
    for (buf[0..k]) |j| {
        if (game.open[j] == 0 and game.flag[j] == 0) return true;
    }
    return false;
}

fn chordTarget(i: usize) bool {
    if (chord_cell < 0) return false;
    const cell: usize = @intCast(chord_cell);
    if (!chordable(cell)) return false;
    if (game.open[i] != 0 or game.flag[i] != 0) return false;
    var buf: [8]usize = undefined;
    const k = game.nbrs(cell, &buf);
    for (buf[0..k]) |j| {
        if (j == i) return true;
    }
    return false;
}

fn cellSprite(i: usize) u16 {
    if (press_cell >= 0 and @as(usize, @intCast(press_cell)) == i and game.open[i] == 0) return A.blank;
    if (chordTarget(i)) return A.blank;
    const revealed = game.over and !game.win;
    if (game.open[i] != 0) {
        if (game.mine[i] != 0) {
            if (game.boom == @as(i32, @intCast(i))) return boomSprite(game.mine[i]);
            return mineSprite(game.mine[i]);
        }
        const D = game.clue[i];
        if (D == 0 and game.nbrMineCount(i) == 0) return A.blank;
        const s = if (hyper())
            A.hnum_by_D[@intCast(D + 64)]
        else
            A.num_by_D[@intCast(D)];
        return if (s == 0xFFFF) A.blank else s;
    }
    if (game.flag[i] != 0) {
        const t = game.mine[i];
        const f = game.flag[i];
        if (revealed) {
            if (t == 0) return A.wrongblank_sprite;
            if (f == t) return rightSprite(t);
            return wrongSprite(t);
        }
        if (game.win) {
            if (t != 0 and f == t) return rightFlagSprite(t);
            return wrongFlagSprite(if (t != 0) t else f);
        }
        return flagSprite(f);
    }
    if (revealed and game.mine[i] != 0) return mineSprite(game.mine[i]);
    return A.closed;
}

fn paintGame(canv: *Canvas, L: Layout) void {
    canv.fill(0, 0, L.client_w, L.client_h, cv.C_BTNFACE);
    canv.draw3d(0, 0, L.client_w, L.client_h, L.frame, true);

    const hx = L.header_x;
    const hy = L.header_y;
    const hh = L.header_h;
    const hw2 = L.header_w;
    canv.draw3d(hx, hy, hw2, hh, 2 * L.z, false);

    const col_x = countersX(L);
    var cy = countersY(L);
    for (1..5) |t| {
        const val = counterShown(t);
        const imag = counterImag(t);
        const cw2 = counterWidth(L.z, panelCells(imag, val));
        canv.draw3d(col_x, cy, cw2, 26 * L.z, 1 * L.z, false);
        blitSpriteSq(canv, flagSprite(@intCast(t)), col_x + L.z + L.z, cy + @divTrunc(26 * L.z - 16 * L.z, 2), 16 * L.z);
        const led_x = col_x + L.z + 2 * L.z + 16 * L.z;
        const led_y = cy + @divTrunc(26 * L.z - 23 * L.z, 2);
        const vw = drawLed(canv, led_x, led_y, val, panelValueDigits(imag, val), L.z);
        if (imag) blitSprite(canv, if (val == null) A.led_blank else if (hyper()) A.led_j else A.led_i, led_x + vw, led_y, 13 * L.z, 23 * L.z);
        cy += 26 * L.z + 2 * L.z;
    }

    const tx = timerX(L);
    const ty = timerY(L);
    const tv: ?i32 = if (game.started) timerSeconds() else null;
    canv.draw3d(tx, ty, timerWidth(L.z), 26 * L.z, 1 * L.z, false);
    _ = drawLed(canv, tx + L.z, ty + @divTrunc(26 * L.z - 23 * L.z, 2), tv, panelValueDigits(false, tv), L.z);

    blitSpriteSq(canv, faceSprite(), faceLeft(L), faceTop(L), FACE_SIZE * L.z);

    const bx = L.board_x - L.box;
    const by = L.board_y - L.box;
    const bw = @as(i32, game.w) * L.cell + 2 * L.box;
    const bh = @as(i32, game.h) * L.cell + 2 * L.box;
    canv.draw3d(bx, by, bw, bh, L.box, false);

    var i: usize = 0;
    while (i < game.n) : (i += 1) {
        const r: i32 = @intCast(i / game.w);
        const col: i32 = @intCast(i % game.w);
        const x = L.board_x + col * L.cell;
        const y = L.board_y + r * L.cell;
        blitSpriteSq(canv, cellSprite(i), x, y, L.cell);
    }
}

// ------------------------------------------------------------------ 声音 / 时钟
fn interactive() bool {
    return arg_count == 0;
}

fn audible() bool {
    return !sound_muted and !sound_off;
}

fn playSound(s: snd.Sounds) void {
    const i = @intFromEnum(s);
    sound_log[i] +%= 1;
    if (!audible()) return;
    audio.play(snd.wav(i));
}

fn maybePlayTick() void {
    if (!game.started or game.over) return;
    const sec = timerSeconds();
    if (sec < 1 or sec == tick_second) return;
    tick_second = sec;
    playSound(.tick);
}

fn flashFace() void {
    face_flash_until = nowMs() +% FACE_FLASH_MS;
}

fn timerSeconds() i32 {
    if (!game.started) return 0;
    return @intCast(@min(@as(u32, 9999), game.elapsed_ms / 1000));
}

fn nowMs() u32 {
    const t: i64 = std.time.milliTimestamp();
    return @truncate(@as(u64, @bitCast(t)));
}

// ------------------------------------------------------------------ 局面操作
fn cellAt(L: Layout, px: i32, py: i32) i32 {
    const cx = px - L.board_x;
    const cy = py - L.board_y;
    if (cx < 0 or cy < 0) return -1;
    const col = @divTrunc(cx, L.cell);
    const r = @divTrunc(cy, L.cell);
    if (col < 0 or r < 0 or col >= game.w or r >= game.h) return -1;
    return @intCast(@as(usize, @intCast(r)) * game.w + @as(usize, @intCast(col)));
}

fn inFace(L: Layout, px: i32, py: i32) bool {
    const fw = FACE_SIZE * L.z;
    const fx = faceLeft(L);
    const fy = faceTop(L);
    return px >= fx and py >= fy and px < fx + fw and py < fy + fw;
}

fn startNewGame(seed_override: ?u32) void {
    const seed = seed_override orelse nowMs();
    game.newGame(seed);
    press_cell = -1;
    chord_cell = -1;
    l_down = false;
    r_down = false;
    m_down = false;
    face_down = false;
    face_armed = false;
    face_flash_until = 0;
    over_sound_done = false;
    tick_second = -1;
}

fn setPreset(idx: i32, m: g.Mode) void {
    if (idx >= 0 and idx < @as(i32, @intCast(g.PRESETS.len))) {
        const p = g.PRESETS[@intCast(idx)];
        game.w = p.w;
        game.h = p.h;
        game.mines = p.mines;
        game.type_count = [_]u16{0} ** 5;
    }
    game.mode = m;
    cur_preset = idx;
    syncMode();
    resizeWindowForBoard();
    startNewGame(null);
}

fn syncMode() void {
    if (scores_persist) loadScores();
}

fn applyCustomFromDialog() void {
    cur_preset = -1;
    resizeWindowForBoard();
    startNewGame(null);
}

fn afterGameAction() void {
    if (!game.over) return;
    if (!over_sound_done) {
        over_sound_done = true;
        if (game.win) {
            playSound(.win);
        } else {
            const t: u8 = if (game.boom >= 0) game.mine[@intCast(game.boom)] else 1;
            playSound(snd.Sounds.mineOf(t));
        }
    }
    if (game.t0 != 0) game.elapsed_ms = nowMs() -% game.t0;
    if (!game.win) return;
    const idx = presetIndex();
    if (idx < 0) return;
    const sec: i32 = @max(1, @as(i32, @intCast(game.elapsed_ms / 1000)));
    const u: usize = @intCast(idx);
    if (best_scores[u] != 0 and sec >= best_scores[u]) return;
    best_scores[u] = sec;
    saveScores();
    if (!scores_quiet) showBestScores(true, game.mode);
}

fn doExpand(cell: usize) void {
    const m0 = game.moves;
    game.tryExpand(cell);
    afterGameAction();
    if (game.moves != m0 and !game.over) flashFace();
}

// ------------------------------------------------------------------ 最高分纪录
const SCORE_KEYS_CPLX = [3][]const u8{ "score.complex.0", "score.complex.1", "score.complex.2" };
const SCORE_KEYS_HYPER = [3][]const u8{ "score.hyper.0", "score.hyper.1", "score.hyper.2" };
const SCORE_LABEL = [3][]const u8{ "初级", "中级", "高级" };

fn presetIndex() i32 {
    for (g.PRESETS, 0..) |p, i| {
        if (game.w == p.w and game.h == p.h and game.mines == p.mines) return @intCast(i);
    }
    return -1;
}

fn readScores(m: g.Mode) [3]i32 {
    var out = [3]i32{ 0, 0, 0 };
    if (!scores_persist) return out;
    if (!prefs_ready) return out;
    out = prefs.state.scores[@intFromEnum(m)];
    return out;
}

fn loadScores() void {
    if (!scores_persist) return;
    if (!prefs_ready) return;
    best_scores = prefs.state.scores[@intFromEnum(game.mode)];
}

fn saveScores() void {
    if (!scores_persist) return;
    if (!prefs_ready) return;
    prefs.state.scores[@intFromEnum(game.mode)] = best_scores;
    prefs.save();
}

fn saveSoundPref() void {
    if (!scores_persist or !prefs_ready) return;
    prefs.state.sound_on = !sound_off;
    prefs.save();
}

fn saveColorPref() void {
    if (!scores_persist or !prefs_ready) return;
    prefs.state.color_on = !color_off;
    prefs.save();
}

fn toggleSound() void {
    sound_off = !sound_off;
    if (sound_off) audio.stopAll();
    saveSoundPref();
}

fn toggleColor() void {
    color_off = !color_off;
    saveColorPref();
}

fn appendStr(buf: []u8, n: *usize, s: []const u8) void {
    const take = @min(s.len, buf.len - n.*);
    @memcpy(buf[n.*..][0..take], s[0..take]);
    n.* += take;
}

fn appendInt(buf: []u8, n: *usize, v: i32) void {
    if (v <= 0) {
        appendStr(buf, n, "———");
        return;
    }
    var tmp: [12]u8 = undefined;
    const s = std.fmt.bufPrint(&tmp, "{d}", .{v}) catch return;
    appendStr(buf, n, s);
}

fn buildScoresText(buf: []u8, scores: [3]i32) usize {
    var n: usize = 0;
    for (0..3) |i| {
        appendStr(buf, &n, SCORE_LABEL[i]);
        appendStr(buf, &n, "      ");
        appendInt(buf, &n, scores[i]);
        if (scores[i] > 0) appendStr(buf, &n, " 秒");
        appendStr(buf, &n, "\n");
    }
    return n;
}

var scores_text_buf: [1024]u8 = undefined;

fn testSetScoresHook(v0: i32, v1: i32, v2: i32) void {
    best_scores = .{ v0, v1, v2 };
}

// ------------------------------------------------------------------ 自绘对话框
const DlgErr = enum(u8) { none = 0, height, width, sum_zero, sum_big };

fn dlgErrText(e: DlgErr) []const u8 {
    return switch (e) {
        .none => "",
        .height => "高度要在 9 – 30 之间。",
        .width => "宽度要在 9 – 40 之间。",
        .sum_zero => "四种雷合计至少 1 颗。",
        .sum_big => "合计超过上限（格数 − 9）。",
    };
}

var dlg_state: struct {
    h: i32 = 16,
    w: i32 = 30,
    t: [5]i32 = .{ 0, 25, 25, 25, 24 },
    err: DlgErr = .none,
} = .{};

var dialog_open = false;
var dialog_done = false;
var dialog_cancel = false;
var dlg_active: usize = 0;
var dlg_edits: [6][16]u8 = [_][16]u8{.{0} ** 16} ** 6;
var dlg_lens: [6]usize = [_]usize{0} ** 6;

const DLG_W: i32 = 330;
const DLG_H: i32 = 308;
const DLG_TITLE_H: i32 = 26;

fn editText(i: usize) []const u8 {
    return dlg_edits[i][0..dlg_lens[i]];
}

fn setEditText(i: usize, text: []const u8) void {
    const n = @min(text.len, dlg_edits[i].len);
    @memcpy(dlg_edits[i][0..n], text[0..n]);
    dlg_lens[i] = n;
}

fn setEditInt(i: usize, v: i32) void {
    var buf: [16]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, "{d}", .{v}) catch return;
    setEditText(i, s);
}

fn getEditInt(i: usize, fallback: i32) i32 {
    var v: i32 = 0;
    var any = false;
    for (editText(i)) |ch| {
        if (ch < '0' or ch > '9') continue;
        v = v * 10 + @as(i32, @intCast(ch - '0'));
        any = true;
        if (v > 100000) v = 100000;
    }
    return if (any) v else fallback;
}

fn readDlgCounts() [5]i32 {
    var t = [5]i32{ 0, 0, 0, 0, 0 };
    for (1..5) |k| t[k] = getEditInt(k + 1, 0);
    return t;
}

fn dlgApply() void {
    const h = getEditInt(0, 16);
    const ww = getEditInt(1, 30);
    const t = readDlgCounts();
    var sum: i32 = 0;
    for (1..5) |k| sum += t[k];
    if (h < 9 or h > 30) {
        dlg_state.err = .height;
        return;
    }
    if (ww < 9 or ww > 40) {
        dlg_state.err = .width;
        return;
    }
    if (sum < 1) {
        dlg_state.err = .sum_zero;
        return;
    }
    const maxm = ww * h - 9;
    if (sum > maxm) {
        dlg_state.err = .sum_big;
        return;
    }
    dlg_state.err = .none;
    game.w = @intCast(ww);
    game.h = @intCast(h);
    game.mines = @intCast(sum);
    game.type_count = .{ 0, @intCast(t[1]), @intCast(t[2]), @intCast(t[3]), @intCast(t[4]) };
    dialog_done = true;
}

fn dlgSplit() void {
    var sum: i32 = 0;
    const cur = readDlgCounts();
    for (1..5) |t| sum += cur[t];
    if (sum <= 0) sum = 99;
    const sp = g.splitEvenly(@intCast(@min(sum, 999)));
    for (1..5) |t| setEditInt(t + 1, sp[t]);
}

fn openDialog() bool {
    cancelHeld();
    closeMenu();
    dialog_done = false;
    dialog_cancel = false;
    dlg_state.err = .none;
    dlg_state.h = game.h;
    dlg_state.w = game.w;
    var tc = game.type_count;
    var any: u16 = 0;
    for (1..5) |t| any += tc[t];
    if (any == 0) tc = g.splitEvenly(game.mines);
    for (1..5) |t| dlg_state.t[t] = tc[t];
    for (1..5) |t| setEditInt(t + 1, dlg_state.t[t]);
    setEditInt(0, dlg_state.h);
    setEditInt(1, dlg_state.w);
    dlg_active = 0;
    dialog_open = true;
    overlay.kind = .dialog;
    syncViewSize();
    return true;
}

fn closeDialog() void {
    dialog_open = false;
    if (overlay.kind == .dialog) overlay.kind = .none;
    syncViewSize();
}

fn dlgContentY() i32 {
    return @divTrunc(canvas.h - (DLG_H + DLG_TITLE_H), 2) + DLG_TITLE_H;
}

fn dlgX() i32 {
    return @divTrunc(canvas.w - DLG_W, 2);
}

fn dlgEditRect(i: usize) RectI {
    const x = dlgX();
    const cy = dlgContentY();
    if (i == 0) return .{ .x = x + 78, .y = cy + 12, .w = 70, .h = 22 };
    if (i == 1) return .{ .x = x + 78, .y = cy + 42, .w = 70, .h = 22 };
    return .{ .x = x + 220, .y = cy + 76 + @as(i32, @intCast(i - 2)) * 28, .w = 62, .h = 22 };
}

fn dlgTypeLabels() [4][]const u8 {
    if (hyper()) return .{
        "正实雷（正类空雷）：",
        "负实雷（负类空雷）：",
        "正双曲虚雷（正类时雷）：",
        "负双曲虚雷（负类时雷）：",
    };
    return .{ "正实雷：", "负实雷：", "正虚雷：", "负虚雷：" };
}

fn dlgSplitRect() RectI {
    return .{ .x = dlgX() + 12, .y = dlgContentY() + 194, .w = 100, .h = 24 };
}
fn dlgOkRect() RectI {
    return .{ .x = dlgX() + 122, .y = dlgContentY() + 228, .w = 88, .h = 26 };
}
fn dlgCancelRect() RectI {
    return .{ .x = dlgX() + 218, .y = dlgContentY() + 228, .w = 88, .h = 26 };
}
fn dlgCloseRect() RectI {
    return .{ .x = dlgX() + DLG_W - 24, .y = @divTrunc(canvas.h - (DLG_H + DLG_TITLE_H), 2) + 3, .w = 20, .h = 20 };
}

fn drawButton(canv: *Canvas, r: RectI, label: []const u8, default: bool) void {
    canv.fill(r.x, r.y, r.w, r.h, cv.C_BTNFACE);
    canv.draw3d(r.x, r.y, r.w, r.h, 2, true);
    if (default) {
        canv.fill(r.x + 3, r.y + 3, r.w - 6, 1, cv.C_BLACK);
        canv.fill(r.x + 3, r.y + r.h - 4, r.w - 6, 1, cv.C_BLACK);
        canv.fill(r.x + 3, r.y + 3, 1, r.h - 6, cv.C_BLACK);
        canv.fill(r.x + r.w - 4, r.y + 3, 1, r.h - 6, cv.C_BLACK);
    }
    const th = textHeight(14);
    drawTextCentered(canv, label, r.x + @divTrunc(r.w, 2), r.y + @divTrunc(r.h - th, 2), 14, cv.C_BLACK);
}

fn drawEdit(canv: *Canvas, r: RectI, i: usize) void {
    canv.fill(r.x, r.y, r.w, r.h, cv.C_WHITE);
    const bc = if (dialog_open and dlg_active == i) cv.C_MENU_HOT else cv.C_SHADOW;
    canv.fill(r.x, r.y, r.w, 1, bc);
    canv.fill(r.x, r.y + r.h - 1, r.w, 1, bc);
    canv.fill(r.x, r.y, 1, r.h, bc);
    canv.fill(r.x + r.w - 1, r.y, 1, r.h, bc);
    const th = textHeight(14);
    drawText(canv, editText(i), r.x + 5, r.y + @divTrunc(r.h - th, 2), 14, cv.C_BLACK);
    if (dialog_open and dlg_active == i) {
        const tw = textWidth(editText(i), 14);
        canv.fill(r.x + 5 + tw + 1, r.y + 4, 1, r.h - 8, cv.C_BLACK);
    }
}

fn drawDialog(canv: *Canvas) void {
    const x = dlgX();
    const y = @divTrunc(canvas.h - (DLG_H + DLG_TITLE_H), 2);
    canv.fill(x, y, DLG_W, DLG_H + DLG_TITLE_H, cv.C_WHITE);
    canv.draw3d(x, y, DLG_W, DLG_H + DLG_TITLE_H, 2, true);
    canv.fill(x + 2, y + 2, DLG_W - 4, DLG_TITLE_H - 2, cv.C_MENU_HOT);
    drawText(canv, "自定义雷区", x + 10, y + 5, 14, cv.C_WHITE);
    const cr = dlgCloseRect();
    drawText(canv, "×", cr.x + 3, cr.y - 1, 18, cv.C_WHITE);

    const cy = dlgContentY();
    drawText(canv, "高度(H)：", x + 12, cy + 15, 14, cv.C_BLACK);
    drawEdit(canv, dlgEditRect(0), 0);
    drawText(canv, "9 – 30 行", x + 156, cy + 15, 14, cv.C_BLACK);
    drawText(canv, "宽度(W)：", x + 12, cy + 45, 14, cv.C_BLACK);
    drawEdit(canv, dlgEditRect(1), 1);
    drawText(canv, "9 – 40 列", x + 156, cy + 45, 14, cv.C_BLACK);

    const labels = dlgTypeLabels();
    for (0..4) |k| {
        const yy = cy + 76 + @as(i32, @intCast(k)) * 28;
        drawText(canv, labels[k], x + 12, yy + 3, 14, cv.C_BLACK);
        drawEdit(canv, dlgEditRect(k + 2), k + 2);
    }
    drawButton(canv, dlgSplitRect(), "按合计均分", false);
    drawText(canv, dlgErrText(dlg_state.err), x + 120, cy + 197, 14, cv.C_BLACK);
    drawButton(canv, dlgOkRect(), "确定", true);
    drawButton(canv, dlgCancelRect(), "取消", false);
}

fn dlgKey(key: u32, repeat: bool) void {
    if (key == 0x0D) {
        dlgApply();
        if (dialog_done) {
            if (!dialog_cancel) applyCustomFromDialog();
            closeDialog();
        }
        return;
    }
    if (key == 0x1B) {
        dialog_cancel = true;
        dialog_done = true;
        closeDialog();
        return;
    }
    if (key == 0x09) {
        dlg_active = (dlg_active + 1) % 6;
        return;
    }
    if (key == 0x08) {
        _ = repeat;
        if (dlg_lens[dlg_active] > 0) dlg_lens[dlg_active] -= 1;
        return;
    }
}

fn dlgTextInput(text: []const u8) void {
    for (text) |ch| {
        if (ch < '0' or ch > '9') continue;
        if (dlg_lens[dlg_active] >= 5) continue;
        dlg_edits[dlg_active][dlg_lens[dlg_active]] = ch;
        dlg_lens[dlg_active] += 1;
    }
}

fn dlgMouseDown(x: i32, y: i32) void {
    if (inside(dlgCloseRect(), x, y)) {
        dialog_cancel = true;
        dialog_done = true;
        closeDialog();
        return;
    }
    for (0..6) |i| {
        if (inside(dlgEditRect(i), x, y)) {
            dlg_active = i;
            return;
        }
    }
    if (inside(dlgSplitRect(), x, y)) {
        dlgSplit();
        return;
    }
    if (inside(dlgOkRect(), x, y)) {
        dlgApply();
        if (dialog_done) {
            if (!dialog_cancel) applyCustomFromDialog();
            closeDialog();
        }
        return;
    }
    if (inside(dlgCancelRect(), x, y)) {
        dialog_cancel = true;
        dialog_done = true;
        closeDialog();
    }
}

// ------------------------------------------------------------------ 自绘消息框
const OverlayKind = enum { none, message, dialog };

const Overlay = struct {
    kind: OverlayKind = .none,
};
var overlay: Overlay = .{};

var msg_title_buf: [256]u8 = undefined;
var msg_body_buf: [8192]u8 = undefined;
var message_title: []const u8 = "";
var message_body: []const u8 = "";
var message_w: i32 = 620;

const MSG_TITLE_H: i32 = 26;

fn copyText(dst: []u8, src: []const u8) []const u8 {
    const n = @min(src.len, dst.len);
    @memcpy(dst[0..n], src[0..n]);
    return dst[0..n];
}

fn lineCount(s: []const u8) i32 {
    var n: i32 = 1;
    for (s) |ch| if (ch == '\n') {
        n += 1;
    };
    return n;
}

fn messageBoxSize() struct { w: i32, h: i32 } {
    const wrap = message_w - 76;
    var bh: i32 = 0;
    if (font) |*f| {
        bh = f.measureWrapped(message_body, 15, wrap).h;
    } else {
        bh = lineCount(message_body) * 20;
    }
    bh = @max(bh, 32);
    return .{ .w = message_w, .h = MSG_TITLE_H + 12 + bh + 12 + 28 + 12 };
}

const MessageLayout = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    body_x: i32,
    body_y: i32,
    wrap: i32,
    ok: RectI,
};

fn messageLayout() MessageLayout {
    const sz = messageBoxSize();
    const x = @divTrunc(canvas.w - sz.w, 2);
    const y = @divTrunc(canvas.h - sz.h, 2);
    const body_x = x + 16 + 32 + 12;
    const body_y = y + MSG_TITLE_H + 12;
    const wrap = sz.w - 76;
    return .{
        .x = x,
        .y = y,
        .w = sz.w,
        .h = sz.h,
        .body_x = body_x,
        .body_y = body_y,
        .wrap = wrap,
        .ok = .{ .x = x + @divTrunc(sz.w - 88, 2), .y = y + sz.h - 28 - 12, .w = 88, .h = 28 },
    };
}

fn drawIcon(canv: *Canvas, x: i32, y: i32, size: i32) void {
    const r = A.rect(A.icon);
    if (r.w == 0 or r.h == 0) return;
    const off: usize = 12 + @as(usize, A.count) * 8;
    var dy: i32 = 0;
    while (dy < size) : (dy += 1) {
        const sy: i32 = r.y + @divTrunc(dy * r.h, size);
        var dx: i32 = 0;
        while (dx < size) : (dx += 1) {
            const sx: i32 = r.x + @divTrunc(dx * r.w, size);
            const o = off + (@as(usize, @intCast(sy)) * A.atlas_w + @as(usize, @intCast(sx))) * 4;
            const a = A.blob[o + 3];
            if (a == 0) continue;
            const col: Color = (@as(u32, a) << 24) | (@as(u32, A.blob[o + 2]) << 16) | (@as(u32, A.blob[o + 1]) << 8) | A.blob[o];
            canv.blend(x + dx, y + dy, col);
        }
    }
}

fn drawMessage(canv: *Canvas) void {
    const ml = messageLayout();
    canv.fill(ml.x, ml.y, ml.w, ml.h, cv.C_MENU_BG);
    canv.draw3d(ml.x, ml.y, ml.w, ml.h, 2, true);
    canv.fill(ml.x + 2, ml.y + 2, ml.w - 4, MSG_TITLE_H - 2, cv.C_MENU_HOT);
    drawText(canv, message_title, ml.x + 10, ml.y + 5, 14, cv.C_WHITE);
    drawText(canv, "×", ml.x + ml.w - 21, ml.y + 3, 18, cv.C_WHITE);
    drawIcon(canv, ml.x + 16, ml.body_y, 32);
    if (font) |*f| {
        _ = f.drawWrapped(canv, message_body, ml.body_x, ml.body_y, 15, cv.C_BLACK, ml.wrap);
    }
    drawButton(canv, ml.ok, "确定", true);
}

fn showMessage(title: []const u8, body: []const u8, width: i32) void {
    cancelHeld();
    closeMenu();
    message_title = copyText(&msg_title_buf, title);
    message_body = copyText(&msg_body_buf, body);
    message_w = width;
    overlay.kind = .message;
    syncViewSize();
}

fn closeMessage() void {
    if (overlay.kind == .message) overlay.kind = .none;
    syncViewSize();
}

fn showBestScores(highlight: bool, m: g.Mode) void {
    const scores = readScores(m);
    const n = buildScoresText(&scores_text_buf, scores);
    var tb: [128]u8 = undefined;
    var tn: usize = 0;
    appendStr(&tb, &tn, if (highlight) "新纪录！" else "最高分纪录");
    appendStr(&tb, &tn, if (m == .hyper) " · 双曲复数模式（闵可夫斯基模式）" else " · 圆复数模式");
    showMessage(tb[0..tn], scores_text_buf[0..n], 460);
}

fn showAbout() void {
    showMessage("关于复扫雷", ABOUT_TEXT, 620);
}

fn showHelp() void {
    showMessage("玩法与操作", HELP_TEXT, 620);
}

fn messageMouseDown(x: i32, y: i32) void {
    const ml = messageLayout();
    if (inside(ml.ok, x, y) or inside(.{ .x = ml.x + ml.w - 24, .y = ml.y + 3, .w = 20, .h = 20 }, x, y)) {
        closeMessage();
    }
}

// ------------------------------------------------------------------ 菜单布局与交互
fn barLabel(tm: TopMenu) []const u8 {
    return splitLabel(tm.label).main;
}

fn barItemWidth(tm: TopMenu) i32 {
    return textWidth(barLabel(tm), 14) + 18;
}

fn barX(top: i32) i32 {
    var x: i32 = 0;
    var i: i32 = 0;
    while (i < top) : (i += 1) {
        if (topMenu(i)) |tm| x += barItemWidth(tm);
    }
    return x;
}

fn barIndexAt(x: i32, y: i32) i32 {
    if (y < 0 or y >= MENU_BAR_H) return -1;
    var xx: i32 = 0;
    var i: i32 = 0;
    while (i < @as(i32, @intCast(top_menus.len))) : (i += 1) {
        const ww = barItemWidth(top_menus[@intCast(i)]);
        if (x >= xx and x < xx + ww) return i;
        xx += ww;
    }
    return -1;
}

fn entryH(e: MenuEntry) i32 {
    return switch (e) {
        .sep => 8,
        else => 22,
    };
}

fn popupWidth(entries: []const MenuEntry) i32 {
    var widest: i32 = 80;
    for (entries) |e| {
        const ew: i32 = switch (e) {
            .sep => 0,
            .item => |it| blk: {
                const parts = splitLabel(it.label);
                var ww: i32 = 26 + textWidth(parts.main, 14) + 12;
                if (parts.shortcut.len > 0) ww += 20 + textWidth(parts.shortcut, 14);
                break :blk ww;
            },
            .sub => |sm| 26 + textWidth(sm.label, 14) + 20 + 12,
        };
        widest = @max(widest, ew);
    }
    return @max(widest, 160);
}

fn popupHeight(entries: []const MenuEntry) i32 {
    var h: i32 = 6;
    for (entries) |e| h += entryH(e);
    return h;
}

const PopupLayout = struct { x: i32, y: i32, w: i32, h: i32 };

fn popupLayout(top: i32) PopupLayout {
    const tm = topMenu(top) orelse return .{ .x = 0, .y = MENU_BAR_H, .w = 160, .h = 0 };
    return .{ .x = barX(top), .y = MENU_BAR_H, .w = popupWidth(tm.entries), .h = popupHeight(tm.entries) };
}

fn subLayout(parent: PopupLayout, top: i32, sub_idx: i32) PopupLayout {
    const sm = subAt(top, sub_idx) orelse return .{ .x = parent.x + parent.w, .y = parent.y, .w = 160, .h = 0 };
    const tm = topMenu(top) orelse return .{ .x = parent.x + parent.w, .y = parent.y, .w = 160, .h = 0 };
    var y = parent.y + 3;
    var i: i32 = 0;
    while (i < sub_idx and i < @as(i32, @intCast(tm.entries.len))) : (i += 1) {
        y += entryH(tm.entries[@intCast(i)]);
    }
    return .{ .x = parent.x + parent.w, .y = y, .w = popupWidth(sm.entries), .h = popupHeight(sm.entries) };
}

fn entryIndexAt(entries: []const MenuEntry, local_y: i32) i32 {
    var y: i32 = 3;
    for (entries, 0..) |e, i| {
        const h = entryH(e);
        if (local_y >= y and local_y < y + h) {
            return switch (e) {
                .sep => -1,
                else => @intCast(i),
            };
        }
        y += h;
    }
    return -1;
}

fn closeMenu() void {
    const was_open = menu.open_top >= 0;
    menu.open_top = -1;
    menu.open_sub = -1;
    menu.hot_item = -1;
    menu.hot_sub = -1;
    if (was_open) syncViewSize();
}

fn executeCommand(id: usize) void {
    closeMenu();
    handleCommand(id);
}

fn menuMouseDown(x: i32, y: i32) void {
    const top = barIndexAt(x, y);
    if (top >= 0) {
        if (menu.open_top == top) {
            closeMenu();
        } else {
            menu.open_top = top;
            menu.hot_item = -1;
            menu.open_sub = -1;
            menu.hot_sub = -1;
            syncViewSize();
        }
        return;
    }
    if (menu.open_top >= 0) {
        const pr = popupLayout(menu.open_top);
        if (menu.open_sub >= 0) {
            const sr = subLayout(pr, menu.open_top, menu.open_sub);
            if (inside(.{ .x = sr.x, .y = sr.y, .w = sr.w, .h = sr.h }, x, y)) {
                const sm = subAt(menu.open_top, menu.open_sub) orelse return;
                const idx = entryIndexAt(sm.entries, y - sr.y);
                if (idx >= 0) {
                    switch (sm.entries[@intCast(idx)]) {
                        .item => |it| executeCommand(it.id),
                        else => {},
                    }
                }
                return;
            }
        }
        if (inside(.{ .x = pr.x, .y = pr.y, .w = pr.w, .h = pr.h }, x, y)) {
            const tm = topMenu(menu.open_top) orelse return;
            const idx = entryIndexAt(tm.entries, y - pr.y);
            if (idx >= 0) {
                switch (tm.entries[@intCast(idx)]) {
                    .item => |it| executeCommand(it.id),
                    .sub => {
                        menu.open_sub = idx;
                        menu.hot_sub = -1;
                        syncViewSize();
                    },
                    .sep => {},
                }
            }
            return;
        }
    }
    closeMenu();
}

fn menuMouseMove(x: i32, y: i32) void {
    const top = barIndexAt(x, y);
    if (top >= 0) {
        menu.hot_top = top;
        if (menu.open_top >= 0 and menu.open_top != top) {
            menu.open_top = top;
            menu.hot_item = -1;
            menu.open_sub = -1;
            menu.hot_sub = -1;
            syncViewSize();
        }
        return;
    }
    menu.hot_top = -1;
    if (menu.open_top < 0) return;
    const pr = popupLayout(menu.open_top);
    if (menu.open_sub >= 0) {
        const sr = subLayout(pr, menu.open_top, menu.open_sub);
        if (inside(.{ .x = sr.x, .y = sr.y, .w = sr.w, .h = sr.h }, x, y)) {
            const sm = subAt(menu.open_top, menu.open_sub) orelse return;
            menu.hot_sub = entryIndexAt(sm.entries, y - sr.y);
            return;
        }
        menu.hot_sub = -1;
    }
    if (inside(.{ .x = pr.x, .y = pr.y, .w = pr.w, .h = pr.h }, x, y)) {
        const tm = topMenu(menu.open_top) orelse return;
        const idx = entryIndexAt(tm.entries, y - pr.y);
        menu.hot_item = idx;
        if (idx >= 0) {
            switch (tm.entries[@intCast(idx)]) {
                .sub => {
                    if (menu.open_sub != idx) {
                        menu.open_sub = idx;
                        menu.hot_sub = -1;
                        syncViewSize();
                    }
                },
                else => {
                    if (menu.open_sub >= 0) {
                        menu.open_sub = -1;
                        menu.hot_sub = -1;
                    }
                },
            }
        } else if (menu.open_sub >= 0) {
            menu.open_sub = -1;
            menu.hot_sub = -1;
        }
        return;
    }
    menu.hot_item = -1;
    if (menu.open_sub >= 0) {
        menu.open_sub = -1;
        menu.hot_sub = -1;
    }
}

fn popupRightExtent() struct { w: i32, h: i32 } {
    var ww: i32 = 0;
    var hh: i32 = 0;
    if (menu.open_top >= 0) {
        const pr = popupLayout(menu.open_top);
        ww = pr.x + pr.w;
        hh = pr.y + pr.h;
        if (menu.open_sub >= 0) {
            const sr = subLayout(pr, menu.open_top, menu.open_sub);
            ww = @max(ww, sr.x + sr.w);
            hh = @max(hh, sr.y + sr.h);
        }
    }
    return .{ .w = ww, .h = hh };
}

// ------------------------------------------------------------------ 菜单绘制
fn drawMenuBar(canv: *Canvas) void {
    canv.fill(0, 0, canv.w, MENU_BAR_H, cv.C_MENU_BG);
    canv.fill(0, MENU_BAR_H - 1, canv.w, 1, cv.C_SHADOW);
    var x: i32 = 0;
    var i: i32 = 0;
    while (i < @as(i32, @intCast(top_menus.len))) : (i += 1) {
        const tm = top_menus[@intCast(i)];
        const bw = barItemWidth(tm);
        const hot = menu.open_top == i or (menu.open_top < 0 and menu.hot_top == i);
        if (hot) canv.fill(x, 0, bw, MENU_BAR_H - 1, cv.C_MENU_HOT);
        const label = barLabel(tm);
        const th = textHeight(14);
        drawText(canv, label, x + 9, @divTrunc(MENU_BAR_H - th, 2), 14, if (hot) cv.C_MENU_HOT_TEXT else cv.C_BLACK);
        x += bw;
    }
    if (menu.open_top >= 0) {
        const pr = popupLayout(menu.open_top);
        drawPopup(canv, menu.open_top, pr, menu.hot_item);
        if (menu.open_sub >= 0) {
            const sr = subLayout(pr, menu.open_top, menu.open_sub);
            if (subAt(menu.open_top, menu.open_sub)) |sm| {
                drawPopupEntries(canv, sr, sm.entries, menu.hot_sub);
            }
        }
    }
}

fn drawPopup(canv: *Canvas, top: i32, pr: PopupLayout, hot: i32) void {
    const tm = topMenu(top) orelse return;
    drawPopupEntries(canv, pr, tm.entries, hot);
}

fn drawPopupEntries(canv: *Canvas, pr: PopupLayout, entries: []const MenuEntry, hot: i32) void {
    canv.fill(pr.x, pr.y, pr.w, pr.h, cv.C_MENU_BG);
    canv.draw3d(pr.x, pr.y, pr.w, pr.h, 1, true);
    var y = pr.y + 3;
    for (entries, 0..) |e, idx| {
        const h = entryH(e);
        const is_hot = hot == @as(i32, @intCast(idx));
        switch (e) {
            .sep => {
                canv.fill(pr.x + 6, y + 3, pr.w - 12, 1, cv.C_SHADOW);
                canv.fill(pr.x + 6, y + 4, pr.w - 12, 1, cv.C_HILIGHT);
            },
            .item => |it| {
                if (is_hot) canv.fill(pr.x + 2, y, pr.w - 4, h, cv.C_MENU_HOT);
                const fg = if (is_hot) cv.C_MENU_HOT_TEXT else cv.C_BLACK;
                const parts = splitLabel(it.label);
                const th = textHeight(14);
                if (itemChecked(it)) drawRadioDot(canv, pr.x + 14, y + @divTrunc(h, 2));
                drawText(canv, parts.main, pr.x + 26, y + @divTrunc(h - th, 2), 14, fg);
                if (parts.shortcut.len > 0) {
                    const sw = textWidth(parts.shortcut, 14);
                    drawText(canv, parts.shortcut, pr.x + pr.w - 12 - sw, y + @divTrunc(h - th, 2), 14, if (is_hot) cv.C_MENU_HOT_TEXT else cv.C_DARKGRAY);
                }
            },
            .sub => |sm| {
                if (is_hot) canv.fill(pr.x + 2, y, pr.w - 4, h, cv.C_MENU_HOT);
                const fg = if (is_hot) cv.C_MENU_HOT_TEXT else cv.C_BLACK;
                const th = textHeight(14);
                drawText(canv, sm.label, pr.x + 26, y + @divTrunc(h - th, 2), 14, fg);
                drawSubArrow(canv, pr.x + pr.w - 16, y + @divTrunc(h, 2));
            },
        }
        y += h;
    }
}

// ------------------------------------------------------------------ 视图尺寸
fn baseViewSize() struct { w: i32, h: i32 } {
    const L = layout();
    return .{ .w = L.client_w, .h = MENU_BAR_H + L.client_h };
}

fn syncTexture() void {
    const r = renderer orelse return;
    if (texture) |t| {
        if (tex_w == canvas.w and tex_h == canvas.h) {
            _ = c.SDL_SetRenderLogicalPresentation(r, canvas.w, canvas.h, c.SDL_LOGICAL_PRESENTATION_LETTERBOX);
            return;
        }
        c.SDL_DestroyTexture(t);
        texture = null;
    }
    texture = c.SDL_CreateTexture(r, c.SDL_PIXELFORMAT_ARGB8888, c.SDL_TEXTUREACCESS_STREAMING, canvas.w, canvas.h);
    tex_w = canvas.w;
    tex_h = canvas.h;
    if (texture) |t| _ = c.SDL_SetTextureScaleMode(t, c.SDL_SCALEMODE_NEAREST);
    _ = c.SDL_SetRenderLogicalPresentation(r, canvas.w, canvas.h, c.SDL_LOGICAL_PRESENTATION_LETTERBOX);
}

fn syncViewSize() void {
    const base = baseViewSize();
    var ww = base.w;
    var hh = base.h;
    const ext = popupRightExtent();
    if (ext.w > 0) ww = @max(ww, ext.w + 4);
    if (ext.h > 0) hh = @max(hh, ext.h + 4);
    if (overlay.kind == .dialog) {
        ww = @max(ww, DLG_W + 40);
        hh = @max(hh, DLG_H + DLG_TITLE_H + 40);
    } else if (overlay.kind == .message) {
        const sz = messageBoxSize();
        ww = @max(ww, sz.w + 40);
        hh = @max(hh, sz.h + 40);
    }
    canvas.resize(ww, hh) catch return;
    if (window) |win| {
        var cw0: i32 = 0;
        var ch0: i32 = 0;
        _ = c.SDL_GetWindowSize(win, &cw0, &ch0);
        if (cw0 != ww or ch0 != hh) _ = c.SDL_SetWindowSize(win, ww, hh);
    }
    syncTexture();
}

fn resizeWindowForBoard() void {
    syncViewSize();
}

// ------------------------------------------------------------------ 渲染
fn renderFrame() void {
    if (canvas.px.len == 0) return;
    @memset(canvas.px, cv.C_BTNFACE);
    canvas.oy = MENU_BAR_H;
    paintGame(&canvas, layout());
    canvas.oy = 0;
    drawMenuBar(&canvas);
    switch (overlay.kind) {
        .none => {},
        .dialog => drawDialog(&canvas),
        .message => drawMessage(&canvas),
    }
    const r = renderer orelse return;
    const t = texture orelse return;
    _ = c.SDL_SetRenderDrawColor(r, 0, 0, 0, 255);
    _ = c.SDL_RenderClear(r);
    _ = c.SDL_UpdateTexture(t, null, canvas.px.ptr, canvas.w * 4);
    var dst = c.SDL_FRect{ .x = 0, .y = 0, .w = @floatFromInt(canvas.w), .h = @floatFromInt(canvas.h) };
    _ = c.SDL_RenderTexture(r, t, null, &dst);
    _ = c.SDL_RenderPresent(r);
}

// ------------------------------------------------------------------ 输入
fn cancelHeld() void {
    face_down = false;
    face_armed = false;
    press_cell = -1;
    chord_cell = -1;
    l_down = false;
    r_down = false;
    m_down = false;
}

fn onLeftDown(x: i32, y: i32) void {
    const L = layout();
    const on_face = inFace(L, x, y);
    l_down = true;
    face_armed = on_face;
    face_down = on_face;
    const cell = cellAt(L, x, y);
    if (r_down) {
        chord_cell = cell;
        press_cell = -1;
    } else {
        press_cell = if (cell >= 0 and !on_face and !game.over and game.open[@intCast(cell)] == 0) cell else -1;
    }
}

fn onLeftUp(x: i32, y: i32) void {
    const L = layout();
    const held = press_cell;
    const chord = chord_cell;
    const was_face = face_armed;
    l_down = false;
    press_cell = -1;
    chord_cell = -1;
    face_down = false;
    face_armed = false;
    if (!r_down and !m_down) _ = c.SDL_CaptureMouse(false);
    if (was_face and inFace(L, x, y)) {
        startNewGame(null);
        return;
    }
    if (chord >= 0) {
        if (cellAt(L, x, y) == chord) doExpand(@intCast(chord));
        return;
    }
    if (held >= 0 and cellAt(L, x, y) == held and !game.over and game.flag[@intCast(held)] == 0) {
        const cell: usize = @intCast(held);
        const covered = game.open[cell] == 0;
        if (!game.started) {
            game.startAt(cell, nowMs());
            game.setMsg(.started);
            tick_second = -1;
        } else {
            game.reveal(cell, nowMs());
            afterGameAction();
        }
        if (covered and !game.over) flashFace();
    }
}

fn onRightDown(x: i32, y: i32) void {
    r_down = true;
    const L = layout();
    const cell = cellAt(L, x, y);
    if (l_down) {
        chord_cell = cell;
        press_cell = -1;
        return;
    }
    if (cell >= 0 and !game.over and game.open[@intCast(cell)] == 0) {
        if (game.cycleFlag(@intCast(cell))) flashFace();
    }
}

fn onRightUp(x: i32, y: i32) void {
    r_down = false;
    const chord = chord_cell;
    if (chord >= 0) {
        const L = layout();
        chord_cell = -1;
        press_cell = -1;
        face_down = false;
        if (cellAt(L, x, y) == chord) doExpand(@intCast(chord));
    }
    if (!l_down and !m_down) _ = c.SDL_CaptureMouse(false);
}

fn onMiddleDown(x: i32, y: i32) void {
    const L = layout();
    m_down = true;
    chord_cell = cellAt(L, x, y);
    press_cell = -1;
}

fn onMiddleUp(x: i32, y: i32) void {
    const L = layout();
    const chord = chord_cell;
    m_down = false;
    chord_cell = -1;
    face_down = false;
    if (!l_down and !r_down) _ = c.SDL_CaptureMouse(false);
    if (chord >= 0 and cellAt(L, x, y) == chord) doExpand(@intCast(chord));
}

fn onMouseMove(x: i32, y: i32) void {
    const L = layout();
    const cell = cellAt(L, x, y);
    if (chord_cell >= 0) {
        chord_cell = if (cell >= 0) cell else -1;
        return;
    }
    if (press_cell < 0) return;
    press_cell = if (cell >= 0 and game.open[@intCast(cell)] == 0) cell else -1;
}

fn handleCommand(id: usize) void {
    switch (id) {
        IDM_NEW => startNewGame(null),
        IDM_BEGINNER => setPreset(0, .complex),
        IDM_INTERMEDIATE => setPreset(1, .complex),
        IDM_EXPERT => setPreset(2, .complex),
        IDM_CUSTOM => {
            _ = openDialog();
        },
        IDM_HYPER_BEGINNER => setPreset(0, .hyper),
        IDM_HYPER_INTERMEDIATE => setPreset(1, .hyper),
        IDM_HYPER_EXPERT => setPreset(2, .hyper),
        IDM_HYPER_CUSTOM => {
            _ = openDialog();
        },
        IDM_BEST => showBestScores(false, .complex),
        IDM_HYPER_BEST => showBestScores(false, .hyper),
        IDM_SOUND => toggleSound(),
        IDM_COLOR => toggleColor(),
        IDM_EXIT => quit_requested = true,
        IDM_ZOOM1, IDM_ZOOM2, IDM_ZOOM3 => {
            zoom = switch (id) {
                IDM_ZOOM1 => 1,
                IDM_ZOOM2 => 2,
                else => 3,
            };
            resizeWindowForBoard();
        },
        IDM_HELP_HOW => showHelp(),
        IDM_HELP_ABOUT => showAbout(),
        else => {},
    }
}

fn keyDown(key: u32, repeat: bool) void {
    if (overlay.kind == .dialog) {
        dlgKey(key, repeat);
        return;
    }
    if (overlay.kind == .message) {
        if (key == 0x0D or key == 0x1B or key == 0x20) closeMessage();
        return;
    }
    if (menu.open_top >= 0) {
        if (key == 0x1B) closeMenu();
        return;
    }
    if (key == 0x72 or key == 0x4000003B) startNewGame(null);
}

fn textInput(text: []const u8) void {
    if (overlay.kind == .dialog) dlgTextInput(text);
}

fn handleEvents() void {
    var ev: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&ev)) {
        if (ev.type == c.SDL_EVENT_QUIT or ev.type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED) {
            quit_requested = true;
        } else if (ev.type == c.SDL_EVENT_WINDOW_FOCUS_LOST) {
            cancelHeld();
        } else if (ev.type == c.SDL_EVENT_WINDOW_MOUSE_LEAVE) {
            menu.hot_top = -1;
            if (l_down or r_down or m_down) cancelHeld();
        } else if (ev.type == c.SDL_EVENT_KEY_DOWN) {
            keyDown(ev.key.key, ev.key.repeat);
        } else if (ev.type == c.SDL_EVENT_TEXT_INPUT) {
            textInput(std.mem.span(ev.text.text));
        } else if (ev.type == c.SDL_EVENT_MOUSE_MOTION) {
            const p = toCanvas(ev.motion.x, ev.motion.y);
            if (overlay.kind != .none) continue;
            if (menu.open_top >= 0 or p.y < MENU_BAR_H) {
                menuMouseMove(p.x, p.y);
            }
        } else if (ev.type == c.SDL_EVENT_MOUSE_BUTTON_DOWN) {
            const p = toCanvas(ev.button.x, ev.button.y);
            const btn = ev.button.button;
            if (overlay.kind == .message) {
                messageMouseDown(p.x, p.y);
                swallow_mouse_up = true;
                continue;
            }
            if (overlay.kind == .dialog) {
                dlgMouseDown(p.x, p.y);
                swallow_mouse_up = true;
                continue;
            }
            if (menu.open_top >= 0 or p.y < MENU_BAR_H) {
                menuMouseDown(p.x, p.y);
                swallow_mouse_up = true;
                continue;
            }
            const gy = p.y - MENU_BAR_H;
            if (btn == c.SDL_BUTTON_LEFT) {
                onLeftDown(p.x, gy);
                _ = c.SDL_CaptureMouse(true);
            } else if (btn == c.SDL_BUTTON_RIGHT) {
                onRightDown(p.x, gy);
                _ = c.SDL_CaptureMouse(true);
            } else if (btn == c.SDL_BUTTON_MIDDLE) {
                onMiddleDown(p.x, gy);
                _ = c.SDL_CaptureMouse(true);
            }
        } else if (ev.type == c.SDL_EVENT_MOUSE_BUTTON_UP) {
            if (swallow_mouse_up) {
                swallow_mouse_up = false;
                continue;
            }
            if (overlay.kind != .none or menu.open_top >= 0) continue;
            const p = toCanvas(ev.button.x, ev.button.y);
            const gy = p.y - MENU_BAR_H;
            const btn = ev.button.button;
            if (btn == c.SDL_BUTTON_LEFT) {
                onLeftUp(p.x, gy);
            } else if (btn == c.SDL_BUTTON_RIGHT) {
                onRightUp(p.x, gy);
            } else if (btn == c.SDL_BUTTON_MIDDLE) {
                onMiddleUp(p.x, gy);
            }
        }
    }
}

fn toCanvas(wx: f32, wy: f32) struct { x: i32, y: i32 } {
    var lx: f32 = wx;
    var ly: f32 = wy;
    if (renderer) |r| {
        if (!c.SDL_RenderCoordinatesFromWindow(r, wx, wy, &lx, &ly)) {
            lx = wx;
            ly = wy;
        }
    }
    return .{ .x = @intFromFloat(lx), .y = @intFromFloat(ly) };
}

fn tick() void {
    if (game.started and !game.over) {
        game.elapsed_ms = nowMs() -% game.t0;
        maybePlayTick();
    }
    audio.update();
}

// ------------------------------------------------------------------ 图集 / SDL
fn loadAtlas() bool {
    atlas_img = cv.Image.fromCsat(A.blob) orelse return false;
    if (atlas_img.?.w != A.atlas_w or atlas_img.?.h != A.atlas_h) return false;
    atlas_bw = cv.Image.fromCsbw(A.blob_bw);
    bw_loaded = atlas_bw != null;
    if (bw_loaded and (atlas_bw.?.w != A.atlas_w or atlas_bw.?.h != A.atlas_h)) {
        atlas_bw.?.deinit();
        atlas_bw = null;
        bw_loaded = false;
    }
    const r = A.rect(A.icon);
    icon_ok = r.w == 32 and r.h == 32;
    return true;
}

fn setWindowIcon(win: *c.SDL_Window) void {
    const r = A.rect(A.icon);
    if (r.w != 32 or r.h != 32) return;
    const surf_c = c.SDL_CreateSurface(32, 32, c.SDL_PIXELFORMAT_ARGB8888) orelse return;
    const surf: *c.SDL_Surface = @ptrCast(surf_c);
    defer c.SDL_DestroySurface(surf_c);
    const dst: [*]u8 = @ptrCast(surf.pixels.?);
    const pitch: usize = @intCast(surf.pitch);
    const off: usize = 12 + @as(usize, A.count) * 8;
    var y: i32 = 0;
    while (y < 32) : (y += 1) {
        const src = off + (@as(usize, @intCast(r.y + y)) * A.atlas_w + @as(usize, @intCast(r.x))) * 4;
        @memcpy(dst[@as(usize, @intCast(y)) * pitch ..][0 .. 32 * 4], A.blob[src..][0 .. 32 * 4]);
    }
    _ = c.SDL_SetWindowIcon(win, surf);
}

fn initHeadlessFont() void {
    _ = c.SDL_Init(0);
    sdl_inited = true;
    font = FontMod.Font.open();
}

fn cleanup() void {
    if (texture) |t| c.SDL_DestroyTexture(t);
    texture = null;
    if (renderer) |r| c.SDL_DestroyRenderer(r);
    renderer = null;
    if (window) |win| c.SDL_DestroyWindow(win);
    window = null;
    if (font) |*f| f.close();
    font = null;
    audio.deinit();
    if (atlas_img) |*im| im.deinit();
    atlas_img = null;
    if (atlas_bw) |*im| im.deinit();
    atlas_bw = null;
    if (canvas.px.len != 0) canvas.deinit();
    if (sdl_inited) c.SDL_Quit();
    sdl_inited = false;
}

fn runInteractive() void {
    _ = c.SDL_SetAppMetadata("Complexweeper", APP_VERSION, "io.github.complexweeper");
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.debug.print("SDL_Init 失败：{s}\n", .{std.mem.span(c.SDL_GetError())});
        return;
    }
    sdl_inited = true;
    const base = baseViewSize();
    window = c.SDL_CreateWindow(APP_TITLE.ptr, base.w, base.h, c.SDL_WINDOW_HIGH_PIXEL_DENSITY);
    if (window == null) {
        std.debug.print("SDL_CreateWindow 失败：{s}\n", .{std.mem.span(c.SDL_GetError())});
        return;
    }
    renderer = c.SDL_CreateRenderer(window.?, null);
    if (renderer == null) {
        std.debug.print("SDL_CreateRenderer 失败：{s}\n", .{std.mem.span(c.SDL_GetError())});
        return;
    }
    setWindowIcon(window.?);
    font = FontMod.Font.open();
    if (font == null) std.debug.print("没有找到可用的中文字体，菜单文字将不会显示。\n", .{});
    prefs = prefsmod.Prefs.load();
    prefs_ready = true;
    sound_off = !prefs.state.sound_on;
    color_off = !prefs.state.color_on;
    loadScores();
    audio = audiomod.Audio.init();

    canvas = Canvas.init(base.w, base.h) catch return;
    syncViewSize();
    _ = c.SDL_ShowWindow(window.?);
    while (!quit_requested) {
        handleEvents();
        if (quit_requested) break;
        tick();
        renderFrame();
        c.SDL_Delay(8);
    }
}

// ------------------------------------------------------------------ 入口
const selftest = @import("selftest.zig");
const uitest = @import("uitest.zig");

var shot_path_buf: [512]u8 = undefined;
var shot_path_len: usize = 0;
var selftest_path_buf: [512]u8 = undefined;
var selftest_path_len: usize = 0;
var uitest_path_buf: [512]u8 = undefined;
var uitest_path_len: usize = 0;
var dump_path_buf: [512]u8 = undefined;
var dump_path_len: usize = 0;

fn copyPath(dst: []u8, src: []const u8) usize {
    const n = @min(src.len, dst.len);
    @memcpy(dst[0..n], src[0..n]);
    return n;
}

fn shotPath() ?[]const u8 {
    if (shot_path_len == 0) return null;
    return shot_path_buf[0..shot_path_len];
}
fn selftestPath() ?[]const u8 {
    if (selftest_path_len == 0) return null;
    return selftest_path_buf[0..selftest_path_len];
}
fn uitestPath() ?[]const u8 {
    if (uitest_path_len == 0) return null;
    return uitest_path_buf[0..uitest_path_len];
}
fn dumpPath() ?[]const u8 {
    if (dump_path_len == 0) return null;
    return dump_path_buf[0..dump_path_len];
}

var window_shot = false;
var sheet_mode = false;

const DemoMode = enum { none, mid, lose, win, custom, hyper, judge_lose, judge_win };
var demo_mode: DemoMode = .none;

fn parseArgs() void {
    var it = std.process.argsWithAllocator(std.heap.page_allocator) catch return;
    defer it.deinit();
    var expect: enum { none, shot, selftest, dump, uitest } = .none;
    var first = true;
    while (it.next()) |arg| {
        if (first) {
            first = false;
            continue;
        }
        arg_count += 1;
        switch (expect) {
            .shot => {
                shot_path_len = copyPath(&shot_path_buf, arg);
                expect = .none;
                continue;
            },
            .selftest => {
                selftest_path_len = copyPath(&selftest_path_buf, arg);
                expect = .none;
                continue;
            },
            .dump => {
                dump_path_len = copyPath(&dump_path_buf, arg);
                expect = .none;
                continue;
            },
            .uitest => {
                uitest_path_len = copyPath(&uitest_path_buf, arg);
                expect = .none;
                continue;
            },
            .none => {},
        }
        if (std.mem.eql(u8, arg, "--shot")) expect = .shot;
        if (std.mem.eql(u8, arg, "--selftest")) expect = .selftest;
        if (std.mem.eql(u8, arg, "--dump")) expect = .dump;
        if (std.mem.eql(u8, arg, "--uitest")) expect = .uitest;
        if (std.mem.eql(u8, arg, "--demo")) demo_mode = .mid;
        if (std.mem.eql(u8, arg, "--demo-lose")) demo_mode = .lose;
        if (std.mem.eql(u8, arg, "--demo-win")) demo_mode = .win;
        if (std.mem.eql(u8, arg, "--custom")) demo_mode = .custom;
        if (std.mem.eql(u8, arg, "--demo-hyper")) demo_mode = .hyper;
        if (std.mem.eql(u8, arg, "--demo-judge")) demo_mode = .judge_lose;
        if (std.mem.eql(u8, arg, "--demo-judge-win")) demo_mode = .judge_win;
        if (std.mem.eql(u8, arg, "--zoom1")) zoom = 1;
        if (std.mem.eql(u8, arg, "--zoom2")) zoom = 2;
        if (std.mem.eql(u8, arg, "--zoom3")) zoom = 3;
        if (std.mem.eql(u8, arg, "--shot-window")) {
            window_shot = true;
            if (shot_path_len == 0) expect = .shot;
        }
        if (std.mem.eql(u8, arg, "--sheet")) {
            sheet_mode = true;
            if (shot_path_len == 0) expect = .shot;
        }
        if (std.mem.eql(u8, arg, "--quiet")) scores_quiet = true;
    }
}

fn setupDemo() void {
    switch (demo_mode) {
        .none => return,
        .judge_lose => {
            game.mode = .complex;
            game.w = 16;
            game.h = 16;
            game.mines = 40;
            game.newGame(20260101);
            game.startAt(8 * 16 + 8, 0);
            game.setMsg(.started);
            game.elapsed_ms = 61_000;
            syncMode();
            var host: usize = 0;
            var found = false;
            for (0..game.n) |i| {
                if (game.open[i] == 0 or game.mine[i] != 0) continue;
                var buf: [8]usize = undefined;
                const k = game.nbrs(i, &buf);
                var mi: u32 = 0;
                var fr: u32 = 0;
                for (buf[0..k]) |j| {
                    if (game.mine[j] != 0) {
                        mi += 1;
                    } else if (game.open[j] == 0) {
                        fr += 1;
                    }
                }
                if (mi >= 2 and fr >= 1) {
                    host = i;
                    found = true;
                    break;
                }
            }
            if (found) {
                var buf: [8]usize = undefined;
                const k = game.nbrs(host, &buf);
                var mi: u32 = 0;
                var fr: u32 = 0;
                for (buf[0..k]) |j| {
                    if (game.mine[j] != 0) {
                        mi += 1;
                        const f: u8 = if (mi == 1) game.mine[j] else @as(u8, if (game.mine[j] == 1) 2 else 1);
                        _ = game.setFlag(j, f);
                    } else if (game.open[j] == 0 and fr == 0) {
                        _ = game.setFlag(j, 3);
                        fr += 1;
                    }
                }
            }
            for (0..game.n) |i| {
                if (game.mine[i] != 0 and game.flag[i] == 0) {
                    game.reveal(i, 0);
                    break;
                }
            }
            return;
        },
        .judge_win => {
            game.mode = .complex;
            game.w = 9;
            game.h = 9;
            game.mines = 10;
            game.newGame(20260101);
            game.startAt(40, 0);
            game.setMsg(.started);
            game.elapsed_ms = 27_000;
            syncMode();
            var mi: u32 = 0;
            for (0..game.n) |i| {
                if (game.mine[i] == 0) continue;
                mi += 1;
                const f: u8 = if (mi % 2 == 1) game.mine[i] else @as(u8, if (game.mine[i] == 1) 2 else 1);
                _ = game.setFlag(i, f);
            }
            for (0..game.n) |i| {
                if (game.mine[i] == 0 and game.open[i] == 0) game.reveal(i, 0);
            }
            afterGameAction();
            return;
        },
        .hyper => {
            game.mode = .hyper;
            game.w = 16;
            game.h = 16;
            game.mines = 40;
            game.newGame(20260101);
            game.startAt(8 * 16 + 8, 0);
            game.setMsg(.started);
            game.elapsed_ms = 83_000;
            syncMode();
            var i: usize = 0;
            var opened: u32 = 0;
            while (i < game.n and opened < 24) : (i += 1) {
                if (game.mine[i] != 0 or game.open[i] != 0) continue;
                game.reveal(i, 0);
                opened += 1;
                if (game.over) break;
            }
            var flagged: u32 = 0;
            i = 0;
            while (i < game.n and flagged < 8) : (i += 1) {
                if (game.open[i] != 0) continue;
                _ = game.setFlag(i, @intCast(1 + (flagged % 4)));
                flagged += 1;
            }
            return;
        },
        .custom => {
            game.w = 12;
            game.h = 12;
            game.mines = 14;
            game.type_count = .{ 0, 0, 7, 0, 7 };
            game.newGame(20260101);
            game.startAt(6 * 12 + 6, 0);
            game.setMsg(.started);
            game.elapsed_ms = 42_000;
            return;
        },
        else => {},
    }
    game.w = 16;
    game.h = 16;
    game.mines = 40;
    game.newGame(20260101);
    game.startAt(8 * 16 + 8, 0);
    game.setMsg(.started);
    game.elapsed_ms = 83_000;

    if (demo_mode == .mid) {
        var i: usize = 0;
        var opened: u32 = 0;
        while (i < game.n and opened < 14) : (i += 1) {
            if (game.mine[i] != 0 or game.open[i] != 0) continue;
            game.reveal(i, 0);
            opened += 1;
        }
        var flagged: u32 = 0;
        i = 0;
        while (i < game.n and flagged < 6) : (i += 1) {
            if (game.open[i] != 0) continue;
            _ = game.setFlag(i, @intCast(1 + (flagged % 4)));
            flagged += 1;
        }
    } else if (demo_mode == .win) {
        for (0..game.n) |i| {
            if (game.mine[i] == 0 and game.open[i] == 0) game.reveal(i, 0);
        }
        afterGameAction();
    } else if (demo_mode == .lose) {
        var i: usize = 0;
        var flagged: u32 = 0;
        while (i < game.n and flagged < 4) : (i += 1) {
            if (game.open[i] != 0 or game.mine[i] != 0) continue;
            _ = game.setFlag(i, @intCast(1 + (flagged % 4)));
            flagged += 1;
        }
        i = 0;
        while (i < game.n) : (i += 1) {
            if (game.mine[i] == 2) {
                game.reveal(i, 0);
                break;
            }
        }
    }
}

fn renderToFile(path: []const u8) void {
    const L = layout();
    canvas.oy = 0;
    paintGame(&canvas, L);
    _ = canvas.saveBmp(path);
}

fn captureWindow(path: []const u8) void {
    const L = layout();
    @memset(canvas.px, cv.C_BTNFACE);
    canvas.oy = MENU_BAR_H;
    paintGame(&canvas, L);
    canvas.oy = 0;
    drawMenuBar(&canvas);
    _ = canvas.saveBmp(path);
}

fn renderSheet(path: []const u8) void {
    const z: i32 = 3;
    const cellw = 16 * z + 6;
    const cellh = 16 * z + 22;
    const w0: i32 = 24 * cellw + 20;
    const y0: i32 = 6;
    const y1: i32 = y0 + cellh;
    const y2: i32 = y1 + cellh;
    const y3: i32 = y2 + cellh;
    const y4: i32 = y3 + 24 * z + 8;
    const h0: i32 = y4 + 24 * z + 12;
    canvas.resize(w0, h0) catch return;
    canvas.oy = 0;
    canvas.fill(0, 0, w0, h0, cv.C_BTNFACE);

    var x: i32 = 10;
    for (g.ACHIEVABLE) |D| {
        const spr = A.num_by_D[D];
        blitSpriteSq(&canvas, spr, x, y0, 16 * z);
        var txt: [32]u8 = undefined;
        const s = std.fmt.bufPrint(&txt, "D={d}", .{D}) catch "?";
        drawTextCentered(&canvas, s, x + 8 * z, y0 + 16 * z + 2, 13, cv.C_BLACK);
        x += cellw;
    }

    var x2: i32 = 10;
    const row2 = [_]struct { s: u16, label: []const u8 }{
        .{ .s = A.closed, .label = "closed" },
        .{ .s = A.blank, .label = "blank" },
        .{ .s = A.flag_1, .label = "+1" },
        .{ .s = A.flag_2, .label = "-1" },
        .{ .s = A.flag_3, .label = "+i" },
        .{ .s = A.flag_4, .label = "-i" },
        .{ .s = A.mine_1, .label = "m+1" },
        .{ .s = A.mine_2, .label = "m-1" },
        .{ .s = A.mine_3, .label = "m+i" },
        .{ .s = A.mine_4, .label = "m-i" },
    };
    for (row2) |it| {
        blitSpriteSq(&canvas, it.s, x2, y1, 16 * z);
        drawTextCentered(&canvas, it.label, x2 + 8 * z, y1 + 16 * z + 2, 13, cv.C_BLACK);
        x2 += cellw;
    }

    var x3: i32 = 10;
    const row3 = [_]struct { s: u16, label: []const u8 }{
        .{ .s = A.boom_1, .label = "boom+1" },
        .{ .s = A.boom_2, .label = "boom-1" },
        .{ .s = A.boom_3, .label = "boom+i" },
        .{ .s = A.boom_4, .label = "boom-i" },
        .{ .s = A.wrong_1, .label = "wrong+1" },
        .{ .s = A.wrong_2, .label = "wrong-1" },
        .{ .s = A.wrong_3, .label = "wrong+i" },
        .{ .s = A.wrong_4, .label = "wrong-i" },
    };
    for (row3) |it| {
        blitSpriteSq(&canvas, it.s, x3, y2, 16 * z);
        drawTextCentered(&canvas, it.label, x3 + 8 * z, y2 + 16 * z + 2, 13, cv.C_BLACK);
        x3 += cellw;
    }

    var x4: i32 = 10;
    var d: u16 = 0;
    while (d <= 9) : (d += 1) {
        blitSprite(&canvas, digitSprite(@intCast('0' + d)), x4, y3, 13 * z, 23 * z);
        x4 += 13 * z + 4;
    }
    blitSprite(&canvas, A.led_blank, x4, y3, 13 * z, 23 * z);
    x4 += 13 * z + 4;
    blitSprite(&canvas, A.led_minus, x4, y3, 13 * z, 23 * z);
    x4 += 13 * z + 4;
    blitSprite(&canvas, A.led_i, x4, y3, 13 * z, 23 * z);

    var x5: i32 = 10;
    for ([_]u16{ A.face_normal, A.face_down, A.face_scan, A.face_dead, A.face_win }) |f| {
        blitSpriteSq(&canvas, f, x5, y4, 24 * z);
        x5 += 24 * z + 8;
    }
    const sx = x5 + 20;
    const sw = 4 * 13 * z + 10;
    const sy = y4;
    _ = drawLed(&canvas, sx, sy, 83, 4, z);
    _ = drawLed(&canvas, sx + sw, sy, -14, 4, z);
    var vx = sx + 2 * sw;
    _ = drawLed(&canvas, vx, sy, 7, 3, z);
    blitSprite(&canvas, A.led_i, vx + 3 * 13 * z, sy, 13 * z, 23 * z);
    vx = sx + 3 * sw;
    _ = drawLed(&canvas, vx, sy, -7, 3, z);
    blitSprite(&canvas, A.led_i, vx + 3 * 13 * z, sy, 13 * z, 23 * z);

    _ = canvas.saveBmp(path);
}

fn dumpState(path: []const u8) void {
    const f = std.fs.cwd().createFile(path, .{}) catch return;
    defer f.close();
    var s = std.ArrayList(u8).init(std.heap.page_allocator);
    defer s.deinit();
    s.writer().print("棋盘 {d}×{d} · 雷 {d} · 已翻开 {d} · 开局格 {d}\n", .{ game.w, game.h, game.mines, game.openedCount(), game.start_cell }) catch {};
    s.writer().print("type_total  = {d} {d} {d} {d}\n", .{ game.type_total[1], game.type_total[2], game.type_total[3], game.type_total[4] }) catch {};
    s.writer().print("flags_of    = {d} {d} {d} {d}\n", .{ game.flags_of[1], game.flags_of[2], game.flags_of[3], game.flags_of[4] }) catch {};
    s.writer().print("unmarked    = {d} {d} {d} {d}\n", .{ game.unmarked(1), game.unmarked(2), game.unmarked(3), game.unmarked(4) }) catch {};
    s.writer().print("counterValue= {d} {d} {d} {d}\n", .{ counterValue(1), counterValue(2), counterValue(3), counterValue(4) }) catch {};
    s.writer().print("panelCells  = {d} {d} {d} {d}   timer={d}\n", .{
        panelCells(false, counterShown(1)),                            panelCells(true, counterShown(2)),
        panelCells(true, counterShown(3)),                             panelCells(true, counterShown(4)),
        panelCells(false, if (game.started) timerSeconds() else null),
    }) catch {};
    s.writer().print("started={} over={} win={} elapsed_ms={d}\n", .{ game.started, game.over, game.win, game.elapsed_ms }) catch {};
    f.writeAll(s.items) catch {};
}

fn runSelftest(path: []const u8) u32 {
    var buf: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    var out = std.ArrayList(u8).init(fba.allocator());
    const fails = selftest.run(&out);
    const file = std.fs.cwd().createFile(path, .{}) catch return 2;
    defer file.close();
    file.writeAll(out.items) catch return 2;
    return if (fails == 0) 0 else 1;
}

fn runUiTest(path: []const u8) u32 {
    const buf = std.heap.page_allocator;
    var out = std.ArrayList(u8).init(buf);
    defer out.deinit();
    const fails = uitest.run(&out);
    const file = std.fs.cwd().createFile(path, .{}) catch return 2;
    defer file.close();
    file.writeAll(out.items) catch return 2;
    return if (fails == 0) 0 else 1;
}

pub fn main() void {
    parseArgs();
    sound_muted = !interactive();
    if (selftestPath()) |p| {
        const code = runSelftest(p);
        std.process.exit(if (code == 0) 0 else 1);
    }
    if (!loadAtlas()) {
        std.debug.print("内置图集损坏，无法启动。\n", .{});
        return;
    }
    game.w = g.PRESETS[2].w;
    game.h = g.PRESETS[2].h;
    game.mines = g.PRESETS[2].mines;
    game.newGame(1);
    app_ready = true;
    if (uitestPath()) |p| {
        const code = runUiTest(p);
        cleanup();
        std.process.exit(if (code == 0) 0 else 1);
    }
    if (shotPath()) |p| {
        initHeadlessFont();
        setupDemo();
        if (sheet_mode) {
            renderSheet(p);
        } else if (window_shot) {
            const base = baseViewSize();
            canvas.resize(base.w, base.h) catch {};
            captureWindow(p);
        } else {
            const L = layout();
            canvas.resize(L.client_w, L.client_h) catch {};
            renderToFile(p);
        }
        if (dumpPath()) |dp| dumpState(dp);
        cleanup();
        return;
    }
    runInteractive();
    cleanup();
}

// ------------------------------------------------------------------ 给 uitest 用的钩子
pub const game_ptr = &game;
pub const test_IDM_BEGINNER = IDM_BEGINNER;
pub const test_IDM_INTERMEDIATE = IDM_INTERMEDIATE;
pub const test_IDM_EXPERT = IDM_EXPERT;
pub const test_IDM_ZOOM1 = IDM_ZOOM1;
pub const test_IDM_ZOOM2 = IDM_ZOOM2;
pub const test_IDM_ZOOM3 = IDM_ZOOM3;
pub const test_IDM_NEW = IDM_NEW;
pub const test_IDM_HELP_HOW = IDM_HELP_HOW;
pub const test_IDM_HELP_ABOUT = IDM_HELP_ABOUT;
pub const test_IDM_BEST = IDM_BEST;
pub const test_IDM_HELP_TABLE_REMOVED: usize = 201;
pub const test_IDM_HYPER_BEGINNER = IDM_HYPER_BEGINNER;
pub const test_IDM_HYPER_INTERMEDIATE = IDM_HYPER_INTERMEDIATE;
pub const test_IDM_HYPER_EXPERT = IDM_HYPER_EXPERT;
pub const test_IDM_HYPER_CUSTOM = IDM_HYPER_CUSTOM;
pub const test_IDM_HYPER_BEST = IDM_HYPER_BEST;
pub const test_IDM_CUSTOM = IDM_CUSTOM;
pub const test_IDM_SOUND = IDM_SOUND;
pub const test_IDM_COLOR = IDM_COLOR;

pub fn testIsHyper() bool {
    return hyper();
}
pub fn testPresetIndex() i32 {
    return cur_preset;
}
pub fn testUnitSprite() u16 {
    return if (hyper()) A.led_j else A.led_i;
}
pub const testLedISprite = A.led_i;
pub const testLedJSprite = A.led_j;
pub fn testHnumSprite(D: i32) u16 {
    return A.hnum_by_D[@intCast(D + 64)];
}
pub const SpriteFamily = enum { mine, flag, boom, wrong, right, rightflag, wrongflag };
pub fn testSprite(f: SpriteFamily, hyper_mode: bool, t: u8) u16 {
    const tbl = switch (f) {
        .mine => if (hyper_mode) A.hmine_T else A.mine_T,
        .flag => if (hyper_mode) A.hflag_T else A.flag_T,
        .boom => if (hyper_mode) A.hboom_T else A.boom_T,
        .wrong => if (hyper_mode) A.hwrong_T else A.wrong_T,
        .right => if (hyper_mode) A.hright_T else A.right_T,
        .rightflag => if (hyper_mode) A.hrightflag_T else A.rightflag_T,
        .wrongflag => if (hyper_mode) A.hwrongflag_T else A.wrongflag_T,
    };
    return tbl[@min(@as(usize, t), 4)];
}
pub const testWrongBlankSprite = A.wrongblank_sprite;
pub fn testSoundOff() bool {
    return sound_off;
}
pub fn testAudible() bool {
    return audible();
}
pub fn testPopupItemChecked(top: i32, idx: i32) bool {
    const e = entryAt(top, idx) orelse return false;
    return switch (e) {
        .item => |it| itemChecked(it),
        else => false,
    };
}
pub fn testColorOff() bool {
    return color_off;
}
pub fn testActiveAtlasIsBw() bool {
    return color_off and bw_loaded;
}
pub fn testBwAtlasLoaded() bool {
    return bw_loaded;
}
pub fn testScoreKeysDiffer() bool {
    for (0..3) |i| {
        if (std.mem.eql(u8, SCORE_KEYS_CPLX[i], SCORE_KEYS_HYPER[i])) return false;
    }
    return true;
}
pub fn testSubItemId(top: i32, sub_idx: i32, j: i32) i32 {
    const sm = subAt(top, sub_idx) orelse return -1;
    if (j < 0 or j >= @as(i32, @intCast(sm.entries.len))) return -1;
    return switch (sm.entries[@intCast(j)]) {
        .item => |it| @intCast(it.id),
        else => 0,
    };
}
pub fn testSubItemChecked(top: i32, sub_idx: i32, j: i32) bool {
    const sm = subAt(top, sub_idx) orelse return false;
    if (j < 0 or j >= @as(i32, @intCast(sm.entries.len))) return false;
    return switch (sm.entries[@intCast(j)]) {
        .item => |it| itemChecked(it),
        else => false,
    };
}
pub fn testPopupItemId(top: i32, idx: i32) i32 {
    const e = entryAt(top, idx) orelse return -1;
    return switch (e) {
        .item => |it| @intCast(it.id),
        else => 0,
    };
}
pub fn testWindowReady() bool {
    return app_ready;
}
pub fn testWindowTitle() []const u8 {
    return APP_TITLE;
}
pub const testAppTitle = APP_TITLE;
pub const testAppVersion = APP_VERSION;
pub const testAboutText = ABOUT_TEXT;
pub const testHelpText = HELP_TEXT;
pub fn testIconResourceOk() bool {
    return icon_ok;
}
pub fn testCommand(id: usize) void {
    handleCommand(id);
}
pub fn testZoom() i32 {
    return zoom;
}
pub fn testLayout() Layout {
    return layout();
}
pub fn testFaceDown() bool {
    return face_down;
}
pub fn testFaceArmed() bool {
    return face_armed;
}
pub fn testPressCell() i32 {
    return press_cell;
}
pub fn testChordCell() i32 {
    return chord_cell;
}
pub const testBlankSprite = A.blank;
pub const testClosedSprite = A.closed;
pub fn testFaceX() i32 {
    return faceLeft(layout());
}
pub fn testFaceY() i32 {
    return faceTop(layout());
}
pub fn testCounterValue(t: usize) i32 {
    return counterValue(t);
}
pub fn testCounterCells() i32 {
    var widest: i32 = 0;
    for (1..5) |t| widest = @max(widest, panelCells(counterImag(t), counterShown(t)));
    return widest;
}
pub fn testCounterValueCells(t: usize) i32 {
    return panelValueDigits(counterImag(t), counterShown(t));
}
pub fn testTimerCells() i32 {
    const tv: ?i32 = if (game.started) timerSeconds() else null;
    return panelCells(false, tv);
}
pub fn testTimerValueCells() i32 {
    const tv: ?i32 = if (game.started) timerSeconds() else null;
    return panelValueDigits(false, tv);
}
pub fn testTimerWidth() i32 {
    return timerWidth(zoom);
}
pub fn testCounterImag(t: usize) bool {
    return counterImag(t);
}
pub fn testCountersWidth() i32 {
    return countersWidth(layout());
}
pub fn testSoundCount(i: usize) u32 {
    if (i >= snd.count) return 0;
    return sound_log[i];
}
pub fn testSoundBytes(i: usize) usize {
    return snd.wav(i).len;
}
pub fn testSoundIsRiff(i: usize) bool {
    const b = snd.wav(i);
    return b.len >= 44 and std.mem.eql(u8, b[0..4], "RIFF") and std.mem.eql(u8, b[8..12], "WAVE");
}
pub fn testSoundsEqual(i: usize, j: usize) bool {
    const a = snd.wav(i);
    const b = snd.wav(j);
    if (a.len != b.len) return false;
    return std.mem.eql(u8, a, b);
}
pub fn testSoundReset() void {
    sound_log = [_]u32{0} ** snd.count;
    over_sound_done = false;
    tick_second = -1;
}
pub fn testTimerTick() void {
    if (game.started and !game.over) {
        game.elapsed_ms = nowMs() -% game.t0;
    }
    maybePlayTick();
}
pub fn testSoundMuted() bool {
    return sound_muted;
}
pub fn testArgCount() usize {
    return arg_count;
}

pub const Mouse = enum {
    mousemove,
    lbutton_down,
    lbutton_up,
    lbutton_dblclk,
    rbutton_down,
    rbutton_up,
    rbutton_dblclk,
    mbutton_down,
    mbutton_up,
};

pub fn testMouse(msg: Mouse, x: i32, y: i32) void {
    switch (msg) {
        .mousemove => onMouseMove(x, y),
        .lbutton_down, .lbutton_dblclk => onLeftDown(x, y),
        .lbutton_up => onLeftUp(x, y),
        .rbutton_down, .rbutton_dblclk => onRightDown(x, y),
        .rbutton_up => onRightUp(x, y),
        .mbutton_down => onMiddleDown(x, y),
        .mbutton_up => onMiddleUp(x, y),
    }
}

pub fn testMenuHasId(id: usize) bool {
    for (top_menus) |tm| {
        if (menuEntriesHaveId(tm.entries, id)) return true;
    }
    return false;
}

fn menuEntriesHaveId(entries: []const MenuEntry, id: usize) bool {
    for (entries) |e| {
        switch (e) {
            .item => |it| {
                if (it.id == id) return true;
            },
            .sub => |sm| {
                if (menuEntriesHaveId(sm.entries, id)) return true;
            },
            .sep => {},
        }
    }
    return false;
}

pub fn testPopupCount(top: i32) i32 {
    const tm = topMenu(top) orelse return -1;
    return @intCast(tm.entries.len);
}

pub fn testKey(vk: u32) i32 {
    if (vk == 0x72 or vk == 0x4000003B) startNewGame(null);
    return 0;
}

pub fn testOpenDialog() bool {
    return openDialog();
}
pub fn testCloseDialog() void {
    closeDialog();
}
pub fn testSetEdit(idx: usize, v: i32) void {
    if (idx < 6) setEditInt(idx, v);
}
pub fn testApplyDialog() bool {
    dlgApply();
    if (dialog_done and !dialog_cancel) {
        applyCustomFromDialog();
        return true;
    }
    return false;
}
pub fn testDialogErrName() []const u8 {
    return switch (dlg_state.err) {
        .none => "none",
        .height => "height",
        .width => "width",
        .sum_zero => "sum_zero",
        .sum_big => "sum_big",
    };
}
pub fn testDialogDone() bool {
    return dialog_done;
}

var dlg_texts_buf: [4096]u8 = undefined;
fn appendDlgText(n: *usize, text: []const u8) void {
    if (text.len == 0) return;
    if (n.* > 0 and n.* < dlg_texts_buf.len) {
        dlg_texts_buf[n.*] = '|';
        n.* += 1;
    }
    appendStr(&dlg_texts_buf, n, text);
}

pub fn testDialogTexts() []const u8 {
    var n: usize = 0;
    appendDlgText(&n, "高度(H)：");
    appendDlgText(&n, "9 – 30 行");
    appendDlgText(&n, "宽度(W)：");
    appendDlgText(&n, "9 – 40 列");
    for (0..4) |k| appendDlgText(&n, dlgTypeLabels()[k]);
    for (0..4) |k| appendDlgText(&n, editText(k + 2));
    appendDlgText(&n, "按合计均分");
    appendDlgText(&n, dlgErrText(dlg_state.err));
    appendDlgText(&n, "确定");
    appendDlgText(&n, "取消");
    return dlg_texts_buf[0..n];
}
pub fn testDialogBgBrushIsWhite() bool {
    return dialog_open;
}
pub fn testSplitClick() void {
    if (dialog_open) dlgSplit();
}
pub fn testEditValue(idx: usize) i32 {
    return getEditInt(idx, -1);
}
pub fn testFaceSpriteIsWin() bool {
    return faceSprite() == A.face_win;
}
pub fn testFaceSpriteIsDown() bool {
    return faceSprite() == A.face_down;
}
pub fn testFaceSpriteIsScan() bool {
    return faceSprite() == A.face_scan;
}
pub fn testFaceFlashExpire() void {
    face_flash_until = 0;
}
pub fn testFaceSpriteIsDead() bool {
    return faceSprite() == A.face_dead;
}
pub fn testCellSprite(cell: usize) u16 {
    return cellSprite(cell);
}
pub fn testScoresStopPersist() void {
    scores_persist = false;
    scores_quiet = true;
}
pub fn testSetScores(v0: i32, v1: i32, v2: i32) void {
    testSetScoresHook(v0, v1, v2);
}
pub fn testGetScore(i: usize) i32 {
    return best_scores[i];
}
pub fn testScoresText() []const u8 {
    const n = buildScoresText(&scores_text_buf, best_scores);
    return scores_text_buf[0..n];
}
pub fn testBackdate(ms: u32) void {
    game.t0 = nowMs() -% ms;
}

// ------------------------------------------------------------------ 文案
const ABOUT_TEXT = APP_TITLE ++ " " ++ APP_VERSION ++ "\n" ++
    "基于 Microsoft® 扫雷(原版作者：Robert Donner、Curt Johnson)\n" ++
    "\n" ++
    "图像素材来源：Microsoft(扫雷原始图像素材)；青月晓(新增图像素材)。\n" ++
    "Copyright © 2026 青月晓\n" ++
    "本程序为免费软件\n" ++
    "与 Microsoft 公司无隶属关系";

const HELP_TEXT = "雷区里有四种雷。\n" ++
    "鼠标左键翻开格子，右键插旗，中键或左右键同时点击展开格子。\n" ++
    "点击人脸或者按F2 开局。\n" ++
    "\n" ++
    "圆复数模式：\n" ++
    "四种雷分别是正实雷、负实雷、正虚雷、负虚雷。\n" ++
    "数字代表该格周围所有雷的加和之模长，均被写为整数或最简根式。\n" ++
    "当旗帜数量等于周围真实雷数，且实虚比例符合真实比例或其倒数的时候，可以展开。\n" ++
    "\n" ++
    "双曲复数模式（闵可夫斯基模式）：\n" ++
    "四种雷分别是正实雷（正类空雷）、负实雷（负类空雷）、正双曲虚雷（正类时雷）、负双曲虚雷（负类时雷）。\n" ++
    "定义双曲虚数单位（类时单位）j²=1，形式模长（时空间隔）S=√(a²-b²)，所以，可以出现虚数。\n" ++
    "（本模式只是从闵可夫斯基时空度规得来的灵感，跟广义相对论没有多大关系。）\n" ++
    "数字是该格周围所有雷之加和的形式模长（时空间隔），均被写为整数或最简根式。\n" ++
    "当旗帜数量等于周围真实雷数，且实部（类空部）、j部（类时部）的数量等于真实数量时，可以展开。";
