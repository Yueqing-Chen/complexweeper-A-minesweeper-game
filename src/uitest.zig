// 界面层自检：直接调用界面层的消息级测试钩子，验证 输入 → 状态 → 布局
const std = @import("std");
const Mouse = ui.Mouse;
const g = @import("game.zig");
const ui = @import("main.zig");

var checks: u32 = 0;
var fails: u32 = 0;

fn expect(out: *std.ArrayList(u8), cond: bool, name: []const u8) void {
    checks += 1;
    if (!cond) {
        fails += 1;
        out.writer().print("  [失败] {s}\n", .{name}) catch {};
    }
}

/// 辅助：开局 → 回拨时间 → 点开所有非雷格
fn clearBoard(out: *std.ArrayList(u8), bx: i32, by: i32, backdate_ms: u32) void {
    _ = out;
    ui.testMouse(Mouse.lbutton_down, bx, by);
    ui.testMouse(Mouse.lbutton_up, bx, by);
    ui.testBackdate(backdate_ms);
    var guard: u32 = 0;
    while (guard < 4) : (guard += 1) {
        var done = true;
        for (0..ui.game_ptr.n) |k| {
            if (ui.game_ptr.mine[k] != 0 or ui.game_ptr.open[k] != 0) continue;
            const L = ui.testLayout();
            const mx = L.board_x + @as(i32, @intCast(k % ui.game_ptr.w)) * L.cell + @divTrunc(L.cell, 2);
            const my = L.board_y + @as(i32, @intCast(k / ui.game_ptr.w)) * L.cell + @divTrunc(L.cell, 2);
            ui.testMouse(Mouse.lbutton_down, mx, my);
            ui.testMouse(Mouse.lbutton_up, mx, my);
            if (ui.game_ptr.over) return;
            done = false;
        }
        if (done) return;
    }
}
/// 辅助：找一个「判据放行、邻域还有非雷空格」的已翻开数字格（找不到返回 -1）
fn setupExpandable() i32 {
    for (0..ui.game_ptr.n) |k| {
        if (ui.game_ptr.open[k] == 0 or ui.game_ptr.mine[k] != 0) continue;
        var buf: [8]usize = undefined;
        const nk = ui.game_ptr.nbrs(k, &buf);
        var free_cells: u32 = 0;
        for (buf[0..nk]) |j| {
            if (ui.game_ptr.open[j] == 0 and ui.game_ptr.flag[j] == 0 and ui.game_ptr.mine[j] == 0) free_cells += 1;
        }
        if (free_cells == 0) continue;
        for (buf[0..nk]) |j| {
            if (ui.game_ptr.mine[j] != 0) {
                _ = ui.game_ptr.setFlag(j, ui.game_ptr.mine[j]);
            } else if (ui.game_ptr.flag[j] != 0) {
                _ = ui.game_ptr.setFlag(j, 0);
            }
        }
        if (ui.game_ptr.matchComboTruth(k)) return @intCast(k);
    }
    return -1;
}

