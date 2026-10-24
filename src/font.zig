// 中文文字渲染：SDL3_ttf 渲染到透明 surface，再逐像素合成进软件画布。
// 优先用内置的 Noto Sans CJK 子集（src/font_subset.otf，OFL-1.1）；
// 系统 CJK 字体只作后备，避免 Windows/Linux 各自依赖本机字体。
const std = @import("std");
const c = @import("sdl.zig").c;
const cv = @import("canvas.zig");

const embedded_font = @embedFile("font_subset.otf");

pub const Font = struct {
    f: *c.TTF_Font,
    io: ?*c.SDL_IOStream = null,
    cur_size: f32 = 15,

    const candidates = [_][:0]const u8{
        "/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/wenquanyi/wqy-zenhei/wqy-zenhei.ttc",
        "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
        "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
        "/usr/share/fonts/truetype/arphic/uming.ttc",
        "C:/Windows/Fonts/msyh.ttc",
        "C:/Windows/Fonts/msyh.ttf",
        "C:/Windows/Fonts/simhei.ttf",
        "C:/Windows/Fonts/simsun.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    };

    pub fn open() ?Font {
        if (!c.TTF_Init()) return null;
        if (c.SDL_IOFromConstMem(@ptrCast(embedded_font.ptr), embedded_font.len)) |io| {
            if (c.TTF_OpenFontIO(io, false, 15)) |f| {
                return .{ .f = f, .io = io };
            }
            _ = c.SDL_CloseIO(io);
        }
        for (candidates) |p| {
            if (c.TTF_OpenFont(p.ptr, 15)) |f| {
                return .{ .f = f };
            }
        }
        return null;
    }

    pub fn close(self: *Font) void {
        c.TTF_CloseFont(self.f);
        if (self.io) |io| _ = c.SDL_CloseIO(io);
        self.* = undefined;
    }

    fn setup(self: *Font, size: f32) void {
        if (@abs(size - self.cur_size) > 0.01) {
            _ = c.TTF_SetFontSize(self.f, size);
            self.cur_size = size;
        }
    }

    pub const Size = struct { w: i32, h: i32 };

    pub fn measure(self: *Font, text: []const u8, size: f32) Size {
        self.setup(size);
        var w: c_int = 0;
        var h: c_int = 0;
        if (!c.TTF_GetStringSize(self.f, text.ptr, text.len, &w, &h)) return .{ .w = 0, .h = 0 };
        return .{ .w = w, .h = h };
    }

    pub fn measureWrapped(self: *Font, text: []const u8, size: f32, wrap_w: i32) Size {
        self.setup(size);
        var w: c_int = 0;
        var h: c_int = 0;
        if (!c.TTF_GetStringSizeWrapped(self.f, text.ptr, text.len, wrap_w, &w, &h)) return .{ .w = 0, .h = 0 };
        return .{ .w = w, .h = h };
    }

    /// 画一行文字；返回实际宽高。颜色是 0xAARRGGBB。
    pub fn draw(self: *Font, canvas: *cv.Canvas, text: []const u8, x: i32, y: i32, size: f32, color: cv.Color) Size {
        if (text.len == 0) return .{ .w = 0, .h = 0 };
        self.setup(size);
        const col = c.SDL_Color{
            .r = @truncate((color >> 16) & 0xFF),
            .g = @truncate((color >> 8) & 0xFF),
            .b = @truncate(color & 0xFF),
            .a = @truncate((color >> 24) & 0xFF),
        };
        const surf = c.TTF_RenderText_Blended(self.f, text.ptr, text.len, col) orelse return .{ .w = 0, .h = 0 };
        defer c.SDL_DestroySurface(surf);
        return blitSurface(canvas, surf, x, y);
    }

    /// 自动换行（保留文案里的换行），用于弹窗正文。
    pub fn drawWrapped(self: *Font, canvas: *cv.Canvas, text: []const u8, x: i32, y: i32, size: f32, color: cv.Color, wrap_w: i32) Size {
        if (text.len == 0) return .{ .w = 0, .h = 0 };
        self.setup(size);
        const col = c.SDL_Color{
            .r = @truncate((color >> 16) & 0xFF),
            .g = @truncate((color >> 8) & 0xFF),
            .b = @truncate(color & 0xFF),
            .a = @truncate((color >> 24) & 0xFF),
        };
        const surf = c.TTF_RenderText_Blended_Wrapped(self.f, text.ptr, text.len, col, wrap_w) orelse return .{ .w = 0, .h = 0 };
        defer c.SDL_DestroySurface(surf);
        return blitSurface(canvas, surf, x, y);
    }

    fn blitSurface(canvas: *cv.Canvas, surf: *c.SDL_Surface, x: i32, y: i32) Size {
        const conv_c = c.SDL_ConvertSurface(surf, c.SDL_PIXELFORMAT_ARGB8888) orelse return .{ .w = 0, .h = 0 };
        const conv: *c.SDL_Surface = @ptrCast(conv_c);
        defer c.SDL_DestroySurface(conv_c);
        const w: i32 = conv.w;
        const h: i32 = conv.h;
        if (w <= 0 or h <= 0) return .{ .w = w, .h = h };
        const pitch_px: usize = @intCast(@divTrunc(conv.pitch, 4));
        const base: [*]const u32 = @ptrCast(@alignCast(conv.pixels.?));
        var row: i32 = 0;
        while (row < h) : (row += 1) {
            var col: i32 = 0;
            while (col < w) : (col += 1) {
                canvas.blend(x + col, y + row, base[@as(usize, @intCast(row)) * pitch_px + @as(usize, @intCast(col))]);
            }
        }
        return .{ .w = w, .h = h };
    }
};

/// 把 `&` 加速键标记从显示文本里去掉（下划线不画，只去掉符号）。
pub fn cleanLabel(buf: []u8, label: []const u8) []const u8 {
    var n: usize = 0;
    var i: usize = 0;
    while (i < label.len and n < buf.len) : (i += 1) {
        if (label[i] == '&' and i + 1 < label.len) {
            i += 1;
            buf[n] = label[i];
            n += 1;
        } else {
            buf[n] = label[i];
            n += 1;
        }
    }
    return buf[0..n];
}
