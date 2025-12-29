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
    wezterm
    obsidian
    slack
    epiphany
    gnomeExtensions.appindicator
  ];

  # PATH
  home.sessionPath = [
    "$HOME/.bun/bin"
  ];

  # 2. 環境変数の設定
  home.sessionVariables = {
    EDITOR = "vim";
    # Home Managerで入れたFirefoxを指定
    BROWSER = "firefox";
    DEFAULT_BROWSER = "firefox";
  };
  
  # 3. 設定ファイルの配置 (Symlink作成)
  
  # Starship
  xdg.configFile."starship.toml".source = ./dotfiles/starship.toml;

  # WezTerm
  xdg.configFile."wezterm/wezterm.lua".source = ./dotfiles/wezterm/wezterm.lua;

  # 4. プログラムの有効化・設定
  
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

      # aws sso for starship
      adev = "export AWS_PROFILE=dev && aws sso login";
      aadm = "export AWS_PROFILE=admin && aws sso login";
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

  # firefox
  programs.firefox = {
    enable = true;
    
    # ポリシー設定 (企業向けの管理機能を使ってテレメトリ等を強制オフにする)
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
      };
      DisablePocket = true;
      DisableFirefoxAccounts = false; # Syncを使いたい場合は false
      DisableAccounts = false;
      DisableAppUpdate = true; # Nixで管理するため
      
      # "New Tab" ページの広告などを消す
      FirefoxHome = {
        Search = true;
        Pocket = false;
        Snippets = false;
        TopSites = true;
        Highlights = false;
        SponsoredPocket = false;
        SponsoredTopSites = false;
      };
      Preferences = {
        "media.hardwaremediakeys.enabled" = false;
      };
    };
  };

  # Git
  programs.git = {
    enable = true;
    
    settings = {
      user = {
        name = "okshin";
        email = "156062140+okshn-yk@users.noreply.github.com";
      };
      credential = {
        helper = "!gh auth git-credential";
      };
      init = {
        defaultBranch = "main";
      };
    };
  };

  # Home Manager のバージョン (変更しない)
  home.stateVersion = "26.05"; 
}

