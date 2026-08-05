#!/usr/bin/env bash
# 初回セットアップ: packwiz を導入して、指定サーバ用のパックを生成する
# usage: scripts/bootstrap.sh okaka 26.2
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER="${1:?usage: scripts/bootstrap.sh <server-name> <mc-version>  (e.g. okaka 26.2)}"
VER="${2:?usage: scripts/bootstrap.sh <server-name> <mc-version>  (e.g. okaka 26.2)}"

if ! command -v packwiz >/dev/null 2>&1; then
  echo "packwiz が見つからないためインストールします..."
  if command -v go >/dev/null 2>&1; then
    go install github.com/packwiz/packwiz@latest
    export PATH="$PATH:$(go env GOPATH)/bin"
  elif command -v brew >/dev/null 2>&1; then
    brew install packwiz
  else
    echo "ERROR: Go または Homebrew が必要です。" >&2
    echo "  導入方法: https://packwiz.infra.link/installation/" >&2
    exit 1
  fi
fi

packwiz --help >/dev/null
echo "packwiz OK: $(command -v packwiz)"

exec "$ROOT/scripts/new-server.sh" "$SERVER" "$VER"
