#!/usr/bin/env bash
# 本地发行构建：Linux x86_64 AppImage + Windows x86_64 zip，不经过 CI。
# 依赖：Zig 0.14.1、Node.js、curl、unzip、zip、sha256sum、ldd；
#       Linux 构建另需 pkg-config 能找到 sdl3 与 sdl3-ttf。
# AppImage 打包会从 GitHub Releases 下载 appimagetool 并缓存到 build/appimage-tool/。
# 可选：wine（用于运行 Windows 版自检）。
# 用法： ./scripts/build-release.sh [--no-test]
# 环境： ZIG=/path/to/zig  SDL_MIRROR=https://mirror/  （SDL_MIRROR 置空则直连 GitHub）
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

zig="${ZIG:-zig}"
mirror="${SDL_MIRROR-https://ghfast.top/}"
if [ -n "$mirror" ]; then mirror="${mirror%/}/"; fi

no_test=0
for arg in "$@"; do
    case "$arg" in
        --no-test) no_test=1 ;;
        *) echo "未知参数：$arg" >&2; exit 2 ;;
    esac
done

die() { echo "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"; }

version="$(sed -n 's/.*const APP_VERSION = "\([^"]*\)".*/\1/p' src/main.zig | head -n1)"
[ -n "$version" ] || die "读不到 src/main.zig 里的 APP_VERSION"

need "$zig"
need node
need curl
need unzip
need zip
need sha256sum
need ldd
got="$("$zig" version)"
[ "$got" = "0.14.1" ] || die "Zig 版本不对：$got，本工程按 0.14.1 写"
pkg-config --exists sdl3 sdl3-ttf 2>/dev/null ||
    die "缺少 SDL3 / SDL3_ttf 开发包（pkg-config 找不到 sdl3 或 sdl3-ttf）"

release="$root/build/release"
reports="$release/reports"
rm -rf "$release"
mkdir -p "$reports"

download() {
    local name="$1" url="$2" out="$3"
    local urls=() u tmp="$out.part"
    [ -n "$mirror" ] && urls+=("$mirror$url")
    urls+=("$url")
    rm -f "$tmp"
    for u in "${urls[@]}"; do
        echo "  下载 $name ← $u"
        if curl -fL --retry 3 --connect-timeout 30 --max-time 900 -o "$tmp" "$u"; then
            mv "$tmp" "$out"
            return 0
        fi
        rm -f "$tmp"
    done
    return 1
}

# 把 ldd 列出、除 glibc 之外的共享库收进 AppImage。
copy_runtime_libs() {
    local bin="$1" dest="$2" lib base
    mkdir -p "$dest"
    while IFS= read -r lib; do
        [ -n "$lib" ] || continue
        base="$(basename "$lib")"
        case "$base" in
            libc.so.*|libm.so.*|libpthread.so.*|libdl.so.*|librt.so.*|libresolv.so.*|libnss_*|libutil.so.*|ld-linux*)
                continue
                ;;
        esac
        cp -L "$lib" "$dest/$base"
    done < <(ldd "$bin" | awk '/=> \//{print $3} /^[[:space:]]*\/[^ ]*\.so/{print $1}' | sort -u)
}

echo "[1/4] 生成图集…"
node tools/gen_atlas.js

echo
echo "[2/4] 构建 Linux 版并打包 AppImage…"
"$zig" build -Doptimize=ReleaseSmall

appdir="$root/build/AppDir"
rm -rf "$appdir"
mkdir -p "$appdir/usr/bin" "$appdir/usr/lib" \
    "$appdir/usr/share/applications" \
    "$appdir/usr/share/icons/hicolor/256x256/apps" \
    "$appdir/usr/share/doc/complexweeper"
cp zig-out/bin/complexweeper "$appdir/usr/bin/complexweeper"
copy_runtime_libs "$appdir/usr/bin/complexweeper" "$appdir/usr/lib"

node tools/extract_icon.js "$appdir/complexweeper.png" 256
cp "$appdir/complexweeper.png" "$appdir/usr/share/icons/hicolor/256x256/apps/complexweeper.png"
ln -s complexweeper.png "$appdir/.DirIcon"
cp README.md README.en.md LICENSE ASSET-NOTICE.md "$appdir/usr/share/doc/complexweeper/"
cp assets/fonts/OFL.txt "$appdir/usr/share/doc/complexweeper/FONT-OFL.txt"
cp -r assets/licenses "$appdir/usr/share/doc/complexweeper/licenses"

cat > "$appdir/complexweeper.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Complexweeper
Name[zh_CN]=复扫雷
GenericName=Minesweeper
GenericName[zh_CN]=扫雷
Comment=A cross-platform minesweeper game
Comment[zh_CN]=跨平台扫雷游戏
Exec=complexweeper
Icon=complexweeper
Terminal=false
Categories=Game;LogicGame;
Keywords=minesweeper;game;扫雷;
EOF
cp "$appdir/complexweeper.desktop" "$appdir/usr/share/applications/complexweeper.desktop"
if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$appdir/complexweeper.desktop"
fi

cat > "$appdir/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$HERE/usr/bin/complexweeper" "$@"
EOF
chmod +x "$appdir/AppRun"

appimage_tool="$root/build/appimage-tool/appimagetool-x86_64.AppImage"
if [ ! -x "$appimage_tool" ]; then
    mkdir -p "$(dirname "$appimage_tool")"
    download "appimagetool" \
        "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" \
        "$appimage_tool" ||
        die "下载 appimagetool 失败；可用 SDL_MIRROR 换镜像，或手动把它放到 $appimage_tool"
    chmod +x "$appimage_tool"
fi
appimage_runtime="$root/build/appimage-tool/runtime-x86_64"
if [ ! -f "$appimage_runtime" ]; then
    download "AppImage runtime" \
        "https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64" \
        "$appimage_runtime" ||
        die "下载 AppImage runtime 失败；可用 SDL_MIRROR 换镜像，或手动把它放到 $appimage_runtime"
fi

appimage="$release/complexweeper-$version-x86_64.AppImage"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$appimage_tool" \
    --no-appstream --runtime-file "$appimage_runtime" "$appdir" "$appimage" >/dev/null
rm -f "$release"/*.zsync
[ -f "$appimage" ] || die "AppImage 没有生成"

if [ "$no_test" -eq 0 ]; then
    APPIMAGE_EXTRACT_AND_RUN=1 "$appimage" --selftest "$reports/selftest-linux.txt"
    tail -n 2 "$reports/selftest-linux.txt"
    APPIMAGE_EXTRACT_AND_RUN=1 "$appimage" --uitest "$reports/uitest-linux.txt"
    tail -n 2 "$reports/uitest-linux.txt"
fi

sdl_ver=3.4.18
ttf_ver=3.2.2
deps="$root/build/sdl-deps"
mkdir -p "$deps"

fetch_dep() {
    local name="$1" url="$2" zip="$deps/$1.zip" dir="$deps/$1"
    if [ -d "$dir" ]; then return; fi
    if [ ! -f "$zip" ]; then
        download "$name" "$url" "$zip" ||
            die "下载 $name 失败；可用 SDL_MIRROR 换镜像，或手动把 $name.zip 放进 $deps"
    fi
    mkdir -p "$dir"
    unzip -q "$zip" -d "$dir"
}

echo
echo "[3/4] 构建 Windows 版…"
fetch_dep "SDL3-devel" \
    "https://github.com/libsdl-org/SDL/releases/download/release-$sdl_ver/SDL3-devel-$sdl_ver-mingw.zip"
fetch_dep "SDL3_ttf-devel" \
    "https://github.com/libsdl-org/SDL_ttf/releases/download/release-$ttf_ver/SDL3_ttf-devel-$ttf_ver-mingw.zip"

sdl_inc="$(find "$deps/SDL3-devel" -type d -path '*/x86_64-w64-mingw32/include/SDL3' -print -quit)"
ttf_inc="$(find "$deps/SDL3_ttf-devel" -type d -path '*/x86_64-w64-mingw32/include/SDL3_ttf' -print -quit)"
sdl_lib="$(find "$deps/SDL3-devel" -type f -path '*/x86_64-w64-mingw32/lib/libSDL3.dll.a' -print -quit)"
ttf_lib="$(find "$deps/SDL3_ttf-devel" -type f -path '*/x86_64-w64-mingw32/lib/libSDL3_ttf.dll.a' -print -quit)"
sdl_dll="$(find "$deps/SDL3-devel" -type f -path '*/x86_64-w64-mingw32/bin/SDL3.dll' -print -quit)"
ttf_dll="$(find "$deps/SDL3_ttf-devel" -type f -path '*/x86_64-w64-mingw32/bin/SDL3_ttf.dll' -print -quit)"
[ -n "$sdl_inc" ] && [ -n "$ttf_inc" ] && [ -n "$sdl_lib" ] && [ -n "$ttf_lib" ] &&
    [ -n "$sdl_dll" ] && [ -n "$ttf_dll" ] || die "SDL 开发包目录不完整"

inc_root="$root/build/sdl-include"
lib_root="$root/build/sdl-lib"
rm -rf "$inc_root" "$lib_root"
mkdir -p "$inc_root" "$lib_root"
cp -r "$(dirname "$sdl_inc")/SDL3" "$inc_root/"
cp -r "$(dirname "$ttf_inc")/SDL3_ttf" "$inc_root/"
# Zig 的 linkSystemLibrary 在 windows-gnu 下只认 libSDL3.a，不认 libSDL3.dll.a。
cp "$sdl_lib" "$lib_root/libSDL3.a"
cp "$ttf_lib" "$lib_root/libSDL3_ttf.a"

"$zig" build -Dtarget=x86_64-windows-gnu -Doptimize=ReleaseSmall \
    -Dsdl-include="$inc_root" -Dsdl-lib="$lib_root"

win_stage="$release/complexweeper-$version-win64"
mkdir -p "$win_stage"
cp zig-out/bin/complexweeper.exe "$win_stage/"
cp "$sdl_dll" "$ttf_dll" "$win_stage/"
cp assets/fonts/OFL.txt "$win_stage/FONT-OFL.txt"
cp -r assets/licenses "$win_stage/licenses"

node tools/set_icon.js "$win_stage/complexweeper.exe" "$win_stage/complexweeper-icon.exe"
mv "$win_stage/complexweeper-icon.exe" "$win_stage/complexweeper.exe"
node tools/inspect_exe.js "$win_stage/complexweeper.exe"

if [ "$no_test" -eq 0 ]; then
    if command -v wine >/dev/null 2>&1; then
        if ! (cd "$win_stage" && WINEDEBUG=-all wine complexweeper.exe --selftest selftest.txt \
                >/dev/null 2>"$reports/wine-selftest.log"); then
            cat "$reports/wine-selftest.log" >&2
            die "Windows 规则自检失败"
        fi
        tail -n 2 "$win_stage/selftest.txt"
        if ! (cd "$win_stage" && WINEDEBUG=-all wine complexweeper.exe --uitest uitest.txt \
                >/dev/null 2>"$reports/wine-uitest.log"); then
            cat "$reports/wine-uitest.log" >&2
            die "Windows 界面自检失败"
        fi
        tail -n 2 "$win_stage/uitest.txt"
        mv "$win_stage/selftest.txt" "$reports/selftest-windows.txt"
        mv "$win_stage/uitest.txt" "$reports/uitest-windows.txt"
    else
        echo "警告：未安装 wine，跳过 Windows 版自检。" >&2
    fi
fi

echo
echo "[4/4] 打包…"
zip -j "$release/complexweeper-$version-win64.zip" \
    "$win_stage/complexweeper.exe" "$win_stage/SDL3.dll" "$win_stage/SDL3_ttf.dll" \
    "$win_stage/FONT-OFL.txt" README.md README.en.md LICENSE ASSET-NOTICE.md >/dev/null
(cd "$win_stage" && zip -r "$release/complexweeper-$version-win64.zip" licenses >/dev/null)

(
    cd "$release"
    shopt -s nullglob
    files=(*.zip *.AppImage)
    [ "${#files[@]}" -gt 0 ] || die "没有生成发行包"
    sha256sum "${files[@]}" > SHA256SUMS
)

echo
echo "完成，发行包在 $release："
ls -lh "$release"/*.zip "$release"/*.AppImage "$release/SHA256SUMS"
if [ "$no_test" -eq 0 ]; then
    echo "自检报告在 $reports"
fi
echo
echo "上传： ./scripts/upload-release.sh v$version"
