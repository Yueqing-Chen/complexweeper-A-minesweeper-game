// 音效：内嵌的六段 wav 用 SDL_LoadWAV_IO 解析，每次播放开一条独立音频流。
// 不阻塞事件循环，也不读磁盘；播完由 update() 回收。
const std = @import("std");
const c = @import("sdl.zig").c;

const MAX_STREAMS = 12;

const Active = struct {
    stream: *c.SDL_AudioStream,
    started: u64,
};

pub const Audio = struct {
    ready: bool = false,
    active: [MAX_STREAMS]?Active = [_]?Active{null} ** MAX_STREAMS,

    pub fn init() Audio {
        if (!c.SDL_InitSubSystem(c.SDL_INIT_AUDIO)) return .{};
        return .{ .ready = true };
    }

    pub fn deinit(self: *Audio) void {
        self.stopAll();
        if (self.ready) c.SDL_QuitSubSystem(c.SDL_INIT_AUDIO);
        self.ready = false;
    }

    pub fn play(self: *Audio, bytes: []const u8) void {
        if (!self.ready or bytes.len == 0) return;
        self.update();
        const io = c.SDL_IOFromConstMem(bytes.ptr, bytes.len) orelse return;
        var spec: c.SDL_AudioSpec = std.mem.zeroes(c.SDL_AudioSpec);
        var buf: [*c]u8 = null;
        var blen: u32 = 0;
        if (!c.SDL_LoadWAV_IO(io, true, &spec, &buf, &blen)) return;
        defer if (buf != null) c.SDL_free(buf);
        const stream = c.SDL_OpenAudioDeviceStream(c.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec, null, null) orelse return;
        if (!c.SDL_PutAudioStreamData(stream, buf, @intCast(blen))) {
            c.SDL_DestroyAudioStream(stream);
            return;
        }
        _ = c.SDL_ResumeAudioStreamDevice(stream);
        var slot: ?usize = null;
        for (self.active, 0..) |a, i| {
            if (a == null) {
                slot = i;
                break;
            }
        }
        if (slot == null) {
            // 全满：把最早那条收掉，腾一格
            var oldest: usize = 0;
            var best: u64 = 0xFFFFFFFFFFFFFFFF;
            for (self.active, 0..) |a, i| {
                if (a) |v| {
                    if (v.started <= best) {
                        best = v.started;
                        oldest = i;
                    }
                }
            }
            if (self.active[oldest]) |v| c.SDL_DestroyAudioStream(v.stream);
            slot = oldest;
        }
        self.active[slot.?] = .{ .stream = stream, .started = c.SDL_GetTicks() };
    }

    /// 回收播完的流；每帧/每次播放前调用都行。
    pub fn update(self: *Audio) void {
        const now = c.SDL_GetTicks();
        for (&self.active) |*slot| {
            if (slot.*) |v| {
                if (c.SDL_GetAudioStreamQueued(v.stream) <= 0 and now -% v.started > 100) {
                    c.SDL_DestroyAudioStream(v.stream);
                    slot.* = null;
                }
            }
        }
    }

    pub fn stopAll(self: *Audio) void {
        for (&self.active) |*slot| {
            if (slot.*) |v| c.SDL_DestroyAudioStream(v.stream);
            slot.* = null;
        }
    }
};
