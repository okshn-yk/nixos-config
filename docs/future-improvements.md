# 将来の改善プラン

このファイルは検討中の改善案をまとめています。

---

## 開発ツール (`hm/dev-tools.nix`)

### direnv + nix-direnv
**課題**: プロジェクトごとに`nix develop`を手動実行する必要がある
**解決**: ディレクトリ移動時に自動で開発環境をロード。`.envrc`に`use flake`と書くだけ
```nix
programs.direnv = {
  enable = true;
  enableBashIntegration = true;
  nix-direnv.enable = true;  # キャッシュでロード高速化
};
```

### delta
**課題**: `git diff`の出力が見づらい。行内の変更箇所が分かりにくい
**解決**: シンタックスハイライト付きの美しいdiff表示。行内変更も強調
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

## Flake改善

### devShells
**課題**: このリポジトリで作業する際の開発環境が未定義
**解決**: `nix develop`で必要なツール（nixfmt, nixd等）が即座に使える
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
- `home.nix` - imports追加
- `flake.nix` - devShells追加
- `hm/git.nix` - delta統合
