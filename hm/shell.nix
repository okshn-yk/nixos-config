{ config, pkgs, ... }:

{
  # Bash & Aliases
  programs.bash = {
    enable = true;
    enableCompletion = true;
    shellAliases = {
      # eza
      ls   = "eza --icons --git";
      ll   = "eza -hl --icons --git";
      la   = "eza -hla --icons --git";
      tree = "eza --tree";
      # aws profile
      adev = "export AWS_PROFILE=dev && aws sso login";
      aadm = "export AWS_PROFILE=admin && aws sso login";
      # update-claudcode
      update-claude = "cd ~/nixos-config && nix flake update claude-code-nix && if ! git diff --quiet flake.lock; then git commit -am 'chore: update claude-code' && sudo nixos-rebuild switch --flake .; else echo '✅ Claude Code is already up to date.'; fi";
    };
    initExtra = ''
      # Starship初期化
      eval "$(starship init bash)"

      # ghq + fzf連携
      # 1. 処理を行う関数を定義
      function zrun_ghq_fzf() {
        local src=$(ghq list -p | fzf --preview "ls -la {}")
        if [ -n "$src" ]; then
          cd "$src"
          # 移動後に画面をクリアして、視線を左上に戻す
          clear 
        fi
      }

      # 2. キーバインド設定 
      # bind -x ではなく、標準の bind を使います。
      # \C-u  : 現在入力中の文字を消す（安全のため）
      # zrun_ : 関数名をタイプする
      # \n    : Enterキーを押す
      bind '"\C-g":" \C-u zrun_ghq_fzf\n"'
    '';   
  };

  # CLI Tools (Starship, Zoxide, etc.)
  programs.starship.enable = true;
  
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
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
    config = { theme = "Dracula"; };
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    defaultCommand = "rg --files --hidden --glob '!.git/*'";
    defaultOptions = [ "--height 40%" "--layout=reverse" "--border" ];
  };
}
