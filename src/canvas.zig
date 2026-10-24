// 软件画布：所有界面先画到一块 0xAARRGGBB 的像素缓冲，再整块交给 SDL 纹理。
// 布局与贴图坐标沿用旧 GDI 实现（像素单位、原点在左上），oy 是整块内容的纵向偏移
// （顶部菜单栏占掉的那一条），画游戏内容时设成 MENU_BAR_H，画菜单/弹窗时设成 0。
const std = @import("std");
const A = @import("assets.zig");

pub const Color = u32;

pub fn rgb(r: u8, g: u8, b: u8) Color {
    return 0xFF000000 | (@as(u32, r) << 16) | (@as(u32, g) << 8) | @as(u32, b);
}

pub const C_BTNFACE = rgb(0xC0, 0xC0, 0xC0);
pub const C_HILIGHT = rgb(0xDF, 0xDF, 0xDF);
pub const C_SHADOW = rgb(0x80, 0x80, 0x80);
pub const C_BLACK = rgb(0, 0, 0);
pub const C_WHITE = rgb(0xFF, 0xFF, 0xFF);
pub const C_DARKGRAY = rgb(0x40, 0x40, 0x40);
pub const C_MENU_BG = rgb(0xF0, 0xF0, 0xF0);
pub const C_MENU_HOT = rgb(0x31, 0x6A, 0xC5);
pub const C_MENU_HOT_TEXT = rgb(0xFF, 0xFF, 0xFF);

pub const Image = struct {
    w: i32,
    h: i32,
    px: []u32,

    pub fn deinit(self: *Image) void {
        std.heap.page_allocator.free(self.px);
        self.* = undefined;
    }

    /// 从 CSAT 图集容器展开（BGRA8，透明像素的 RGB 在生成阶段已被填成背景灰，
    /// 与旧 GDI 忽略 alpha 的拷贝行为一致）。
    pub fn fromCsat(blob: []const u8) ?Image {
        if (blob.len < 12) return null;
        if (!(blob[0] == 'C' and blob[1] == 'S' and blob[2] == 'A' and blob[3] == 'T')) return null;
        const count = readU16(blob, 6);
        const aw = readU16(blob, 8);
        const ah = readU16(blob, 10);
        const off: usize = 12 + @as(usize, count) * 8;
        const need: usize = @as(usize, aw) * @as(usize, ah) * 4;
        if (blob.len < off + need) return null;
        const px = std.heap.page_allocator.alloc(u32, @as(usize, aw) * @as(usize, ah)) catch return null;
        errdefer std.heap.page_allocator.free(px);
        var i: usize = 0;
        while (i < px.len) : (i += 1) {
            const b = blob[off + i * 4 + 0];
            const g = blob[off + i * 4 + 1];
            const r = blob[off + i * 4 + 2];
            px[i] = 0xFF000000 | (@as(u32, r) << 16) | (@as(u32, g) << 8) | b;
        }
        return .{ .w = aw, .h = ah, .px = px };
    }

    /// 从 CSBW 容器展开（灰度平面 1 字节/像素）。
    pub fn fromCsbw(blob: []const u8) ?Image {
        if (blob.len < 12) return null;
        if (!(blob[0] == 'C' and blob[1] == 'S' and blob[2] == 'B' and blob[3] == 'W')) return null;
        const gw = readU16(blob, 6);
        const gh = readU16(blob, 8);
        const need: usize = @as(usize, gw) * @as(usize, gh);
        if (blob.len < 12 + need) return null;
        const px = std.heap.page_allocator.alloc(u32, need) catch return null;
        errdefer std.heap.page_allocator.free(px);
        for (px, 0..) |*p, i| {
            const v = blob[12 + i];
            p.* = 0xFF000000 | (@as(u32, v) << 16) | (@as(u32, v) << 8) | v;
        }
        return .{ .w = gw, .h = gh, .px = px };
    }

    fn readU16(b: []const u8, at: usize) u16 {
        return @as(u16, b[at]) | (@as(u16, b[at + 1]) << 8);
    }
};

