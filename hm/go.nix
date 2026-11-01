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

    # pkg-config は hm/rust.nix 側で入れている（cgo と共用）
  ];

  # GOPATH は Go の既定値（$HOME/go）のままなので設定しない。
}
