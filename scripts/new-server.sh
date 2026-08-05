#!/usr/bin/env bash
# 新しいサーバ（遊ぶグループ）用のパックを作成し、catalog を同期する
# 既存サーバのパックはそのまま残るので、サーバごとに別バージョンが共存できる
# usage: scripts/new-server.sh okaka 26.2
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER="${1:?usage: scripts/new-server.sh <server-name> <mc-version>  (e.g. okaka 26.2)}"
VER="${2:?usage: scripts/new-server.sh <server-name> <mc-version>  (e.g. okaka 26.2)}"
DIR="$ROOT/packs/$SERVER"

if ! command -v packwiz >/dev/null 2>&1; then
  echo "ERROR: packwiz がありません。先に scripts/bootstrap.sh を実行してください" >&2
  exit 1
fi

mkdir -p "$DIR"
cd "$DIR"

if [ ! -f pack.toml ]; then
  packwiz init -y \
    --name "client-pack-$SERVER" \
    --author "nocox" \
    --version "1.0.0" \
    --mc-version "$VER" \
    --modloader fabric \
    --fabric-latest
fi

"$ROOT/scripts/sync.sh" "packs/$SERVER"

echo ""
echo "===== 完了: packs/$SERVER (MC $VER) ====="
echo "push後、Prism Launcher の pre-launch に設定する配信URLの例:"
echo "  https://raw.githubusercontent.com/<user>/<repo>/main/packs/$SERVER/pack.toml"
echo "サーバのMCバージョンが上がったら: scripts/bump-version.sh packs/$SERVER <new-ver>"
