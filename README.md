# nixos-config

[![Repository checks](https://github.com/okshn-yk/nixos-config/actions/workflows/check.yml/badge.svg)](https://github.com/okshn-yk/nixos-config/actions/workflows/check.yml)

日本語GNOMEデスクトップと開発環境を管理する、個人用のNixOS設定です。
**Nix Flakes · Home Manager · sops-nix**

## 基本操作

リポジトリのルートで実行します。

| 目的 | コマンド |
| --- | --- |
| 編集用の環境に入る | `nix develop` |
| 整形する | `nix fmt` |
| 設定を検証する | `nix flake check --no-write-lock-file` |
| 依存を更新する | `nix flake update` |
| 設定を反映する | `sudo nixos-rebuild switch --flake .` |

更新後は差分を確認し、検証を通してから反映します。新しいcloneでは、`bash scripts/install-git-hooks.sh` でコミット前の秘密情報検査を有効にしてください。

## 構成

| 場所 | 役割 |
| --- | --- |
| [flake.nix](flake.nix) / [flake.lock](flake.lock) | 依存の定義と固定 |
| [configuration.nix](configuration.nix) / [configs/](configs/) | OS・ハードウェア・サービス |
| [home.nix](home.nix) / [hm/](hm/) | アプリ・シェル・ユーザー設定 |
| [pkgs/](pkgs/) | 自前パッケージ |
| [scripts/](scripts/) / [tests/](tests/) | 運用スクリプト・検証 |

## 詳しい手順

- [Git管理・バックアップ・復旧](docs/recovery.md)
- [別の端末への移行例](docs/migrate-t14-gen6-intel.md)
- [設定の編集ガイド](CLAUDE.md)

端末固有の設定を含みます。別の端末で使う場合は、ハードウェア設定とSOPSの復号鍵を準備してください。秘密情報は暗号化して管理し、秘密鍵や個人データはGitの外でバックアップします。
