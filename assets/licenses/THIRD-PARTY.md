# 第三方运行库许可证（Third-Party Licenses）

本目录收录发行包所附带第三方运行库的许可证文本。这些库不属于本仓库，
版权归各自的作者所有；本项目按各自的许可证原样分发未修改的发行版二进制。

| 库 | 系统包 | 许可证 | 上游 | 许可证文本 |
| --- | --- | --- | --- | --- |
| SDL3 | `sdl3` | Zlib | <https://github.com/libsdl-org/SDL> | `SDL3.txt` |
| SDL3_ttf | `sdl3_ttf` | Zlib | <https://github.com/libsdl-org/SDL_ttf> | `SDL3_ttf.txt` |
| HarfBuzz | `harfbuzz` | MIT（Old MIT） | <https://github.com/harfbuzz/harfbuzz> | `harfbuzz.txt` |
| FreeType | `freetype2` | FTL（FreeType License） | <https://gitlab.freedesktop.org/freetype/freetype> | `freetype.txt` |
| GLib | `glib2` | LGPL-2.1-or-later | <https://gitlab.gnome.org/GNOME/glib> | `glib.txt`、`LGPL-2.1-or-later.txt` |
| Graphite2 | `graphite` | LGPL-2.1-or-later | <https://github.com/silnrsi/graphite> | `graphite2.txt`、`LGPL-2.1-or-later.txt` |
| PCRE2 | `pcre2` | BSD-3-Clause WITH PCRE2-exception | <https://github.com/PCRE2Project/pcre2> | `pcre2.txt` |
| libpng | `libpng` | libpng-2.0 | <http://www.libpng.org/pub/png/libpng.html> | `libpng.txt` |
| zlib | `zlib` | Zlib | <https://zlib.net/> | `zlib.txt` |
| bzip2 | `bzip2` | bzip2-1.0.6 | <https://sourceware.org/bzip2/> | `bzip2.txt` |
| Brotli | `brotli` | MIT | <https://github.com/google/brotli> | `brotli.txt` |

## 分发说明

- Linux AppImage 打包了上表中的全部运行库，许可证文本位于
  `usr/share/doc/complexweeper/licenses/`。
- Windows 发行包只附带 `SDL3.dll` 与 `SDL3_ttf.dll`；为方便查阅，也一并放入本目录的全部文本。
- 字体不是运行库；其许可证（SIL Open Font License 1.1）见 `assets/fonts/OFL.txt`，
  发行包中为 `FONT-OFL.txt`。
- 具体打包的库版本取决于构建主机；本目录只记录许可证，不锁定版本。

如果重新分发本程序的二进制，请保留 `licenses/` 目录与 `ASSET-NOTICE.md`。
