# Complexweeper

[简体中文](README.md) | English

Minesweeper, but the mines are complex numbers: each revealed cell shows the magnitude
of the sum of all mines around it.

Reveal every non-mine cell to win.

Win or lose, the game shows you which mines you flagged correctly and which you got wrong.

This is a rewrite of the gameplay of Microsoft Minesweeper (original authors Robert Donner
and Curt Johnson), built with Zig + SDL3. It runs natively on Windows and Linux
(Wayland / X11). The in-game UI is in Chinese.

## Game modes

There are currently two modes: circular complex numbers and Minkowski (hyperbolic complex numbers).

### Circular complex mode

Each board has four kinds of mines: positive real, negative real, positive imaginary and
negative imaginary — that is, +1, -1, +i and -i.

A cell's number is the magnitude of the sum of the mines around it.

Since there are at most 8 neighbours, only 24 values can appear:

```text
0, 1, 2, 3, 4, 5, 6, 7, 8,
√2, √5, √10, √13, √17, √26, √29, √34, √37,
2√2, 2√5, 3√2, 4√2, 5√2, 2√10
```

Equal numbers of positive and negative mines cancel each other out. We call such a
positive/negative pair a "cancelling pair".

`0` and blank are not the same. A blank cell has no mines around it at all;
`0` means the neighbourhood consists entirely of cancelling pairs.

Rule: a numbered cell can be chorded open when the number of flags around it equals the
true mine count and the real/imaginary ratio matches the true ratio or its reciprocal.
This can be used to probe for cancelling pairs. Remember that the win condition is
revealing all cells, not placing all flags correctly.

### Hyperbolic complex mode (Minkowski mode)

Define the hyperbolic imaginary unit (timelike unit) j² = 1 and the formal magnitude
(spacetime interval) S = √(a² − b²). This mode is merely inspired by the Minkowski
metric; it has little to do with general relativity.

The four kinds of mines are positive real (positive spacelike), negative real
(negative spacelike), positive hyperbolic-imaginary (positive timelike) and negative
hyperbolic-imaginary (negative timelike) — that is, +1, -1, +j and -j.

The possible values are:

```text
0, 1, √3, 2, √5, √7, 2√2, 3, 2√3, √15, 4, √21, 2√6, 5, 4√2, √35, 6, 4√3, 7, 8,
i, √3i, 2i, √5i, √7i, 2√2i, 3i, 2√3i, √15i, 4i, √21i, 2√6i, 5i, 4√2i, √35i, 6i, 4√3i, 7i, 8i
```

Because imaginary values appear, the real and j components of the mines can be inferred
directly, so the chord rule is stricter: the flag counts for the real (spacelike) and
j (timelike) components must both be exactly right. Positive/negative balance is still
not required.

All other rules are unchanged.

## Controls

- Left click: reveal a cell
- Right click: place a flag
- Middle click, or left + right click together: chord a cell open
- Click the face, or press `F2`: start a new game

The menu bar offers Beginner (9×9, 10 mines), Intermediate (16×16, 40 mines),
Expert (30×16, 99 mines) and custom boards for both modes, plus best times,
color/sound toggles and 100% / 200% / 300% zoom.

Best times, sound and color settings are stored in the per-user data directory:

- Linux: `${XDG_DATA_HOME:-~/.local/share}/Complexweeper/Complexweeper/settings.ini`
- Windows: `%APPDATA%\Complexweeper\Complexweeper\settings.ini`

## Download

Release packages are published under [Releases](../../releases):

- Windows: the archive contains `complexweeper.exe` together with the SDL3 runtime
  libraries (`SDL3.dll`, `SDL3_ttf.dll`). Unzip and run; no installation is required.
- Linux: an AppImage that contains the ELF executable and bundles the SDL3 runtime
  libraries, so no system packages are required:

  ```bash
  chmod +x complexweeper-<version>-x86_64.AppImage
  ./complexweeper-<version>-x86_64.AppImage
  ```

  If FUSE is unavailable, run it with `--appimage-extract-and-run`.

Release packages are built by local scripts, not CI.

## Building from source

Requirements:

