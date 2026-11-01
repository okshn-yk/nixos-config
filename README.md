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

### 日本語音声入力（Voxtype）

`Super+Shift+V` で録音開始、もう一度押すと録音終了・文字起こし。
完了通知後、入力欄で `Ctrl+V`（端末では `Ctrl+Shift+V`）を押して貼り付けます。
認識結果がクリップボードの内容を置き換えます。録音は最長60秒です。

Whisper Small の多言語モデルを使い、Vulkan（AMD内蔵GPU）で日本語を端末内処理します。
初回はモデルのダウンロードが必要です。設定は `hm/apps.nix` で管理し、
マイクは GNOME のサウンド設定で既定の入力デバイスを選びます。

準備状況は `systemctl --user status voxtype-model-loader voxtype`、
認識のログは `journalctl --user -u voxtype -n 50` で確認できます。

### 運用と復旧

- [Git管理・バックアップ・復旧](docs/recovery.md)
- [別の端末への移行例](docs/migrate-t14-gen6-intel.md)
- [設定の編集ガイド](CLAUDE.md)

端末固有の設定を含みます。別の端末で使う場合は、ハードウェア設定とSOPSの復号鍵を準備してください。秘密情報は暗号化して管理し、秘密鍵や個人データはGitの外でバックアップします。