/// 辅助：右键点一下
fn rightClick(x: i32, y: i32) void {
    ui.testMouse(Mouse.rbutton_down, x, y);
    ui.testMouse(Mouse.rbutton_up, x, y);
}
/// 辅助：中键点一下
fn middleClick(x: i32, y: i32) void {
    ui.testMouse(Mouse.mbutton_down, x, y);
    ui.testMouse(Mouse.mbutton_up, x, y);
}
/// 辅助：格子 → 客户区坐标
fn cellXY(L: ui.Layout, k: usize) [2]i32 {
    const w_: usize = ui.game_ptr.w;
    return .{
        L.board_x + @as(i32, @intCast(k % w_)) * L.cell + @divTrunc(L.cell, 2),
        L.board_y + @as(i32, @intCast(k / w_)) * L.cell + @divTrunc(L.cell, 2),
    };
}
pub fn run(out: *std.ArrayList(u8)) u32 {
    checks = 0;
    fails = 0;
    ui.testScoresStopPersist();
    if (!ui.testWindowReady()) {
        out.writer().print("窗口未就绪\n", .{}) catch {};
        return 1;
    }
    out.writer().print("复扫雷 {s} · 界面自检（消息级）\n====================================\n", .{ui.testAppVersion}) catch {};

    // 0) 窗口标题
    {
        const t = (ui.testWindowTitle());
        expect(out, std.mem.eql(u8, ui.testWindowTitle(), ui.testAppTitle), "窗口标题应与 APP_TITLE 一致");
        expect(out, std.mem.indexOf(u8, t, "复扫雷") != null, "标题里应有「复扫雷」");
        expect(out, std.mem.indexOf(u8, t, "复数扫雷") == null, "标题里不该再有「复数扫雷」");
        expect(out, std.mem.indexOf(u8, t, "Complexweeper") != null, "标题里应保留英文名 Complexweeper");
        expect(out, ui.testIconResourceOk(), "exe 里应有可加载的图标资源（.rsrc 的 16/32/48 三档）");
        out.writer().print("0 窗口标题：[{s}]\n", .{t}) catch {};
    }

    // 0b) 版本号 / 关于文案 / 玩法文案
    {
        const v = ui.testAppVersion;
        var dots: usize = 0;
        var ok = v.len >= 5;
        for (v) |ch| {
            if (ch == '.') {
                dots += 1;
            } else if (ch < '0' or ch > '9') {
                ok = false;
            }
        }
        expect(out, ok and dots == 2, "版本号应形如 1.0.1");
        const about = (ui.testAboutText);
        expect(out, std.mem.indexOf(u8, about, v) != null, "「关于」正文里应带着版本号");
        expect(out, std.mem.indexOf(u8, about, "复扫雷 Complexweeper") != null, "「关于」里的程序名应是「复扫雷 Complexweeper」");
        expect(out, std.mem.indexOf(u8, about, "Complexweeper") != null, "「关于」里应有英文名 Complexweeper");
        const help = (ui.testHelpText);
        expect(out, std.mem.indexOf(u8, help, "分别是正实雷、负实雷、正虚雷、负虚雷") != null, "四种雷仍按雷的名字列（正实雷…）");
        expect(out, std.mem.indexOf(u8, help, "正实雷（正类空雷）、负实雷（负类空雷）、正双曲虚雷（正类时雷）、负双曲虚雷（负类时雷）") != null, "双曲（闵可夫斯基）模式那段应写四种雷的全名");
        expect(out, std.mem.indexOf(u8, help, "鼠标左键翻开格子，右键插旗") != null, "操作说明应在正文里");
        expect(out, std.mem.indexOf(u8, help, "点击人脸或者按F2 开局") != null, "开局方式应在正文里");
        expect(out, std.mem.indexOf(u8, help, "+1") == null and std.mem.indexOf(u8, help, "-1") == null, "玩法里不该出现 +1/−1 那套符号");
        out.writer().print("0b 版本号：[{s}] · 关于程序名：[复扫雷 Complexweeper]\n", .{v}) catch {};
    }

    // 1) 难度菜单
    ui.testCommand(ui.test_IDM_BEGINNER);
    expect(out, ui.game_ptr.w == 9 and ui.game_ptr.h == 9 and ui.game_ptr.mines == 10, "初级菜单应切成 9×9/10");
    ui.testCommand(ui.test_IDM_INTERMEDIATE);
    expect(out, ui.game_ptr.w == 16 and ui.game_ptr.h == 16 and ui.game_ptr.mines == 40, "中级菜单应切成 16×16/40");
    ui.testCommand(ui.test_IDM_EXPERT);
    expect(out, ui.game_ptr.w == 30 and ui.game_ptr.h == 16 and ui.game_ptr.mines == 99, "高级菜单应切成 30×16/99");
    out.writer().print("1 难度菜单：通过\n", .{}) catch {};

    // 2) 缩放与菜单结构
    ui.testCommand(ui.test_IDM_ZOOM1);
    expect(out, ui.testZoom() == 1, "缩放菜单应切到 100%");
    ui.testCommand(ui.test_IDM_ZOOM3);
    expect(out, ui.testZoom() == 3, "缩放菜单应切到 300%");
    ui.testCommand(ui.test_IDM_ZOOM2);
    expect(out, ui.testZoom() == 2, "缩放菜单应切回 200%");
    expect(out, ui.testPopupCount(1) == 3, "帮助菜单应只剩 3 项（玩法与操作、分隔线、关于）");
    expect(out, ui.testMenuHasId(ui.test_IDM_HELP_HOW), "帮助菜单应有「玩法与操作」");
    expect(out, ui.testMenuHasId(ui.test_IDM_HELP_ABOUT), "帮助菜单应有「关于」");
    expect(out, !ui.testMenuHasId(ui.test_IDM_HELP_TABLE_REMOVED), "「显示值对照表」应从菜单里删掉");
    expect(out, ui.testMenuHasId(ui.test_IDM_BEST), "圆复数模式子菜单里应有「最高分纪录」");
    expect(out, ui.testMenuHasId(ui.test_IDM_HYPER_BEST), "闵可夫斯基模式子菜单里应有「最高分纪录」");
    out.writer().print("2 缩放菜单：通过\n", .{}) catch {};

    // 3) 左键：按下预览、松开翻开
    const L = ui.testLayout();
    const cx = L.board_x + @as(i32, @intCast(ui.game_ptr.w / 2)) * L.cell + @divTrunc(L.cell, 2);
    const cy = L.board_y + @as(i32, @intCast(ui.game_ptr.h / 2)) * L.cell + @divTrunc(L.cell, 2);
    const mid_cell: usize = @as(usize, @intCast(ui.game_ptr.h / 2)) * ui.game_ptr.w + @as(usize, @intCast(ui.game_ptr.w / 2));
    ui.testMouse(Mouse.lbutton_down, cx, cy);
    expect(out, !ui.game_ptr.started, "只按下不该开局");
    expect(out, ui.game_ptr.open[mid_cell] == 0, "只按下不该翻开格子");
    expect(out, ui.testPressCell() == @as(i32, @intCast(mid_cell)), "按下应记下被按住的那一格");
    expect(out, ui.testCellSprite(mid_cell) == ui.testBlankSprite, "按住的那格应画成已翻开的空白");
    expect(out, !ui.testFaceDown(), "按棋盘不该换成按下脸");
    expect(out, ui.testFaceSpriteIsScan(), "按住棋盘准备翻开时应播「脸扫雷」");
    ui.testMouse(Mouse.lbutton_up, cx, cy);
    expect(out, ui.game_ptr.started, "松开后才开局");
    expect(out, ui.game_ptr.openedCount() >= 9, "开局应连片（≥9 格）");
    expect(out, ui.testPressCell() < 0, "松开后不该还有按住的格子");
    expect(out, !ui.testFaceDown(), "翻格前后都不该出现按下脸");
    expect(out, ui.testFaceSpriteIsScan(), "翻开时脸应闪一下「脸扫雷」");
    ui.testFaceFlashExpire();
    expect(out, !ui.testFaceSpriteIsScan(), "闪完应回到普通脸");
    out.writer().print("3 左键按下预览 / 松开翻开：翻开 {d} 格\n", .{ui.game_ptr.openedCount()}) catch {};

    // 3b) 拖动换格 / 拖出棋盘取消
    {
        var t1: i32 = -1;
        var t2: i32 = -1;
        for (0..ui.game_ptr.n) |k| {
            if (ui.game_ptr.open[k] == 0 and ui.game_ptr.mine[k] == 0) {
                if (t1 < 0) t1 = @intCast(k) else if (t2 < 0) {
                    t2 = @intCast(k);
                    break;
                }
            }
        }
        expect(out, t1 >= 0 and t2 >= 0, "应能找到两个未翻开的非雷格");
        const p1 = cellXY(L, @intCast(t1));
        const p2 = cellXY(L, @intCast(t2));
        ui.testMouse(Mouse.lbutton_down, p1[0], p1[1]);
        expect(out, ui.testPressCell() == t1, "按下时应按住第一格");
        ui.testMouse(Mouse.mousemove, p2[0], p2[1]);
        expect(out, ui.testPressCell() == t2, "拖到第二格后，按住预览应跟过去");
        expect(out, ui.testCellSprite(@intCast(t1)) == ui.testClosedSprite, "第一格应恢复成未翻开的样子");
        ui.testMouse(Mouse.lbutton_up, p2[0], p2[1]);
        expect(out, ui.game_ptr.open[@intCast(t2)] != 0, "松手的那一格应被翻开");
        var before: u32 = 0;
        for (0..ui.game_ptr.n) |k| {
            if (ui.game_ptr.open[k] != 0) before += 1;
        }
        var t3: i32 = -1;
        for (0..ui.game_ptr.n) |k| {
            if (ui.game_ptr.open[k] == 0) {
                t3 = @intCast(k);
                break;
            }
        }
        if (t3 >= 0) {
            const p3 = cellXY(L, @intCast(t3));
            ui.testMouse(Mouse.lbutton_down, p3[0], p3[1]);
            ui.testMouse(Mouse.mousemove, L.header_x + 4, L.header_y + 4);
            expect(out, ui.testPressCell() < 0, "拖出棋盘后不该还有按住的格子");
            ui.testMouse(Mouse.lbutton_up, L.header_x + 4, L.header_y + 4);
            var after: u32 = 0;
            for (0..ui.game_ptr.n) |k| {
                if (ui.game_ptr.open[k] != 0) after += 1;
            }
            expect(out, after == before, "拖出棋盘松手不该翻开任何格子");
        }
        out.writer().print("3b 拖动预览 / 拖出取消：通过\n", .{}) catch {};
    }

    // 4) 右键循环插旗（含连点）
    expect(out, !ui.game_ptr.over, "第 4 组开始时局面应还在进行中");
    var closed: i32 = -1;
    for (0..ui.game_ptr.n) |k| {
        if (ui.game_ptr.open[k] == 0) {
            closed = @intCast(k);
            break;
        }
    }
    expect(out, closed >= 0, "应能找到未翻开的格子");
    const fx = L.board_x + @as(i32, @intCast(@as(usize, @intCast(closed)) % ui.game_ptr.w)) * L.cell + @divTrunc(L.cell, 2);
    const fy = L.board_y + @as(i32, @intCast(@as(usize, @intCast(closed)) / ui.game_ptr.w)) * L.cell + @divTrunc(L.cell, 2);
    rightClick(fx, fy);
    expect(out, ui.game_ptr.flag[@intCast(closed)] == 1, "右键第一次应插 +1 旗");
    expect(out, ui.testFaceSpriteIsScan(), "插旗时脸也应闪一下「脸扫雷」");
    expect(out, !ui.testFaceDown(), "插旗不该播按下脸");
    ui.testFaceFlashExpire();
    rightClick(fx, fy);
    expect(out, ui.game_ptr.flag[@intCast(closed)] == 2, "右键第二次应改成 −1 旗");
    expect(out, ui.game_ptr.flags_of[2] == 1 and ui.game_ptr.flags_of[1] == 0, "计数应跟着改");
    middleClick(fx, fy);
    expect(out, ui.game_ptr.flag[@intCast(closed)] == 2, "中键不应再清旗");
    expect(out, ui.game_ptr.flags_of[2] == 1 and ui.game_ptr.flags_of[1] == 0, "中键不应改动旗帜计数");
    expect(out, ui.game_ptr.open[@intCast(closed)] == 0, "中键点在未翻开格上不应翻开它");
    ui.testMouse(Mouse.rbutton_dblclk, fx, fy);
    ui.testMouse(Mouse.rbutton_up, fx, fy);
    expect(out, ui.game_ptr.flag[@intCast(closed)] == 3, "连点的第二下（DBLCLK）也应循环旗帜");
    middleClick(fx, fy);
    expect(out, ui.game_ptr.flag[@intCast(closed)] == 3, "中键连点也不该动旗帜");
    rightClick(fx, fy);
    expect(out, ui.game_ptr.flag[@intCast(closed)] == 4, "第四次右键应到 −i");
    rightClick(fx, fy);
    expect(out, ui.game_ptr.flag[@intCast(closed)] == 0, "第五次右键应循环回空");
    out.writer().print("4 右键循环插旗（含连点）/ 中键不清旗：通过\n", .{}) catch {};

    // 4d) 计雷器符号与 i 单位
    {
        expect(out, !ui.game_ptr.over, "第 4d 组开始时局面应还在进行中");
        var t: usize = 1;
        while (t <= 4) : (t += 1) {
            const left: i32 = @as(i32, ui.game_ptr.type_total[t]) - @as(i32, ui.game_ptr.flags_of[t]);
            const want: i32 = switch (t) {
                2, 4 => -left,
                else => left,
            };
            expect(out, ui.testCounterValue(t) == want, "计雷器显示值 = 该类雷剩余颗数 × 该类雷的符号");
        }
        expect(out, !ui.testCounterImag(1) and !ui.testCounterImag(2), "实雷的计雷器不该带 i 单位格");
        expect(out, ui.testCounterImag(3) and ui.testCounterImag(4), "虚雷的计雷器应带 i 单位格");
        expect(out, ui.testCounterCells() == 4, "四个计雷器都应是四格");
        expect(out, ui.testCounterValueCells(1) == 4 and ui.testCounterValueCells(2) == 4, "实雷的第四格是真数字（四格数字），不是空 LED");
        expect(out, ui.testCounterValueCells(3) == 3 and ui.testCounterValueCells(4) == 3, "虚雷是三格数字，第四格留给 i");
        expect(out, ui.testTimerCells() == 4 and ui.testTimerValueCells() == 4, "计时器也是四格数字");
        expect(out, ui.testTimerWidth() == 4 * 13 * ui.testZoom() + 2 * ui.testZoom(), "计时器面板宽度按四格算");
        {
            const L2 = ui.testLayout();
            const cx2 = L2.header_x + 4 * L2.z;
            expect(out, cx2 + ui.testCountersWidth() < L2.header_x + L2.header_w, "计雷器整列应落在表头里面");
            expect(out, cx2 + ui.testCountersWidth() < ui.testFaceX(), "计雷器整列不该压到人脸");
        }
        const before2 = ui.testCounterValue(2);
        const before1 = ui.testCounterValue(1);
        const before3 = ui.testCounterValue(3);
        const before4 = ui.testCounterValue(4);
        expect(out, before2 < 0 and before4 < 0, "负实雷与负虚雷的计雷器应是负数");
        expect(out, before1 >= 0 and before3 >= 0, "正实雷与正虚雷的计雷器不该是负数");
        var cf: i32 = -1;
        for (0..ui.game_ptr.n) |k| {
            if (ui.game_ptr.open[k] == 0 and ui.game_ptr.flag[k] == 0) {
                cf = @intCast(k);
                break;
            }
        }
        expect(out, cf >= 0, "应能找到未翻开的空格子用来插旗");
        const pf = cellXY(ui.testLayout(), @intCast(cf));
        rightClick(pf[0], pf[1]);
        expect(out, ui.game_ptr.flag[@intCast(cf)] == 1, "那格应插上 +1 旗");
        expect(out, ui.testCounterValue(1) == before1 - 1, "标一颗正实旗帜应让正实计雷器减 1");
        expect(out, ui.testCounterValue(2) == before2 and ui.testCounterValue(3) == before3 and ui.testCounterValue(4) == before4, "别的类的计雷器不该跟着动");
        rightClick(pf[0], pf[1]);
        expect(out, ui.game_ptr.flag[@intCast(cf)] == 2, "那格应改成 −1 旗");
        expect(out, ui.testCounterValue(2) == before2 + 1, "标一颗负实旗帜应让负实计雷器的数字增加 1（朝零走）");
        expect(out, ui.testCounterValue(1) == before1, "撤掉正实旗后正实计雷器应复原");
        rightClick(pf[0], pf[1]);
        expect(out, ui.game_ptr.flag[@intCast(cf)] == 3, "那格应改成 +i 旗");
        expect(out, ui.testCounterValue(3) == before3 - 1, "标一颗正虚旗帜应让正虚计雷器的数字减 1");
        expect(out, ui.testCounterValue(2) == before2, "撤掉负实旗后负实计雷器应复原");
        rightClick(pf[0], pf[1]);
        expect(out, ui.game_ptr.flag[@intCast(cf)] == 4, "那格应改成 −i 旗");
        expect(out, ui.testCounterValue(4) == before4 + 1, "标一颗负虚旗帜应让负虚计雷器的数字增加 1");
        expect(out, ui.testCounterValue(3) == before3, "撤掉正虚旗后正虚计雷器应复原");
        rightClick(pf[0], pf[1]);
        expect(out, ui.game_ptr.flag[@intCast(cf)] == 0, "循环一圈应回到空格");
        expect(out, ui.testCounterValue(4) == before4, "撤旗后负虚计雷器应回到原值");
        ui.testCommand(ui.test_IDM_NEW);
        expect(out, !ui.game_ptr.started, "重开后应回到未开局");
        expect(out, ui.testCounterCells() == 4 and ui.testTimerCells() == 4, "未开局时计雷器与计时器仍是四格");
        expect(out, ui.testCounterValueCells(1) == 4 and ui.testTimerValueCells() == 4, "未开局时实雷与计时器画四格空格子");
        expect(out, ui.testCounterValueCells(3) == 3 and ui.testCounterValueCells(4) == 3, "未开局时虚雷画三格空格子，第四格 i 也画成空格子（计时空）");
        out.writer().print("4d 计雷器符号与 i 单位：通过\n", .{}) catch {};
    }

    // 4b) 开局前插旗，且活过开局
    {
        ui.testCommand(ui.test_IDM_NEW);
        expect(out, !ui.game_ptr.started, "重开后应回到未开局");
        var pre: i32 = -1;
        for (0..ui.game_ptr.n) |k| {
            pre = @intCast(k);
            break;
        }
        const ppre = cellXY(ui.testLayout(), @intCast(pre));
        rightClick(ppre[0], ppre[1]);
        expect(out, ui.game_ptr.flag[@intCast(pre)] == 1, "开局前右键也应插上旗");
        expect(out, ui.game_ptr.flags_of[1] == 1, "开局前的旗也要计数");
        var start_k: usize = 0;
        const L0 = ui.testLayout();
        start_k = @as(usize, @intCast(ui.game_ptr.h)) * ui.game_ptr.w - 1;
        const ps = cellXY(L0, start_k);
        ui.testMouse(Mouse.lbutton_down, ps[0], ps[1]);
        ui.testMouse(Mouse.lbutton_up, ps[0], ps[1]);
        expect(out, ui.game_ptr.started, "左键松开应开局");
        expect(out, ui.game_ptr.flag[@intCast(pre)] == 1, "开局后旗帜应保留");
        expect(out, ui.game_ptr.flags_of[1] == 1, "开局后旗帜计数应保留");
        out.writer().print("4b 开局前插旗 / 活过开局：通过\n", .{}) catch {};
    }

    // 4c) 旗子保护格子
    {
        var t: i32 = -1;
        for (0..ui.game_ptr.n) |k| {
            if (ui.game_ptr.open[k] == 0 and ui.game_ptr.mine[k] == 0 and ui.game_ptr.flag[k] == 0) {
                t = @intCast(k);
                break;
            }
        }
        expect(out, t >= 0, "应能找到未翻开的非雷格");
        const p = cellXY(ui.testLayout(), @intCast(t));
        rightClick(p[0], p[1]);
        expect(out, ui.game_ptr.flag[@intCast(t)] == 1, "先给它插一面 +1 旗");
        ui.testMouse(Mouse.lbutton_down, p[0], p[1]);
        expect(out, ui.testPressCell() == t, "插旗格也能按下（按下时照样显示预览）");
        ui.testMouse(Mouse.lbutton_up, p[0], p[1]);
        expect(out, ui.game_ptr.open[@intCast(t)] == 0, "插了旗的格子左键翻不开");
        expect(out, ui.game_ptr.flag[@intCast(t)] == 1, "翻不开时旗子应原样保留");
        rightClick(p[0], p[1]);
        rightClick(p[0], p[1]);
        rightClick(p[0], p[1]);
        rightClick(p[0], p[1]);
        expect(out, ui.game_ptr.flag[@intCast(t)] == 0, "四次右键应把旗循环回空");
        ui.testMouse(Mouse.lbutton_down, p[0], p[1]);
        ui.testMouse(Mouse.lbutton_up, p[0], p[1]);
        expect(out, ui.game_ptr.open[@intCast(t)] != 0, "撤旗之后左键就能翻开");
        out.writer().print("4c 旗子保护格子：通过\n", .{}) catch {};
    }

    // 5) 人脸重开
    const face_x = ui.testFaceX() + 13 * L.z;
    const face_y = ui.testFaceY() + 13 * L.z;
    ui.testMouse(Mouse.lbutton_down, face_x, face_y);
    expect(out, ui.testFaceDown(), "按在人脸上应显示按下脸");
    expect(out, ui.testFaceArmed(), "按在人脸上应记下『这次是从人脸按下的』");
    expect(out, ui.testFaceSpriteIsDown(), "按住时用的应是「脸按下」那张贴图");
    ui.testMouse(Mouse.lbutton_up, face_x, face_y);
    expect(out, !ui.game_ptr.started, "松开后应重开（回到未开局）");
    expect(out, !ui.testFaceDown(), "重开后脸应恢复正常");
    out.writer().print("5 人脸重开：通过\n", .{}) catch {};

    // 6) 键盘 F2
    ui.testMouse(Mouse.lbutton_down, cx, cy);
    ui.testMouse(Mouse.lbutton_up, cx, cy);
    expect(out, ui.game_ptr.started, "再开一局");
    _ = ui.testKey(0x72);
    expect(out, !ui.game_ptr.started, "F2 应重开（回到未开局）");
    out.writer().print("6 键盘 F2：通过\n", .{}) catch {};

    // 7) 展开：判据不通过时不动棋盘
    ui.testMouse(Mouse.lbutton_down, cx, cy);
    ui.testMouse(Mouse.lbutton_up, cx, cy);
    var target: i32 = -1;
    for (0..ui.game_ptr.n) |k| {
        if (ui.game_ptr.open[k] != 0 and ui.game_ptr.mine[k] == 0) {
            var buf: [8]usize = undefined;
            const nk = ui.game_ptr.nbrs(k, &buf);
            var uns: u32 = 0;
            for (buf[0..nk]) |j| {
                if (ui.game_ptr.open[j] == 0 and ui.game_ptr.flag[j] == 0) uns += 1;
            }
            if (uns > 0) {
                target = @intCast(k);
                break;
            }
        }
    }
    if (target >= 0) {
        const tx = L.board_x + @as(i32, @intCast(@as(usize, @intCast(target)) % ui.game_ptr.w)) * L.cell + @divTrunc(L.cell, 2);
        const ty = L.board_y + @as(i32, @intCast(@as(usize, @intCast(target)) / ui.game_ptr.w)) * L.cell + @divTrunc(L.cell, 2);
        const passed = ui.game_ptr.matchComboTruth(@intCast(target));
        var pending: [8]usize = undefined;
        var npending: usize = 0;
        {
            var nbuf: [8]usize = undefined;
            const nk = ui.game_ptr.nbrs(@intCast(target), &nbuf);
            for (nbuf[0..nk]) |j| {
                if (ui.game_ptr.open[j] == 0 and ui.game_ptr.flag[j] == 0) {
                    pending[npending] = j;
                    npending += 1;
                }
            }
        }

        // 7.1 左右键同时点击：按住预览、松手展开
        {
            ui.testMouse(Mouse.lbutton_down, tx, ty);
            expect(out, !ui.testFaceDown(), "按棋盘（准备翻格）不该播按下脸");
            expect(out, ui.testFaceSpriteIsScan(), "按住棋盘准备翻开时应播「脸扫雷」");
            ui.testMouse(Mouse.rbutton_down, tx, ty);
            expect(out, ui.testChordCell() == target, "左右键同时按下应记下展开目标");
            expect(out, !ui.testFaceDown(), "左右键同时按住时更不该播按下脸");
            expect(out, ui.testFaceSpriteIsScan(), "左右键同时按住（准备展开）应播「脸扫雷」");
            var all_preview = true;
            for (pending[0..npending]) |j| {
                if (ui.testCellSprite(j) != ui.testBlankSprite) all_preview = false;
            }
            expect(out, all_preview, "按住期间待展开的邻格应显示空白贴图");
            expect(out, ui.testCellSprite(@intCast(target)) != ui.testBlankSprite, "展开目标自己不该变成空白格");
            var before_open: u32 = 0;
            for (0..ui.game_ptr.n) |k| {
                if (ui.game_ptr.open[k] != 0) before_open += 1;
            }
            ui.testMouse(Mouse.rbutton_up, tx, ty);
            expect(out, ui.testChordCell() < 0, "松手后展开预览应清掉");
            var after_open: u32 = 0;
            for (0..ui.game_ptr.n) |k| {
                if (ui.game_ptr.open[k] != 0) after_open += 1;
            }
            if (passed) {
                expect(out, after_open >= before_open + npending, "判据通过时左右键同时应展开邻域");
                expect(out, ui.game_ptr.msg == .expand_ok, "左右键同时展开成功应给出 expand_ok 枚举");
                expect(out, ui.testFaceSpriteIsScan(), "展开成功应闪一下「脸扫雷」");
                ui.testFaceFlashExpire();
            } else {
                expect(out, after_open == before_open, "判据不通过时左右键同时不能改变棋盘");
                expect(out, ui.game_ptr.msg == .judge_fail, "判据不通过时应给出判据枚举");
            }
            out.writer().print("7 左右键同时展开：判据{s}，翻开 {d} → {d}\n", .{ if (passed) "通过" else "不通过", before_open, after_open }) catch {};
        }

        // 7.2 中键：同一套「按住预览、松手展开」
        if (!ui.game_ptr.over) {
            var before_open: u32 = 0;
            for (0..ui.game_ptr.n) |k| {
                if (ui.game_ptr.open[k] != 0) before_open += 1;
            }
            ui.testMouse(Mouse.mbutton_down, tx, ty);
            expect(out, ui.testChordCell() == target, "中键按住应记下展开目标");
            expect(out, !ui.testFaceDown(), "中键按住不该播按下脸");
            expect(out, ui.testFaceSpriteIsScan(), "中键按住（准备展开）应播「脸扫雷」");
            var after_open_mid: u32 = 0;
            for (0..ui.game_ptr.n) |k| {
                if (ui.game_ptr.open[k] != 0) after_open_mid += 1;
            }
            expect(out, after_open_mid == before_open, "中键只按下还没松开时不该展开");
            ui.testMouse(Mouse.mbutton_up, tx, ty);
            expect(out, ui.testChordCell() < 0, "中键松手后预览应清掉");
            var after_open: u32 = 0;
            for (0..ui.game_ptr.n) |k| {
                if (ui.game_ptr.open[k] != 0) after_open += 1;
            }
            expect(out, after_open >= before_open, "中键松手后应展开");
            ui.testFaceFlashExpire();
            out.writer().print("7 中键展开（松手才生效）：翻开 {d} → {d}\n", .{ before_open, after_open }) catch {};
        }

        // 7.3 双击不再是展开触发器
        {
            var before_open: u32 = 0;
            for (0..ui.game_ptr.n) |k| {
                if (ui.game_ptr.open[k] != 0) before_open += 1;
            }
            ui.testMouse(Mouse.lbutton_dblclk, tx, ty);
            ui.testMouse(Mouse.lbutton_up, tx, ty);
            var after_open: u32 = 0;
            for (0..ui.game_ptr.n) |k| {
                if (ui.game_ptr.open[k] != 0) after_open += 1;
            }
            expect(out, after_open == before_open, "双击不该再展开（触发改成了左右键同时/中键）");
            out.writer().print("7 双击不再展开：通过\n", .{}) catch {};
        }
    }

    // 7b) 判据通过时，两条路径都要真的翻开
    if (!ui.game_ptr.over) {
        // 7b.1 左右键同时点击
        const t2: i32 = setupExpandable();
        if (t2 >= 0) {
            var before2: u32 = 0;
            for (0..ui.game_ptr.n) |k| {
                if (ui.game_ptr.open[k] != 0) before2 += 1;
            }
            const t2x = L.board_x + @as(i32, @intCast(@as(usize, @intCast(t2)) % ui.game_ptr.w)) * L.cell + @divTrunc(L.cell, 2);
            const t2y = L.board_y + @as(i32, @intCast(@as(usize, @intCast(t2)) / ui.game_ptr.w)) * L.cell + @divTrunc(L.cell, 2);
            ui.testMouse(Mouse.lbutton_down, t2x, t2y);
            ui.testMouse(Mouse.rbutton_down, t2x, t2y);
            ui.testMouse(Mouse.rbutton_up, t2x, t2y);
            ui.testMouse(Mouse.lbutton_up, t2x, t2y);
            var after2: u32 = 0;
            for (0..ui.game_ptr.n) |k| {
                if (ui.game_ptr.open[k] != 0) after2 += 1;
            }
            expect(out, ui.game_ptr.matchComboTruth(@intCast(t2)), "按真值插旗后判据应通过");
            expect(out, after2 > before2, "判据通过时左右键同时点击应真的翻开格子");
            expect(out, ui.game_ptr.msg == .expand_ok, "左右键同时展开成功应给出 expand_ok 枚举");
            out.writer().print("7b 左右键同时展开（判据通过）：翻开 {d} → {d}\n", .{ before2, after2 }) catch {};
        }
        // 7b.2 中键
        var t3: i32 = -1;
        if (!ui.game_ptr.over) t3 = setupExpandable();
        if (t3 >= 0) {
            var before3: u32 = 0;
            for (0..ui.game_ptr.n) |k| {
                if (ui.game_ptr.open[k] != 0) before3 += 1;
            }
            const t3x = L.board_x + @as(i32, @intCast(@as(usize, @intCast(t3)) % ui.game_ptr.w)) * L.cell + @divTrunc(L.cell, 2);
            const t3y = L.board_y + @as(i32, @intCast(@as(usize, @intCast(t3)) / ui.game_ptr.w)) * L.cell + @divTrunc(L.cell, 2);
            middleClick(t3x, t3y);
            var after3: u32 = 0;
            for (0..ui.game_ptr.n) |k| {
                if (ui.game_ptr.open[k] != 0) after3 += 1;
            }
            expect(out, after3 > before3, "判据通过时中键应真的翻开格子");
            expect(out, ui.game_ptr.msg == .expand_ok, "中键展开成功应给出 expand_ok 枚举");
            out.writer().print("7b 中键展开（判据通过）：翻开 {d} → {d}\n", .{ before3, after3 }) catch {};
        }
    }

    // 8) 版式：棋盘完整落在客户区内
    {
        const L2 = ui.testLayout();
        expect(out, L2.board_x >= L2.frame and L2.board_y >= L2.header_y + L2.header_h, "棋盘不能在框外");
        expect(out, L2.board_x + @as(i32, @intCast(ui.game_ptr.w)) * L2.cell + L2.box <= L2.client_w - L2.frame, "棋盘右边不能越界");
        expect(out, L2.frame + L2.pad + ui.game_ptr.h * L2.cell + L2.box + L2.gap <= L2.client_h, "棋盘下边不能越界");
        out.writer().print("8 版式边界：通过\n", .{}) catch {};
    }

    // 9) 自定义雷区对话框：校验与生效
    {
        expect(out, ui.testOpenDialog(), "自定义对话框应能创建");
        expect(out, ui.testEditValue(0) == @as(i32, ui.game_ptr.h) and ui.testEditValue(1) == @as(i32, ui.game_ptr.w), "对话框应预填当前尺寸");
        // 文案：四种雷的名字，「四种雷各自的颗数」那行已删
        {
            const labels = (ui.testDialogTexts());
            expect(out, std.mem.indexOf(u8, labels, "正实雷") != null, "对话框应有「正实雷」");
            expect(out, std.mem.indexOf(u8, labels, "负实雷") != null, "对话框应有「负实雷」");
            expect(out, std.mem.indexOf(u8, labels, "正虚雷") != null, "对话框应有「正虚雷」");
            expect(out, std.mem.indexOf(u8, labels, "负虚雷") != null, "对话框应有「负虚雷」");
            expect(out, std.mem.indexOf(u8, labels, "各自的颗数") == null, "「四种雷各自的颗数」那行应删掉");
            expect(out, std.mem.indexOf(u8, labels, "+1 正实") == null and std.mem.indexOf(u8, labels, "−1 负实") == null, "标签里不该再带 +1/−1 前缀");
            // 白底：静态标签必须拿到那块白刷子
            expect(out, ui.testDialogBgBrushIsWhite(), "静态标签的背景应是白色刷子");
            out.writer().print("9 对话框文案与白底：{s}\n", .{labels}) catch {};
        }
        ui.testSetEdit(0, 99);
        _ = ui.testApplyDialog();
        expect(out, std.mem.eql(u8, ui.testDialogErrName(), "height"), "高度 99 应报 height");
        expect(out, !ui.testDialogDone(), "校验不过时对话框不应关闭");
        {
            const labels4 = (ui.testDialogTexts());
            expect(out, std.mem.indexOf(u8, labels4, "高度要在") != null, "校验失败时错误提示应出现在对话框里");
        }
        ui.testSetEdit(0, 12);
        ui.testSetEdit(1, 12);
        ui.testSetEdit(2, 0);
        ui.testSetEdit(3, 0);
        ui.testSetEdit(4, 0);
        ui.testSetEdit(5, 0);
        _ = ui.testApplyDialog();
        expect(out, std.mem.eql(u8, ui.testDialogErrName(), "sum_zero"), "合计 0 应报 sum_zero");
        ui.testSetEdit(2, 200);
        _ = ui.testApplyDialog();
        expect(out, std.mem.eql(u8, ui.testDialogErrName(), "sum_big"), "合计超上限应报 sum_big");
        ui.testSetEdit(2, 0);
        ui.testSplitClick();
        const a1 = ui.testEditValue(2);
        const a2 = ui.testEditValue(3);
        const a3 = ui.testEditValue(4);
        const a4 = ui.testEditValue(5);
        expect(out, a1 + a2 + a3 + a4 == 99, "均分应按当前合计（99）平摊");
        expect(out, a1 >= 24 and a1 <= 25 and a4 >= 24 and a4 <= 25, "均分结果应尽量平均");
        ui.testSetEdit(0, 12);
        ui.testSetEdit(1, 12);
        ui.testSetEdit(2, 0);
        ui.testSetEdit(3, 7);
        ui.testSetEdit(4, 0);
        ui.testSetEdit(5, 7);
        expect(out, ui.testApplyDialog(), "合法输入应通过并按新配置重开");
        expect(out, std.mem.eql(u8, ui.testDialogErrName(), "none"), "合法输入不应报错");
        expect(out, ui.game_ptr.w == 12 and ui.game_ptr.h == 12 and ui.game_ptr.mines == 14, "应切成 12×12/14");
        expect(out, ui.game_ptr.type_count[2] == 7 and ui.game_ptr.type_count[4] == 7, "配比应写入");
        ui.testCloseDialog();
        const L3 = ui.testLayout();
        const c3x = L3.board_x + 6 * L3.cell + @divTrunc(L3.cell, 2);
        const c3y = L3.board_y + 6 * L3.cell + @divTrunc(L3.cell, 2);
        ui.testMouse(Mouse.lbutton_down, c3x, c3y);
        ui.testMouse(Mouse.lbutton_up, c3x, c3y);
        expect(out, ui.game_ptr.type_total[1] == 0 and ui.game_ptr.type_total[3] == 0, "纯实+纯虚之外的两类应为 0");
        expect(out, ui.game_ptr.type_total[2] == 7 and ui.game_ptr.type_total[4] == 7, "实际配比应等于请求");
        out.writer().print("9 自定义对话框：校验/均分/生效 通过\n", .{}) catch {};
    }

    // 10) 整局通关：胜利脸 + 结束后不再响应
    {
        ui.testCommand(ui.test_IDM_BEGINNER);
        const L4 = ui.testLayout();
        var started = false;
        for (0..ui.game_ptr.n) |k| {
            if (ui.game_ptr.mine[k] != 0) continue;
            const mx = L4.board_x + @as(i32, @intCast(k % ui.game_ptr.w)) * L4.cell + @divTrunc(L4.cell, 2);
            const my = L4.board_y + @as(i32, @intCast(k / ui.game_ptr.w)) * L4.cell + @divTrunc(L4.cell, 2);
            ui.testMouse(Mouse.lbutton_down, mx, my);
            ui.testMouse(Mouse.lbutton_up, mx, my);
            started = true;
            if (ui.game_ptr.over) break;
        }
        expect(out, started and ui.game_ptr.win and ui.game_ptr.over, "翻开所有非雷格必须判胜");
        expect(out, ui.testFaceSpriteIsWin(), "胜利后应换成胜利脸");
        expect(out, ui.game_ptr.openedCount() == ui.game_ptr.safeCount(), "非雷格应全部翻开");
        var t: i32 = -1;
        for (0..ui.game_ptr.n) |k| {
            if (ui.game_ptr.open[k] == 0) {
                t = @intCast(k);
                break;
            }
        }
        if (t >= 0) {
            const p = cellXY(ui.testLayout(), @intCast(t));
            ui.testMouse(Mouse.lbutton_down, p[0], p[1]);
            expect(out, ui.testPressCell() < 0, "胜利后按下不该再压住格子");
            expect(out, !ui.testFaceDown(), "胜利后按棋盘不该再换脸");
            ui.testMouse(Mouse.lbutton_up, p[0], p[1]);
            expect(out, ui.testFaceSpriteIsWin(), "胜利后点棋盘仍是胜利脸");
        }
        out.writer().print("10 整局通关：胜利脸 + 全部翻开 + 结束后不响应 通过\n", .{}) catch {};
    }

    // 11) 踩雷结算：死亡脸 + 记录踩中格
    {
        ui.testCommand(ui.test_IDM_BEGINNER);
        const L5 = ui.testLayout();
        const mid_x = L5.board_x + 2 * L5.cell + @divTrunc(L5.cell, 2);
        const mid_y = L5.board_y + 2 * L5.cell + @divTrunc(L5.cell, 2);
        ui.testMouse(Mouse.lbutton_down, mid_x, mid_y);
        ui.testMouse(Mouse.lbutton_up, mid_x, mid_y);
        expect(out, ui.game_ptr.started, "应先开局");
        var mine_cell: i32 = -1;
        for (0..ui.game_ptr.n) |k| {
            if (ui.game_ptr.mine[k] != 0) {
                mine_cell = @intCast(k);
                break;
            }
        }
        expect(out, mine_cell >= 0, "开局后应能找到雷格");
        const mx2 = L5.board_x + @as(i32, @intCast(@as(usize, @intCast(mine_cell)) % ui.game_ptr.w)) * L5.cell + @divTrunc(L5.cell, 2);
        const my2 = L5.board_y + @as(i32, @intCast(@as(usize, @intCast(mine_cell)) / ui.game_ptr.w)) * L5.cell + @divTrunc(L5.cell, 2);
        ui.testMouse(Mouse.lbutton_down, mx2, my2);
        ui.testMouse(Mouse.lbutton_up, mx2, my2);
        expect(out, ui.game_ptr.over and !ui.game_ptr.win, "点雷应判负");
        expect(out, ui.game_ptr.boom == mine_cell, "应记录踩中的格子");
        expect(out, ui.testFaceSpriteIsDead(), "失败后应换成死亡脸");
        expect(out, ui.testCellSprite(@intCast(mine_cell)) != 0, "踩中的格子应有贴图");
        var t2: i32 = -1;
        for (0..ui.game_ptr.n) |k| {
            if (ui.game_ptr.open[k] == 0) {
                t2 = @intCast(k);
                break;
            }
        }
        if (t2 >= 0) {
            const p2 = cellXY(ui.testLayout(), @intCast(t2));
            ui.testMouse(Mouse.lbutton_down, p2[0], p2[1]);
            expect(out, ui.testPressCell() < 0, "失败后按下不该再压住格子");
            expect(out, !ui.testFaceDown(), "失败后按棋盘不该再换脸");
            ui.testMouse(Mouse.lbutton_up, p2[0], p2[1]);
            const before_flag = ui.game_ptr.flag[@intCast(t2)];
            rightClick(p2[0], p2[1]);
            expect(out, ui.game_ptr.flag[@intCast(t2)] == before_flag, "失败后右键不该再改旗帜");
            expect(out, ui.testFaceSpriteIsDead(), "失败后点棋盘仍是死亡脸");
        }
        out.writer().print("11 踩雷结算：死亡脸 + 记录踩中格 + 结束后不响应 通过\n", .{}) catch {};

        // 11b) 结束后按人脸重开
        {
            const fpx = ui.testFaceX() + 13 * L.z;
            const fpy = ui.testFaceY() + 13 * L.z;
            ui.testMouse(Mouse.lbutton_down, fpx, fpy);
            expect(out, ui.testFaceDown(), "结束后按人脸按钮应播按下脸（准备重开）");
            expect(out, ui.testFaceSpriteIsDown(), "结束后按人脸按钮用的应是「脸按下」贴图");
            ui.testMouse(Mouse.lbutton_up, fpx, fpy);
            expect(out, !ui.game_ptr.over, "松开人脸按钮应重开一局");
            out.writer().print("11b 结束后按人脸重开：按下脸 → 松开重开 通过\n", .{}) catch {};
        }
    }

    // 12) 最高分纪录：记账 / 不覆盖 / 自定义不计入
    {
        ui.testScoresStopPersist();
        ui.testSetScores(0, 0, 0);

        ui.testCommand(ui.test_IDM_BEGINNER);
        const L6 = ui.testLayout();
        const bx = L6.board_x + 2 * L6.cell + @divTrunc(L6.cell, 2);
        const by = L6.board_y + 2 * L6.cell + @divTrunc(L6.cell, 2);
        clearBoard(out, bx, by, 50_000);
        expect(out, ui.game_ptr.win, "初级应通关");
        var tbuf: [64]u8 = undefined;
        const msg = std.fmt.bufPrint(&tbuf, "初级纪录应记为 50 秒，实际 {d}", .{ui.testGetScore(0)}) catch "初级纪录不对";
        expect(out, ui.testGetScore(0) == 50, msg);

        ui.testCommand(ui.test_IDM_BEGINNER);
        clearBoard(out, bx, by, 80_000);
        expect(out, ui.game_ptr.win, "第二局也应通关");
        expect(out, ui.testGetScore(0) == 50, "更慢的用时不应覆盖纪录");

        ui.testCommand(ui.test_IDM_BEGINNER);
        clearBoard(out, bx, by, 20_000);
        expect(out, ui.testGetScore(0) == 20, "更快的用时应覆盖纪录");

        ui.testSetScores(7, 8, 9);
        _ = ui.testOpenDialog();
        ui.testSetEdit(0, 12);
        ui.testSetEdit(1, 12);
        ui.testSetEdit(2, 0);
        ui.testSetEdit(3, 5);
        ui.testSetEdit(4, 0);
        ui.testSetEdit(5, 5);
        _ = ui.testApplyDialog();
        expect(out, ui.game_ptr.w == 12, "自定义应生效");
        const L7 = ui.testLayout();
        const cx7 = L7.board_x + 6 * L7.cell + @divTrunc(L7.cell, 2);
        const cy7 = L7.board_y + 6 * L7.cell + @divTrunc(L7.cell, 2);
        clearBoard(out, cx7, cy7, 5_000);
        expect(out, ui.game_ptr.win, "自定义盘也应能通关");
        expect(out, ui.testGetScore(0) == 7 and ui.testGetScore(1) == 8 and ui.testGetScore(2) == 9, "自定义棋盘不应写入任何纪录");
        out.writer().print("12 最高分纪录：记账/不覆盖/自定义不计入 通过\n", .{}) catch {};

        // 12.5 纪录窗正文：只有三行
        ui.testSetScores(12, 0, 340);
        const s = (ui.testScoresText());
        expect(out, std.mem.count(u8, s, "\n") == 3, "纪录窗应正好三行");
        expect(out, std.mem.startsWith(u8, s, "初级"), "第一行应是初级");
        expect(out, std.mem.indexOf(u8, s, "中级") != null, "应有中级");
        expect(out, std.mem.indexOf(u8, s, "高级") != null, "应有高级");
        expect(out, std.mem.indexOf(u8, s, "12 秒") != null, "初级应显示 12 秒");
        expect(out, std.mem.indexOf(u8, s, "340 秒") != null, "高级应显示 340 秒");
        expect(out, std.mem.indexOf(u8, s, "———") != null, "没纪录的档应给占位符，不该显示 0 秒");
        expect(out, std.mem.indexOf(u8, s, "9×9") == null and std.mem.indexOf(u8, s, "雷") == null, "纪录窗不该再带棋盘尺寸/雷数");
        expect(out, std.mem.indexOf(u8, s, "自定义") == null, "纪录窗不该再提自定义棋盘");
        expect(out, std.mem.indexOf(u8, s, "HKEY") == null and std.mem.indexOf(u8, s, "注册表") == null, "纪录窗不该再写存档位置");
        expect(out, std.mem.indexOf(u8, s, "新纪录") == null, "纪录窗正文里不该再带「新纪录」标记（只在标题里）");
        out.writer().print("12.5 纪录窗正文：\n{s}", .{s}) catch {};
    }

    // 13) 音效：六段内嵌 / tick 每整秒一下 / 四种踩雷按型 / 通关音
    {
        // 13a 内嵌素材：六段都在、都是标准 wav、四种踩雷音各不相同
        var all_riff = true;
        var all_big = true;
        for (0..6) |i| {
            if (!ui.testSoundIsRiff(i)) all_riff = false;
            if (ui.testSoundBytes(i) < 1000) all_big = false;
        }
        expect(out, all_riff, "六段音效都应是标准 wav（RIFF/WAVE 头）");
        expect(out, all_big, "六段音效都不该是空壳");
        expect(out, ui.testArgCount() > 0, "自检进程应当带着开关启动");
        expect(out, ui.testSoundMuted(), "非交互模式（自检/抓图/导出）应当静音");
        expect(out, !ui.testSoundsEqual(0, 1) and !ui.testSoundsEqual(0, 2) and !ui.testSoundsEqual(0, 3) and
            !ui.testSoundsEqual(1, 2) and !ui.testSoundsEqual(1, 3) and !ui.testSoundsEqual(2, 3), "四种踩雷音必须各不相同（不能四种雷一个声）");

        // 13b 计时：第 0 秒不响，从第 1 秒起每整秒一下，同秒不重复
        ui.testSoundReset();
        ui.testCommand(ui.test_IDM_BEGINNER);
        const Ls = ui.testLayout();
        const sx0 = Ls.board_x + 4 * Ls.cell + @divTrunc(Ls.cell, 2);
        const sy0 = Ls.board_y + 4 * Ls.cell + @divTrunc(Ls.cell, 2);
        ui.testMouse(Mouse.lbutton_down, sx0, sy0);
        ui.testMouse(Mouse.lbutton_up, sx0, sy0);
        expect(out, ui.game_ptr.started, "先开一局才谈得上计时的声音");
        ui.testBackdate(0);
        ui.testTimerTick();
        expect(out, ui.testSoundCount(5) == 0, "刚开局（第 0 秒）不该播 tick");
        ui.testBackdate(1_200);
        ui.testTimerTick();
        expect(out, ui.testSoundCount(5) == 1, "走到第 1 秒应播一次 tick");
        ui.testTimerTick();
        expect(out, ui.testSoundCount(5) == 1, "同一秒里再触发不该重复播");
        ui.testBackdate(2_500);
        ui.testTimerTick();
        expect(out, ui.testSoundCount(5) == 2, "第 2 秒应再来一次");
        ui.testBackdate(9_800);
        ui.testTimerTick();
        expect(out, ui.testSoundCount(5) == 3, "一次跳过好几秒也只补一下，不该连着炸一串");
        expect(out, ui.testSoundCount(4) == 0, "还没通关，不该播胜利音");

        // 13c 踩雷：四种雷各踩一次，播各自那一段
        var t: u8 = 1;
        while (t <= 4) : (t += 1) {
            ui.testSoundReset();
            ui.testCommand(ui.test_IDM_EXPERT);
            const Le = ui.testLayout();
            const px = Le.board_x + @divTrunc(Le.cell, 2);
            const py = Le.board_y + @divTrunc(Le.cell, 2);
            ui.testMouse(Mouse.lbutton_down, px, py);
            ui.testMouse(Mouse.lbutton_up, px, py);
            ui.testFaceFlashExpire();
            expect(out, ui.game_ptr.started and !ui.game_ptr.over, "高级盘第一下必是安全开局");
            var snd_cell: i32 = -1;
            for (0..ui.game_ptr.n) |k| {
                if (ui.game_ptr.mine[k] == t) {
                    snd_cell = @intCast(k);
                    break;
                }
            }
            expect(out, snd_cell >= 0, "高级盘（99 雷）四种雷都该有");
            ui.testSoundReset();
            const p = cellXY(Le, @intCast(snd_cell));
            ui.testMouse(Mouse.lbutton_down, p[0], p[1]);
            ui.testMouse(Mouse.lbutton_up, p[0], p[1]);
            expect(out, ui.game_ptr.over and !ui.game_ptr.win, "点雷应判负");
            expect(out, ui.testSoundCount(@as(usize, t) - 1) == 1, "踩中该类雷应播对应那一段踩雷音");
            var others: u32 = 0;
            for (0..6) |i| {
                if (i != @as(usize, t) - 1) others += ui.testSoundCount(i);
            }
            expect(out, others == 0, "踩雷时不该同时播别的声音");
        }

        // 13d 通关：只播胜利音
        ui.testSoundReset();
        ui.testCommand(ui.test_IDM_BEGINNER);
        const Lw = ui.testLayout();
        const wx = Lw.board_x + 4 * Lw.cell + @divTrunc(Lw.cell, 2);
        const wy = Lw.board_y + 4 * Lw.cell + @divTrunc(Lw.cell, 2);
        clearBoard(out, wx, wy, 3_000);
        expect(out, ui.game_ptr.win, "应通关");
        expect(out, ui.testSoundCount(4) == 1, "通关应播一次胜利音");
        var mine_played: u32 = 0;
        for (0..4) |i| mine_played += ui.testSoundCount(i);
        expect(out, mine_played == 0, "通关不该播踩雷音");
        out.writer().print("13 音效：六段内嵌 / tick 每整秒一下 / 四种踩雷按型 / 通关胜利音 通过\n", .{}) catch {};
    }

    // 14) 闵可夫斯基模式：菜单结构 / 圆点 / 标题 / j 单位 / 贴图分派 / 帮助窗口两个选项卡
    {
        // 14a 菜单结构：游戏菜单 = 开局、分隔线、圆复数模式▸、闵可夫斯基模式▸、分隔线、纪录、分隔线、三个缩放、分隔线、退出
        expect(out, ui.testPopupItemId(0, 0) == @as(i32, @intCast(ui.test_IDM_NEW)), "游戏菜单第一项应是开局");
        expect(out, ui.testPopupItemId(0, 1) == 0, "游戏菜单第二项应是分隔线（ID 0）");
        expect(out, ui.testPopupCount(0) == 12, "游戏菜单顶层应是 12 项（开局/分隔线/两个模式/分隔线/颜色/声音/三个缩放/分隔线/退出）");
        expect(out, ui.testSubItemId(0, 2, 0) == @as(i32, @intCast(ui.test_IDM_BEGINNER)), "圆复数模式子菜单第一项应是初级");
        expect(out, ui.testSubItemId(0, 2, 2) == @as(i32, @intCast(ui.test_IDM_EXPERT)), "圆复数模式子菜单第三项应是高级");
        expect(out, ui.testSubItemId(0, 2, 3) == 0, "圆复数模式子菜单第四项应是分隔线（ID 0）");
        expect(out, ui.testSubItemId(0, 2, 4) == @as(i32, @intCast(ui.test_IDM_BEST)), "圆复数模式子菜单应有最高分纪录");
        expect(out, ui.testSubItemId(0, 2, 5) == @as(i32, @intCast(ui.test_IDM_CUSTOM)), "圆复数模式子菜单最后一项应是自定义雷区");
        expect(out, ui.testSubItemId(0, 3, 0) == @as(i32, @intCast(ui.test_IDM_HYPER_BEGINNER)), "闵可夫斯基模式子菜单第一项应是初级");
        expect(out, ui.testSubItemId(0, 3, 2) == @as(i32, @intCast(ui.test_IDM_HYPER_EXPERT)), "闵可夫斯基模式子菜单第三项应是高级");
        expect(out, ui.testSubItemId(0, 3, 4) == @as(i32, @intCast(ui.test_IDM_HYPER_BEST)), "闵可夫斯基模式子菜单应有最高分纪录");
        expect(out, ui.testSubItemId(0, 3, 5) == @as(i32, @intCast(ui.test_IDM_HYPER_CUSTOM)), "闵可夫斯基模式子菜单最后一项应是自定义雷区");
        var best_at_top = false;
        for (0..10) |k| {
            if (ui.testPopupItemId(0, @intCast(k)) == @as(i32, @intCast(ui.test_IDM_BEST))) best_at_top = true;
        }
        expect(out, !best_at_top, "最高分纪录不该再留在游戏菜单顶层（两条都在模式里）");
        expect(out, ui.testMenuHasId(ui.test_IDM_HYPER_BEGINNER), "菜单树里应能找到闵可夫斯基初级");
        expect(out, ui.testMenuHasId(ui.test_IDM_HYPER_CUSTOM), "菜单树里应能找到闵可夫斯基自定义");

        // 14b 切到闵可夫斯基模式初级：模式、棋盘、档位、标题、圆点、j 单位格
        ui.testCommand(ui.test_IDM_HYPER_BEGINNER);
        expect(out, ui.testIsHyper(), "应切到闵可夫斯基模式");
        expect(out, ui.game_ptr.mode == .hyper, "游戏状态里的模式也该跟着切");
        expect(out, ui.game_ptr.w == 9 and ui.game_ptr.h == 9 and ui.game_ptr.mines == 10, "闵可夫斯基初级也应是 9×9/10");
        expect(out, ui.testPresetIndex() == 0, "当前档位应是初级");
        const htitle = (ui.testWindowTitle());
        expect(out, std.mem.eql(u8, ui.testWindowTitle(), ui.testAppTitle), "闵可夫斯基模式下标题也该原样（不多挂模式说明）");
        expect(out, std.mem.indexOf(u8, htitle, "复扫雷 Complexweeper") != null, "标题里应保留程序名");
        expect(out, std.mem.indexOf(u8, htitle, "闵可夫斯基") == null, "标题里不该出现模式说明");
        expect(out, ui.testSubItemChecked(0, 3, 0), "闵可夫斯基模式的初级应打上圆点");
        expect(out, !ui.testSubItemChecked(0, 3, 1), "闵可夫斯基模式的中级不该有圆点");
        expect(out, !ui.testSubItemChecked(0, 2, 0), "圆复数模式的初级不该跟着亮");
        expect(out, ui.testUnitSprite() == ui.testLedJSprite, "闵可夫斯基模式的计雷器第四格应是 j");
        expect(out, ui.testUnitSprite() != ui.testLedISprite, "闵可夫斯基模式不该再用 i 那一格");
        out.writer().print("14 闵可夫斯基模式：菜单结构 / 圆点 / 标题 / j 单位 通过\n", .{}) catch {};

        // 14c 显示值分派：手搓一个 5×5 闵可夫斯基局面，核对 D → 贴图（负数走 hnum_*_i）
        {
            const gm = ui.game_ptr;
            gm.w = 5;
            gm.h = 5;
            gm.n = 25;
            gm.mode = .hyper;
            gm.started = true;
            gm.over = false;
            gm.win = false;
            for (0..25) |k| {
                gm.mine[k] = 0;
                gm.clue[k] = -1;
                gm.open[k] = 0;
                gm.flag[k] = 0;
            }
            // 6=(1,1) 一颗 +1；7=(1,2)、18=(3,3)、19=(3,4) 三颗 +j；21=(4,1) 一颗 +1
            gm.mine[6] = 1;
            gm.mine[7] = 3;
            gm.mine[18] = 3;
            gm.mine[19] = 3;
            gm.mine[21] = 1;
            gm.computeClues();
            for ([_]usize{ 2, 4, 12, 20, 24 }) |k| gm.open[k] = 1;
            expect(out, gm.clue[12] == -3, "一格 +1 加两格 +j 的显示值应是 −3");
            expect(out, gm.clue[20] == 1, "一格 +1 的显示值应是 +1");
            expect(out, gm.clue[24] == -4, "两格 +j 的显示值应是 −4");
            expect(out, gm.clue[2] == 0, "一格 +1 加一格 +j 的显示值应是 0");
            expect(out, ui.testCellSprite(12) == ui.testHnumSprite(-3), "D=−3 应查 hnum_3_i（√3i）");
            expect(out, ui.testCellSprite(20) == ui.testHnumSprite(1), "D=+1 应查 hnum_1");
            expect(out, ui.testCellSprite(24) == ui.testHnumSprite(-4), "D=−4 应查 hnum_4_i（2i）");
            expect(out, ui.testCellSprite(2) == ui.testHnumSprite(0), "有雷但抵消成 0 的格子应显示 0");
            expect(out, ui.testCellSprite(4) == ui.testBlankSprite, "邻域真的没雷的格子仍应是空白");
            expect(out, ui.testHnumSprite(-4) != ui.testHnumSprite(4), "2i 与 2 不能共用一张图");
            out.writer().print("14c 闵可夫斯基贴图分派：−3→√3i / +1→1 / −4→2i / 0 与空白分开 通过\n", .{}) catch {};
        }

        // 14d 玩法与操作：一篇文案讲两个模式（不再是选项卡窗口）
        {
            const help = (ui.testHelpText);
            expect(out, std.mem.indexOf(u8, help, "圆复数模式：") != null, "玩法里应有「圆复数模式：」这一段");
            expect(out, std.mem.indexOf(u8, help, "双曲复数模式（闵可夫斯基模式）：") != null, "玩法里应有「双曲复数模式（闵可夫斯基模式）：」这一段");
            expect(out, std.mem.indexOf(u8, help, "分别是正实雷、负实雷、正虚雷、负虚雷") != null, "圆复数模式那段的四种雷应按雷的名字列");
            expect(out, std.mem.indexOf(u8, help, "正实雷（正类空雷）、负实雷（负类空雷）、正双曲虚雷（正类时雷）、负双曲虚雷（负类时雷）") != null, "双曲（闵可夫斯基）模式那段应写四种雷的全名");
            expect(out, std.mem.indexOf(u8, help, "实虚比例符合真实比例或其倒数") != null, "圆复数模式的判据要写清楚");
            expect(out, std.mem.indexOf(u8, help, "实部（类空部）、j部（类时部）的数量等于真实数量") != null, "闵可夫斯基模式的判据要写清楚（实部/类空部、j部/类时部）");
            expect(out, std.mem.indexOf(u8, help, "形式模长（时空间隔）S=√(a²-b²)") != null, "闵可夫斯基模式要说清时空间隔怎么算");
            expect(out, std.mem.indexOf(u8, help, "定义双曲虚数单位（类时单位）j²=1") != null, "闵可夫斯基模式要写明「定义类时单位j²=1」");
            out.writer().print("14d 玩法与操作：一篇文案含两个模式的规则 通过\n", .{}) catch {};
        }
        // 14e 纪录分模式 + 闵可夫斯基局照样记账
        {
            expect(out, ui.testScoreKeysDiffer(), "两个模式应各记一套纪录（键名不同）");
            ui.testSetScores(0, 0, 0);
            ui.testCommand(ui.test_IDM_HYPER_BEGINNER);
            const Lh = ui.testLayout();
            const hx = Lh.board_x + 4 * Lh.cell + @divTrunc(Lh.cell, 2);
            const hy = Lh.board_y + 4 * Lh.cell + @divTrunc(Lh.cell, 2);
            clearBoard(out, hx, hy, 33_000);
            expect(out, ui.game_ptr.win, "闵可夫斯基初级应能通关");
            expect(out, ui.testGetScore(0) == 33, "闵可夫斯基模式的用时也该记进初级那一格");
            out.writer().print("14e 纪录：闵可夫斯基局照记账 / 两套键名不同 通过\n", .{}) catch {};
        }
    }

    // 14f 自定义雷区的雷名随模式：闵可夫斯基模式下写「类空雷 / 类时雷」，圆复数模式写「实雷 / 虚雷」
    {
        ui.testCommand(ui.test_IDM_HYPER_BEGINNER);
        expect(out, ui.testOpenDialog(), "闵可夫斯基模式下自定义对话框应能打开");
        const labels = (ui.testDialogTexts());
        expect(out, std.mem.indexOf(u8, labels, "正实雷（正类空雷）") != null, "闵可夫斯基模式下应写全名「正实雷（正类空雷）」");
        expect(out, std.mem.indexOf(u8, labels, "负实雷（负类空雷）") != null, "闵可夫斯基模式下应写全名「负实雷（负类空雷）」");
        expect(out, std.mem.indexOf(u8, labels, "正双曲虚雷（正类时雷）") != null, "闵可夫斯基模式下应写全名「正双曲虚雷（正类时雷）」");
        expect(out, std.mem.indexOf(u8, labels, "负双曲虚雷（负类时雷）") != null, "闵可夫斯基模式下应写全名「负双曲虚雷（负类时雷）」");
        ui.testCloseDialog();
        ui.testCommand(ui.test_IDM_BEGINNER); // 回到圆复数模式，别影响后面的组
        expect(out, ui.testOpenDialog(), "圆复数模式下自定义对话框也应能打开");
        const labels2 = (ui.testDialogTexts());
        expect(out, std.mem.indexOf(u8, labels2, "正实雷") != null, "圆复数模式下仍写「正实雷」");
        expect(out, std.mem.indexOf(u8, labels2, "正虚雷") != null, "圆复数模式下仍写「正虚雷」");
        expect(out, std.mem.indexOf(u8, labels2, "正类空雷") == null, "圆复数模式下不该写「正类空雷」");
        expect(out, std.mem.indexOf(u8, labels2, "正类时雷") == null, "圆复数模式下不该写「正类时雷」");
        ui.testCloseDialog();
        out.writer().print("14f 自定义雷区：雷名随模式（实雷·虚雷 / 类空雷·类时雷）通过\n", .{}) catch {};
    }

    // 15) 失败/胜利后的判定贴图：标错雷 / 标错空格子 / 标对雷 / 标对旗 / 标错旗
    {
        const gm = ui.game_ptr;
        const S = ui.SpriteFamily;
        var nbuf: [8]usize = undefined;
        // 干净的小盘：5×5，中央 12 周围摆三种雷（1 正实 / 2 负实 / 3 正虚）
        const setup = struct {
            fn go(g2: *g.Game) void {
                g2.w = 5;
                g2.h = 5;
                g2.n = 25;
                g2.mode = .complex; // 别受前面几组留下的模式影响
                g2.started = true;
                g2.over = false;
                g2.win = false;
                g2.boom = -1;
                for (0..25) |k| {
                    g2.mine[k] = 0;
                    g2.flag[k] = 0;
                    g2.open[k] = 0;
                    g2.clue[k] = -1;
                }
            }
        }.go;
        setup(gm);
        _ = gm.nbrs(12, &nbuf);
        gm.mine[nbuf[0]] = 3; // 正虚雷（闵可夫斯基模式下就是正类时雷）
        gm.mine[nbuf[1]] = 1; // 正实雷
        gm.mine[nbuf[2]] = 2; // 负实雷
        gm.computeClues();

        // 15a 失败局面
        gm.over = true;
        gm.win = false;
        _ = gm.setFlag(nbuf[0], 1); // 正虚雷插成了正实旗 → 标错雷，按真实雷型（3）出图
        _ = gm.setFlag(nbuf[1], 1); // 正实雷插对了 → 标对雷
        _ = gm.setFlag(nbuf[3], 4); // 空格子插了旗 → 标错空格子
        expect(out, ui.testCellSprite(nbuf[0]) == ui.testSprite(S.wrong, false, 3), "失败：旗插错要贴「标错+真实雷型」那张，不是玩家插错的那型");
        expect(out, ui.testCellSprite(nbuf[0]) != ui.testSprite(S.wrong, false, 1), "失败：标错雷不能按玩家插错的旗型选图");
        expect(out, ui.testCellSprite(nbuf[1]) == ui.testSprite(S.right, false, 1), "失败：插对了要贴「标对正实雷」");
        expect(out, ui.testCellSprite(nbuf[3]) == ui.testWrongBlankSprite, "失败：给空格子插旗要贴「标错空格子」");
        expect(out, ui.testCellSprite(nbuf[2]) == ui.testSprite(S.mine, false, 2), "失败：没插旗的雷照旧显示雷本身");
        expect(out, ui.testSprite(S.mine, false, 2) != ui.testSprite(S.right, false, 2), "标对雷与雷本身不能是同一张");

        // 15b 胜利局面（胜利时所有非雷格都已翻开，所以旗只会在雷上）
        setup(gm);
        _ = gm.nbrs(12, &nbuf);
        gm.mine[nbuf[0]] = 3;
        gm.mine[nbuf[1]] = 1;
        gm.mine[nbuf[2]] = 2;
        gm.computeClues();
        gm.over = true;
        gm.win = true;
        _ = gm.setFlag(nbuf[0], 3); // 插对了 → 标对旗
        _ = gm.setFlag(nbuf[2], 1); // 插错了 → 标错旗（按真实雷型 2）
        expect(out, ui.testCellSprite(nbuf[0]) == ui.testSprite(S.rightflag, false, 3), "胜利：插对了要贴「标对正虚旗」");
        expect(out, ui.testCellSprite(nbuf[2]) == ui.testSprite(S.wrongflag, false, 2), "胜利：插错了要贴「标错+真实雷型」那张");
        expect(out, ui.testCellSprite(nbuf[2]) != ui.testSprite(S.wrongflag, false, 1), "胜利：标错旗也不能按玩家插错的旗型选图");
        expect(out, ui.testCellSprite(nbuf[1]) == ui.testClosedSprite, "胜利：没插旗的雷不该翻开（还是闭格）");

        // 15c 闵可夫斯基模式：3/4 两种雷换成 j 系列贴图
        gm.mode = .hyper;
        expect(out, ui.testSprite(S.mine, true, 1) == ui.testSprite(S.mine, false, 1), "闵可夫斯基模式的实雷与圆复数模式共用贴图");
        expect(out, ui.testSprite(S.mine, true, 3) != ui.testSprite(S.mine, false, 3), "闵可夫斯基模式的闵可夫斯基雷要换成它自己的贴图");
        expect(out, ui.testSprite(S.flag, true, 3) != ui.testSprite(S.flag, false, 3), "闵可夫斯基模式的闵可夫斯基旗要换成它自己的贴图");
        setup(gm);
        gm.mode = .hyper;
        _ = gm.nbrs(12, &nbuf);
        gm.mine[nbuf[0]] = 3;
        gm.mine[nbuf[2]] = 4;
        gm.computeClues();
        gm.over = true;
        gm.win = false;
        _ = gm.setFlag(nbuf[0], 1);
        expect(out, ui.testCellSprite(nbuf[0]) == ui.testSprite(S.wrong, true, 3), "闵可夫斯基模式失败：标错雷要用 j 版那张");
        gm.over = false;
        gm.win = false;
        expect(out, ui.testCellSprite(nbuf[1]) == ui.testClosedSprite, "闵可夫斯基模式中途：没插旗的格子仍是闭格");
        gm.boom = @intCast(nbuf[2]);
        gm.open[nbuf[2]] = 1;
        expect(out, ui.testCellSprite(nbuf[2]) == ui.testSprite(S.boom, true, 4), "闵可夫斯基模式踩中的闵可夫斯基雷要用它自己的踩中贴图");
        expect(out, ui.testCellSprite(nbuf[2]) != ui.testSprite(S.boom, false, 4), "闵可夫斯基模式踩中贴图不能沿用圆复数模式的");
        gm.mode = .complex;
        gm.boom = -1;
        out.writer().print("15 判定贴图：标错雷/标错空格子/标对雷/标对旗/标错旗 + 闵可夫斯基 j 系列 通过\n", .{}) catch {};
    }

    // 16) 声音开关：菜单里一行，点一下翻转，圆点跟着翻转
    {
        // 游戏菜单顶层：开局/分隔线/两个模式/分隔线/声音/三个缩放/分隔线/退出
        expect(out, ui.testPopupCount(0) == 12, "游戏菜单顶层应是 12 项（多出「颜色」「声音」两行）");
        expect(out, ui.testPopupItemId(0, 6) == @as(i32, @intCast(ui.test_IDM_SOUND)), "「声音」应在两个模式与「颜色」之后（第 7 项）");
        expect(out, ui.testPopupItemId(0, 7) == @as(i32, @intCast(ui.test_IDM_ZOOM1)), "「声音」后面接着三个缩放");
        // 起手状态取决于本机存着的偏好（默认是没有这一项 = 开），所以这里只验"翻转"，
        // 不去假设机器上一定是开的——否则换台机器、或者上次关过声音，自检就红了。
        const was_off = ui.testSoundOff();
        expect(out, ui.testPopupItemChecked(0, 6) == !was_off, "菜单圆点应反映当前状态（开着才有圆点）");
        ui.testCommand(ui.test_IDM_SOUND);
        expect(out, ui.testSoundOff() != was_off, "点一下应把开关翻过来");
        expect(out, ui.testPopupItemChecked(0, 6) == was_off, "翻过来后圆点状态也跟着翻");
        ui.testCommand(ui.test_IDM_SOUND);
        expect(out, ui.testSoundOff() == was_off, "再点一下应还原");
        expect(out, ui.testPopupItemChecked(0, 6) == !was_off, "圆点也应还原");
        expect(out, ui.testSoundMuted(), "自检进程仍然是强制静音状态（用户开关不影响这一层）");
        expect(out, !ui.testAudible(), "自检进程无论如何都不出声");
        out.writer().print("16 声音开关：点一下翻转（圆点跟着翻转）/ 再点还原 通过\n", .{}) catch {};
    }

    // 17) 颜色开关：勾选态 = 彩色贴图；关掉改用黑白贴图（菜单圆点与图集一起翻）
    {
        expect(out, ui.testPopupItemId(0, 5) == @as(i32, @intCast(ui.test_IDM_COLOR)), "第 6 项应是「颜色」");
        expect(out, ui.testBwAtlasLoaded(), "黑白图集应加载成功（由 assets/atlas-bw.png 生成的灰度图）");
        // 起手状态取决于本机存的偏好（默认没有这一项 = 彩色），所以只验翻转与图集切换
        const mono = ui.testColorOff();
        expect(out, ui.testPopupItemChecked(0, 5) == !mono, "颜色勾选态应反映当前状态（彩色才有圆点）");
        expect(out, ui.testActiveAtlasIsBw() == mono, "贴图该用哪份图集要跟颜色开关一致");
        ui.testCommand(ui.test_IDM_COLOR);
        expect(out, ui.testColorOff() != mono, "点一下应把颜色开关翻过来");
        expect(out, ui.testPopupItemChecked(0, 5) == mono, "翻过来后圆点也跟着翻");
        expect(out, ui.testActiveAtlasIsBw() != mono, "翻过来后贴图图集也应跟着换");
        ui.testCommand(ui.test_IDM_COLOR);
        expect(out, ui.testColorOff() == mono, "再点一下应还原");
        expect(out, ui.testActiveAtlasIsBw() == mono, "图集也应还原");
        out.writer().print("17 颜色开关：勾选=彩色贴图 / 取消=黑白贴图，圆点与图集同步 通过\n", .{}) catch {};
    }

    out.writer().print("\n断言 {d} 项，失败 {d} 项\n", .{ checks, fails }) catch {};
    out.writer().print("{s}\n", .{if (fails == 0) "全部通过" else "存在失败"}) catch {};
    return fails;
}
