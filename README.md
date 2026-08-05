# mc-client-packs

Minecraft のクライアントmod（軽量化・影mod・便利mod）を **packwiz** で宣言的に管理するリポジトリ。

- mod構成は `catalog/mods.txt` に slug を書くだけ（Infrastructure as Code のノリ）
- パックは **遊ぶサーバ（グループ）ごと**に独立して共存（`packs/okaka/` など）。
  MCバージョンはパックの属性で、サーバのバージョンが上がったらそのパックを in-place で移行する
  → インスタンスと配信URLはサーバごとに固定のまま
- クライアント側は **packwiz-installer** が起動時に自動同期 → 手作業でのmod入れ替えが不要
- 更新は AI起点（Claude Code / GitHub Actions / Cowork定期タスク）で PR が来る → マージするだけ

```
┌─────────────────────┐   週次 update / 対応調査   ┌──────────────┐
│ GitHub Actions /    │ ───────────────────────▶ │  このリポジトリ  │
│ Claude Code / Cowork│           PR             │ catalog+packs │
└─────────────────────┘                          └──────┬───────┘
                                                        │ raw URL
                                        起動時に自動同期  ▼
                                          ┌───────────────────────────┐
                                          │ Prism Launcher             │
                                          │  ├ instance okaka (26.2)   │← packwiz-installer
                                          │  └ instance <server2> (…)  │← packwiz-installer
                                          └───────────────────────────┘
```

## 初回セットアップ

