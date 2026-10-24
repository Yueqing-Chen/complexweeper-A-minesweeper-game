#!/usr/bin/env python3
"""下载 OFL 授权的 Noto Sans CJK SC，并按界面用字生成嵌入程序的字体子集。

用法: python3 tools/make_font_subset.py [--force]
环境: FONT_MIRROR=https://mirror/  （置空则直连 GitHub；默认沿用 SDL_MIRROR 或 ghfast）
产物: src/font_subset.otf（嵌入程序）、assets/fonts/OFL.txt（许可证）
依赖: curl、fonttools（pyftsubset）
"""
import argparse
import os
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONT_COMMIT = "f8d157532fbfaeda587e826d4cd5b21a49186f7c"
FONT_URL = (
    "https://raw.githubusercontent.com/notofonts/noto-cjk/"
    f"{FONT_COMMIT}/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf"
)
LICENSE_URL = (
    "https://raw.githubusercontent.com/notofonts/noto-cjk/"
    f"{FONT_COMMIT}/Sans/LICENSE"
)
FONT_CACHE = ROOT / "build" / "fonts" / "NotoSansCJKsc-Regular.otf"
CHARS_FILE = ROOT / "build" / "fonts" / "chars.txt"
OUT_FONT = ROOT / "src" / "font_subset.otf"
OUT_LICENSE = ROOT / "assets" / "fonts" / "OFL.txt"

# 界面会用到、但不一定出现在字符串字面量里的字符：ASCII、全角 ASCII、中文标点与常用数学符号。
EXTRA_CHARS = (
    "　！＂＃＄％＆＇（）＊＋，－．／０１２３４５６７８９：；＜＝＞？＠［＼］＾＿｀｛｜｝～"
    "、。〃々〆〇〈〉《》「」『』【】〔〕〖〗〘〙〚〛〜〝〞〟〰〾〿–—‘’“”„…‧﹏￥"
    "×÷±√∞≤≥≠≈→←↑↓"
)
STRING_RE = re.compile(r'"(?:\\.|[^"\\])*"', re.S)
ESCAPE_RE = re.compile(r"\\u\{([0-9A-Fa-f]+)\}")


def mirror_urls(url):
    mirror = os.environ.get("FONT_MIRROR")
    if mirror is None:
        mirror = os.environ.get("SDL_MIRROR", "https://ghfast.top/")
    mirror = mirror.strip()
    if mirror:
        return [mirror.rstrip("/") + "/" + url, url]
    return [url]


def download(name, url, dest, force=False):
    dest = pathlib.Path(dest)
    if dest.exists() and not force:
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    for u in mirror_urls(url):
        print(f"下载 {name} ← {u}")
        tmp.unlink(missing_ok=True)
        if subprocess.run(
            ["curl", "-fL", "--retry", "3", "--connect-timeout", "30",
             "--max-time", "1800", "-o", str(tmp), u],
        ).returncode == 0:
            tmp.replace(dest)
            return
    raise SystemExit(
        f"下载 {name} 失败；可用 FONT_MIRROR 换镜像，或手动放到 {dest}"
    )


def collect_chars():
    chars = {chr(c) for c in range(0x20, 0x7F)}
    chars.update(EXTRA_CHARS)
    for path in sorted((ROOT / "src").rglob("*.zig")):
        text = path.read_text("utf-8")
        for m in STRING_RE.finditer(text):
            chars.update(m.group(0)[1:-1])
        for m in ESCAPE_RE.finditer(text):
            chars.add(chr(int(m.group(1), 16)))
    for c in "\n\r\t":
        chars.discard(c)
    return chars


def fonttools_python():
    for exe in (sys.executable, "/usr/bin/python", "/usr/bin/python3"):
        if exe and subprocess.run(
            [exe, "-c", "import fontTools"], capture_output=True,
        ).returncode == 0:
            return exe
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--force", action="store_true", help="重新下载字体与许可证并重切子集")
    args = ap.parse_args()

    if subprocess.run(["pyftsubset", "--help"], capture_output=True).returncode != 0:
        raise SystemExit("缺少 pyftsubset，请安装 fonttools（python-fonttools）")
    check_py = fonttools_python()
    if not check_py:
        raise SystemExit("找不到能 import fontTools 的 Python 解释器")

    download("Noto Sans CJK SC", FONT_URL, FONT_CACHE, args.force)
    download("OFL 许可证", LICENSE_URL, OUT_LICENSE, args.force)

    chars = collect_chars()
    CHARS_FILE.parent.mkdir(parents=True, exist_ok=True)
    CHARS_FILE.write_text("".join(sorted(chars)), "utf-8")

    OUT_FONT.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        "pyftsubset", str(FONT_CACHE),
        f"--text-file={CHARS_FILE}",
        f"--output-file={OUT_FONT}",
        "--layout-features=*",
        "--glyph-names",
        "--symbol-cmap",
        "--legacy-cmap",
        "--notdef-glyph",
        "--notdef-outline",
        "--recommended-glyphs",
        "--name-IDs=*",
        "--name-languages=*",
    ]
    print(f"切子集：{len(chars)} 个字符…")
    subprocess.run(cmd, check=True)

    verify = (
        "import sys\n"
        "from fontTools.ttLib import TTFont\n"
        "chars = set(open(sys.argv[2], encoding='utf-8').read())\n"
        "cmap = TTFont(sys.argv[1]).getBestCmap()\n"
        "missing = sorted(c for c in chars if ord(c) not in cmap)\n"
        "print(''.join(missing))\n"
        "print(len(cmap))\n"
        "sys.exit(1 if missing else 0)\n"
    )
    r = subprocess.run(
        [check_py, "-c", verify, str(OUT_FONT), str(CHARS_FILE)],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        print("字体缺少以下界面字符：" + r.stdout.splitlines()[0], file=sys.stderr)
        raise SystemExit(1)
    mapped = int(r.stdout.splitlines()[1])

    src_size = FONT_CACHE.stat().st_size
    out_size = OUT_FONT.stat().st_size
    print(f"完成：{OUT_FONT}（{out_size} 字节，源字体 {src_size} 字节，{mapped} 个映射）")


if __name__ == "__main__":
    main()
