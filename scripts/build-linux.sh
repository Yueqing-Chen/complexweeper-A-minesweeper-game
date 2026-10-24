#!/usr/bin/env bash
# 构建 Linux 原生版本并跑两套自检。
# 依赖：Zig 0.14.1、SDL3 与 SDL3_ttf 的开发包（pkg-config 能找到 SDL3、SDL3_ttf）。
# 用法： ./scripts/build-linux.sh [--no-test]
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

zig="${ZIG:-zig}"
if ! command -v "$zig" >/dev/null 2>&1; then
    echo "找不到 zig。请安装 Zig 0.14.1，或用 ZIG=/path/to/zig 指定。" >&2
    exit 1
fi
if ! pkg-config --exists sdl3 sdl3-ttf 2>/dev/null; then
    echo "缺少 SDL3 / SDL3_ttf 开发包（pkg-config 找不到 sdl3 或 sdl3-ttf）。" >&2
    echo "Arch: pacman -S sdl3 sdl3_ttf；Debian/Ubuntu: apt install libsdl3-dev libsdl3-ttf-dev" >&2
    exit 1
fi

if command -v node >/dev/null 2>&1; then
    node tools/gen_atlas.js
elif [ ! -f src/atlas.bin ] || [ ! -f src/assets.zig ]; then
    echo "缺少 src/atlas.bin 或 src/assets.zig，且没有 Node.js 可以重新生成图集。" >&2
    exit 1
fi

"$zig" version
"$zig" build -Doptimize=ReleaseSmall

mkdir -p build
cp zig-out/bin/complexweeper build/complexweeper

if [ "${1:-}" != "--no-test" ]; then
    echo
    ./build/complexweeper --selftest build/selftest.txt
    tail -n 2 build/selftest.txt
    ./build/complexweeper --uitest build/uitest.txt
    tail -n 2 build/uitest.txt
fi

echo
echo "完成：build/complexweeper"
