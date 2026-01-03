# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 概要

NixOS Flakeベースの個人ワークステーション設定（ユーザー: okshin）。Home Managerでユーザー設定を管理し、日本語環境のGNOMEデスクトップを構築。

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

### Flake構成

- `flake.nix` - エントリポイント。入力定義（nixpkgs unstable, home-manager, xremap, sops-nix, claude-code-nix, rust-overlay）
- `configuration.nix` - システムレベル設定。`configs/`からモジュールをインポート
- `home.nix` - Home Managerエントリポイント。`hm/`からユーザー設定をインポート

### システム設定 (`configs/`)

| ファイル | 内容 |
|----------|------|
| `desktop.nix` | GNOME、Pipewireオーディオ、フォント（HackGen, Noto CJK）、Fcitx5+Mozc IME |
| `dev-env.nix` | Podman、nix-ld（VSCode Server互換）、基本開発ツール |
| `keymap.nix` | xremapキーリマップ（カスタム「Onishi Layout」） |
| `laptop.nix` | ラップトップ固有のハードウェア設定 |
| `wifi.nix` | ネットワーク設定 |
| `aws-config.nix` | AWS SSO設定 |

### Home Manager設定 (`hm/`)

| ファイル | 内容 |
|----------|------|
| `apps.nix` | GUIアプリ（Ghostty, Firefox, Zellij）、CopyQ、dconf設定 |
| `shell.nix` | Bash設定、エイリアス、Starship、zoxide、eza、fzf、bat |
| `git.nix` | Git設定、gh/ghq/lazygit、ghによる認証ヘルパー |
| `vscode.nix` | VS Code設定 |
| `claude.nix` | Claude Code（claude-code-nixフレーク経由）、Nixツール群（nixd, nix-search-cli, nix-tree, nixfmt） |
| `autostart.nix` | 自動起動アプリ |
| `rust.nix` | Rust開発環境（rust-bin stable, cargo-edit/watch/audit/expand, bacon） |

### シークレット管理

sops-nixとage暗号化を使用。`secrets.yaml`に保存し、SSHホスト鍵（`/etc/ssh/ssh_host_ed25519_key`）で復号。

## 利用可能なNixツール

- `nixd` - Nix LSP（IDE補完・定義ジャンプ）
- `nix-search-cli` - パッケージ/オプション検索CLI（search.nixos.org相当）
- `nix-tree` - 依存関係ツリー表示
- `nixfmt-rfc-style` - Nixコードフォーマッター

## シェルエイリアス・キーバインド

- `update-claude` - claude-code-nixを更新してリビルド
- `adev` / `aadm` - AWS SSOログインショートカット
- `ls`, `ll`, `la`, `tree` - eza版（アイコン/git連携付き）
- `Ctrl+g` - ghq+fzfでリポジトリ選択・移動
