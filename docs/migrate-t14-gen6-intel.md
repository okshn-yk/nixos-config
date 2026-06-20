# NixOS 構成を ThinkPad P14s Gen 2a (AMD) → T14 Gen 6 (Intel) へ移行

## 背景・結論

現在の構成は Lenovo ThinkPad P14s Gen 2a（AMD Ryzen + AMD iGPU, MTM `21A1S0FY00`）専用に書かれた箇所がある。これを ThinkPad T14 Gen 6（Intel CPU + Intel iGPU）へ移行する。

**結論: 移行は可能。** NixOS 構成のうちハードウェア依存部分はごく一部に局在しており、CPU ベンダー固有設定（microcode / KVM / pstate）と自動生成される `hardware-configuration.nix`、および sops の鍵周りを更新すれば移行できる。Home Manager 配下（`hm/`）やアプリ・シェル・Git 等の設定は完全にハードウェア非依存なので無変更で動く。

- **移行方法**: 新規インストール（T14 に NixOS をクリーンインストールし、本リポジトリを clone して再構築）。
- **方針**: コミュニティの **nixos-hardware** プロファイルを導入してハードウェア最適化を自動適用する。

> ⚠️ 重要な前提: 本作業の大半（インストール・`nixos-generate-config`・`sudo nixos-rebuild`・sops 再暗号化）は **新しい T14 実機上で実行する**作業であり、現在の P14s 上では実行できない。本書はその実機作業のランブック。現在のリポジトリ側で事前に編集できるのは「ベンダー固有設定の書き換え」と「nixos-hardware の追加」のみ。

---

## 変更が必要な箇所（ハードウェア依存の全インベントリ）

| 項目 | ファイル:行 | 現状(AMD) | 変更後(Intel) |
| --- | --- | --- | --- |
| KVM モジュール | `hardware-configuration.nix:13` | `kvm-amd` | `kvm-intel` |
| microcode | `hardware-configuration.nix:32` | `hardware.cpu.amd.updateMicrocode` | `hardware.cpu.intel.updateMicrocode` |
| initrd モジュール | `hardware-configuration.nix:11` | `xhci_pci_renesas` 等 AMD機固有 | `nixos-generate-config` で再生成 |
| ルートFS UUID | `hardware-configuration.nix:17` | `3792e68d-…` | 新ディスクのUUID（再生成） |
| boot FS UUID | `hardware-configuration.nix:22` | `0BEB-2AE0` | 新ディスクのUUID（再生成） |
| swap UUID | `hardware-configuration.nix:28` | `c40808f8-…` | 新ディスクのUUID（再生成） |
| resume device UUID | `configs/laptop.nix:10` | `c40808f8-…` | 上記 swap UUID に合わせる |
| CPU pstate | `configuration.nix:31` | `amd_pstate=active` | 削除（Intel は `intel_pstate` が既定で自動有効） |
| GPU スリープ対策コメント | `configuration.nix:28` | "AMD GPU…" | コメント更新／`mem_sleep_default=s2idle` は要否を再評価 |

**ハードウェア非依存で無変更**: `hm/` 全体、`configs/desktop.nix` `dev-env.nix` `keymap.nix` `wifi.nix` `aws-config.nix` `security.nix` `performance.nix`、`configs/laptop.nix` の TLP / logind / upower / fprintd（Intel でもそのまま有効）。

---

## 実装手順

### フェーズ A: 事前にリポジトリ側で編集（現在のマシンで可能）

別ブランチ（例 `migrate/t14-intel`）で以下を編集・コミットしておくと、新マシンで clone → rebuild するだけになる。

1. **`configuration.nix` のカーネルパラメータを Intel 化**（`configuration.nix:28-32`）
   - `"amd_pstate=active"` を削除。
   - コメント `# AMD GPU スリープ復帰問題対策` を見直し。`mem_sleep_default=s2idle` は AMD 機の S3 復帰対策だったため、Intel では一旦外して様子見でよい（不安定なら戻す）。

2. **nixos-hardware を flake input に追加**（`flake.nix`）
   ```nix
   # inputs に追加
   nixos-hardware.url = "github:NixOS/nixos-hardware/master";
   ```
   `outputs` の引数と `modules` に追加:
   ```nix
   outputs = { self, nixpkgs, home-manager, xremap-flake, sops-nix, rust-overlay, nixos-hardware, ... }@inputs:
   ...
   modules = [
     ./configuration.nix
     nixos-hardware.nixosModules.lenovo-thinkpad-t14  # ← T14 Gen6 専用が無ければこの汎用 t14 を使う
     ...
   ];
   ```
   - 補足: nixos-hardware に T14 Gen6 専用パスが存在するか実機作業前に確認（`github:NixOS/nixos-hardware` の `flake.nix` の `nixosModules` 一覧）。専用が無い場合は汎用 `lenovo-thinkpad-t14`、それも合わなければ `common/cpu/intel` + `common/gpu/intel` + `common/pc/laptop` + `common/pc/laptop/ssd` の個別 import で代替。

