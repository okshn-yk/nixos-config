{ config, pkgs, ... }:

{
  home.username = "okshin";
  home.homeDirectory = "/home/okshin";


  # 1. パッケージ管理

  home.packages = with pkgs; [
    # Language Runtimes
    bun
    nodejs_24

    # Dev Tools
    awscli2     # AWS CLI
    gh          # GitHub CLI
    jq          # JSON processor
    ripgrep     # Fast grep (rg)
    lazygit     # Git TUI
    btop        # System monitor

    # GUI Applications
    # configuration.nix から移管
    wezterm
    obsidian
    slack
    librewolf
    epiphany
    gnomeExtensions.appindicator
  ];

  # PATH
  home.sessionPath = [
    "$HOME/.bun/bin"
  ];

  # 2. 設定ファイルの配置 (Symlink作成)
  
  # Starship
  xdg.configFile."starship.toml".source = ./dotfiles/starship.toml;

  # WezTerm
  xdg.configFile."wezterm/wezterm.lua".source = ./dotfiles/wezterm/wezterm.lua;

  # 3. プログラムの有効化
  
  #
  programs.bash = {
    enable = true;
    enableCompletion = true;
   
    # Aliases
    shellAliases = {
      # eza (ls replacement)
      ls   = "eza --icons --git";
      ll   = "eza -hl --icons --git";
      la   = "eza -hla --icons --git";
      tree = "eza --tree";
    };
  };
  
  # Starship の有効化設定もこちらに移管できます
  programs.starship = {
    enable = true;
  }; 
  
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    options = [ "--cmd cd" ]; # cdコマンド自体を置き換え
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
    enableBashIntegration = true;
    
    # 検索コマンドに ripgrep を使用 (高速・.gitignore尊重)
    defaultCommand = "rg --files --hidden --glob '!.git/*'";
    defaultOptions = [ "--height 40%" "--layout=reverse" "--border" ];
    
    # Ctrl+T (ファイル選択) のプレビューに bat を使用
    fileWidgetOptions = [
      "--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
    ];
  };
  # Git設定などもここで書けます (今回は省略)

  # Home Manager のバージョン (変更しない)
  home.stateVersion = "26.05"; 
}

