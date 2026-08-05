#!/usr/bin/env bash
# サーバのMCバージョンが上がったとき、そのサーバのパックを in-place で移行する
# （ディレクトリはそのままなので Prism の pre-launch URL は変わらない）
#
# 移行前の構成には git タグ <server>/<old-ver> を打つ。古いバージョンに戻りたく
# なったら、そのタグの raw URL を指すインスタンスを作れば復活できる:
#   https://raw.githubusercontent.com/<user>/<repo>/<server>%2F<old-ver>/packs/<server>/pack.toml
#
# usage: scripts/bump-version.sh packs/okaka 26.3
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACK_DIR="${1:?usage: scripts/bump-version.sh <pack-dir> <new-mc-version>  (e.g. packs/okaka 26.3)}"
NEW_VER="${2:?usage: scripts/bump-version.sh <pack-dir> <new-mc-version>  (e.g. packs/okaka 26.3)}"

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

SERVER="$(basename "$PWD")"
OLD_VER="$(sed -n 's/^minecraft = "\(.*\)"$/\1/p' pack.toml | tr -d '\r')"

if [ -z "$OLD_VER" ]; then
  echo "ERROR: pack.toml から現在のMCバージョンを読み取れませんでした" >&2
  exit 1
fi
if [ "$OLD_VER" = "$NEW_VER" ]; then
  echo "すでに MC $NEW_VER です。何もしません"
  exit 0
fi

echo "===== $SERVER: MC $OLD_VER -> $NEW_VER ====="

# 移行前の構成にロールバック用タグを打つ（コミット済みの状態のみ）
TAG="$SERVER/$OLD_VER"
if git -C "$ROOT" rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "tag $TAG は既に存在します（スキップ）"
elif [ -z "$(git -C "$ROOT" status --porcelain -- "packs/$SERVER")" ]; then
  git -C "$ROOT" tag "$TAG"
  echo "tag $TAG を作成しました（push時: git push origin $TAG）"
else
  echo "WARN: packs/$SERVER に未コミットの変更があるため、ロールバック用タグは打ちません" >&2
fi

packwiz migrate minecraft "$NEW_VER"
packwiz migrate loader latest

# 各modを新MCバージョン向けに再解決する。対応版が無いmodはいったん外す
# （catalog には残るので、mod側が対応した後の sync / 週次Actions で自動復帰する）
dropped=""
for f in mods/*.pw.toml; do
  [ -f "$f" ] || continue
  name="$(basename "$f" .pw.toml)"
  echo ""
  echo "==> update: $name"
  if ! packwiz update "$name" -y </dev/null; then
    echo "DROP: $name は MC $NEW_VER 対応版が見つからないため外します"
    packwiz remove "$name" </dev/null || true
    dropped="$dropped $name"
  fi
done

packwiz refresh

# catalog を再同期（新バージョンで対応済みになったmodの取り込み + check-compat --fix）
"$ROOT/scripts/sync.sh" "packs/$SERVER"

echo ""
echo "===== bump 完了: $SERVER MC $OLD_VER -> $NEW_VER ====="
echo "DROPPED:${dropped:- (none)}"
echo ""
echo "残作業:"
echo "  1. 差分を確認してコミット: feat: $SERVER を $NEW_VER へ更新"
echo "  2. push（タグも）: git push && git push origin $TAG"
echo "  3. Prism の $SERVER 用インスタンスで Version -> Minecraft $NEW_VER / Fabric Loader を更新"
