{ pkgs, ... }:

{
  # ===========================================================================
  # Rust Development Environment
  # Compiler, LSP, Formatter, and System Dependencies
  # ===========================================================================

  home.packages = with pkgs; [
    # --- 1. The Toolchain (Latest Stable) ---
    # rustc, cargo, clippy, rustfmt, rust-src が全部入りになったパッケージ
    # rust-overlay のおかげでこれが使えます
    (rust-bin.stable.latest.default.override {
      extensions = [ "rust-src" "rust-analyzer" ];
    })

    # --- 2. Cargo Utilities ---
    cargo-edit    # 'cargo add <crate>' が使えるようになる
    cargo-watch   # 'cargo watch -x run' でファイル変更検知＆自動実行
    cargo-audit   # 依存クレートの脆弱性チェック
    cargo-expand  # マクロがどう展開されるか確認する (学習に最適)
    cargo-nextest # 高速テストランナー 'cargo nextest run'
    bacon         # バックグラウンドでコンパイルチェック (rust-analyzerより軽い)

    # --- 3. Build Dependencies  ---
    pkg-config   # C言語ライブラリを探すツール
    openssl      # Web系クレート(reqwest, axum等)で必須
  ];

  # ===========================================================================
  # Environment Variables
  # VSCodeなどがRustの標準ライブラリのソースコードを見つけられるようにする
  # ===========================================================================
  home.sessionVariables = {
    RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
  };
}