前提: Java / Go（または Homebrew）/ [Prism Launcher](https://prismlauncher.org/)

### 1. リポジトリを GitHub に作る

```bash
git init && git add -A && git commit -m "feat: 初期構成"
gh repo create mc-client-packs --public --source=. --push
```

> raw URL で配信するため **public 推奨**。private にする場合は後述の「private運用」を参照。

### 2. パックを生成する

```bash
./scripts/bootstrap.sh okaka 26.2   # packwiz導入 + packs/okaka/ を生成 + catalog同期
git add -A && git commit -m "feat: okaka パック追加" && git push
```

途中で `SKIPPED` と出たmodは、そのMCバージョン未対応なだけ。カタログに残しておけば
対応版リリース後の sync / 週次Actions で自動的に入ります。

### 3. Prism Launcher 側の設定（サーバごとに1回だけ）

1. 新規インスタンス作成: MC / Fabric（バージョンは `packs/<server>/pack.toml` と合わせる）
2. [packwiz-installer-bootstrap.jar](https://github.com/packwiz/packwiz-installer-bootstrap/releases) をダウンロードし、インスタンスの `.minecraft`（または `minecraft`）フォルダに置く
3. インスタンス編集 → Settings → Custom commands → **Pre-launch command** に:

```
"$INST_JAVA" -jar packwiz-installer-bootstrap.jar https://raw.githubusercontent.com/<user>/mc-client-packs/main/packs/okaka/pack.toml
```

以後、**ゲームを起動するたびにリポジトリの構成が自動反映**されます。
URL はサーバ名で固定なので、サーバのMCバージョンが上がってもインスタンスを作り直す必要はありません。
別のサーバ（グループ）で遊び始めるときだけ、インスタンスをもう1つ作って URL の `packs/<server>/` を変えます。

## 日常運用

| やりたいこと | 操作 |
| --- | --- |
| 普通に遊ぶ | Prismで起動するだけ（起動時に自動同期） |
| modを足す | `catalog/mods.txt` に slug 追記 → `./scripts/sync.sh packs/<server>` → commit & push |
| mod一括更新 | 週次Actionsが作るPRをマージ（手動なら `./scripts/update-all.sh`） |
| サーバのMCバージョンが上がった | `./scripts/bump-version.sh packs/<server> <new-ver>` → commit & push（タグも）→ Prismの該当インスタンスで MC / Fabric Loader のバージョンを変更 |
| 新しいサーバで遊び始める | `./scripts/new-server.sh <server> <ver>` → commit & push → Prismに新インスタンス追加 |
| 動作確認（push前） | パックのディレクトリで `packwiz serve` → pre-launch URL を一時的に `http://localhost:8080/pack.toml` に |

### バージョンアップの仕組み

`bump-version.sh` は移行前の構成に git タグ `<server>/<old-ver>` を打ってから、
`packwiz migrate` でMC/ローダーのバージョンを更新し、全modを新バージョン向けに再解決します。
新バージョン未対応の mod は DROPPED としていったん外れます（catalog には残るので、
mod側が対応した後の sync / 週次Actions で自動復帰）。

古いバージョンに戻りたくなったら、タグの raw URL を指すインスタンスを作れば復活できます:

```
https://raw.githubusercontent.com/<user>/mc-client-packs/refs/tags/<server>%2F<old-ver>/packs/<server>/pack.toml
```

## AI起点の運用

### Claude Code（対話的な変更）

リポジトリ直下に `CLAUDE.md` があるので、Claude Code がレシピを理解した状態で作業できます。プロンプト例:

- 「okaka のサーバが 26.3 に上がったので追従して。未対応modは Modrinth API で調べて一覧にして」
- 「ミニマップ系の便利modを比較して、良さそうなのを catalog に追加して全パックに反映して」
- 「このスクリーンショットのクラッシュログを見て原因のmodを特定して外して」

### GitHub Actions（週次の自動更新PR）

`.github/workflows/update-mods.yml` が毎週土曜 6:00 JST に:

1. `packwiz update --all` で既存modを更新
2. `sync.sh` でカタログ未反映mod（新たに対応されたもの）を取り込み
3. `check-compat.sh` で mod間の対バージョン（Iris↔Sodium 等）を検査・自動修復
4. 差分があればPRを作成（不整合が残っている場合はPRを作らず失敗する）

→ あなたはPRの差分を見てマージするだけ。次回起動時に反映されます。

### Cowork 定期タスク（判断込みのチェック）

Actionsが「機械的な更新」担当なのに対し、Coworkには「判断が要る調査」を任せます。
Coworkで以下のような定期タスクを作成してください（雛形）:

```
GitHubリポジトリ https://github.com/<user>/mc-client-packs は packwiz で
Minecraftクライアントmodを管理している（packs/<server>/ が遊ぶサーバごとのパック）。
以下を実行して:
1. https://launchermeta.mojang.com/mc/game/version_manifest.json で新しい安定版が出ていないか確認
2. 出ていたら、catalog/mods.txt 記載の各modについて Modrinth API
   (https://api.modrinth.com/v2/project/<slug>/version?game_versions=["<ver>"]&loaders=["fabric"])
   で新バージョン対応状況を調査
3. 主要mod（sodium, iris, lithium）が対応済みなら「サーバが <ver> に上がったときは
   scripts/bump-version.sh packs/<server> <ver> で追従可能」、未対応なら「様子見」を、
   未対応mod一覧・代替候補付きでレポートして
```

## 現在の構成

| サーバ | MCバージョン | 備考 |
| --- | --- | --- |
| okaka | 26.2 | |

### okaka の対応状況（2026-08-04 時点、MC 26.2）

| カテゴリ | mod | 26.2 |
| --- | --- | --- |
| 軽量化 | Sodium / Lithium / EntityCulling / Dynamic FPS | ✓ |
| 軽量化 | FerriteCore / ImmediatelyFast / ModernFix | 未対応（カタログ登録済み、対応後に自動追加） |
| 影mod | Iris / Complementary Reimagined | ✓ |
| 便利mod | （今後 `catalog/mods.txt` に追加） | - |

## private運用にしたい場合

raw URL に認証が必要になるため、いずれかを選択:

- pack.toml 配信だけ別の public リポジトリ / GitHub Pages に分ける
- 自宅サーバー等で `packwiz serve` 相当の静的配信をする
- URL にファイングレインドPATを含める（漏洩リスクがあるため非推奨）

## トラブルシュート

- **サーバ/ワールドに入った瞬間 Mixin エラーでクラッシュする**（例: `Mixin transformation of ...sodium... failed` / `MixinRenderRegionManager ... failed injection check`）: Iris↔Sodium の対バージョン不整合。`./scripts/check-compat.sh packs/<server> --fix` で要求バージョンに揃えて commit & push
- **起動時に hash mismatch 等で失敗する**: 対象パックで `packwiz refresh` → commit & push して再起動
- **modがSKIPPEDのまま入らない**: そのMCバージョン未対応。`https://modrinth.com/mod/<slug>/versions` で対応状況を確認
- **OptiFine系シェーダーを使いたい**: このパックは Iris + Sodium 構成。シェーダーパックは Iris対応のものを `catalog/mods.txt` に追加する（Modrinthにあるものなら packwiz で管理可能）
