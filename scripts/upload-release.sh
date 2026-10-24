#!/usr/bin/env bash
# 用 gh 上传 build/release/ 下的发行包；release 不存在时尝试创建。
# 先运行 ./scripts/build-release.sh 生成产物。
# 用法： ./scripts/upload-release.sh <tag>
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

tag="${1:-}"
[ -n "$tag" ] || { echo "用法：$0 <tag>，例如 v1.3.0" >&2; exit 2; }

version="$(sed -n 's/.*const APP_VERSION = "\([^"]*\)".*/\1/p' src/main.zig | head -n1)"
[ -n "$version" ] || { echo "读不到 src/main.zig 里的 APP_VERSION" >&2; exit 1; }

shopt -s nullglob
assets=(build/release/*.zip build/release/*.AppImage build/release/SHA256SUMS)
[ "${#assets[@]}" -gt 0 ] || { echo "没有发行包，先运行 ./scripts/build-release.sh" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "缺少 gh 命令" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh 尚未登录" >&2; exit 1; }

if ! gh release view "$tag" >/dev/null 2>&1; then
    repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
    sha="$(git rev-parse HEAD)"
    if ! gh api "repos/$repo/commits/$sha" >/dev/null 2>&1; then
        echo "当前提交 $sha 还没有推送到 $repo，无法创建指向它的 release。" >&2
        echo "请先推送当前分支，或先在 GitHub 上创建 release，再运行本脚本。" >&2
        exit 1
    fi
    gh release create "$tag" --target "$sha" \
        --title "复扫雷 Complexweeper $version" --generate-notes
fi

gh release upload "$tag" "${assets[@]}" --clobber
gh release view "$tag" --json url -q .url
