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

# Nixファイルのフォーマット
nixfmt *.nix **/*.nix

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

### Home Manager 設定 (`hm/`)

| ファイル        | 内容                                                                                                |
| --------------- | --------------------------------------------------------------------------------------------------- |
| `apps.nix`      | パッケージ（言語、ビルドツール、GUI アプリ）、CopyQ、dconf、Fcitx5                                  |
| `terminal.nix`  | Ghostty、Zellij 設定                                                                                |
| `browser.nix`   | Firefox 設定（プロファイル、ポリシー）                                                              |
| `shell.nix`     | Bash 設定、エイリアス、Starship、zoxide、eza、fzf、bat、ble.sh                                      |
| `git.nix`       | Git 設定、gh/ghq/lazygit、gh による認証ヘルパー                                                     |
| `vscode.nix`    | VS Code 設定                                                                                        |
| `claude.nix`    | Claude Code（claude-code-nix フレーク経由）、Nix ツール群（nixd, nix-search-cli, nix-tree, nixfmt） |
| `autostart.nix` | 自動起動アプリ                                                                                      |
| `rust.nix`      | Rust 開発環境（rust-bin stable, cargo-edit/watch/audit/expand, bacon）                              |

### シークレット管理

sops-nix と age 暗号化を使用。`secrets.yaml`に保存し、SSH ホスト鍵（`/etc/ssh/ssh_host_ed25519_key`）で復号。

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
