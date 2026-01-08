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
  ];

  # CopyQ
  services.copyq = {
    enable = true;
    # Systemdサービスとして管理し、Nixリビルド時に自動再起動させる
    systemdTarget = "graphical-session.target";
  };

  # GNOME dconf設定
  dconf.settings = {
    # CopyQショートカット
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "CopyQ Toggle";
      command = "${pkgs.copyq}/bin/copyq toggle";
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
