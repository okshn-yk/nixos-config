{ config, pkgs, ... }:

{
  # Install Packages
  home.packages = with pkgs; [
    # Language
    bun
    nodejs_24
    uv
    
    # Build Tools
    gcc
    gnumake

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

  #CopyQ 
  services.copyq = {
    enable = true;
    # Systemdサービスとして管理し、Nixリビルド時に自動再起動させる
    systemdTarget = "graphical-session.target";
  };
  # CopyQとのショートカット競合回避
  dconf.settings = {
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "CopyQ Toggle";
      # pkgs.copyq を埋め込むことでパス問題を回避
      command = "${pkgs.copyq}/bin/copyq toggle";
      binding = "<Super>v";
    };

    # 2. 定義したショートカットをシステムに「登録」
    # ここにリストとしてパスを列挙します
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };
    "org/gnome/shell/keybindings" = {
      # 通知トレイを Super + N に変更
      toggle-message-tray = ["<Super>t"];
    };
  };

  # ghossty
  programs.ghostty = {
    enable = true;
    settings = {
      theme = "TokyoNight Night";
      
      # Zellijを自動起動する場合
      # command = "${pkgs.zellij}/bin/zellij";
      
      # フォント
      font-family = "HackGen Console";
      font-size = 14;
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

      # Claude Code改行設定（shift + enter）
      "keybind" = "shift+enter=text:\\x1b\\x0d";
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

  xdg.configFile."zellij/config.kdl".text = ''
    keybinds {
        locked {
            unbind "Ctrl g"
            bind "Alt g" { SwitchToMode "Normal"; }
        }
        shared_except "locked" {
            unbind "Ctrl g"
            bind "Alt g" { SwitchToMode "Locked"; }
            // Alt+oでセッションメニュー 
            unbind "Ctrl o"
            bind "Alt o" { SwitchToMode "Session"; }
        }
    }
  '';

  # 変換ウィンドウ設定
  xdg.configFile."fcitx5/conf/classicui.conf".text = ''
    Vertical Candidate List=True
    PerScreenDPI=True
    Font="Sans 12"
    Theme=catppuccin-macchiato-blue
  '';

  # Firefox Config
  programs.firefox = {
    enable = true;
    # 日本語スペルチェック無効
    profiles.default = {
      id = 0;
      name = "default";
      isDefault = true;

      settings = {
        # ▼ スペルチェックを完全に無効化
        # 0: 無効
        # 1: 複数行の入力ボックスのみ有効 (デフォルト)
        # 2: すべての入力ボックスで有効
        "layout.spellcheckDefault" = 0;
        "network.dns.disableIPv6" = true;
        "privacy.resistFingerprinting" = false;
      };
    };
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
