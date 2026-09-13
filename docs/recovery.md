# Git管理と端末の復旧

GitHubにはNix設定・flake.lock・SOPS暗号文を保存する。秘密鍵、認証情報、ブラウザプロファイルなどはGitに入れず、別ディスクの暗号化バックアップで保管する。

## 日常の変更手順

```bash
nix develop
bash scripts/install-git-hooks.sh  # 新しいcloneごとに一度だけ
# 設定を編集する
nix flake check --no-write-lock-file
git add <変更したファイル>
git diff --cached --stat
git commit -m '変更理由'
git push origin master
sudo nixos-rebuild switch --flake .
```

pre-commitはステージ済みの変更をGitleaksで検査し、ステージ済みsecrets.yamlに平文がないことも確認する。GitHub Actionsは履歴スキャン・設定評価・整形・回帰テストを実行する。フックは各cloneの設定であり、自動的には伝播しない。

update-claude / update-codexは、ステージ済み・未ステージ・未追跡の変更が一つでもあると停止する。Gitが無視する一時ファイルは対象外。更新中は別の端末からこのリポジトリを編集しない。

.gitignoreは既に追跡されたファイルや過去のコミットを消さない。実際の資格情報が混入した場合は、削除コミットだけで済ませず、まず失効・再発行する。

## 1. ホームと個人age鍵の暗号化バックアップ

外付けディスクをマウントし、その中のディレクトリを指定する。同じホーム内や同じファイルシステムへの保存はスクリプトが拒否する。

```bash
nix develop --command bash scripts/backup-home.sh /run/media/okshin/BACKUP/restic
```

resticが端末でパスワードを要求する。**バックアップのパスワードは、バックアップの中だけに保存しない。** 別途パスワードマネージャーやオフラインの復旧記録に保管する。バックアップは暗号化され、2回目以降は重複排除される。世代の自動削除は行わない。

ホーム内の個人age鍵 `~/.config/sops/age/keys.txt`、コード、ブラウザ、アプリ設定を含める。キャッシュ・ゴミ箱は除外し、別マウントのデータはたどらない。Podmanのroot所有ファイルなど、一般ユーザーが読めないデータは個別に退避する。終了コードが0でなければ完全なバックアップとして扱わない。重要アプリを閉じて取得すると整合性を保ちやすい。

`/etc/ssh` のホスト秘密鍵はホームのバックアップに含まれない。本構成のSOPSは個人age鍵でも復号できるため、移行時はその鍵を使って新しいホスト鍵へ再暗号化する。個人鍵だけで復号できることを以下で確認する（平文を表示しない）。

```bash
SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" sops decrypt secrets.yaml >/dev/null
chmod 600 ~/.config/sops/age/keys.txt
```

外付けディスクは平時に取り外す。初回と定期的な復旧試験では `restic restore latest --target /別の空ディレクトリ` で復元し、ファイルが開けること・個人鍵で復号できることを確認する。`restic check --read-data` で全データの整合性も確認できる。通常スクリプト内の `restic check` は主にリポジトリ構造の検査であり、全内容の復元試験の代わりにはならない。

## 2. 配布終了に備えた独自パッケージの保管

Gitだけでは配布元が削除したdebを取得できない。更新後のクリーンなコミットで次を実行する。

```bash
nix develop --command bash scripts/export-recovery-cache.sh /run/media/okshin/BACKUP/nix-cache
```

保存するもの:

- Git履歴のbundleとコミットID
- Flake本体と固定した全入力のソース
- ChatGPTのdebと、ビルド済みChatGPTの実行時依存一式

キャッシュは暗号化されないため、自分の管理するディスクに置く。NixソースにはSOPS暗号文が入るが、復号鍵やホームのデータは入れない。全NixOSパッケージのオフライン復旧までは保証しない。完全なオフライン復旧が必要な場合は、容量を確保して `nix copy --to file:///保存先/store /run/current-system` で稼働世代の依存も保存する。

復旧時はbundleからcloneするかGitHubから取得し、保存したコミットへ切り替える。信頼できる自分のバックアップからのみ、保存したpathsファイルの各ストアパスを次で取り込む。

```bash
nix copy --from file:///run/media/okshin/BACKUP/nix-cache/store --no-check-sigs /nix/store/保存済みのパス
```

`--no-check-sigs` は自分のローカルキャッシュが署名されていないため必要。第三者のキャッシュに対して使わない。秘密鍵をホームへ復元してから、機種変更手順 `docs/migrate-t14-gen6-intel.md` に従いハードウェア設定とSOPS受信者を更新する。

## 保存状況

スクリプトやCIがあるだけではバックアップ済みにはならない。初回取得後、保存先・最終成功日・復元確認日をGitに含めない個人の記録へ残す。外部保存先が未定の段階では、実バックアップは未実施として扱う。
