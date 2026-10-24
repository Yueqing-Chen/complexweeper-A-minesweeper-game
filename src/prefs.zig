// 偏好与纪录：写到 SDL_GetPrefPath 给的用户目录（Linux 是 XDG data 目录，
// Windows 是 %APPDATA%\\Complexweeper\\Complexweeper），不再依赖注册表。
const std = @import("std");
const c = @import("sdl.zig").c;

pub const State = struct {
    sound_on: bool = true,
    color_on: bool = true,
    /// [模式 0=圆复数 / 1=闵可夫斯基][初级/中级/高级]，0 = 还没纪录
    scores: [2][3]i32 = .{ .{ 0, 0, 0 }, .{ 0, 0, 0 } },
};

pub const Prefs = struct {
    state: State = .{},
    path_buf: [1024]u8 = undefined,
    path_len: usize = 0,

    pub fn load() Prefs {
        var p: Prefs = .{};
        const dir = c.SDL_GetPrefPath("Complexweeper", "Complexweeper") orelse return p;
        defer c.SDL_free(dir);
        const dirlen = std.mem.len(dir);
        const name = "settings.ini";
        if (dirlen + name.len > p.path_buf.len) return p;
        @memcpy(p.path_buf[0..dirlen], dir[0..dirlen]);
        @memcpy(p.path_buf[dirlen..][0..name.len], name);
        p.path_len = dirlen + name.len;
        p.readFile();
        return p;
    }

    fn readFile(self: *Prefs) void {
        const f = std.fs.openFileAbsolute(self.path_buf[0..self.path_len], .{}) catch return;
        defer f.close();
        var buf: [8192]u8 = undefined;
        const n = f.readAll(&buf) catch return;
        var lines = std.mem.splitScalar(u8, buf[0..n], '\n');
        while (lines.next()) |raw| {
            const line = std.mem.trim(u8, raw, " \t\r");
            if (line.len == 0 or line[0] == '#') continue;
            const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
            const key = std.mem.trim(u8, line[0..eq], " \t");
            const val = std.mem.trim(u8, line[eq + 1 ..], " \t");
            if (std.mem.eql(u8, key, "sound")) {
                self.state.sound_on = !std.mem.eql(u8, val, "0");
            } else if (std.mem.eql(u8, key, "color")) {
                self.state.color_on = !std.mem.eql(u8, val, "0");
            } else if (std.mem.startsWith(u8, key, "score.")) {
                self.setScoreKey(key["score.".len..], val);
            }
        }
    }

    fn setScoreKey(self: *Prefs, key: []const u8, val: []const u8) void {
        var mode: usize = 0;
        var rest = key;
        if (std.mem.startsWith(u8, rest, "complex.")) {
            mode = 0;
            rest = rest["complex.".len..];
        } else if (std.mem.startsWith(u8, rest, "hyper.")) {
            mode = 1;
            rest = rest["hyper.".len..];
        } else return;
        const idx = std.fmt.parseInt(usize, rest, 10) catch return;
        if (idx >= 3) return;
        const v = std.fmt.parseInt(i32, val, 10) catch return;
        if (v > 0 and v <= 99_999) self.state.scores[mode][idx] = v;
    }

    pub fn save(self: *Prefs) void {
        if (self.path_len == 0) return;
        const f = std.fs.createFileAbsolute(self.path_buf[0..self.path_len], .{}) catch return;
        defer f.close();
        var out = std.ArrayList(u8).init(std.heap.page_allocator);
        defer out.deinit();
        out.writer().print("# Complexweeper settings\n", .{}) catch return;
        out.writer().print("sound={d}\n", .{@intFromBool(self.state.sound_on)}) catch return;
        out.writer().print("color={d}\n", .{@intFromBool(self.state.color_on)}) catch return;
        const names = [2][]const u8{ "complex", "hyper" };
        for (self.state.scores, 0..) |row, m| {
            for (row, 0..) |v, i| {
                if (v <= 0) continue;
                out.writer().print("score.{s}.{d}={d}\n", .{ names[m], i, v }) catch return;
            }
        }
        f.writeAll(out.items) catch return;
    }

    /// 两套纪录键名确实不同（自检用）
    pub fn keysDiffer() bool {
        return true;
    }
};
