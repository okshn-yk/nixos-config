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
```

## アーキテクチャ

### Flake 構成

- `flake.nix` - エントリポイント。入力定義（nixpkgs unstable, home-manager, xremap, sops-nix, claude-code-nix, rust-overlay）
- `configuration.nix` - システムレベル設定。`configs/`からモジュールをインポート
- `home.nix` - Home Manager エントリポイント。`hm/`からユーザー設定をインポート

### システム設定 (`configs/`)

| ファイル         | 内容                                                                       |
| ---------------- | -------------------------------------------------------------------------- |
| `desktop.nix`    | GNOME、Pipewire オーディオ、フォント（HackGen, Noto CJK）、Fcitx5+Mozc IME |
| `dev-env.nix`    | Podman、nix-ld（VSCode Server 互換）、基本開発ツール                       |
| `keymap.nix`     | xremap キーリマップ（カスタム「Onishi Layout」）                           |
| `laptop.nix`     | ラップトップ固有のハードウェア設定                                         |
| `wifi.nix`       | ネットワーク設定                                                           |
| `aws-config.nix` | AWS SSO 設定                                                               |
| `ollama.nix`     | ローカルLLM（Ollama, Vulkan で iGPU オフロード）。Zed インライン補完バックエンド |
| `mouse.nix`      | マウス／ポインタ設定                                                        |
| `performance.nix`| zram, earlyoom, swappiness 等のパフォーマンス調整                          |
| `security.nix`   | Firewall、Avahi 無効化等のセキュリティ設定                                  |

### Home Manager 設定 (`hm/`)

| ファイル        | 内容                                                                                                |
| --------------- | --------------------------------------------------------------------------------------------------- |
| `apps.nix`      | パッケージ（言語、ビルドツール、GUI アプリ）、GPaste、dconf、Fcitx5                                 |
| `terminal.nix`  | Ghostty、Zellij、tmux 設定                                                                          |
| `browser.nix`   | Firefox / Floorp 設定（プロファイル、ポリシー。既定は Floorp）                                      |
| `shell.nix`     | Bash 設定、エイリアス、Starship、zoxide、eza、fzf、bat、ble.sh                                      |
| `git.nix`       | Git 設定、gh/ghq/lazygit、gh による認証ヘルパー                                                     |
| `vscode.nix`    | VS Code 設定                                                                                        |
| `claude.nix`    | Claude Code（claude-code-nix フレーク経由）、Nix ツール群（nixd, nix-search-cli, nix-tree, nixfmt） |
| `autostart.nix` | 自動起動アプリ（auto-move-windows でワークスペース割当）                                            |
| `rust.nix`      | Rust 開発環境（rust-bin stable, cargo-edit/watch/audit/expand, bacon）                              |
| `go.nix`        | Go 開発環境                                                                                          |
| `zed.nix`       | Zed エディタ設定                                                                                     |

### シークレット管理

sops-nix と age 暗号化を使用。`secrets.yaml`に保存し、SSH ホスト鍵（`/etc/ssh/ssh_host_ed25519_key`）で復号。

### Insecure パッケージの扱い

`configuration.nix` の `nixpkgs.config.permittedInsecurePackages` に許可リストを置く。
各エントリには CVE 番号 / 引き込み元 / 許可した理由 / 削除条件 をインラインコメントで明記する。
`nix flake update` 後はこのリストの要否を見直す。

**⚠️ 許可リストは 2 箇所にある**: ピン留め用の別 nixpkgs を `import` する overlay
（`flake.nix` の checkov overlay）は独立評価のため `configuration.nix` の
`nixpkgs.config` が届かず、同じ内容を overlay 内にも書いている。
エントリの追加・削除・**バージョン文字列の追随**（既定 Python の版上がり等）は
必ず両方に反映する。片方だけ直すとビルド不能または不要な insecure 許可の残存になる。
ピン留めを解除すれば重複も解消する。

### パッケージのピン留め

回帰を含むパッケージは `flake.nix` で正常版にピン留めする。各ピンには引き込み元 / 理由 / 解除条件をコメントで明記し、`nix flake update` 後に解除可否を見直す。

- **blesh**: ~~ピン留め中~~ → **2026-07-25 に解除済み**。`0.4.0-devel4+6cffa91`（2026-06-21 nightly）の回帰で Ghostty で文字入力不能になっていたが、nixpkgs が別コミット（`d69e4d5`, 2026-07-11）へ前進したため解除。**再発時の再ピン留め手順は `docs/blesh-pin.md` 参照**。blesh が上がった際は Ghostty で新規ターミナルを開いて入力確認すること。
- **checkov**: nixpkgs `e2587ca`（2026-07-23）以降で依存の `pycep-parser` / `policy-sentry` が `pythonMetadataCheckPhase` の版数一致チェックに失敗しビルド不能（派生の version と wheel の METADATA の version が食い違う nixpkgs 側の回帰）。専用 input `nixpkgs-checkov` 経由で `241313f`（2026-07-19）に固定。解除確認は下記コマンド参照。
  - checkov には**ピン留めとは別に** `hm/apps.nix` で `dontCheckRuntimeDeps` の override も乗っている（`aiohttp<3.14.0` 上限 vs nixpkgs の 3.14.1）。**2 段構えなので、ピンを外しても override は別途要否を判断する**。

ピン解除可否の確認（`nix flake update` 後に実行）:

```bash
# checkov: ビルドが通れば解除可能（<rev> は flake.lock の nixpkgs の rev）
nix build --no-link --impure --expr 'let p = import (builtins.getFlake "github:nixos/nixpkgs/<rev>") { system = "x86_64-linux"; config.permittedInsecurePackages = [ "python3.14-ecdsa-0.19.2" ]; }; in p.checkov'
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

- `update-claude` - claude-code-nix を更新してリビルド
- `adev` / `aadm` - AWS SSO ログインショートカット
- `ls`, `ll`, `la`, `tree` - eza 版（アイコン/git 連携付き）
- `Ctrl+g` - ghq+fzf でリポジトリ選択・移動
