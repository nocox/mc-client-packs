#!/usr/bin/env bash
# 全サーバのパックの mod を最新版へ一括更新する
# usage: scripts/update-all.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v packwiz >/dev/null 2>&1; then
  echo "ERROR: packwiz がありません。先に scripts/bootstrap.sh を実行してください" >&2
  exit 1
fi

found=0
for dir in "$ROOT"/packs/*/; do
  [ -f "$dir/pack.toml" ] || continue
  found=1
  echo ""
  echo "===== update: ${dir#"$ROOT"/} ====="
  (cd "$dir" && packwiz update --all -y && packwiz refresh)
  # update は最新版（alpha含む）へ進めるため、mod間の対バージョンを検査して
  # ズレていれば要求されているバージョンへ戻す（Iris↔Sodium 等）
  "$ROOT/scripts/check-compat.sh" "$dir" --fix
done

if [ "$found" -eq 0 ]; then
  echo "packs/ 配下にパックがありません。scripts/new-server.sh <server> <ver> で作成してください"
  exit 1
fi

echo ""
echo "===== 差分 ====="
git -C "$ROOT" --no-pager diff --stat || true
