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
    wezterm
    obsidian
    slack
    epiphany
    gnomeExtensions.appindicator
  ];

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
