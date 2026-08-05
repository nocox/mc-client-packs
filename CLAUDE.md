# CLAUDE.md

このリポジトリは Minecraft のクライアントmod構成（軽量化・影mod）を packwiz で宣言的に管理する。
Claude Code はこのファイルの規約に従って作業すること。

## 構造

```
catalog/mods.txt        # 欲しいmodのカタログ（Modrinth slug、カテゴリはコメントで区分）
packs/<server>/         # 遊ぶサーバごとのpackwizパック（pack.toml / index.toml / mods/*.pw.toml）
scripts/                # 運用スクリプト（下記レシピから呼ぶ）
.github/workflows/      # 週次自動更新PR
```

- パックの軸は **サーバ（遊ぶグループ）**。MCバージョンはパックの属性（`pack.toml` の `[versions]`）であり、
  サーバのバージョンが上がったらそのパックを in-place で移行する（ディレクトリ名・配信URLは不変）
- 複数サーバのパックが `packs/` 配下に共存する。サーバごとにバージョンアップのタイミングは独立
- 過去バージョンの構成は git タグ `<server>/<mc-version>`（bump-version.sh が自動作成）で参照できる
- ローダーは Fabric 固定
- jar はコミットしない。packwiz が管理するメタデータ（*.toml, *.pw.toml）のみコミットする
- `pack.toml` / `index.toml` / `mods/*.pw.toml` は packwiz が生成・更新するので手編集しない

## レシピ

### mod を追加したい
1. `catalog/mods.txt` に Modrinth の slug を適切なカテゴリ欄へ追記
2. 対象パックへ反映: `./scripts/sync.sh packs/<server>`（全サーバに入れる場合は各パックに実行）
3. SKIPPED が出たら未対応。カタログには残し、コメントで「未対応（YYYY-MM-DD 調査）」と記す

### サーバのMCバージョンが上がった
1. `./scripts/bump-version.sh packs/<server> <new-ver>` を実行
   （移行前の構成にタグ `<server>/<old-ver>` が打たれ、mod が新バージョン向けに再解決される。
   未対応で外れた mod は DROPPED として表示される。catalog には残るので対応後に自動復帰する）
2. DROPPED / SKIPPED 一覧を README の対応状況表に反映
3. コミットし、タグも push する（`git push origin <server>/<old-ver>`）
4. ユーザーに「Prism の該当インスタンスで Minecraft / Fabric Loader のバージョン変更が必要」と伝える

### 新しいサーバ（グループ）で遊び始めたい
1. `./scripts/new-server.sh <server> <mc-version>` を実行（既存サーバのパックは残る）
2. sync 結果の SKIPPED 一覧を README の対応状況表に反映
3. コミットし、Prism 用の配信URL（`packs/<server>/pack.toml` の raw URL）をユーザーに伝える

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
2. `./scripts/check-compat.sh packs/<server>` が成功すること
   （mod間の対バージョン検査。Iris は特定バージョンの Sodium を要求するため、
   片方だけ新しい alpha に更新されるとワールド参加時にクラッシュする。
   sync.sh / update-all.sh / bump-version.sh は自動で `--fix` 付き実行するが、
   packwiz を直接叩いて変更した場合は手動で実行すること）

## コミット規約

- `feat: <slug> を追加 (<server>)` / `chore: mod更新` / `feat: <server> パック追加` /
  `feat: <server> を <ver> へ更新` の形式
- カタログ変更とパック変更は同一コミットにまとめてよい
