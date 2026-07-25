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
    # checkov 3.3.6 は aiohttp<3.14.0 を要求するが、nixpkgs更新で aiohttp 3.14.1 が
    # 引き込まれ pythonRuntimeDepsCheckHook が失敗する。実行時の非互換ではなく
    # メタデータの上限が保守的なだけなので、ランタイム依存チェックのみ無効化。
    # 解除条件: nixpkgs側で checkov が aiohttp 3.14 を許可したら override を削除。
    # 見直し: `nix flake update` 後にこの override の要否を確認。
    (checkov.overridePythonAttrs (_: {
      dontCheckRuntimeDeps = true;
    })) # IaC セキュリティスキャン（Terraform, Dockerfile等）
    trivy # コンテナ・ファイルシステム脆弱性スキャン

    # IaC Tools
    tenv # Terraform/Terragrunt/OpenTofu バージョンマネージャー

    # GUI Apps
    obsidian
    slack
    xmind
    google-chrome # Playwright MCP が依存（削除不可）
    gnomeExtensions.appindicator

    # Clipboard Manager
    gpaste # GNOMEネイティブのクリップボードマネージャー
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
    # ロック画面で通知を非表示
    "org/gnome/desktop/notifications" = {
      show-in-lock-screen = false;
    };

    # タッチパッドのポインタ加速
    #
    # 「最初はゆっくり、速く動かすほど大きく飛ぶ」挙動は libinput の
    # adaptive プロファイルそのもので、既定でも有効。ここでは意図を明示
    # するため adaptive を直接指定する（touchpad の "default" は adaptive）。
    #
    # macOS のカーブそのものを移植することは GNOME/Wayland では不可能。
    # libinput 1.31 には任意のカーブを点列で与える custom プロファイルが
    # あるが、mutter 50 は libinput_config_accel_create / set_points を
    # 一切呼んでおらず、gsettings の enum も default/flat/adaptive のみ。
    # したがって調整できるのは speed によるカーブ全体のスケールだけ。
    #
    # speed は -1.0〜1.0。値を上げるとカーブ全体が持ち上がり、特に高速時の
    # 移動量が伸びる（macOS 寄りの「振ると大きく飛ぶ」感触）。
    # 実機で詰めるときは下記で即時反映して試し、決まった値をここへ戻す:
    #   gsettings set org.gnome.desktop.peripherals.touchpad speed 0.5
    #
    # 経緯: RMI4 化前は PS/2 で 0.559 だった。RMI4 で分解能とレポートレートが
    # 上がった分だけ同じ speed でも機敏になるため、一度 0.7 まで上げたところ
    # 過敏だった。0.55 に戻して落ち着かせている（RMI4 の追従性向上はそのまま
    # 残るので、PS/2 時代の 0.559 と同値でも体感は別物）。
    "org/gnome/desktop/peripherals/touchpad" = {
      accel-profile = "adaptive";
      speed = 0.55;
    };

    # 電源ボタンの動作: AC 接続中でもハイバネート
    # (フタ閉じの AC 時は configs/laptop.nix で suspend のまま)
    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action = "hibernate";
    };

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
      toggle-message-tray = [ "<Super>t" ];
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
