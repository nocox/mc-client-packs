# CLAUDE.md

このリポジトリは Minecraft のクライアントmod構成（軽量化・影mod）を packwiz で宣言的に管理する。
Claude Code はこのファイルの規約に従って作業すること。

## 構造

```
catalog/mods.txt        # 欲しいmodのカタログ（Modrinth slug、カテゴリはコメントで区分）
packs/<mc-version>/     # バージョンごとのpackwizパック（pack.toml / index.toml / mods/*.pw.toml）
scripts/                # 運用スクリプト（下記レシピから呼ぶ）
.github/workflows/      # 週次自動更新PR
```

- 複数のMCバージョンのパックが `packs/` 配下に共存する。古いバージョンは消さない（ランチャー側で選び分ける）
- ローダーは Fabric 固定
- jar はコミットしない。packwiz が管理するメタデータ（*.toml, *.pw.toml）のみコミットする
- `pack.toml` / `index.toml` / `mods/*.pw.toml` は packwiz が生成・更新するので手編集しない

## レシピ

### mod を追加したい
1. `catalog/mods.txt` に Modrinth の slug を適切なカテゴリ欄へ追記
2. 対象パックへ反映: `./scripts/sync.sh packs/<ver>`（全バージョンに入れる場合は各パックに実行）
3. SKIPPED が出たら未対応。カタログには残し、コメントで「未対応（YYYY-MM-DD 調査）」と記す

### 新しいMCバージョンに対応したい
1. `./scripts/new-version.sh <ver>` を実行（既存パックは残る）
2. sync 結果の SKIPPED 一覧を README の対応状況表に反映
3. コミットし、Prism 用の配信URL（`packs/<ver>/pack.toml` の raw URL）をユーザーに伝える

### mod を一括更新したい
`./scripts/update-all.sh` → 差分を確認してコミット

### mod の対応状況を調べたい
Modrinth API を使う（認証不要）:
```
https://api.modrinth.com/v2/project/<slug>/version?game_versions=["<ver>"]&loaders=["fabric"]
```
空配列なら未対応。代替modを探す場合は `https://api.modrinth.com/v2/search?query=...&facets=...` を使う。
最新の安定版MCバージョンは `https://launchermeta.mojang.com/mc/game/version_manifest.json` の `latest.release`。

## 検証

コミット前に必ず、変更したパックで以下を確認する:

1. `packwiz refresh` が成功すること
2. `./scripts/check-compat.sh packs/<ver>` が成功すること
   （mod間の対バージョン検査。Iris は特定バージョンの Sodium を要求するため、
   片方だけ新しい alpha に更新されるとワールド参加時にクラッシュする。
   sync.sh / update-all.sh は自動で `--fix` 付き実行するが、packwiz を
   直接叩いて変更した場合は手動で実行すること）

## コミット規約

- `feat: <slug> を追加 (<ver>)` / `chore: mod更新` / `feat: <ver> パック追加` の形式
- カタログ変更とパック変更は同一コミットにまとめてよい
