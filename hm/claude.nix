{ pkgs, inputs, lib, ... }:

let
  # ステータスライン用スクリプト
  claudeStatuslineScript = pkgs.writeShellScript "claude-statusline" ''
    input=$(cat)

    # モデル名を取得
    MODEL=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.model.display_name')

    # コンテキストウィンドウ情報を取得
    CONTEXT_SIZE=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.context_window.context_window_size')
    USAGE=$(echo "$input" | ${pkgs.jq}/bin/jq '.context_window.current_usage')

    if [ "$USAGE" != "null" ] && [ "$CONTEXT_SIZE" != "null" ] && [ "$CONTEXT_SIZE" != "0" ]; then
        # 現在のトークン数を計算
        INPUT_TOKENS=$(echo "$USAGE" | ${pkgs.jq}/bin/jq -r '.input_tokens // 0')
        CACHE_CREATE=$(echo "$USAGE" | ${pkgs.jq}/bin/jq -r '.cache_creation_input_tokens // 0')
        CACHE_READ=$(echo "$USAGE" | ${pkgs.jq}/bin/jq -r '.cache_read_input_tokens // 0')

        CURRENT_TOKENS=$((INPUT_TOKENS + CACHE_CREATE + CACHE_READ))
        PERCENT_USED=$((CURRENT_TOKENS * 100 / CONTEXT_SIZE))

        # 使用率に応じて色を変更（80%以上:赤, 50%以上:黄, それ以下:緑）
        if [ "$PERCENT_USED" -ge 80 ]; then
            COLOR="\033[31m"  # 赤
        elif [ "$PERCENT_USED" -ge 50 ]; then
            COLOR="\033[33m"  # 黄
        else
            COLOR="\033[32m"  # 緑
        fi
        RESET="\033[0m"

        echo -e "[$MODEL] Context: ''${COLOR}''${PERCENT_USED}%''${RESET} (''${CURRENT_TOKENS}/''${CONTEXT_SIZE})"
    else
        echo "[$MODEL] Context: 0%"
    fi
  '';
in
{
  # ===========================================================================
  # Claude Code Agent & Nix Ecosystem
  # ===========================================================================

  home.packages = with pkgs; [
    # 1. Claude Code
    # claude-code
    inputs.claude-code-nix.packages.${pkgs.system}.default

    # 2. Nix Knowledge Tools
    nixd              # LSP: 構文チェック、定義ジャンプ、ドキュメント参照用
    nix-search-cli    # Search: 'search.nixos.org' のCLI版。パッケージやオプションの調査用
    nix-tree          # Analysis: 依存関係のツリー表示。「なぜこのパッケージが入った？」の調査用
    nixfmt-rfc-style  # Formatter: コードを編集した後の整形用

  ];

  # ===========================================================================
  # Claude Code Status Line Script
  # Nix storeからシンボリックリンクを作成
  # ===========================================================================
  home.file.".claude/statusline.sh" = {
    source = claudeStatuslineScript;
    executable = true;
  };

  # ===========================================================================
  # Activation Hook: settings.jsonにstatusLine設定を追加/更新
  # 既存の設定（enabledPlugins等）を保持しつつstatusLineのみ更新
  # ===========================================================================
  home.activation.claudeStatusLine = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    SETTINGS_FILE="$HOME/.claude/settings.json"

    # .claudeディレクトリが存在しない場合は作成
    mkdir -p "$HOME/.claude"

    # settings.jsonが存在しない場合は空のJSONオブジェクトを作成
    if [ ! -f "$SETTINGS_FILE" ]; then
      echo '{}' > "$SETTINGS_FILE"
    fi

    # statusLine設定を追加/更新（既存の設定は保持）
    ${pkgs.jq}/bin/jq '.statusLine = {
      "type": "command",
      "command": "~/.claude/statusline.sh",
      "padding": 0
    }' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  '';

  # ===========================================================================
  # Environment Variables
  # 必要に応じてClaudeの動作環境変数を設定します
  # ===========================================================================
  home.sessionVariables = {
    # Nix環境でClaudeを使う際、利用状況やテレメトリを制御したい場合はここに記述
    # CLAUDE_CODE_USAGE_REPORTING = "false";
  };
}
