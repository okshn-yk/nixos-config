# ble.sh ピン留めの経緯と今後の対応

## TL;DR

- **症状**: `nix flake update` 後に `nixos-rebuild switch` すると、ble.sh が新しい nightly に上がり、**Ghostty で文字入力が一切できなくなる**。
- **原因**: ble.sh 開発版 nightly（`0.4.0-devel4+6cffa91`, 2026-06-21）の回帰。あなたの設定ミスでも Ghostty のバグでもない。
- **対処**: `flake.nix` で `blesh` を既知の正常版（`0.4.0-devel3-unstable-2026-03-10`, upstream `b99cadb`）にピン留めしていた。
- **現状（2026-07-25）**: 解除条件を満たしたため**ピンを解除した**（下記「解除の記録」参照）。

## 解除の記録（2026-07-25）

| | バージョン | upstream rev |
| --- | --- | --- |
| 解除前（ピン先） | `0.4.0-devel3-unstable-2026-03-10` | `b99cadb` |
| 解除後（nixpkgs `e2587ca`） | `0.4.0-devel3-unstable-2026-07-11` | `d69e4d5` |

- 破損版 `6cffa910`（2026-06-21）とは**別コミット**で、3 週間分新しい。
- 破損版と同時期の upstream issue [#662](https://github.com/akinomyoga/ble.sh/issues/662)（2026-06-21 close）/ #707（2026-06-22 close）の修正後の版。
- `flake.nix` から `nixpkgs-blesh` input と blesh overlay を削除し、`nixos-rebuild build` は成功。
- **再発した場合**: 下の「再ピン留めの手順」に従って戻す。

---

## 何が起きたか

| | バージョン | upstream | 入力 |
| --- | --- | --- | --- |
| 正常版 | `0.4.0-devel3-unstable-2026-03-10` | `b99cadb` | ✅ |
| 破損版 | `0.4.0-devel4+6cffa91`（2026-06-21）| `6cffa910` | ❌ 入力不能 |

bash 本体（5.3p9）・home-manager・ユーザー設定は無関係。`nix flake update` で nixpkgs が進み、それに追従して blesh が上がったことが引き金。

## 原因（調査結果）

- 破損版の正確なコミット `6cffa910` は、ble.sh ChangeLog の **`#D2413` "term: use the kitty keyboard protocol in Ghostty and Zellij"** と同一。
  つまり破損版は「**Ghostty/Zellij で kitty キーボードプロトコルを有効化する変更が入った、まさにその瞬間の nightly**」だった。
- ソース上も `ble.sh` 内に `(ghostty:*|zellij:*) method=kitty_keyboard_protocol`（旧版には無い分岐）を確認。
  Ghostty は DA2 応答 `1;10;0` で `ghostty` と判定され、新版ではキー解読がこのプロトコルに切り替わる。
- **これが Ghostty での入力不能の最有力の引き金**。ただし PTY による局所再現では Ghostty 判定を外した条件でも新版は壊れたため、「この1コミットだけが原因」と断定はしていない（nightly 全体が入力周りに複数の粗を抱えている可能性）。

### 関連 upstream Issue（破損版の日付前後に活発に修正中）

- [#662](https://github.com/akinomyoga/ble.sh/issues/662) Ghostty で Alt キーが `unbound keyseq`（2026-06-21 close）
- [#684](https://github.com/akinomyoga/ble.sh/issues/684) Ghostty 1.3.1 でプロンプト二重（別件）
- #707 Zellij への kitty プロトコル対応（2026-06-22 close）
- 我々と完全一致する「Ghostty で一切入力不能」の個別 Issue は未発見。

## 検証手順（解除後・再発時ともこれで判定する）

`sudo nixos-rebuild switch --flake .` の後:

1. **Ghostty で新しいターミナルを開き、文字入力できることを確認**（ble.sh は新規シェルでアタッチされるため、既存セッションでは検証にならない）。
2. 日本語入力・Alt/Ctrl 系キー・右矢印での履歴サジェスト確定も確認する。

## 再ピン留めの手順（入力不能が再発したら）

1. `flake.nix` の `inputs` に追加（rev は破損版より前の既知の正常版）:

   ```nix
   nixpkgs-blesh.url = "github:nixos/nixpkgs/567a49d1913ce81ac6e9582e3553dd90a955875f";
   ```

2. `outputs` の引数に `nixpkgs-blesh` を追加。
3. `nixpkgs.overlays` に追加:

   ```nix
   (final: prev: {
     blesh = nixpkgs-blesh.legacyPackages.${system}.blesh;
   })
   ```

4. `nix flake lock` → `sudo nixos-rebuild switch --flake .` → 上の検証手順。

`home-manager.useGlobalPkgs = true` のため、`hm/shell.nix` の `pkgs.blesh` もこの overlay 経由で正常版を参照する。

なお 2026-07-25 の解除は git 履歴に残っているので、`git revert` でも戻せる。

## 今後の確認

`nix flake update` 後に blesh が上がったら、上の検証手順で入力を確認する。バージョン確認:

```bash
nix eval --raw "github:nixos/nixpkgs/nixos-unstable#blesh.version"
```

### 暫定回避策（ピンを使わず最新を使いたい場合の保険）

どうしても最新 blesh を使いつつ回避したい場合は、`hm/shell.nix` の ble.sh 読み込み箇所で kitty キーボードプロトコルを抑制する方向の `bleopt` を試す余地はある（要検証）。ただし**ピン留めが最も確実**なので、無理に最新を追わない。

## 参考

- [akinomyoga/ble.sh](https://github.com/akinomyoga/ble.sh)（ChangeLog `#D2413` = commit `6cffa910`）
- 調査日: 2026-06-30
