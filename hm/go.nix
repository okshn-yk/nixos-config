{ pkgs, ... }:

{
  # ===========================================================================
  # Go Development Environment
  # Compiler, LSP, Linter, and Tools
  # ===========================================================================

  home.packages = with pkgs; [
    # --- 1. Go Compiler ---
    go # 最新stable

    # --- 2. Development Tools ---
    gopls # Go Language Server (IDE補完・定義ジャンプ)
    golangci-lint # Linter集約ツール
    go-tools # goimports, gorename等の公式ツール群
    delve # デバッガ

    # --- 3. Build Dependencies ---
    pkg-config # C言語ライブラリを探すツール
  ];

  # ===========================================================================
  # Environment Variables
  # ===========================================================================
  home.sessionVariables = {
    GOPATH = "$HOME/go";
  };
}
