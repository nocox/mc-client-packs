#!/usr/bin/env bash
# mod間の「対バージョン」整合性を Modrinth API で検査する
#
# 背景: packwiz の add / update はリリースチャンネル（release/beta/alpha）を
# 区別せず「そのMCバージョンに合う最新版」を入れる。一方 Iris のように
# 特定バージョンの Sodium を必須依存として固定する mod があり、片方だけ
# 新しい alpha に進むと Mixin 適用に失敗してワールド参加時にクラッシュする
# （例: 2026-08 の Sodium 0.9.2-alpha.3 × Iris 1.11.2+mc26.2）。
#
# このスクリプトは、パック内の各 mod が Modrinth 上で宣言している
# 「バージョン固定の必須依存」を実際のインストール内容と照合する。
#
# usage: scripts/check-compat.sh <pack-dir> [--fix]
#   --fix: 不整合を検出したら、要求されているバージョンで入れ直して refresh する
# exit code: 0 = 問題なし/修復済み（API未到達等でスキップした場合も0）
#            1 = 不整合あり（--fix なし）、または修復失敗
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACK_DIR="${1:?usage: scripts/check-compat.sh <pack-dir> [--fix]}"
FIX=0
[ "${2:-}" = "--fix" ] && FIX=1

API="https://api.modrinth.com/v2"

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
  echo "ERROR: pack.toml がありません" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "WARN: jq が無いため互換性チェックをスキップします（apt/brew install jq で導入推奨）" >&2
  exit 0
fi

api_get() {
  curl -sSf --max-time 30 "$1" </dev/null
}

# インストール済み一覧: 「project_id version_id metafile名」を1行ずつ
INSTALLED="$(mktemp)"
trap 'rm -f "$INSTALLED"' EXIT
for f in mods/*.pw.toml; do
  [ -f "$f" ] || continue
  pid="$(sed -n 's/^mod-id = "\(.*\)"$/\1/p' "$f")"
  vid="$(sed -n 's/^version = "\(.*\)"$/\1/p' "$f")"
  [ -n "$pid" ] && [ -n "$vid" ] || continue
  printf '%s %s %s\n' "$pid" "$vid" "$(basename "$f" .pw.toml)" >>"$INSTALLED"
done

mismatch=0
fixed=0
while read -r pid vid name; do
  json="$(api_get "$API/version/$vid")" || {
    echo "WARN: Modrinth API に到達できないため互換性チェックをスキップします" >&2
    exit 0
  }
  vnum="$(jq -r .version_number <<<"$json")"
  vtype="$(jq -r .version_type <<<"$json")"
  case "$vtype" in
    alpha | beta) echo "NOTE: $name は $vtype 版です ($vnum)" ;;
  esac

  # この mod がバージョン固定で要求する必須依存を、実際のインストールと照合
  while read -r dep_pid dep_vid; do
    [ -n "$dep_pid" ] || continue
    line="$(grep "^$dep_pid " "$INSTALLED" || true)"
    [ -n "$line" ] || continue # パックに入っていない依存の解決は packwiz に任せる
    inst_vid="$(cut -d' ' -f2 <<<"$line")"
    dep_name="$(cut -d' ' -f3 <<<"$line")"
    [ "$inst_vid" = "$dep_vid" ] && continue

    want="$(api_get "$API/version/$dep_vid" | jq -r .version_number || echo "$dep_vid")"
    echo ""
    echo "MISMATCH: $name ($vnum) は $dep_name のバージョン $want を要求していますが、"
    echo "          パックには別のバージョンが入っています"
    mismatch=1
    if [ "$FIX" = 1 ]; then
      echo "FIX: $dep_name を要求バージョン ($want) で入れ直します"
      if packwiz remove "$dep_name" </dev/null &&
        packwiz modrinth add "$dep_pid" --version-id "$dep_vid" -y </dev/null; then
        fixed=1
      else
        echo "ERROR: $dep_name の入れ直しに失敗しました" >&2
        exit 1
      fi
    fi
  done < <(jq -r '.dependencies[]? | select(.dependency_type == "required" and .version_id != null) | "\(.project_id) \(.version_id)"' <<<"$json")
done <"$INSTALLED"

if [ "$fixed" = 1 ]; then
  packwiz refresh </dev/null
  echo ""
  echo "check-compat: 不整合を修復しました。差分を確認してコミットしてください"
  exit 0
fi
if [ "$mismatch" = 1 ]; then
  echo ""
  echo "check-compat: バージョン不整合があります。--fix 付きで再実行すると修復できます:"
  echo "  ./scripts/check-compat.sh <pack-dir> --fix"
  exit 1
fi
echo "check-compat: OK（mod間の対バージョンに不整合なし）"
