{
  config,
  lib,
  pkgs,
  ...
}:

{
  # CLI Tools Package
  home.packages = with pkgs; [
    fd # find の高速代替
    dust # du の代替。ディレクトリごとの使用量を大きい順にツリーと棒グラフで表示
    duf # df の代替。マウントごとの空き容量を表で表示
    blesh # ble.sh - Bash Line Editor（オートサジェスト・構文ハイライト）
  ];

  # Bash & Aliases
  programs.bash = {
    enable = true;
    enableCompletion = true;

    # 履歴: 既定 (500/1000) では数日で流れるので大きく取る。
    # ignoreboth = 先頭スペース付き・連続重複を記録しない。erasedups で古い重複を消す。
    # histappend は Home Manager の shellOptions 既定に含まれる。
    # ペイン間のリアルタイム共有は ble.sh の history_share（initExtra）で行う。
    historySize = 100000;
    historyFileSize = 200000;
    historyControl = [
      "ignoreboth"
      "erasedups"
    ];
    historyIgnore = [
      "ls"
      "ll"
      "la"
      "exit"
      "clear"
    ];

    shellAliases = {
      # eza: ls / lt / lla と、--icons auto --git 付きの eza 自身は
      # programs.eza の Bash 連携が定義する（bash は別名の先頭語も展開するので、
      # 下の "eza ..." にも icons / git が自動で付く）。ここはヘッダ行(-h)付きにしたい分だけ上書き。
      ll = "eza -hl";
      la = "eza -hla";
      tree = "eza --tree";
      lg = "lazygit";
      # fd (隠しファイル込み検索)
      fdh = "fd --hidden --no-ignore";
      # AWS SSO ログインは関数 asso（initExtra）に集約
      # update-claude / update-codex は関数として initExtra 側で定義
      # （検証→コミットの安全な順序と dirty ガードが必要なため）
    };
    initExtra = ''
      # ble.sh 初期化（最初に読み込む）
      [[ $- == *i* ]] && source "${pkgs.blesh}/share/blesh/ble.sh" --noattach

      # 複数の Ghostty / tmux ペイン間で履歴をコマンド実行ごとに共有する
      [[ ''${BLE_VERSION-} ]] && bleopt history_share=1

      # ===========================================================================
      # Ghostty テーマ動的切り替え（Claude/Codex 視認性向上）
      # ===========================================================================

      # TokyoNight Night テーマ色
      _GHOSTTY_TOKYONIGHT_BG="#1a1b26"
      _GHOSTTY_TOKYONIGHT_FG="#c0caf5"

      # Dracula テーマ色
      _GHOSTTY_DRACULA_BG="#282A36"
      _GHOSTTY_DRACULA_FG="#F8F8F2"

      # テーマ適用関数
      _ghostty_set_theme() {
        printf '\033]11;%s\033\\' "$1"  # 背景
        printf '\033]10;%s\033\\' "$2"  # 前景
      }

      # Codex ラッパー（Dracula テーマで実行。CODEX_HOME はグローバル ~/.codex を使用）
      codex() {
        _ghostty_set_theme "$_GHOSTTY_DRACULA_BG" "$_GHOSTTY_DRACULA_FG"
        trap '_ghostty_set_theme "$_GHOSTTY_TOKYONIGHT_BG" "$_GHOSTTY_TOKYONIGHT_FG"' EXIT INT TERM
        command codex "$@"
        local exit_code=$?
        trap - EXIT INT TERM
        _ghostty_set_theme "$_GHOSTTY_TOKYONIGHT_BG" "$_GHOSTTY_TOKYONIGHT_FG"
        return $exit_code
      }

      # flake 入力を安全な順序で更新する共通処理。
      # 更新 → flake check → rebuild test（成功）→ flake.lock のみコミット → switch。
      # 更新・検証に失敗したら flake.lock を元に戻す。コミット以降の失敗では
      # 検証済みの lock を保持し、実行中の設定との対応を失わないようにする。
      # リポジトリ全体をクリーンな状態に限定し、他の未コミット設定を
      # rebuild が取り込んでコミットと稼働設定が食い違うことを防ぐ。
      # 関数全体を subshell にして、cd が呼び出し元のカレントディレクトリを
      # 書き換えないようにする（どこで update-claude を打っても戻ってこられる）。
      _update_flake_input() (  # $1=入力名 $2=コミットメッセージ
        cd ~/nixos-config || return 1
        local status
        status=$(git status --porcelain --untracked-files=all) || return 1
        if [ -n "$status" ]; then
          echo "❌ リポジトリに未コミット・未追跡の変更があります。先に整理してください。"
          return 1
        fi
        if ! nix flake update "$1"; then
          echo "❌ flake update に失敗。flake.lock を元に戻します。"
          git restore --source=HEAD --worktree -- flake.lock
          return 1
        fi
        if git diff --quiet HEAD -- flake.lock; then
          echo "✅ $1 is already up to date."
          return 0
        fi
        if ! nix flake check; then
          echo "❌ flake check に失敗。flake.lock を元に戻します。"
          git restore --source=HEAD --worktree -- flake.lock
          return 1
        fi
        if ! sudo nixos-rebuild test --flake .; then
          echo "❌ rebuild test に失敗。flake.lock を元に戻します。"
          git restore --source=HEAD --worktree -- flake.lock
          return 1
        fi
        if ! git commit -m "$2" -- flake.lock; then
          echo "❌ コミットに失敗。test で実行中の設定と flake.lock を保持し、switch は中止します。"
          return 1
        fi
        if ! sudo nixos-rebuild switch --flake .; then
          echo "❌ switch に失敗。検証済みのコミットを保持しました。原因を解消して switch を再実行してください。"
          return 1
        fi
      )

      # Claude Code / Codex の更新ショートカット（中身は上の共通処理）。
      update-claude() { _update_flake_input claude-code-nix "chore: update claude-code"; }
      update-codex() { _update_flake_input codex-cli-nix "chore: update codex"; }

      # AWS SSO ログイン: `asso <profile>`、引数なしなら fzf で選択。
      # プロファイル一覧は ~/.aws/config（configs/aws-config.nix）から取るので、
      # プロファイルを増やしてもここは変更不要。AWS_PROFILE を現在のシェルへ
      # export するためエイリアスやスクリプトではなく関数にしている。
      # 一覧は設定ファイルを直接読む（`aws configure list-profiles` は 1 秒強かかり、
      # Tab 補完のたびに待たされるため）。
      _asso_profiles() {
        sed -n 's/^\[profile \(.*\)\]$/\1/p' "''${AWS_CONFIG_FILE:-$HOME/.aws/config}"
      }
      asso() {
        local profile=''${1-}
        local profiles
        profiles=$(_asso_profiles)
        if [[ -z $profiles ]]; then
          echo "asso: AWS のプロファイルが見つかりません" >&2
          return 1
        fi
        if [[ -z $profile ]]; then
          profile=$(fzf --prompt 'AWS profile> ' --height 10 <<< "$profiles") || return 1
        elif ! grep -qxF -- "$profile" <<< "$profiles"; then
          echo "asso: 不明なプロファイル: $profile（候補: ''${profiles//$'\n'/ }）" >&2
          return 1
        fi
        export AWS_PROFILE=$profile
        aws sso login
      }
      _asso_complete() {
        mapfile -t COMPREPLY < <(compgen -W "$(_asso_profiles 2>/dev/null)" -- "''${COMP_WORDS[COMP_CWORD]}")
      }
      complete -F _asso_complete asso

      # ghq + fzf連携
      function zrun_ghq_fzf() {
        local src=$(ghq list -p | fzf --preview "ls -la {}")
        if [ -n "$src" ]; then
          cd "$src"
          clear
        fi
      }
      bind '"\C-g":" \C-u zrun_ghq_fzf\n"'

      # ble.sh fzf キーバインド統合（Ctrl+r, Ctrl+t, Alt+c）
      [[ ''${BLE_VERSION-} ]] && ble-import contrib/fzf-key-bindings

      # zoxide 初期化（ble-attach の直前に配置）
      # 引数は programs.zoxide.options に一本化（Bash 連携を切っているので自前で渡す）
      eval "$(${lib.getExe config.programs.zoxide.package} init bash ${lib.escapeShellArgs config.programs.zoxide.options})"

      # direnv フック（zoxide と同じ理由で手動。ble-attach より前に置く）
      eval "$(${lib.getExe config.programs.direnv.package} hook bash)"

      # ble.sh アタッチ（最後に実行）
      [[ ''${BLE_VERSION-} ]] && ble-attach
    '';
  };

  # CLI Tools (Starship, Zoxide, etc.)
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = false; # 手動で初期化するため無効化（ble.sh との順序問題回避）
    options = [
      "--cmd"
      "cd"
    ];
  };

  # direnv + nix-direnv: `.envrc` に `use flake` と書けば cd で devShell を自動ロード。
  # nix-direnv が評価結果をキャッシュし GC ルートも張るので、2 回目以降は即時。
  # 新しい .envrc は `direnv allow` で許可する。
  programs.direnv = {
    enable = true;
    enableBashIntegration = false; # 手動で初期化するため無効化（ble.sh との順序問題回避）
    nix-direnv.enable = true;
    silent = true; # cd のたびの export 一覧を出さない
  };

  # nix-index（nix-index-database の DB 同梱版。モジュールは home.nix で import）。
  # 未インストールのコマンドを打つと、それを含むパッケージを提示する。
  # comma: `, cowsay` で未インストールのコマンドをその場で一時実行する。
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;

  # tealdeer: `tldr <cmd>` で実例中心の短いヘルプ（man より速く引ける）。
  # キャッシュは systemd timer で定期更新する（初回は `tldr --update`）。
  programs.tealdeer = {
    enable = true;
    enableAutoUpdates = true;
  };

  # yazi: TUI ファイラー（プレビュー付き）。`y` で起動し、終了時のディレクトリへ cd する。
  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
    shellWrapperName = "y";
  };

  programs.eza = {
    enable = true;
    enableBashIntegration = true;
    icons = "auto";
    git = true;
  };

  programs.bat = {
    enable = true;
    config = {
      theme = "Dracula";
    };
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = false; # ble.sh の fzf 統合を使用するため無効化
    defaultCommand = "rg --files --hidden --glob '!.git/*'";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
    ];
  };
}
