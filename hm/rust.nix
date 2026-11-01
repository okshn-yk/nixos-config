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
      extensions = [
        "rust-src"
        "rust-analyzer"
      ];
    })

    # --- 2. Cargo Utilities ---
    cargo-edit # 'cargo add <crate>' が使えるようになる
    cargo-watch # 'cargo watch -x run' でファイル変更検知＆自動実行
    cargo-audit # 依存クレートの脆弱性チェック
    cargo-expand # マクロがどう展開されるか確認する (学習に最適)
    cargo-nextest # 高速テストランナー 'cargo nextest run'
    bacon # バックグラウンドでコンパイルチェック (rust-analyzerより軽い)

    # --- 3. Build Dependencies  ---
    # 注意: ここに入れても C ライブラリのビルド依存にはならない。home.packages には
    # openssl の dev 出力（ヘッダ・.pc）が入らず PKG_CONFIG_PATH も通らないため、
    # openssl-sys 等は失敗する。必要なプロジェクトでは devShell
    # （packages = [ pkg-config openssl ]）を用意すること。
    pkg-config # C言語ライブラリを探すツール（Go の cgo と共用）
    openssl # openssl コマンド（証明書の確認など）
  ];

  # RUST_SRC_PATH は設定しない。以前は nixpkgs の rustLibSrc を指していたが、
  # 上の rust-bin（rust-overlay）とは版が別で（例: 1.99.0 に対し 1.98.1）、
  # rust-analyzer が古い std を読んでいた。rust-src 拡張を入れたツールチェーンなら
  # rust-analyzer は `rustc --print sysroot` から std のソースを自分で見つける。
}
