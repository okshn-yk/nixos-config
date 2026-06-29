# ble.sh ピン留めの経緯と今後の対応

## TL;DR

- **症状**: `nix flake update` 後に `nixos-rebuild switch` すると、ble.sh が新しい nightly に上がり、**Ghostty で文字入力が一切できなくなる**。
- **原因**: ble.sh 開発版 nightly（`0.4.0-devel4+6cffa91`, 2026-06-21）の回帰。あなたの設定ミスでも Ghostty のバグでもない。
- **対処**: `flake.nix` で `blesh` を既知の正常版（`0.4.0-devel3-unstable-2026-03-10`, upstream `b99cadb`）にピン留め済み。
- **解除**: nixpkgs の blesh が `2026-06-21` より新しい日付に進んだら、ピンを外して Ghostty で入力を再検証する。

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

## 現在の対処（実装済み）

`flake.nix` に専用 input と overlay を追加し、`blesh` だけを正常版に固定している。

```nix
# inputs
nixpkgs-blesh.url = "github:nixos/nixpkgs/567a49d1913ce81ac6e9582e3553dd90a955875f";

# nixpkgs.overlays
(final: prev: {
  blesh = nixpkgs-blesh.legacyPackages.${system}.blesh;
})
```

`home-manager.useGlobalPkgs = true` のため、`hm/shell.nix` の `pkgs.blesh` もこの overlay 経由で正常版を参照する。

## 今後の対応

### 1. 解除できるか定期的に確認する

`nix flake update` 後などに、nixpkgs の blesh が前進したか確認:

```bash
nix eval --raw "github:nixos/nixpkgs/nixos-unstable#blesh.version"
```

- `2026-06-21` のまま → **ピン継続**（まだ破損版）。
- より新しい日付になった → 次の手順で解除を試す。

### 2. 解除手順（修正版が来たら）

1. `flake.nix` から `nixpkgs-blesh` input と blesh overlay を削除。
2. `nix flake lock` → `sudo nixos-rebuild switch --flake .`。
3. **Ghostty で新しいターミナルを開き、文字入力できることを必ず確認**（ble.sh は新規シェルでアタッチされるため、既存セッションでは検証にならない）。
   - 念のため日本語入力・Alt/Ctrl 系キー・矢印キーでの履歴サジェスト確定も確認する。
4. 問題なければコミット。**入力不能が再発したらピンに戻す**。

### 3. 暫定回避策（ピンを使わず最新を使いたい場合の保険）

どうしても最新 blesh を使いつつ回避したい場合は、`hm/shell.nix` の ble.sh 読み込み箇所で kitty キーボードプロトコルを抑制する方向の `bleopt` を試す余地はある（要検証）。ただし**現状はピン留めが最も確実**なので、無理に最新を追わない。

## 参考

- [akinomyoga/ble.sh](https://github.com/akinomyoga/ble.sh)（ChangeLog `#D2413` = commit `6cffa910`）
- 調査日: 2026-06-30
