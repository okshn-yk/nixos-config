{ pkgs, ... }:

{
  # CLI Tools Package
  home.packages = with pkgs; [
    fd # find の高速代替
    blesh # ble.sh - Bash Line Editor（オートサジェスト・構文ハイライト）
  ];

  # Bash & Aliases
  programs.bash = {
    enable = true;
    enableCompletion = true;
    shellAliases = {
      # eza
      ls = "eza --icons --git";
      ll = "eza -hl --icons --git";
      la = "eza -hla --icons --git";
      tree = "eza --tree";
      # fd (隠しファイル込み検索)
      fdh = "fd --hidden --no-ignore";
      # aws profile
      adev = "export AWS_PROFILE=dev && aws sso login";
      aadm = "export AWS_PROFILE=admin && aws sso login";
      aprd = "export AWS_PROFILE=prd && aws sso login";
      # update-claude / update-codex は関数として initExtra 側で定義
      # （検証→コミットの安全な順序と dirty ガードが必要なため）
    };
    initExtra = ''
      # ble.sh 初期化（最初に読み込む）
      [[ $- == *i* ]] && source "${pkgs.blesh}/share/blesh/ble.sh" --noattach

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
      # いずれかで失敗したら flake.lock を元に戻し、無関係な作業中変更はコミットしない。
      # 事前に flake.lock の未コミット変更を弾くのは、失敗時の巻き戻し
      # (git checkout -- flake.lock) が他の入力の更新まで破棄してしまうため。
      # 成功時の git commit -- flake.lock も同様に、無関係な入力の更新まで
      # 巻き込んでコミットしてしまう。
      _update_flake_input() {  # $1=入力名 $2=コミットメッセージ
        cd ~/nixos-config || return 1
        if ! git diff --quiet flake.lock; then
          echo "❌ flake.lock に未コミットの変更があります。先にコミットするか破棄してください。"
          return 1
        fi
        nix flake update "$1"
        if git diff --quiet flake.lock; then
          echo "✅ $1 is already up to date."
          return 0
        fi
        if ! nix flake check; then
          echo "❌ flake check に失敗。flake.lock を元に戻します。"
          git checkout -- flake.lock
          return 1
        fi
        if ! sudo nixos-rebuild test --flake .; then
          echo "❌ rebuild test に失敗。flake.lock を元に戻します。"
          git checkout -- flake.lock
          return 1
        fi
        git commit -m "$2" -- flake.lock
        sudo nixos-rebuild switch --flake .
      }

      # Claude Code / Codex の更新ショートカット（中身は上の共通処理）。
      update-claude() { _update_flake_input claude-code-nix "chore: update claude-code"; }
      update-codex() { _update_flake_input codex-cli-nix "chore: update codex"; }

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
      eval "$(zoxide init bash --cmd cd)"

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
    options = [ "--cmd cd" ];
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