/// 图集里某张图的矩形（由 assets.zig 生成）。
pub const Rect = struct { x: i32, y: i32, w: i32, h: i32 };

pub const Canvas = struct {
    w: i32 = 0,
    h: i32 = 0,
    /// 内容纵向偏移：画游戏区时 = 顶部菜单栏高度
    oy: i32 = 0,
    px: []u32 = &.{},

    pub fn init(w: i32, h: i32) !Canvas {
        const n: usize = @intCast(@max(0, w) * @max(0, h));
        const px = try std.heap.page_allocator.alloc(u32, n);
        @memset(px, 0xFF000000);
        return .{ .w = w, .h = h, .px = px };
    }

    pub fn deinit(self: *Canvas) void {
        if (self.px.len != 0) std.heap.page_allocator.free(self.px);
        self.* = undefined;
    }

    pub fn resize(self: *Canvas, w: i32, h: i32) !void {
        if (w == self.w and h == self.h and self.px.len != 0) return;
        if (self.px.len != 0) std.heap.page_allocator.free(self.px);
        const n: usize = @intCast(@max(0, w) * @max(0, h));
        self.px = try std.heap.page_allocator.alloc(u32, n);
        @memset(self.px, 0xFF000000);
        self.w = w;
        self.h = h;
    }

    pub fn set(self: *Canvas, x: i32, y: i32, color: Color) void {
        const yy = y + self.oy;
        if (x < 0 or yy < 0 or x >= self.w or yy >= self.h) return;
        self.px[@as(usize, @intCast(yy)) * @as(usize, @intCast(self.w)) + @as(usize, @intCast(x))] = color;
    }

    pub fn fill(self: *Canvas, x: i32, y: i32, cw: i32, ch: i32, color: Color) void {
        if (cw <= 0 or ch <= 0) return;
        var x0 = x;
        var y0 = y + self.oy;
        var x1 = x + cw;
        var y1 = y + ch + self.oy;
        if (x0 < 0) x0 = 0;
        if (y0 < 0) y0 = 0;
        if (x1 > self.w) x1 = self.w;
        if (y1 > self.h) y1 = self.h;
        if (x1 <= x0 or y1 <= y0) return;
        var row: i32 = y0;
        while (row < y1) : (row += 1) {
            const base = @as(usize, @intCast(row)) * @as(usize, @intCast(self.w));
            @memset(self.px[base + @as(usize, @intCast(x0)) .. base + @as(usize, @intCast(x1))], color);
        }
    }

    /// 经典立体边框：raised = 左上亮、右下暗；sunken 反过来
    pub fn draw3d(self: *Canvas, x: i32, y: i32, cw: i32, ch: i32, t: i32, raised: bool) void {
        const a = if (raised) C_HILIGHT else C_SHADOW;
        const b = if (raised) C_SHADOW else C_HILIGHT;
        self.fill(x, y, cw, t, a);
        self.fill(x, y, t, ch, a);
        self.fill(x, y + ch - t, cw, t, b);
        self.fill(x + cw - t, y, t, ch, b);
    }

    /// 最近邻缩放贴图。不透明拷贝（与旧 GDI 的 BitBlt/StretchBlt 一致，忽略 alpha）。
    pub fn blit(self: *Canvas, img: Image, src: Rect, dx: i32, dy: i32, dw: i32, dh: i32) void {
        if (dw <= 0 or dh <= 0 or src.w <= 0 or src.h <= 0) return;
        const x0 = @max(dx, 0);
        const y0 = @max(dy + self.oy, 0);
        const x1 = @min(dx + dw, self.w);
        const y1 = @min(dy + dh + self.oy, self.h);
        if (x1 <= x0 or y1 <= y0) return;
        var y = y0;
        while (y < y1) : (y += 1) {
            const sy = src.y + @divTrunc((y - dy - self.oy) * src.h, dh);
            if (sy < 0 or sy >= img.h) continue;
            const sbase = @as(usize, @intCast(sy)) * @as(usize, @intCast(img.w));
            const dbase = @as(usize, @intCast(y)) * @as(usize, @intCast(self.w));
            var x = x0;
            while (x < x1) : (x += 1) {
                const sx = src.x + @divTrunc((x - dx) * src.w, dw);
                if (sx < 0 or sx >= img.w) continue;
                self.px[dbase + @as(usize, @intCast(x))] = img.px[sbase + @as(usize, @intCast(sx))];
            }
        }
    }

    pub fn blitSq(self: *Canvas, img: Image, src: Rect, dx: i32, dy: i32, size: i32) void {
        self.blit(img, src, dx, dy, size, size);
    }

    /// 带 alpha 的逐像素合成（字体、图标用）。
    pub fn blend(self: *Canvas, x: i32, y: i32, src: Color) void {
        const yy = y + self.oy;
        if (x < 0 or yy < 0 or x >= self.w or yy >= self.h) return;
        const a: u32 = (src >> 24) & 0xFF;
        if (a == 0) return;
        const i = @as(usize, @intCast(yy)) * @as(usize, @intCast(self.w)) + @as(usize, @intCast(x));
        if (a == 255) {
            self.px[i] = src;
            return;
        }
        const d = self.px[i];
        const ia = 255 - a;
        const r = (((src >> 16) & 0xFF) * a + ((d >> 16) & 0xFF) * ia + 127) / 255;
        const g = (((src >> 8) & 0xFF) * a + ((d >> 8) & 0xFF) * ia + 127) / 255;
        const b = ((src & 0xFF) * a + (d & 0xFF) * ia + 127) / 255;
        self.px[i] = 0xFF000000 | (r << 16) | (g << 8) | b;
    }

    /// 写 32bpp BMP（自底向上，BGRA 字节序）。
    pub fn saveBmp(self: *Canvas, path: []const u8) bool {
        const cw: usize = @intCast(@max(self.w, 0));
        const ch: usize = @intCast(@max(self.h, 0));
        const row_bytes = cw * 4;
        const img_size = row_bytes * ch;
        const file_size = 14 + 40 + img_size;
        const f = std.fs.cwd().createFile(path, .{}) catch return false;
        defer f.close();
        var hdr: [54]u8 = [_]u8{0} ** 54;
        hdr[0] = 'B';
        hdr[1] = 'M';
        std.mem.writeInt(u32, hdr[2..6], @intCast(file_size), .little);
        std.mem.writeInt(u32, hdr[10..14], 54, .little);
        std.mem.writeInt(u32, hdr[14..18], 40, .little);
        std.mem.writeInt(i32, hdr[18..22], self.w, .little);
        std.mem.writeInt(i32, hdr[22..26], self.h, .little);
        std.mem.writeInt(u16, hdr[26..28], 1, .little);
        std.mem.writeInt(u16, hdr[28..30], 32, .little);
        std.mem.writeInt(u32, hdr[34..38], @intCast(img_size), .little);
        f.writeAll(&hdr) catch return false;
        const row = std.heap.page_allocator.alloc(u8, row_bytes) catch return false;
        defer std.heap.page_allocator.free(row);
        var y: usize = ch;
        while (y > 0) {
            y -= 1;
            const base = y * cw;
            var x: usize = 0;
            while (x < cw) : (x += 1) {
                const p = self.px[base + x];
                row[x * 4 + 0] = @truncate(p);
                row[x * 4 + 1] = @truncate(p >> 8);
                row[x * 4 + 2] = @truncate(p >> 16);
                row[x * 4 + 3] = @truncate(p >> 24);
            }
            f.writeAll(row) catch return false;
        }
        return true;
    }
};

// 让 assets.zig 的矩形常量直接可用。
pub fn spriteRect(sprite: u16) Rect {
    const r = A.rect(sprite);
    return .{ .x = r.x, .y = r.y, .w = r.w, .h = r.h };
}