- [Zig](https://ziglang.org/download/) 0.14.1
- SDL3 3.4.18 and SDL3_ttf 3.2.2 development packages
- Node.js (needed for release packaging; optional for a normal build — generated files are committed)
- Python 3 + fonttools (only when regenerating the font subset; the generated file is committed)
- No extra font is required; the UI font (a Noto Sans CJK SC subset) is embedded

### Linux

```bash
# Arch Linux
sudo pacman -S --needed base-devel sdl3 sdl3_ttf nodejs

# Debian / Ubuntu
sudo apt install build-essential libsdl3-dev libsdl3-ttf-dev nodejs

./scripts/build-linux.sh          # build and run both self-tests
./build/complexweeper
```

Or build directly with Zig:

```bash
zig build -Doptimize=ReleaseSmall
./zig-out/bin/complexweeper
```

SDL picks an available video driver automatically. To force native Wayland on a Wayland desktop:

```bash
SDL_VIDEODRIVER=wayland ./build/complexweeper
```

### Windows

In PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build-windows.ps1
```

The script downloads and caches the SDL3 / SDL3_ttf MinGW development packages,
cross-compiles a 64-bit Windows executable, copies the executable and runtime DLLs to
`build/dist/`, injects the icon, and runs both self-tests.

Downloads go through the `https://ghfast.top/` mirror by default. Pass
`-SdlMirror <prefix>` or set `SDL_MIRROR` to use another mirror, or `-SdlMirror ''`
to download directly from GitHub. Pre-downloaded zips can be placed in `build/sdl-deps/`.

### Regenerating the font subset

The UI font is already subset and committed as `src/font_subset.otf`, so a normal build
does not need to regenerate it. After changing UI text, add the new characters with:

```bash
# Arch: sudo pacman -S python-fonttools
# Debian / Ubuntu: sudo apt install python3-fonttools
python3 tools/make_font_subset.py
```

The script downloads the OFL-licensed Noto Sans CJK SC, subsets it using the string
literals in `src/*.zig`, caches the source font in `build/fonts/`, and writes the license
to `assets/fonts/OFL.txt`.

### Local release packages

On a Linux host, build both platform packages locally without CI:

```bash
./scripts/build-release.sh
```

The script regenerates the atlas, builds the native Linux version and cross-compiles the
Windows x86_64 version, runs both self-tests (the Windows tests require Wine), and writes
to `build/release/`:

```text
complexweeper-<version>-x86_64.AppImage
complexweeper-<version>-win64.zip
SHA256SUMS
```

AppImage packaging downloads `appimagetool` from GitHub Releases and caches it in
`build/appimage-tool/`. SDL downloads use the `https://ghfast.top/` mirror by default;
override with `SDL_MIRROR`.
Pass `--no-test` to skip the self-tests. Upload to GitHub Releases with:

```bash
./scripts/upload-release.sh v<version>
```

The current commit must already be pushed to GitHub, or a release with the same tag must exist.

## Self-tests

The program includes two windowless self-tests covering the rules and the
input → state → layout path of the UI:

```bash
./build/complexweeper --selftest build/selftest.txt
./build/complexweeper --uitest build/uitest.txt
```

Each report prints the number of passes and any failures; the build scripts fail
if either suite fails.

## Project layout

```text
src/           Zig sources (UI/platform layer, rules, audio, fonts, preferences)
assets/        Atlas images (color/mono) and slot table
tools/         Asset tools for atlas, sounds and icon (Node.js)
scripts/       Linux / Windows build and release scripts
build.zig      Zig build entry point
```

## Assets and licensing

Original Minesweeper image assets: Microsoft (original Minesweeper authors Robert Donner
and Curt Johnson).

New image assets (additional displayed values, four flag types, the i/j units of the
pseudo seven-segment display, the face button, etc.): 青月晓 (Qingyuexiao).

Program icon: 青月晓.

This program is not affiliated with Microsoft.

The code is licensed under GPL-3.0 (see `LICENSE`). The rights to the "original
Minesweeper image assets" belong to Microsoft and are not covered by the GPL-3.0 license.
See [`ASSET-NOTICE.md`](ASSET-NOTICE.md) for the detailed asset licensing status.

The program dynamically links SDL3 and SDL3_ttf (both zlib licensed). The Windows
release bundles those two runtime libraries; the Linux AppImage also bundles the
indirect font-rendering dependencies. Third-party license texts are in
[`assets/licenses/`](assets/licenses/), and inside release packages under `licenses/`.
