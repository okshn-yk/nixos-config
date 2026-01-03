{ pkgs, ... }:

{
  # ===========================================================================
  # Claude Code Agent & Nix Ecosystem
  # ===========================================================================

  home.packages = with pkgs; [
    # 1. Claude Code
    claude-code

    # 2. Nix Knowledge Tools
    nixd              # LSP: 構文チェック、定義ジャンプ、ドキュメント参照用
    nix-search-cli    # Search: 'search.nixos.org' のCLI版。パッケージやオプションの調査用
    nix-tree          # Analysis: 依存関係のツリー表示。「なぜこのパッケージが入った？」の調査用
    nixfmt-rfc-style  # Formatter: コードを編集した後の整形用

  ];

  # ===========================================================================
  # Environment Variables
  # 必要に応じてClaudeの動作環境変数を設定します
  # ===========================================================================
  home.sessionVariables = {
    # Nix環境でClaudeを使う際、利用状況やテレメトリを制御したい場合はここに記述
    # CLAUDE_CODE_USAGE_REPORTING = "false"; 
  };
}
