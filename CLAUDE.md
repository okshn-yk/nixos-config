# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 概要

NixOS Flake ベースの個人ワークステーション設定（ユーザー: okshin）。Home Manager でユーザー設定を管理し、日本語環境の GNOME デスクトップを構築。

## よく使うコマンド

```bash
# 設定を反映（リビルド＆切り替え）
sudo nixos-rebuild switch --flake .

# 全Flake入力を更新
nix flake update

# 特定入力のみ更新（例: claude-code-nix）
nix flake update claude-code-nix

# Nixファイルのフォーマット（nixfmt = nixfmt-rfc-style）
nixfmt *.nix **/*.nix
# または flake の formatter 経由
nix fmt

# パッケージ/オプション検索
nix-search <クエリ>

# このリポジトリ編集用の開発環境（nixfmt, nixd, nix-search-cli）
nix develop
```

## アーキテクチャ

### Flake 構成

- `flake.nix` - エントリポイント。入力定義（nixpkgs unstable, home-manager, xremap, sops-nix, claude-code-nix, rust-overlay）
- `configuration.nix` - システムレベル設定。`configs/`からモジュールをインポート
- `home.nix` - Home Manager エントリポイント。`hm/`からユーザー設定をインポート

### システム設定 (`configs/`)

| ファイル         | 内容                                                                       |
| ---------------- | -------------------------------------------------------------------------- |
| `desktop.nix`    | GNOME、Pipewire オーディオ、フォント（Inter, HackGen, Noto CJK）と描画設定（ヒンティング無効＋グレースケール AA の macOS 風）、Web フォント名の alias、Fcitx5+Mozc IME |
| `dev-env.nix`    | Podman、nix-ld（VSCode Server 互換）、基本開発ツール                       |
| `keymap.nix`     | xremap キーリマップ（カスタム「Onishi Layout」）                           |
| `hardware-amd.nix` | AMD 固有のカーネルパラメータ（`amd_pstate`, `mem_sleep_default`）。Intel 機へ移行する際は import を外す |
| `laptop.nix`     | ラップトップ固有のハードウェア設定                                         |
| `wifi.nix`       | ネットワーク設定                                                           |
| `aws-config.nix` | AWS SSO 設定                                                               |
| `ollama.nix`     | ローカルLLM（Ollama, Vulkan で iGPU オフロード）。Zed インライン補完バックエンド |
| `mouse.nix`      | マウス設定（Solaar パッケージ・udev ルール・uinput）。logiops から Solaar へ一本化済み |
| `performance.nix`| zram, earlyoom, swappiness 等のパフォーマンス調整                          |
| `security.nix`   | Firewall、Avahi 無効化等のセキュリティ設定                                  |

### Home Manager 設定 (`hm/`)

| ファイル        | 内容                                                                                                |
| --------------- | --------------------------------------------------------------------------------------------------- |
| `apps.nix`      | パッケージ（言語、ビルドツール、GUI アプリ、セキュリティスキャナ）、GPaste のキーバインドと常駐設定、dconf、Fcitx5 |
| `terminal.nix`  | Ghostty、Zellij、tmux 設定                                                                          |
| `browser.nix`   | Firefox / Floorp 設定（プロファイル、ポリシー。既定は Floorp）                                      |
| `shell.nix`     | Bash 設定、エイリアス、Starship、zoxide、eza、fzf、bat、ble.sh                                      |
| `git.nix`       | Git 設定、gh/ghq/lazygit、gh による認証ヘルパー                                                     |
| `vscode.nix`    | VS Code 設定                                                                                        |
| `claude.nix`    | Claude Code（claude-code-nix フレーク経由）、Nix ツール群（nixd, nix-search-cli, nix-tree, nixfmt） |
| `autostart.nix` | 自動起動アプリ（auto-move-windows でワークスペース割当）                                            |
| `rust.nix`      | Rust 開発環境（rust-bin stable, cargo-edit/watch/audit/expand, bacon）                              |
| `go.nix`        | Go 開発環境                                                                                          |
| `mouse.nix`     | Solaar のルール（rules.yaml）とデーモン、`solaar-apply-settings`（ボタン diversion 適用） |
| `zed.nix`       | Zed エディタ設定                                                                                     |

### 自前パッケージ (`pkgs/`)

