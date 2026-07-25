{
  pkgs,
  inputs,
  lib,
  username,
  ...
}:

let
  # ステータスライン用スクリプト
  claudeStatuslineScript = pkgs.writeShellScript "claude-statusline" ''
    input=$(cat)

    RESET="\033[0m"

    # 使用率(0-100)に応じたANSI色を返す（80%以上:赤, 50%以上:黄, それ以下:緑）
    pct_color() {
        if [ "$1" -ge 80 ]; then
            printf '\033[31m'   # 赤
        elif [ "$1" -ge 50 ]; then
            printf '\033[33m'   # 黄
        else
            printf '\033[32m'   # 緑
        fi
    }

    # モデル名を取得
    MODEL=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.model.display_name')

    # Gitブランチを取得
    GIT_BRANCH=""
    if ${pkgs.git}/bin/git rev-parse --git-dir > /dev/null 2>&1; then
        BRANCH=$(${pkgs.git}/bin/git branch --show-current 2>/dev/null)
        if [ -n "$BRANCH" ]; then
            GIT_BRANCH=" [$BRANCH]"
        fi
    fi

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
        CTX_COLOR=$(pct_color "$PERCENT_USED")
        CONTEXT_STR="Ctx: ''${CTX_COLOR}''${PERCENT_USED}%''${RESET} (''${CURRENT_TOKENS}/''${CONTEXT_SIZE})"
    else
        CONTEXT_STR="Ctx: 0%"
    fi

    # 利用状況（5h / weekly のレート制限）を取得
    # ※ rate_limits は Claude.ai サブスク(Pro/Max)で最初のAPI応答後にのみ出現する。
    #   未取得の場合はセクションごと非表示にする。
    fmt_reset() {
        # $1: resets_at (Unix epoch秒) → "→HH:MM" のローカル時刻。無効なら空。
        if [ -n "$1" ] && [ "$1" != "null" ] && [ "$1" -gt 0 ] 2>/dev/null; then
            printf '→%s' "$(${pkgs.coreutils}/bin/date -d "@$1" +%H:%M 2>/dev/null)"
        fi
    }

    LIMITS=""
    FIVE_H=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.rate_limits.five_hour.used_percentage // empty')
    if [ -n "$FIVE_H" ]; then
        FIVE_H_INT=$(printf '%.0f' "$FIVE_H")
        FIVE_RESET=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.rate_limits.five_hour.resets_at // empty')
        LIMITS="5h: $(pct_color "$FIVE_H_INT")''${FIVE_H_INT}%''${RESET}$(fmt_reset "$FIVE_RESET")"
    fi

    WEEK=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.rate_limits.seven_day.used_percentage // empty')
    if [ -n "$WEEK" ]; then
        WEEK_INT=$(printf '%.0f' "$WEEK")
        WEEK_RESET=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.rate_limits.seven_day.resets_at // empty')
        WEEK_STR="7d: $(pct_color "$WEEK_INT")''${WEEK_INT}%''${RESET}$(fmt_reset "$WEEK_RESET")"
        LIMITS="''${LIMITS:+$LIMITS }''${WEEK_STR}"
    fi

    LINE="[$MODEL]''${GIT_BRANCH} ''${CONTEXT_STR}"
    [ -n "$LIMITS" ] && LINE="''${LINE} | ''${LIMITS}"
    echo -e "$LINE"
  '';
in
{
  # ===========================================================================
  # Claude Code Agent & Nix Ecosystem
  # ===========================================================================

  home.packages = with pkgs; [
    # 1. Claude Code
    # claude-code
    inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default

    # 1b. Codex (OpenAI Codex CLI)
    # nixpkgs の codex は上流リリースに数日遅れるため、追従型 flake を使う。
    inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default

    # 2. Nix Knowledge Tools
    nixd # LSP: 構文チェック、定義ジャンプ、ドキュメント参照用
    nix-search-cli # Search: 'search.nixos.org' のCLI版。パッケージやオプションの調査用
    nix-tree # Analysis: 依存関係のツリー表示。「なぜこのパッケージが入った？」の調査用
    nixfmt # Formatter: コードを編集した後の整形用

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
  # Playwright MCP: NixOSではChromeが/opt/google/chrome/chromeに無いため
  # --executable-pathでNixOS上のChromeパスを直接指定
  # 設定先: ~/.claude.json（ユーザーレベル = 全リポジトリ共通）
  home.activation.claudeMcpConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CLAUDE_JSON="$HOME/.claude.json"

    # 新規環境では ~/.claude.json が無く、また壊れた JSON だと後段の jq が失敗して
    # activation 全体（set -e）が落ちる。妥当性を検証して駄目なら作り直す
    # （ファイルが無いケースもこの検証で一緒に吸収できる）。
    if ! ${pkgs.jq}/bin/jq -e . "$CLAUDE_JSON" >/dev/null 2>&1; then
      echo '{}' > "$CLAUDE_JSON"
    fi

    ${pkgs.jq}/bin/jq '.mcpServers.playwright = {
      "type": "stdio",
      "command": "${pkgs.playwright-mcp}/bin/playwright-mcp",
      "args": ["--executable-path", "/etc/profiles/per-user/${username}/bin/google-chrome-stable"]
    }' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
  '';

  home.activation.claudeStatusLine = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    SETTINGS_FILE="$HOME/.claude/settings.json"

    # .claudeディレクトリが存在しない場合は作成
    mkdir -p "$HOME/.claude"

    # 壊れた JSON だと後段の jq が失敗し activation 全体（set -e）が落ちるため、
    # 妥当性を検証して駄目なら作り直す（未作成のケースもこれで吸収できる）。
    if ! ${pkgs.jq}/bin/jq -e . "$SETTINGS_FILE" >/dev/null 2>&1; then
      echo '{}' > "$SETTINGS_FILE"
    fi

    # statusLine設定を追加/更新（既存の設定は保持）
    ${pkgs.jq}/bin/jq '.statusLine = {
      "type": "command",
      "command": "~/.claude/statusline.sh",
      "padding": 0
    }' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  '';
}
