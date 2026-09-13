{
  pkgs,
  inputs,
  lib,
  username,
  ...
}:

let
  claudeCodePkg = inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;

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
        # 小数（例 1787699103.5）で来ることがあり、そのまま [ -gt ] に渡すと
        # 「integer expression expected」で失敗する。2>/dev/null に握り潰されて
        # リセット時刻だけが黙って消えるため、比較前に整数部だけを取り出す。
        local ts=''${1%%.*}
        if [ -n "$ts" ] && [ "$ts" != "null" ] && [ "$ts" -gt 0 ] 2>/dev/null; then
            printf '→%s' "$(${pkgs.coreutils}/bin/date -d "@$ts" +%H:%M 2>/dev/null)"
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
    claudeCodePkg

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
  # claude-cli:// のディープリンクハンドラ
  # ===========================================================================
  # home.nix の xdg.mimeApps が x-scheme-handler/claude-cli をこの .desktop へ
  # 向けているが、実体は Claude Code が ~/.local/share/applications へ自作した
  # 管理外ファイルだった。しかもその Exec は自前インストールの
  # ~/.local/bin/claude（2026-02 時点の 2.1.50 で凍結）を指しており、PATH 上の
  # Nix 管理版 (2.1.246) とは別物が起動していた。
  #
  # ここで xdg.desktopEntries ではなく xdg.dataFile を使うのは書き込み先の違いによる。
  # useUserPackages = true のとき xdg.desktopEntries は home.packages 経由で
  # /etc/profiles/per-user/<user>/share/applications へ入るが、XDG の探索順は
  # $XDG_DATA_HOME(= ~/.local/share) が $XDG_DATA_DIRS より先。つまり自作ファイルが
  # 残っている限りそちらが優先され、宣言しても何も変わらない（実測で確認済み）。
  # xdg.dataFile なら ~/.local/share/applications に直接置くので確実に勝つ。
  #
  # 加えて Claude Code はこのファイルを再生成しうる。同じパスを home-manager が
  # 所有していれば、次の activation で backupFileExtension = "hm-bak"（flake.nix）
  # により退避されたうえで symlink に戻るので、影が復活しても自動で直る。
  xdg.dataFile."applications/claude-code-url-handler.desktop".text = ''
    [Desktop Entry]
    Name=Claude Code URL Handler
    Comment=Handle claude-cli:// deep links for Claude Code
    Exec=${claudeCodePkg}/bin/claude --handle-uri %u
    Type=Application
    NoDisplay=true
    MimeType=x-scheme-handler/claude-cli;
  '';

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

    # 期待する playwright エントリ。定義はここ一箇所。
    DESIRED=$(${pkgs.jq}/bin/jq -n '{
      "type": "stdio",
      "command": "${pkgs.playwright-mcp}/bin/playwright-mcp",
      "args": ["--executable-path", "/etc/profiles/per-user/${username}/bin/google-chrome-stable"]
    }')

    # 新規環境では ~/.claude.json が無く、また壊れた JSON だと後段の jq が失敗して
    # activation 全体（set -e）が落ちる。妥当性を検証して駄目なら作り直す
    # （ファイルが無いケースもこの検証で一緒に吸収できる）。
    if ! ${pkgs.jq}/bin/jq -e . "$CLAUDE_JSON" >/dev/null 2>&1; then
      echo '{}' > "$CLAUDE_JSON"
    fi

    # すでに期待どおりなら書き込まない。
    # ~/.claude.json は Claude Code 自身が実行中に更新するファイルなので、
    # rebuild のたびに読んで書き戻すと「読み込み〜mv の間に Claude Code が
    # 書いた内容」を取りこぼす（mv 自体は原子的でも、read-modify-write 全体は
    # そうではない）。書き込みを実際に変更が要るときだけに絞れば、
    # 通常の rebuild ではこの窓が発生しない。
    if ! ${pkgs.jq}/bin/jq -e --argjson want "$DESIRED" \
        '.mcpServers.playwright == $want' "$CLAUDE_JSON" >/dev/null 2>&1; then
      ${pkgs.jq}/bin/jq --argjson want "$DESIRED" '.mcpServers.playwright = $want' \
        "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
    fi
  '';

  home.activation.claudeStatusLine = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    SETTINGS_FILE="$HOME/.claude/settings.json"

    DESIRED_STATUSLINE=$(${pkgs.jq}/bin/jq -n '{
      "type": "command",
      "command": "~/.claude/statusline.sh",
      "padding": 0
    }')

    # .claudeディレクトリが存在しない場合は作成
    mkdir -p "$HOME/.claude"

    # 壊れた JSON だと後段の jq が失敗し activation 全体（set -e）が落ちるため、
    # 妥当性を検証して駄目なら作り直す（未作成のケースもこれで吸収できる）。
    if ! ${pkgs.jq}/bin/jq -e . "$SETTINGS_FILE" >/dev/null 2>&1; then
      echo '{}' > "$SETTINGS_FILE"
    fi

    # statusLine設定を追加/更新（既存の設定は保持）。
    # 上の claudeMcpConfig と同じ理由で、差分があるときだけ書き込む。
    if ! ${pkgs.jq}/bin/jq -e --argjson want "$DESIRED_STATUSLINE" \
        '.statusLine == $want' "$SETTINGS_FILE" >/dev/null 2>&1; then
      ${pkgs.jq}/bin/jq --argjson want "$DESIRED_STATUSLINE" '.statusLine = $want' \
        "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    fi
  '';
}