nixpkgs に無い（または Linux 向けが無い）ものを `callPackage` 形式で置く。利用箇所から `pkgs.callPackage ../pkgs/<name>.nix { }` で呼ぶ。新規ファイルは `git add` しないと flake から見えない。

| ファイル                     | 内容                                                                                   |
| ---------------------------- | -------------------------------------------------------------------------------------- |
| `chatgpt.nix`                | ChatGPT デスクトップ（公式 Linux 版 .deb を autoPatchelf で再パッケージ）。引込み元: `hm/apps.nix` |
| `chatgpt-prepare-plugins.sh` | 上記のラッパーが起動前に source する処理。同梱プラグインの書き込み可能なコピーを `~/.cache/chatgpt-nix/<ストアパス名>/` に作る |

ChatGPT デスクトップの注意点:

- **更新は手動**。アプリ内アップデータは効かない。OpenAI の apt リポジトリの一覧から版とハッシュを取り、`pkgs/chatgpt.nix` の `version` / `hash` を差し替える（`pool/` 配下の旧版が消えると再ビルド不能になるので、放置せず追従する）。
- **プラグインのコピーを外さないこと**。アプリは同梱プラグインを `fs.cp` で `~/.codex/.tmp` に複製してから書き換えるが、Nix ストアから複製すると読み取り専用のまま書き込みが EACCES で失敗し、browser use を含む同梱プラグインが導入されない。`CODEX_ELECTRON_BUNDLED_PLUGINS_RESOURCES_PATH` で書き込み可能なコピーに向けて回避している。
- **`app.asar` の `process.report.getReport()` 置換を外さないこと**。この Electron は `getReport()` で SIGILL を起こす。detect-libc は ELF インタプリタ → `/usr/bin/ldd` → `getReport()` の順に libc を判定するが、patchelf で PT_INTERP がファイル末尾へ移り、NixOS には `/usr/bin/ldd` も無いため `getReport()` まで到達し、プロジェクトを開いて git ワーカーが `@parcel/watcher` を読んだ瞬間にアプリごと落ちる（「応答なし」→終了。coredump の落ちたスレッド名は `git`）。同じバイト長の空オブジェクト式に置換している。件数が 1 件でなくなるとビルドが止まるので、その時は置換を見直す。
- `~/.codex` は Codex CLI と共有。起動のたびに `~/.codex/config.toml` の `mcp_servers.node_repl` / `cua_repl` へ**そのときのストアパスを書き込む**。版を上げて旧版を GC した後、アプリを一度も起動しないまま Codex CLI を使うと、この MCP サーバーの起動に失敗する（アプリを起動すれば書き直される）。
- 動作確認のログは `chatgpt --enable-logging=stderr` で見られる。`browser_use_availability_resolved available=true` と `plugin_install_succeeded pluginName=browser` が出ていれば browser use は使える状態。

```bash
# 最新版と SHA256（16進）を確認
curl -s https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages | awk '/^Version:/{v=$2} /^SHA256:/{print v, $2}'
# pkgs/chatgpt.nix の hash 用に SRI 形式へ変換
nix hash convert --hash-algo sha256 --to sri <SHA256>
```

### シークレット管理

sops-nix と age 暗号化を使用。`secrets.yaml`に保存し、SSH ホスト鍵（`/etc/ssh/ssh_host_ed25519_key`）で復号。

### Insecure パッケージの扱い

`configuration.nix` の `nixpkgs.config.permittedInsecurePackages` に許可リストを置く。
各エントリには CVE 番号 / 引き込み元 / 許可した理由 / 削除条件 をインラインコメントで明記する。
`nix flake update` 後はこのリストの要否を見直す。

許可リストは `configuration.nix` の 1 箇所のみ。以前は checkov ピン留め用の
別 nixpkgs を独立評価していたため `hm/apps.nix` にも同じ内容を書く必要があったが、
2026-08-26 のピン解除で重複は解消した。**別 nixpkgs を `import` するピンを再び
入れる場合は、その `let` 束縛にも同じ許可リストを書くこと**（独立評価には
`configuration.nix` の `nixpkgs.config` が届かない）。

### パッケージのピン留め

回帰を含むパッケージは正常版にピン留めする。各ピンには引き込み元 / 理由 / 解除条件をコメントで明記し、`nix flake update` 後に解除可否を見直す。

