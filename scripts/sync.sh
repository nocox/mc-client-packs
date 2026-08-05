#!/usr/bin/env bash
# catalog/mods.txt の内容を指定パックへ同期する（冪等・何度でも再実行OK）
# usage: scripts/sync.sh packs/okaka
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACK_DIR="${1:?usage: scripts/sync.sh <pack-dir>  (e.g. packs/okaka)}"
CATALOG="$ROOT/catalog/mods.txt"

# 絶対パス/相対パスどちらでも受ける
if [ -d "$ROOT/$PACK_DIR" ]; then
  cd "$ROOT/$PACK_DIR"
elif [ -d "$PACK_DIR" ]; then
  cd "$PACK_DIR"
else
  echo "ERROR: pack dir not found: $PACK_DIR" >&2
  exit 1
fi

if [ ! -f pack.toml ]; then
  echo "ERROR: pack.toml がありません。先に scripts/new-server.sh <server> <ver> を実行してください" >&2
  exit 1
fi
if ! command -v packwiz >/dev/null 2>&1; then
  echo "ERROR: packwiz が見つかりません。scripts/bootstrap.sh を参照してください" >&2
  exit 1
fi

ok_list=""
skip_list=""

while IFS= read -r line || [ -n "$line" ]; do
  slug="${line%%#*}"                       # 行内コメントを除去
  slug="$(printf '%s' "$slug" | tr -d '[:space:]')"
  [ -z "$slug" ] && continue

  echo ""
  echo "==> $slug"
  if packwiz modrinth add "$slug" -y; then
    ok_list="$ok_list $slug"
  else
    skip_list="$skip_list $slug"
  fi
done < "$CATALOG"

packwiz refresh

# mod間の対バージョン（Iris が要求する Sodium 等）を検査し、ズレていれば入れ直す。
# packwiz add はチャンネルを見ずに最新版（alpha含む）を選ぶため、これが無いと
# 片方だけ新しい alpha が入ってクラッシュする構成がそのまま通ってしまう
"$ROOT/scripts/check-compat.sh" "$PWD" --fix

echo ""
echo "===== sync result: $PACK_DIR ====="
echo "OK     :${ok_list:- (none)}"
echo "SKIPPED:${skip_list:- (none)}"
if [ -n "$skip_list" ]; then
  echo ""
  echo "SKIPPED はこのMCバージョン未対応の可能性が高いです。"
  echo "mod側が対応した後にこのスクリプトを再実行すれば自動で追加されます。"
  # CI(GitHub Actions)からPR本文に使えるようファイルにも書き出す
  printf '%s\n' $skip_list > .sync-skipped.txt
else
  rm -f .sync-skipped.txt
fi