3. **microcode / KVM は `hardware-configuration.nix` 側で実機再生成時に上書きされる**ため、フェーズ A では触らず、フェーズ C で対応（nixos-hardware が `common/cpu/intel` 経由で intel microcode を有効化するので明示設定が不要になる場合もある）。

### フェーズ B: T14 に NixOS をクリーンインストール

4. NixOS インストーラ（unstable 系 ISO 推奨。Gen6 の新しい Intel iGPU 対応のため新しいカーネル/mesa が要る）で起動。
5. ディスクをパーティション分割・フォーマット（現行と同構成: ext4 ルート + vfat ESP + swap パーティション。`suspend-then-hibernate` を使うため **swap は RAM 以上のサイズ**を確保 — 現行コメントでは RAM27GB に対し swap30GB）。
6. `sudo nixos-generate-config --root /mnt` で新しい `hardware-configuration.nix` を生成。

### フェーズ C: リポジトリを反映して再構築

7. 生成された `/mnt/etc/nixos/hardware-configuration.nix` の内容で、リポジトリの `hardware-configuration.nix` を**置き換える**（新しい UUID・initrd モジュール・`kvm-intel`・`hardware.cpu.intel.updateMicrocode` が自動で入る）。
8. **`configs/laptop.nix:10` の `boot.resumeDevice`** を、新しい swap パーティションの UUID（手順7で生成された `swapDevices` の UUID）に書き換える。
9. リポジトリを `/etc/nixos` などに clone（または ghq 配下に置きパスを通す）。

### フェーズ D: sops シークレットの再鍵（新規インストール必須作業）

> 本構成は secrets を **host_key（SSHホスト鍵由来）と user_key（個人 age 鍵）の両方**に暗号化している（`.sops.yaml`）。新規インストールでは SSH ホスト鍵が変わるため host_key 部分が無効になる。**user_key の秘密鍵さえ手元にあれば**復号・再暗号化できる。

10. **前提**: 個人 age 秘密鍵（`.sops.yaml` の `user_key = age1phuhhymxyd…` に対応する秘密鍵）を新マシンの `~/.config/sops/age/keys.txt` に配置しておく。これが無いと secrets を一切復号できないため、移行前に必ず退避・持参すること。
11. 新マシンの SSH ホスト鍵から age 公開鍵を導出:
    ```bash
    cat /etc/ssh/ssh_host_ed25519_key.pub | nix shell nixpkgs#ssh-to-age -c ssh-to-age
    ```
12. `.sops.yaml` の `&host_key age1greva…` を手順11で得た新しい age 公開鍵に置換。
13. user_key で復号できる状態で鍵を更新:
    ```bash
    nix shell nixpkgs#sops -c sops updatekeys secrets.yaml
    ```
    これで secrets.yaml が新 host_key + user_key で再暗号化される。

### フェーズ E: ビルドと検証

14. `sudo nixos-rebuild switch --flake .#nixos`（`nixosConfigurations` 名は `nixos`、`flake.nix:37`）。
15. 下記「検証」を実施。

---

## 検証（実機での確認項目）

```bash
# CPU/microcode が Intel として認識
journalctl -k | grep -i microcode          # "microcode updated early" 等
lscpu | grep -i "model name"               # Intel Core … を確認
ls /dev/kvm                                 # kvm-intel ロード確認
lsmod | grep kvm_intel

# pstate ドライバ
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver   # intel_pstate 期待

# GPU（Intel iGPU）
nix shell nixpkgs#pciutils -c lspci -k | grep -A3 VGA       # i915 / xe ドライバ
journalctl -b | grep -iE "i915|xe "

# sops シークレットが復号できている
systemctl status sops-nix
ls -l /run/secrets/                          # wifi_ssid, aws/* 等が展開
nmcli connection show                        # home-wifi が生成され接続可

# 電源・サスペンド・指紋
systemctl status tlp fprintd fwupd
systemctl suspend        # 復帰確認（s2idle 外した影響の有無）
fprintd-enroll           # 指紋登録・認証

# Home Manager / アプリ
which claude codex starship eza               # ユーザーパッケージ反映確認
```

問題が出やすい点と対処:
- **Intel iGPU が新しすぎて表示が出ない**: unstable の新カーネル/mesa を使う、`hardware.enableAllFirmware = true` を一時追加。
- **サスペンド復帰不調**: `configuration.nix` に `mem_sleep_default=s2idle` を戻す、または BIOS のスリープ設定（s2idle/S3）を確認。
- **sops が復号失敗**: user_key 秘密鍵の配置漏れ、または手順12の host_key 置換漏れ。`sops -d secrets.yaml` で単体確認。

---

## 変更対象ファイルまとめ（リポジトリ側）

- `flake.nix` — nixos-hardware input + module 追加
- `configuration.nix` — `amd_pstate` 削除、コメント更新
- `hardware-configuration.nix` — 実機で全置換（UUID/KVM/microcode/initrd）
- `configs/laptop.nix` — `boot.resumeDevice` UUID 更新
- `.sops.yaml` — host_key を新マシンの age 公開鍵へ
- `secrets.yaml` — `sops updatekeys` で再暗号化
