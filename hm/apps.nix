{ pkgs, ... }:

{
  # ===========================================================================
  # Packages & GNOME Integration
  # ===========================================================================

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

    # Security Scanning
    checkov  # IaC セキュリティスキャン（Terraform, Dockerfile等）
    trivy    # コンテナ・ファイルシステム脆弱性スキャン

    # IaC Tools
    tenv  # Terraform/Terragrunt/OpenTofu バージョンマネージャー

    # GUI Apps
    # wezterm
    obsidian
    slack
    epiphany
    gnomeExtensions.appindicator

    # Clipboard Manager
    gpaste  # GNOMEネイティブのクリップボードマネージャー
  ];

  # GPasteデーモン自動起動
  systemd.user.services.gpaste = {
    Unit = {
      Description = "GPaste clipboard manager daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.gpaste}/libexec/gpaste/gpaste-daemon";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # GNOME dconf設定
  dconf.settings = {
    # GPasteショートカット
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "GPaste Toggle";
      command = "${pkgs.gpaste}/libexec/gpaste/gpaste-ui";
      binding = "<Super>v";
    };

    # カスタムショートカットの登録
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };

    # GNOMEキーバインド
    "org/gnome/shell/keybindings" = {
      toggle-message-tray = ["<Super>t"];
    };
  };

  # Fcitx5 変換ウィンドウ設定
  xdg.configFile."fcitx5/conf/classicui.conf".text = ''
    Vertical Candidate List=True
    PerScreenDPI=True
    Font="Sans 12"
    Theme=catppuccin-macchiato-blue
  '';
}
