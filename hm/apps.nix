{ config, pkgs, ... }:

let
  # checkov: 依存の bc-detect-secrets 1.5.52 のテストが unidiff 1.0.1 の厳格化で 2 件落ちてビルド不能
  # （TestScanDiff のフィクスチャの diff が "Target without source: +++ b/.secrets.baseline" で
  # 拒否される。nixpkgs 02c087f, 2026-10-20 で確認）。他の 1173 件は通るので、その 2 件だけ外す。
  # bc-detect-secrets を引き込むのは checkov だけなので checkov の dependencies 内で差し替える。
  # 解除条件: 素の nixpkgs で checkov がビルドできたら（CLAUDE.md の確認コマンド参照）。
  checkov = pkgs.checkov.overridePythonAttrs (old: {
    dependencies = map (
      dep:
      if (dep.pname or "") == "bc-detect-secrets" then
        dep.overridePythonAttrs (o: {
          disabledTestPaths = (o.disabledTestPaths or [ ]) ++ [
            "tests/core/secrets_collection_test.py::TestScanDiff::test_filename_filters_are_invoked_first"
            "tests/core/secrets_collection_test.py::TestScanDiff::test_success"
          ];
        })
      else
        dep
    ) old.dependencies;
  });
in
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
    ssm-session-manager-plugin # aws ssm start-session（ポートフォワード）に必要
    jq
    ripgrep
    btop
    kiro-cli # Kiro Crew（~/.kiro/crew-venv に curl で導入、Nix 管理外）の土台

    # Security Scanning
    checkov # IaC セキュリティスキャン（Terraform, Dockerfile等）。上の let で bc-detect-secrets を上書き
    trivy # コンテナ・ファイルシステム脆弱性スキャン

    # IaC Tools
    tenv # Terraform/Terragrunt/OpenTofu バージョンマネージャー

    # GUI Apps
    obsidian
    slack
    xmind
    google-chrome # Playwright MCP が依存（削除不可）
    # ChatGPT デスクトップ（ChatGPT / Work / Codex 統合）。nixpkgs の chatgpt は macOS 専用のため
    # 自前の pkgs/chatgpt.nix を flake.nix の overlay で pkgs.chatgpt に差し替えている
    chatgpt
    # GNOME Shell 拡張は hm/autostart.nix の programs.gnome-shell で管理

    # クリップボードマネージャ（GPaste）はシステム側の programs.gpaste.enable
    # （configuration.nix）で入る。本体・D-Bus activation・gsettings schema を
    # 上流オプションがまとめて面倒みるため、ここでは何も入れない。
  ];

  # 日本語音声入力。GNOME のショートカットで録音を切り替える。
  # キー入力の合成は使わず、認識結果をコピーして好きな入力欄へ貼り付ける。
  services.voxtype = {
    enable = true;
    # 通常版は CPU のみ。Whisper Small の認識を AMD 内蔵 GPU にオフロードする。
    # ROCm ではなく Mesa/RADV 経由の Vulkan を使用。
    package = pkgs.voxtype.override { vulkanSupport = true; };
    loadModels = [ "small" ]; # 多言語版（small.en は英語専用）
    settings = {
      state_file = "auto";
      hotkey.enabled = false; # evdev ではなく GNOME のカスタムキーを使用
      audio = {
        device = "default";
        max_duration_secs = 60;
      };
      whisper = {
        mode = "local";
        model = "small";
        language = "ja";
        translate = false;
        on_demand_loading = true; # 録音開始時に読み込み、認識後に解放
      };
      output = {
        mode = "clipboard";
        notification = {
          on_recording_start = true;
          on_recording_stop = true;
          on_transcription = true;
        };
      };
    };
  };

  # GPaste デーモンをログイン時から常駐させる。
  # gpaste パッケージは user unit (Type=dbus, BusName=org.gnome.GPaste) を同梱し、
  # programs.gpaste.enable がそれを /etc/systemd/user へ配置するが、NixOS は
  # user unit の [Install] を自動で有効化しない。そのため D-Bus activation 頼みになり、
  # 最初に Super+V を押すまでデーモンが起動せず、それ以前のコピーが履歴に残らない。
  # 上流の unit をそのまま graphical-session.target から要求することで、
  # ExecStart 等を自前で書き写さずにログイン時起動へ戻す
  # （= systemctl --user enable 相当を宣言的に行う）。
  xdg.configFile."systemd/user/graphical-session.target.wants/org.gnome.GPaste.service".source =
    "${pkgs.gpaste}/etc/systemd/user/org.gnome.GPaste.service";

  # GNOME dconf設定
  dconf.settings = {
    # ロック画面で通知を非表示
    "org/gnome/desktop/notifications" = {
      show-in-lock-screen = false;
    };

    # フォント描画を macOS 風に（ヒンティングなし + グレースケール AA）
    # GTK アプリ（Floorp/Firefox 含む）は fontconfig より GNOME のこの設定を
    # 優先するため、configs/desktop.nix の fontconfig 側と揃えておく
    "org/gnome/desktop/interface" = {
      font-hinting = "none";
      font-antialiasing = "grayscale";
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

    # GPasteショートカット（Super+V で履歴 UI を開く）
    # デーモンは NixOS 側の programs.gpaste.enable（configuration.nix）が
    # D-Bus activation で供給する。ここはキーバインドの定義のみ。
    # command は store パス直指定なので PATH に依存しない。
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "GPaste Toggle";
      command = "${pkgs.gpaste}/libexec/gpaste/gpaste-ui";
      binding = "<Super>v";
    };

    # カスタムショートカットの登録
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voxtype" = {
      name = "Voxtype: 日本語音声入力";
      command = "${config.services.voxtype.package}/bin/voxtype record toggle";
      binding = "<Super><Shift>v";
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voxtype/"
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
