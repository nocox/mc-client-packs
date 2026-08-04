#!/usr/bin/env bash
# 新しいMinecraftバージョン用のパックを作成し、catalog を同期する
# 既存バージョンのパックはそのまま残るので、複数バージョンが共存できる
# usage: scripts/new-version.sh 26.2
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VER="${1:?usage: scripts/new-version.sh <mc-version>  (e.g. 26.2)}"
DIR="$ROOT/packs/$VER"

if ! command -v packwiz >/dev/null 2>&1; then
  echo "ERROR: packwiz がありません。先に scripts/bootstrap.sh を実行してください" >&2
  exit 1
fi

mkdir -p "$DIR"
cd "$DIR"

if [ ! -f pack.toml ]; then
  packwiz init -y \
    --name "client-pack-$VER" \
    --author "nocox" \
    --version "1.0.0" \
    --mc-version "$VER" \
    --modloader fabric \
    --fabric-latest
fi

"$ROOT/scripts/sync.sh" "packs/$VER"

echo ""
echo "===== 完了: packs/$VER ====="
echo "push後、Prism Launcher の pre-launch に設定する配信URLの例:"
echo "  https://raw.githubusercontent.com/<user>/<repo>/main/packs/$VER/pack.toml"
