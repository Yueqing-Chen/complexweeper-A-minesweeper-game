// 无界面自检：跑规则层不变量，结果写文本文件
const std = @import("std");
const g = @import("game.zig");
const A = @import("assets.zig"); // 只为核对"每个显示值都有贴图"
const ui = @import("main.zig"); // 只为拿版本号（抬头要写）

var fails: u32 = 0;
var checks: u32 = 0;

fn expect(out: *std.ArrayList(u8), cond: bool, name: []const u8) void {
    checks += 1;
    if (!cond) {
        fails += 1;
        out.writer().print("  [失败] {s}\n", .{name}) catch {};
    }
}

fn note(out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) void {
    out.writer().print(fmt, args) catch {};
}

/// 独立的洪水填充，用来核对连片
fn expectedCascade(game: *const g.Game, start: usize, set: *[g.MAX_CELLS]bool) void {
    for (0..g.MAX_CELLS) |i| set[i] = false;
    var stack: [g.MAX_CELLS]usize = undefined;
    var sp: usize = 0;
    stack[sp] = start;
    sp += 1;
    var comp: [g.MAX_CELLS]bool = [_]bool{false} ** g.MAX_CELLS;
    comp[start] = true;
    while (sp > 0) {
        sp -= 1;
        const i = stack[sp];
        var buf: [8]usize = undefined;
        const k = game.nbrs(i, &buf);
        for (buf[0..k]) |j| {
            if (comp[j] or game.mine[j] != 0) continue;
            if (game.isBlank(j)) {
                comp[j] = true;
                stack[sp] = j;
                sp += 1;
            }
        }
    }
    // 连片覆盖 = 连通空白格 ∪ 它们的非雷邻居
    for (0..game.n) |i| {
        if (!comp[i]) continue;
        set[i] = true;
        var buf: [8]usize = undefined;
        const k = game.nbrs(i, &buf);
        for (buf[0..k]) |j| {
            if (game.mine[j] == 0) set[j] = true;
        }
    }
}

fn buildBoard(game: *g.Game, n: u16, rows: u16, mines: u16, tc: [5]u16, seed: u32, start: usize) void {
    game.w = n;
    game.h = rows;
    game.mines = mines;
    game.type_count = tc;
    game.newGame(seed);
    game.startAt(start, 0);
}

/// 闵可夫斯基自检用：5×5 棋盘中央格（下标 12）周围正好 8 个邻居，按"四种雷的颗数"配比摆上去。
/// as_flag = true 时摆的是旗帜（不重算显示值），否则摆真雷并重算。
fn hyperPlace(game: *g.Game, counts: [4]u8, as_flag: bool) void {
    for (0..25) |i| {
        if (!as_flag) game.mine[i] = 0;
        game.flag[i] = 0;
        game.open[i] = 0;
        game.clue[i] = -1;
    }
    var buf: [8]usize = undefined;
    const k = game.nbrs(12, &buf);
    var slot: usize = 0;
    for (counts, 1..) |c, t| {
        var j: u8 = 0;
        while (j < c and slot < k) : (j += 1) {
            const cell = buf[slot];
            if (as_flag) {
                _ = game.setFlag(cell, @intCast(t));
            } else {
                game.mine[cell] = @intCast(t);
            }
            slot += 1;
        }
    }
    if (!as_flag) game.computeClues();
}

