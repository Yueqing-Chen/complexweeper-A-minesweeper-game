# 素材说明（Asset Notice）

本仓库的图像素材分两类，授权状态不同。转载、再发布或商用之前请读一遍这张表。

图集有两份同槽位的版本：`assets/atlas.png`（彩色）与 `assets/atlas-bw.png`（黑白），
均为 208×207 的整图；`assets/atlas.json` 是槽位表。下面用槽位名指认具体是哪几张。

## 一、扫雷原始图像素材 —— 权利属于 Microsoft

| 槽位 | 内容 |
| --- | --- |
| `closed` / `blank` | 经典立体按钮：未翻开格、已翻开的空白格 |
| `flag_1`…`flag_4` | 四种旗帜（正实 / 负实 / 正虚 / 负虚），由原版旗帜按类型做色相调整 |
| `mine_1`…`mine_4` | 四种雷，同上 |
| `boom_1`…`boom_4` | 踩中的四种雷（同色雷 + 红底） |
| `wrong_1`…`wrong_4` | 标错的四种旗（按玩家插的那一型取图，同色雷 + 红叉） |

这些图形的版权归 Microsoft 所有，源自 Microsoft 扫雷（作者 Robert Donner、Curt Johnson），
**不适用本仓库的 GPL-3.0 授权**。把它们留在这里，是为了让这个复刻版在视觉上与经典扫雷一致，
只在"个人学习 / 兼容性展示"的意义上使用。

**要商用或正式再发布**：请自行确认这部分素材的可用性，或者把它们换成你自己的图——
改 `assets/atlas.png` 里对应的那几个矩形即可（槽位坐标见 `assets/atlas.json`，改完重新构建；
`tools/gen_atlas.js` 会挡住尺寸/越界/缺图这几类错误）。

## 二、原创与新增素材 —— 青月晓，随本仓库按 GPL-3.0 发布

| 槽位 | 内容 |
| --- | --- |
| `num_0` … `num_64` | 24 个显示值的数字贴图，含 $k\sqrt{r}$ 那几种带系数的根式 |
| `led_0`…`led_9` / `led_minus` / `led_blank` / `led_i` | 计雷器与计时器的 LED 数字、负号、空格子、虚雷第四格那个 $i$ 单位 |
| `face_normal` / `face_down` / `face_scan` / `face_dead` / `face_win` | 五张脸（风格取自原版笑脸，重绘） |
| `icon` | 程序图标，32×32，带 alpha |

（绘制源文件与音效原件都留在本机，未随仓库发布。）

## 三、音效 —— 青月晓自制，随本仓库按 GPL-3.0 发布

六段 22050 Hz / 8 bit / 单声道 wav：四种雷各一段踩雷音、`win`（通关）、`tick`（计时每秒一下）。
它们由本项目的 DSP 脚本合成，**已经编进程序**
（打包成 `src/sounds.bin`）。

`assets/sounds/` 里的 wav 原件留在本机，不随仓库发布；
要改音效就用 `node tools/gen_sounds.js --extract <目录>` 把内嵌的六段导出来。

## 四、字体 —— SIL Open Font License 1.1

界面字体使用 **Noto Sans CJK SC** 的子集，已嵌入程序二进制（`src/font_subset.otf`）。
源字体来自 <https://github.com/notofonts/noto-cjk>（commit
`f8d157532fbfaeda587e826d4cd5b21a49186f7c` 的
`Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf`），按 SIL Open Font License 1.1
发布；许可证全文见 `assets/fonts/OFL.txt`，发行包中随附为 `FONT-OFL.txt`。
子集只保留界面实际用到的字符，由 `tools/make_font_subset.py` 生成。系统字体仅在子集缺字时
作为后备，不再是运行必需。

## 五、第三方运行库

程序动态链接 SDL3 与 SDL3_ttf，AppImage 还打包了字体渲染所需的间接依赖。
这些库不属于本仓库，按各自的许可证原样分发，完整文本见 `assets/licenses/`
（发行包中为 `licenses/`，AppImage 内位于 `usr/share/doc/complexweeper/licenses/`）：

| 库 | 许可证 |
| --- | --- |
| SDL3、SDL3_ttf | Zlib |
| HarfBuzz | MIT（Old MIT） |
| FreeType | FTL（FreeType License） |
| GLib | LGPL-2.1-or-later |
| Graphite2 | LGPL-2.1-or-later |
| PCRE2 | BSD-3-Clause WITH PCRE2-exception |
| libpng | libpng-2.0 |
| zlib | Zlib |
| bzip2 | bzip2-1.0.6 |
| Brotli | MIT |

Windows 发行包只附带 `SDL3.dll` 与 `SDL3_ttf.dll`；Linux AppImage 打包上表全部运行库。
具体版本取决于构建主机，`assets/licenses/THIRD-PARTY.md` 记录了各库的上游地址与许可证文件。

## 商标

本程序是独立复刻作品，与 Microsoft 公司无隶属关系，也未获得其授权或背书。
"Minesweeper"、"扫雷"及相关商标归各自权利人所有。