ピン留めの置き場所は消費者の広さで決める。複数モジュールから参照するものは `flake.nix` の overlay、単一ファイルからしか使わないものは利用箇所の `let` 束縛に置き、システム全体の overlay を増やさない。

**現在アクティブなピンは無し。override は VS Code の terraform 拡張と、Solaar の依存を足す overlay（下記）のみ。**

- **hashicorp.terraform (VS Code 拡張)**: nixpkgs が 2.40.0 に記録した src ハッシュが実際の配信物と食い違いビルド不能。`hm/vscode.nix` で実測値へ上書きする。`ext.version == "2.40.0"` の条件式でガードしてあるので、**バージョンが上がれば自動的に素の派生へ戻る**。
- **blesh**: ~~ピン留め中~~ → **2026-07-25 に解除済み**。`0.4.0-devel4+6cffa91`（2026-06-21 nightly）の回帰で Ghostty で文字入力不能になっていたが、nixpkgs が別コミット（`d69e4d5`, 2026-07-11）へ前進したため解除。**再発時の再ピン留め手順は `docs/blesh-pin.md` 参照**。blesh が上がった際は Ghostty で新規ターミナルを開いて入力確認すること。
- **checkov**: ~~ピン留め + `dontCheckRuntimeDeps` override~~ → **2026-08-26 に両方とも解除済み**。nixpkgs `e2587ca`（2026-07-23）以降で依存の `pycep-parser` / `policy-sentry` が `pythonMetadataCheckPhase` に失敗しビルド不能だったため専用 input `nixpkgs-checkov` で固定していたが、checkov 3.3.9 が素の nixpkgs でビルドできることを確認して input・`checkovPinned` 束縛・override をすべて撤去した。再発したときの再ピン留め用に確認コマンドを下に残す。
- **Solaar**: ~~1.1.20 への版上げ overlay~~ → **2026-08-26 に版の上書きのみ解除済み**。nixpkgs が 1.1.20 に追いついたため `version` / `src` を削除した。`flake.nix` の overlay 自体は残るが、役割は **`pycairo` と `libnotify` の追加**だけ（どちらも nixpkgs 側の派生に入っていない）。この 2 つが上流に入ったら overlay ごと削除できる。

ピン解除可否の確認（`nix flake update` 後に実行）:

```bash
# checkov: ビルドが通れば素の nixpkgs で使える（再ピン留めした場合の解除判定用）
REV=$(nix eval --raw --impure --expr '(builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs.locked.rev')
nix build --no-link --impure --expr "let p = import (builtins.getFlake \"github:nixos/nixpkgs/$REV\") { system = \"x86_64-linux\"; config.permittedInsecurePackages = [ \"python3.14-ecdsa-0.19.2\" ]; }; in p.checkov"

# Solaar: overlay ごと削除できるか（両方 true になったら削除可能）
nix eval --impure --expr 'let p = (builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.x86_64-linux; s = p.solaar; in {
  pycairo  = builtins.any (x: (x.pname or "") == "pycairo")  s.propagatedBuildInputs;
  libnotify = builtins.any (x: (x.pname or "") == "libnotify") s.buildInputs;
}'
```

## 利用可能な Nix ツール

- `nixd` - Nix LSP（IDE 補完・定義ジャンプ）
- `nix-search-cli` - パッケージ/オプション検索 CLI（search.nixos.org 相当）
- `nix-tree` - 依存関係ツリー表示
- `nixfmt-rfc-style` - Nix コードフォーマッター

## シェル機能

### ble.sh（Bash Line Editor）

- 入力中に灰色で履歴ベースのオートサジェスト表示
- 構文ハイライト（存在するコマンド: 緑、存在しない: 赤）
- 右矢印キーで候補を確定

### エイリアス・キーバインド

- `update-claude` / `update-codex` - 各 flake 入力を更新してリビルド（実体は共通関数 `_update_flake_input`）。失敗時の巻き戻しが他の入力の更新を壊さないよう、`flake.lock` に未コミット変更があると実行を拒否する
- `adev` / `aadm` - AWS SSO ログインショートカット
- `ls`, `ll`, `la`, `tree` - eza 版（アイコン/git 連携付き）
- `Ctrl+g` - ghq+fzf でリポジトリ選択・移動