pub fn run(out: *std.ArrayList(u8)) u32 {
    fails = 0;
    checks = 0;
    var game: g.Game = .{};

    note(out, "复扫雷 {s} · 规则自检\n==========================\n", .{ui.testAppVersion});

    // ---- 1. 随机数确定性 ----
    {
        var a: g.Game = .{};
        var b: g.Game = .{};
        buildBoard(&a, 16, 16, 40, [_]u16{0} ** 5, 12345, 100);
        buildBoard(&b, 16, 16, 40, [_]u16{0} ** 5, 12345, 100);
        var same = true;
        for (0..a.n) |i| {
            if (a.mine[i] != b.mine[i]) same = false;
        }
        expect(out, same, "同种子 + 同开局格应生成完全相同的棋盘");
        var c: g.Game = .{};
        buildBoard(&c, 16, 16, 40, [_]u16{0} ** 5, 999, 100);
        var diff = false;
        for (0..a.n) |i| {
            if (a.mine[i] != c.mine[i]) diff = true;
        }
        expect(out, diff, "不同种子应生成不同棋盘");
        note(out, "1 随机数确定性：通过（校验 {d} 项）\n", .{checks});
    }

    // ---- 2. 精确配比 ----
    {
        const cases = [_][5]u16{
            .{ 0, 3, 2, 4, 1 },
            .{ 0, 0, 0, 0, 6 },
            .{ 0, 7, 0, 0, 0 },
            .{ 0, 5, 5, 0, 0 },
            .{ 0, 0, 0, 4, 4 },
        };
        var bad: u32 = 0;
        for (cases) |tc| {
            var sum: u16 = 0;
            for (1..5) |t| sum += tc[t];
            for ([_]u32{ 11, 22, 33 }) |seed| {
                buildBoard(&game, 12, 12, sum, tc, seed, 70);
                for (1..5) |t| {
                    if (game.type_total[t] != tc[t]) bad += 1;
                }
                if (game.typeSum() != sum) bad += 1;
                if (game.mines != sum) bad += 1;
            }
        }
        expect(out, bad == 0, "指定配比必须被精确执行（5 种配比 × 3 种子）");
        note(out, "2 精确配比：{s}\n", .{if (bad == 0) "通过" else "有偏差"});
    }

    // ---- 3. 纯实 / 纯虚局面的显示值全是完全平方数 ----
    {
        var bad: u32 = 0;
        const pure = [_][5]u16{ .{ 0, 5, 5, 0, 0 }, .{ 0, 0, 0, 4, 4 } };
        for (pure) |tc| {
            var sum: u16 = 0;
            for (1..5) |t| sum += tc[t];
            for ([_]u32{ 7, 8, 9 }) |seed| {
                buildBoard(&game, 12, 12, sum, tc, seed, 70);
                var first_bad: i32 = -1;
                for (0..game.n) |i| {
                    if (game.mine[i] != 0) continue;
                    const D: u32 = @intCast(game.clue[i]);
                    var r: u32 = 0;
                    while (r * r < D) r += 1;
                    if (r * r != D) {
                        bad += 1;
                        if (first_bad < 0) first_bad = @intCast(i);
                    }
                }
                if (first_bad >= 0) {
                    note(out, "  [调试] 请求配比 {d}/{d}/{d}/{d}，实际 type_total {d}/{d}/{d}/{d}，首个非平方格 {d} 的 D={d}，周围雷 {d} 颗\n", .{
                        tc[1],              tc[2],                          tc[3],                                  tc[4],
                        game.type_total[1], game.type_total[2],             game.type_total[3],                     game.type_total[4],
                        first_bad,          game.clue[@intCast(first_bad)], game.nbrMineCount(@intCast(first_bad)),
                    });
                }
            }
        }
        expect(out, bad == 0, "纯实/纯虚局面里所有显示值都必须是完全平方数");
        note(out, "3 纯实/纯虚不变量：{s}\n", .{if (bad == 0) "通过" else "失败"});
    }

    // ---- 4. 连片：与独立洪水填充逐格一致，且绝不翻雷 ----
    {
        var mismatch: u32 = 0;
        var mine_opened: u32 = 0;
        var samples: u32 = 0;
        var zero_cascaded: u32 = 0;
        var zero_samples: u32 = 0;
        for ([_]u32{ 301, 302, 303, 304, 305 }) |seed| {
            buildBoard(&game, 12, 12, 24, [_]u16{0} ** 5, seed, 70);
            var i: usize = 0;
            while (i < game.n and samples < 40) : (i += 1) {
                if (game.mine[i] != 0 or game.open[i] != 0 or !game.isBlank(i)) continue;
                buildBoard(&game, 12, 12, 24, [_]u16{0} ** 5, seed, 70);
                if (game.open[i] != 0) continue;
                var before: [g.MAX_CELLS]bool = undefined;
                for (0..g.MAX_CELLS) |k| before[k] = game.open[k] != 0;
                game.reveal(i, 0);
                var want: [g.MAX_CELLS]bool = undefined;
                expectedCascade(&game, i, &want);
                samples += 1;
                for (0..game.n) |k| {
                    const got = (game.open[k] != 0) and !before[k];
                    const exp = want[k] and !before[k];
                    if (got != exp) mismatch += 1;
                    if (got and game.mine[k] != 0) mine_opened += 1;
                }
            }
            // 显示 0 绝不连片
            buildBoard(&game, 12, 12, 24, [_]u16{0} ** 5, seed, 70);
            for (0..game.n) |k| {
                if (game.mine[k] != 0 or game.open[k] != 0) continue;
                if (game.clue[k] != 0 or game.nbrMineCount(k) == 0) continue;
                var before: [g.MAX_CELLS]bool = undefined;
                for (0..g.MAX_CELLS) |m| before[m] = game.open[m] != 0;
                game.reveal(k, 0);
                var opened_now: u32 = 0;
                for (0..game.n) |m| {
                    if (game.open[m] != 0 and !before[m]) opened_now += 1;
                }
                zero_samples += 1;
                if (opened_now != 1) zero_cascaded += 1;
            }
        }
        expect(out, samples >= 20, "空白格连片样本数足够");
        expect(out, mismatch == 0, "连片结果必须与独立洪水填充逐格一致");
        expect(out, mine_opened == 0, "连片绝不能翻开雷");
        expect(out, zero_samples >= 5, "显示 0 的样本数足够");
        expect(out, zero_cascaded == 0, "显示 0 的格子绝不能连片");
        note(out, "4 连片展开：空白样本 {d}，显示 0 样本 {d}，不一致 {d}，翻雷 {d}\n", .{ samples, zero_samples, mismatch, mine_opened });
    }

    // ---- 4b. 大盘开局连片：栈吃满也不许漏格 ----
    {
        const shapes = [_]struct { w: u16, h: u16, m: u16 }{
            .{ .w = 40, .h = 30, .m = 1 },
            .{ .w = 40, .h = 30, .m = 5 },
            .{ .w = 40, .h = 30, .m = 20 },
            .{ .w = 40, .h = 30, .m = 60 },
            .{ .w = 40, .h = 20, .m = 40 },
            .{ .w = 30, .h = 30, .m = 60 },
        };
        var mismatch: u32 = 0;
        var opened_mine: u32 = 0;
        var samples: u32 = 0;
        var big: u32 = 0;
        var worst: usize = 0;
        for (shapes) |sh| {
            const bw: usize = sh.w;
            const bh: usize = sh.h;
            const starts = [_]usize{ 0, bw / 2, (bh / 2) * bw + bw / 2, bw * bh - 1 };
            for ([_]u32{ 4111, 4127, 4133, 4139, 4153, 4159 }) |seed| {
                for (starts) |st| {
                    buildBoard(&game, sh.w, sh.h, sh.m, [_]u16{0} ** 5, seed, st);
                    var want: [g.MAX_CELLS]bool = undefined;
                    expectedCascade(&game, st, &want);
                    for (0..game.n) |k| {
                        if ((game.open[k] != 0) != want[k]) mismatch += 1;
                        if (game.open[k] != 0 and game.mine[k] != 0) opened_mine += 1;
                    }
                    const oc = game.openedCount();
                    if (oc > worst) worst = oc;
                    if (oc >= 400) big += 1;
                    samples += 1;
                }
            }
        }
        expect(out, samples >= 72, "大盘连片样本数足够（6 种盘面 × 6 种子 × 4 开局格）");
        expect(out, big >= 8, "大盘样本里应有真正的大连片（≥400 格）");
        expect(out, mismatch == 0, "大盘开局连片必须与独立洪水填充逐格一致（栈吃满也不许漏格）");
        expect(out, opened_mine == 0, "大盘连片也绝不能翻开雷");
        note(out, "4b 大盘连片：样本 {d}，大连片 {d} 次，一次最多翻开 {d} 格，逐格不一致 {d}\n", .{ samples, big, worst, mismatch });
    }

    // ---- 5. 开局必定连片且不踩雷 ----
    {
        var bad: u32 = 0;
        for ([_]u32{ 501, 502, 503, 504, 505 }) |seed| {
            var gm: g.Game = .{};
            gm.w = 16;
            gm.h = 16;
            gm.mines = 40;
            gm.newGame(seed);
            const start: usize = 16 * 8 + 8;
            gm.startAt(start, 0);
            if (gm.over) bad += 1;
            if (gm.openedCount() < 9) bad += 1;
            if (!gm.isBlank(start)) bad += 1;
            // 开局后各类雷数已知，且合计 = 总雷数
            if (gm.typeSum() != 40) bad += 1;
            for (1..5) |t| {
                if (gm.type_total[t] == 0 and gm.mines >= 40) bad += 1;
                if (gm.unmarked(t) != @as(i32, gm.type_total[t])) bad += 1;
            }
        }
        expect(out, bad == 0, "开局格必为空白格、必连片（≥9 格）且不踩雷；各类雷数已知");
        note(out, "5 开局连片与分类计数：{s}\n", .{if (bad == 0) "通过" else "失败"});
    }

    // ---- 6. 判据：与独立实现一致 ----
    {
        var mismatch: u32 = 0;
        var pass: u32 = 0;
        var total: u32 = 0;
        for ([_]u32{ 601, 602, 603 }) |seed| {
            buildBoard(&game, 12, 12, 24, [_]u16{0} ** 5, seed, 70);
            for (0..game.n) |i| {
                if (game.mine[i] != 0 or game.open[i] == 0) continue;
                var t: usize = 1;
                var buf: [8]usize = undefined;
                const k = game.nbrs(i, &buf);
                for (buf[0..k]) |j| {
                    if (game.open[j] != 0) continue;
                    _ = game.setFlag(j, @intCast(1 + ((i + j) % 4)));
                    t += 1;
                }
                var truth = [4]i32{ 0, 0, 0, 0 };
                var got = [4]i32{ 0, 0, 0, 0 };
                for (buf[0..k]) |j| {
                    if (game.mine[j] != 0) truth[game.mine[j] - 1] += 1;
                    if (game.flag[j] != 0) got[game.flag[j] - 1] += 1;
                }
                const P = truth[0] + truth[1];
                const V = truth[2] + truth[3];
                const gp = got[0] + got[1];
                const gv = got[2] + got[3];
                const want = (gp + gv == P + V) and ((gp == P and gv == V) or (gp == V and gv == P));
                const mine = game.matchComboTruth(i);
                total += 1;
                if (want != mine) mismatch += 1;
                if (want) pass += 1;
            }
            for (0..game.n) |j| _ = game.setFlag(j, 0);
        }
        expect(out, total > 50, "判据样本数足够");
        expect(out, mismatch == 0, "判据结果必须与独立实现一致");
        expect(out, pass > 0, "判据应至少放行一部分组合");
        note(out, "6 组合匹配判据：样本 {d}，放行 {d}，不一致 {d}\n", .{ total, pass, mismatch });
    }

    // ---- 7. 插旗不限量 + 循环顺序 ----
    {
        buildBoard(&game, 9, 9, 10, [_]u16{0} ** 5, 701, 40);
        var placed: u32 = 0;
        for (0..game.n) |i| {
            if (game.open[i] != 0) continue;
            if (game.setFlag(i, 1)) placed += 1;
        }
        expect(out, placed > 0, "所有未翻开格都能插旗");
        expect(out, game.flags_of[1] == placed, "计数与实际插旗数一致");
        expect(out, game.unmarked(1) < 0, "插超后未标记数应为负数");
        var cell: usize = 0;
        for (0..game.n) |i| {
            if (game.open[i] == 0) {
                cell = i;
                break;
            }
        }
        _ = game.setFlag(cell, 0);
        var seq: [6]u8 = undefined;
        for (0..6) |k| {
            _ = game.cycleFlag(cell);
            seq[k] = game.flag[cell];
        }
        const want_seq = [6]u8{ 1, 2, 3, 4, 0, 1 };
        var ok = true;
        for (0..6) |k| {
            if (seq[k] != want_seq[k]) ok = false;
        }
        expect(out, ok, "右键循环必须是 1,2,3,4,0,1");
        note(out, "7 插旗不限量：插了 {d} 面，循环 {any}\n", .{ placed, seq });
    }

    // ---- 8. 翻开已插旗格：先清旗再翻开 ----
    {
        buildBoard(&game, 9, 9, 10, [_]u16{0} ** 5, 801, 40);
        var cell: usize = 0;
        for (0..game.n) |i| {
            if (game.open[i] == 0 and game.mine[i] == 0) {
                cell = i;
                break;
            }
        }
        _ = game.setFlag(cell, 3);
        expect(out, game.flags_of[3] == 1, "插旗后计数为 1");
        // 旗子保护格子：插了旗就翻不开
        game.reveal(cell, 0);
        expect(out, game.open[cell] == 0, "插旗的格子翻不开");
        expect(out, game.flag[cell] == 3, "翻不开时旗帜应原样保留");
        expect(out, game.flags_of[3] == 1, "翻不开时计数不动");
        // 连片也不该把旗子吃掉
        var blank: usize = 0;
        var flagged_nbr: usize = 0;
        var found = false;
        for (0..game.n) |i| {
            if (game.open[i] != 0 or game.mine[i] != 0 or !game.isBlank(i)) continue;
            var buf: [8]usize = undefined;
            const k = game.nbrs(i, &buf);
            for (buf[0..k]) |j| {
                if (game.open[j] == 0 and game.mine[j] == 0 and game.flag[j] == 0) {
                    blank = i;
                    flagged_nbr = j;
                    found = true;
                    break;
                }
            }
            if (found) break;
        }
        if (found) {
            _ = game.setFlag(flagged_nbr, 1);
            game.reveal(blank, 0);
            expect(out, game.open[blank] == 1, "空白格应能翻开");
            expect(out, game.open[flagged_nbr] == 0, "连片展开不该翻开插了旗的格子");
            expect(out, game.flag[flagged_nbr] == 1, "连片展开不该清掉旗子");
        }
        // 撤旗之后才翻得开
        _ = game.setFlag(cell, 0);
        game.reveal(cell, 0);
        expect(out, game.open[cell] == 1, "撤旗后应能翻开");
        expect(out, game.flags_of[3] == 0, "撤旗后计数归还");
        note(out, "8 旗子保护格子（翻不开、连片也不碰）：通过\n", .{});
    }

    // ---- 9. 胜负判定 ----
    {
        // 胜利：翻开全部非雷格即可，旗帜不参与
        buildBoard(&game, 9, 9, 10, [_]u16{0} ** 5, 901, 40);
        for (0..game.n) |i| {
            if (game.mine[i] == 0 and game.open[i] == 0) game.reveal(i, 0);
        }
        expect(out, game.win and game.over, "翻开所有非雷格必须判胜");
        // 留一个非雷格就不算胜
        buildBoard(&game, 9, 9, 10, [_]u16{0} ** 5, 902, 40);
        var left: usize = 0;
        for (0..game.n) |i| {
            if (game.mine[i] == 0 and game.open[i] == 0) {
                left = i;
                break;
            }
        }
        for (0..game.n) |i| {
            if (i != left and game.mine[i] == 0 and game.open[i] == 0) game.reveal(i, 0);
        }
        expect(out, !game.win, "还剩非雷格未翻开时不能判胜");
        buildBoard(&game, 9, 9, 10, [_]u16{0} ** 5, 903, 40);
        var m: usize = 0;
        for (0..game.n) |i| {
            if (game.mine[i] != 0) {
                m = i;
                break;
            }
        }
        game.reveal(m, 0);
        expect(out, game.over and !game.win, "翻开雷必须判负");
        expect(out, game.boom == @as(i32, @intCast(m)), "记录踩中的格子");
        note(out, "9 胜负判定：通过\n", .{});
    }

    // ---- 10. 展开：判据不过时棋盘不变 ----
    {
        buildBoard(&game, 12, 12, 24, [_]u16{0} ** 5, 1001, 70);
        var cell: usize = 0;
        for (0..game.n) |i| {
            if (game.open[i] != 0 and game.mine[i] == 0) {
                var buf: [8]usize = undefined;
                const k = game.nbrs(i, &buf);
                var uns: u32 = 0;
                for (buf[0..k]) |j| {
                    if (game.open[j] == 0 and game.flag[j] == 0) uns += 1;
                }
                if (uns > 0) {
                    cell = i;
                    break;
                }
            }
        }
        var before: [g.MAX_CELLS]bool = undefined;
        for (0..g.MAX_CELLS) |i| before[i] = game.open[i] != 0;
        game.tryExpand(cell);
        if (!game.matchComboTruth(cell)) {
            var changed = false;
            for (0..game.n) |i| {
                if ((game.open[i] != 0) != before[i]) changed = true;
            }
            expect(out, !changed, "判据不通过时展开不能改变棋盘");
        }
        note(out, "10 展开门禁：通过\n", .{});
    }

    // ---- 11. 闵可夫斯基模式：显示值集合、贴图覆盖、判据 ----
    {
        // 枚举 495 种邻域组合（四种雷的颗数 n1..n4，总数 ≤ 8）：两套显示值集合都算一遍。
        // 圆复数模式必须正好得到现有那 24 个值（模型与已发布实现的交叉验证），
        // 闵可夫斯基模式必须正好得到 39 个值，且每个值在图集里都有贴图。
        var seen_c = [_]bool{false} ** 65;
        var seen_h = [_]bool{false} ** 129;
        var combos: u32 = 0;
        var n1: u32 = 0;
        while (n1 <= 8) : (n1 += 1) {
            var n2: u32 = 0;
            while (n1 + n2 <= 8) : (n2 += 1) {
                var n3: u32 = 0;
                while (n1 + n2 + n3 <= 8) : (n3 += 1) {
                    var n4: u32 = 0;
                    while (n1 + n2 + n3 + n4 <= 8) : (n4 += 1) {
                        combos += 1;
                        const a = @as(i32, @intCast(n1)) - @as(i32, @intCast(n2));
                        const b = @as(i32, @intCast(n3)) - @as(i32, @intCast(n4));
                        seen_c[@intCast(a * a + b * b)] = true;
                        seen_h[@intCast(a * a - b * b + 64)] = true;
                    }
                }
            }
        }
        expect(out, combos == 495, "邻域组合应枚举出 495 种");
        var cn: u32 = 0;
        for (seen_c) |v| {
            if (v) cn += 1;
        }
        var hn: u32 = 0;
        for (seen_h) |v| {
            if (v) hn += 1;
        }
        expect(out, cn == g.ACHIEVABLE.len, "圆复数模式的显示值应为 24 个（与现有贴图一致）");
        expect(out, hn == 39, "闵可夫斯基模式的显示值应为 39 个");
        var cplx_bad: u32 = 0;
        for (g.ACHIEVABLE) |D| {
            if (!seen_c[D]) cplx_bad += 1;
        }
        expect(out, cplx_bad == 0, "圆复数模式的显示值集合必须正好是 ACHIEVABLE 那 24 个");
        // 19 个模长正负成对 + 一个 0；再核对每个值都有贴图、且贴图没有重复占用
        const MAG = [19]i32{ 1, 3, 4, 5, 7, 8, 9, 12, 15, 16, 21, 24, 25, 32, 35, 36, 48, 49, 64 };
        var pair_ok = seen_h[64];
        for (MAG) |m| {
            if (!seen_h[@intCast(m + 64)] or !seen_h[@intCast(-m + 64)]) pair_ok = false;
        }
        expect(out, pair_ok, "闵可夫斯基模式应是 19 个模长各带正负、外加一个 0");
        var missing: u32 = 0;
        var used = [_]bool{false} ** 256;
        var dup: u32 = 0;
        for (0..129) |i| {
            if (!seen_h[i]) continue;
            const s = A.hnum_by_D[i];
            if (s == 0xFFFF) {
                missing += 1;
            } else if (used[s]) {
                dup += 1;
            } else {
                used[s] = true;
            }
        }
        expect(out, missing == 0, "闵可夫斯基模式每个可能的显示值都必须有贴图（hnum_by_D 无空洞）");
        expect(out, dup == 0, "39 张贴图不该被两个显示值共用");
        note(out, "11 闵可夫斯基显示值集合与贴图覆盖：{s}（组合 {d} 种，闵可夫斯基 {d} 值）\n", .{ if (missing == 0 and dup == 0 and hn == 39) "通过" else "有缺口", combos, hn });

        // 显示值算法：a² − b²（圆复数模式是 a² + b²），负值照算，显示成根式加 i
        var h: g.Game = .{};
        h.mode = .hyper;
        const clues = [_]struct { t: [4]u8, want: i32 }{
            .{ .t = .{ 1, 0, 0, 0 }, .want = 1 },
            .{ .t = .{ 0, 0, 1, 0 }, .want = -1 },
            .{ .t = .{ 1, 0, 1, 0 }, .want = 0 },
            .{ .t = .{ 2, 0, 0, 0 }, .want = 4 },
            .{ .t = .{ 0, 2, 0, 0 }, .want = 4 },
            .{ .t = .{ 1, 0, 2, 0 }, .want = -3 },
            .{ .t = .{ 0, 0, 2, 0 }, .want = -4 },
            .{ .t = .{ 2, 1, 3, 1 }, .want = -3 },
            .{ .t = .{ 4, 0, 0, 4 }, .want = 0 },
            .{ .t = .{ 0, 0, 6, 0 }, .want = -36 },
            .{ .t = .{ 3, 0, 4, 0 }, .want = -7 },
            .{ .t = .{ 4, 0, 0, 0 }, .want = 16 },
        };
        var clue_bad: u32 = 0;
        for (clues) |c| {
            hyperPlace(&h, c.t, false);
            if (h.clue[12] != c.want) clue_bad += 1;
            const idx: usize = @intCast(c.want + 64);
            if (A.hnum_by_D[idx] == 0xFFFF) clue_bad += 1;
        }
        expect(out, clue_bad == 0, "闵可夫斯基显示值必须是 a² − b²（12 组配比逐一核对）");
        // 同一个配比在圆复数模式下应得 a² + b²（这里 a=1、b=2）
        h.mode = .complex;
        hyperPlace(&h, .{ 2, 1, 3, 1 }, false);
        expect(out, h.clue[12] == 5, "同一配比在圆复数模式下应是 a² + b²（1+4=5）");
        h.mode = .hyper;
        note(out, "11b 闵可夫斯基显示值算法（a² − b²）：{s}\n", .{if (clue_bad == 0) "通过" else "有偏差"});

        // 判据：真值 = 一颗 +1 加一颗 +j（a=1、b=1、共 2 颗，显示值 0）
        hyperPlace(&h, .{ 1, 0, 1, 0 }, false);
        expect(out, h.clue[12] == 0, "真值配比的显示值应为 0");
        hyperPlace(&h, .{ 1, 0, 1, 0 }, true);
        expect(out, h.matchComboTruth(12), "旗帜与真值一致时判据应通过");
        hyperPlace(&h, .{ 0, 1, 0, 1 }, true);
        expect(out, h.matchComboTruth(12), "推荐判据允许 a、b 各自取负（四种符号组合）");
        hyperPlace(&h, .{ 1, 1, 0, 0 }, true);
        expect(out, !h.matchComboTruth(12), "推荐判据：|a|、|b| 不相符必须拦住");
        h.judge_loose = true;
        expect(out, h.matchComboTruth(12), "备选判据：同旗数且 a²−b² 相同就应通过");
        h.judge_loose = false;
        hyperPlace(&h, .{ 1, 0, 0, 0 }, true);
        expect(out, !h.matchComboTruth(12), "旗数与真实雷数不符必须拦住（两种判据都一样）");
        hyperPlace(&h, .{ 2, 0, 0, 0 }, false);
        hyperPlace(&h, .{ 1, 1, 0, 0 }, true);
        expect(out, !h.matchComboTruth(12), "旗数 2 = 2 但 |a| 不同（2 与 0）仍须拦住");
        // 展开：判据过了就翻开其余未插旗的邻格（这个 5×5 小盘一次可能就翻完 → 顺带判胜，两种都算过）
        hyperPlace(&h, .{ 1, 0, 1, 0 }, false);
        hyperPlace(&h, .{ 1, 0, 1, 0 }, true);
        h.open[12] = 1;
        h.over = false;
        h.win = false;
        h.boom = -1;
        h.msg = .none;
        h.tryExpand(12);
        expect(out, h.msg == .expand_ok or h.win, "闵可夫斯基模式判据通过后展开应报 expand_ok");
        expect(out, h.boom < 0, "邻域里的雷都插了旗，展开不该踩雷");
        var opened_any = false;
        for (0..h.n) |i| {
            if (i != 12 and h.open[i] != 0) opened_any = true;
        }
        expect(out, opened_any, "判据通过后应真的翻开邻格");
        note(out, "11c 闵可夫斯基判据（推荐 / 备选两档）：通过\n", .{});
    }

    // ---- 12. 判定贴图表：不许有空洞，实雷两个模式共用 ----
    {
        const tables = [_][5]u16{
            A.mine_T,      A.hmine_T,
            A.flag_T,      A.hflag_T,
            A.boom_T,      A.hboom_T,
            A.wrong_T,     A.hwrong_T,
            A.right_T,     A.hright_T,
            A.rightflag_T, A.hrightflag_T,
            A.wrongflag_T, A.hwrongflag_T,
        };
        var bad: u32 = 0;
        for (tables) |t| {
            for (1..5) |k| {
                if (t[k] >= A.count) bad += 1; // 越界 = 生成器写错了
            }
        }
        expect(out, bad == 0, "判定贴图表里每一张都应是合法槽位号");
        var shared_ok = true;
        for (1..3) |k| {
            if (A.mine_T[k] != A.hmine_T[k] or A.flag_T[k] != A.hflag_T[k] or A.boom_T[k] != A.hboom_T[k] or
                A.wrong_T[k] != A.hwrong_T[k] or A.right_T[k] != A.hright_T[k]) shared_ok = false;
        }
        expect(out, shared_ok, "1/2 两种实雷在两个模式下必须共用同一批贴图");
        expect(out, A.hmine_T[3] != A.mine_T[3] and A.hflag_T[4] != A.flag_T[4], "3/4 在闵可夫斯基模式下应换成 j 版贴图");
        expect(out, A.wrongblank_sprite < A.count, "「标错空格子」应指向合法槽位");
        note(out, "12 判定贴图表：通过（实雷共用、j 版独立、无空洞）\n", .{});
    }

    note(out, "\n断言 {d} 项，失败 {d} 项\n", .{ checks, fails });
    note(out, "{s}\n", .{if (fails == 0) "全部通过" else "存在失败"});
    return fails;
}
