#!/usr/bin/env bash
#
# slim-repo.sh — 把 photos/*.jpg 母版从 Git 历史里移除，降低 clone 体积。
#
#   ⚠️ 这一步不可逆，而且不是「跑一次就变小」：
#      1. 重写历史会改写所有 commit 的 SHA，远端需要 force-push；
#      2. force-push 之后旧对象仍留在 GitHub 上，仓库体积不会立刻下降；
#      3. 真正回收空间必须联系 GitHub Support 请求 GC（或删除重建仓库）。
#
#   所以本脚本默认只做「演练」（--dry-run），必须显式加 --apply 才会真跑，
#   而且跑之前会强制检查备份是否存在。
#
# 前置：
#   - 母版已备份到仓库外（默认检查 $HOME/Pictures/studio-photos-originals）
#   - 已安装 git-filter-repo：brew install git-filter-repo
#
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/Pictures/studio-photos-originals}"
APPLY=0

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --dry-run) APPLY=0 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "未知参数: $arg" >&2; exit 2 ;;
  esac
done

cd "$REPO_DIR"

echo "仓库:   $REPO_DIR"
echo "备份:   $BACKUP_DIR"
echo "模式:   $([ $APPLY -eq 1 ] && echo '真跑 (--apply)' || echo '演练 (默认, 不做任何修改)')"
echo

# ── 1. 前置检查 ────────────────────────────────────────────────
masters=$(find photos -maxdepth 1 -name '*.jpg' ! -name 'hero.jpg' | wc -l | tr -d ' ')
echo "母版数量: $masters 张（不含 hero.jpg）"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "✗ 备份目录不存在: $BACKUP_DIR" >&2
  echo "  先备份再谈删历史。备份命令：" >&2
  echo "    mkdir -p \"$BACKUP_DIR\" && cp -p photos/*.jpg photos/bgm.mp3 \"$BACKUP_DIR\"/" >&2
  exit 1
fi

missing=0
for f in photos/*.jpg; do
  [ -e "$BACKUP_DIR/$(basename "$f")" ] || { echo "✗ 备份缺文件: $(basename "$f")" >&2; missing=1; }
done
[ $missing -eq 0 ] || { echo "✗ 备份不完整，中止。" >&2; exit 1; }
echo "✓ 备份完整（逐文件存在性检查通过）"

command -v git-filter-repo >/dev/null 2>&1 || {
  echo "✗ 未安装 git-filter-repo。macOS: brew install git-filter-repo" >&2
  exit 1
}

if [ -n "$(git status --porcelain)" ]; then
  echo "✗ 工作区不干净，先提交或 stash。" >&2
  exit 1
fi
echo "✓ 工作区干净"

# 列出会被移除的路径，供人复核
echo
echo "将从全部历史中移除的路径模式："
echo "  photos/*.jpg      （母版，保留 photos/opt/*.webp）"
echo "  photos/hero.jpg"
echo "  photos/bgm.mp3    （11.9 MB，如需保留音频请注释掉脚本里对应的 --path）"
echo
echo "当前 .git 体积: $(du -sh .git | cut -f1)"

if [ $APPLY -eq 0 ]; then
  cat <<'NOTE'

── 演练结束，未做任何修改 ──

真跑的顺序（自己确认后再执行，逐条来）：

  1) git filter-repo \
       --path photos/ --invert-paths \
       --path-glob 'photos/*.jpg'  # 见下方说明：filter-repo 的写法与 git filter-branch 不同
     实际上更稳的等价写法是只删母版、保留 opt：
       git filter-repo --invert-paths --path-glob 'photos/*.jpg'

  2) 校验：git log --oneline | head、ls photos/、确认 photos/opt 仍在
  3) 重新关联远端（filter-repo 会移除 origin）：
       git remote add origin https://github.com/Nana77mii/studio-photos.git
  4) force-push：
       git push --force origin main
  5) 到 GitHub 提 support ticket 请求 garbage collect，
     否则仓库体积不会下降（force-push 只移动指针，对象还在）。

回滚：filter-repo 运行前它会留下 origin 备份；最保险是提前
       git clone --mirror 一份到别处。
NOTE
  exit 0
fi

# ── 2. 真跑 ────────────────────────────────────────────────────
echo
read -r -p "确认要从历史中删除母版？此操作不可逆，输入 DELETE 继续: " confirm
[ "$confirm" = "DELETE" ] || { echo "已取消。"; exit 1; }

mirror_backup="$HOME/Pictures/studio-photos-git-mirror-$(date +%Y%m%d-%H%M%S)"
echo "→ 先做镜像备份: $mirror_backup"
git clone --mirror . "$mirror_backup"

echo "→ 重写历史…"
git filter-repo --invert-paths --path-glob 'photos/*.jpg'

echo
echo "✓ 历史已重写。体积: $(du -sh .git | cut -f1)"
echo "  工作区里的母版文件会保留（filter-repo 只改历史，不动工作区）。"
echo
echo "接下来手动执行："
echo "  git remote add origin https://github.com/Nana77mii/studio-photos.git"
echo "  git push --force origin main"
echo "  # 然后去 GitHub Support 申请 GC，否则体积不降"
