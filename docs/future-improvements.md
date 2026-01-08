# 将来の改善プラン

このファイルは検討中の改善案をまとめています。

---

## 開発ツール

### delta

**課題**: `git diff`の出力が見づらい。行内の変更箇所が分かりにくい
**解決**: シンタックスハイライト付きの美しい diff 表示。行内変更も強調

```nix
programs.git.delta = {
  enable = true;
  options = {
    navigate = true;
    side-by-side = true;
  };
};
```

### その他開発ツール

```nix
home.packages = with pkgs; [
  tokei       # コード統計（言語別行数カウント）
  hyperfine   # コマンドベンチマーク（複数コマンドの速度比較）
  just        # Makefileの現代版（シンプルなタスクランナー）
];
```

---

## Flake 改善

### devShells

**課題**: このリポジトリで作業する際の開発環境が未定義
**解決**: `nix develop`で必要なツール（nixfmt, nixd 等）が即座に使える

```nix
devShells.x86_64-linux.default = pkgs.mkShell {
  packages = with pkgs; [ nixfmt-rfc-style nixd ];
};
```

---

## 実装時のファイル構成

**新規作成予定**

- `hm/dev-tools.nix` - 開発効率化ツール

**更新予定**

- `home.nix` - imports 追加
- `flake.nix` - devShells 追加
- `hm/git.nix` - delta 統合
