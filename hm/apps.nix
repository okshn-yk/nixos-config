{ config, pkgs, ... }:

{
  # Install Packages
  home.packages = with pkgs; [
    # Runtimes
    bun
    nodejs_24
    
    # Dev Tools
    awscli2
    jq
    ripgrep
    btop

    # Formatter
    nixfmt-rfc-style

    # GUI Apps
    # wezterm
    obsidian
    slack
    epiphany
    gnomeExtensions.appindicator
  ];

  # ghossty
  programs.ghostty = {
    enable = true;
    settings = {
      theme = "TokyoNight Night";
      
      # Zellijを自動起動する場合
      # command = "${pkgs.zellij}/bin/zellij";
      
      # フォント
      font-family = "HackGen Console";
      font-size = 15;
      font-feature = ["calt" "liga"];
      
      # --- ウィンドウ (没入感の向上) ---
      window-padding-x = 6;
      window-padding-y = 6;
      # GNOMEネイティブな見た目を維持 (Linux)
      gtk-titlebar = true;

      # コピー時に末尾の空白を自動削除 (YAML/Pythonのインデント事故防止！)
      clipboard-trim-trailing-spaces = true;

      # --- システム連携 (NixOS向け) ---
      # アップデート通知を無効化 (NixOSはパッケージ管理側で更新するため不要)
      auto-update = "off";
      # シェル統合機能の有効化
      shell-integration = "detect";
    };
  };

  # zellij
  programs.zellij = {
    enable = true;
    settings = {
      theme = "catppuccin-macchiato";
      pane_frames = false;   
      show_startup_tips = false;
    };
  };

  # Firefox Config
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
}
