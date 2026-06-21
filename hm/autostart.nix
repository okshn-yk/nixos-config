{ pkgs, ... }:

let
  # ===========================================================================
  # ログイン時に自動起動するアプリ
  # delay: 起動ラッシュ(Thundering Herd)緩和のための起動前 sleep 秒数
  # ===========================================================================
  autostartApps = {
    floorp = {
      exec = "${pkgs.floorp-bin}/bin/floorp";
      delay = 0; # ブラウザ: メインツールなので即時 (WS1)
      desc = "Floorp browser";
    };
    ghostty = {
      exec = "${pkgs.ghostty}/bin/ghostty";
      delay = 0; # ターミナル: すぐ作業したいので即時 (WS2)
      desc = "Ghostty terminal";
    };
    vscode = {
      exec = "${pkgs.vscode}/bin/code";
      delay = 3; # WS2
      desc = "Visual Studio Code";
    };
    zed = {
      exec = "${pkgs.zed-editor}/bin/zeditor";
      delay = 4; # WS3
      desc = "Zed editor";
    };
    obsidian = {
      exec = "${pkgs.obsidian}/bin/obsidian";
      delay = 5; # WS3
      desc = "Obsidian";
    };
    slack = {
      exec = "${pkgs.slack}/bin/slack";
      delay = 6; # WS4
      desc = "Slack";
    };
  };

  # 各アプリを systemd user service 化する。
  # graphical-session.target 配下に置くことで GNOME ログイン後に起動し、
  # ログアウト時に停止する。`systemctl --user status <name>` / `journalctl --user -u <name>`
  # で起動失敗とログを追跡でき、異常終了時は自動再起動する。
  mkService = _name: app: {
    Unit = {
      Description = "${app.desc} (autostart)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep ${toString app.delay}";
      ExecStart = app.exec;
      # 単一インスタンス/フォーク方式のアプリはランチャが正常終了(exit 0)するため、
      # これが無いとサービスが dead 表示になる。終了後も "active (exited)" を維持し
      # 「起動成功」を明示する（前面維持アプリの異常終了時 Restart も両立）。
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
in
{
  # --- 0. 依存パッケージ (拡張機能) のインストール ---
  home.packages = with pkgs; [
    gnomeExtensions.auto-move-windows
  ];

  # --- 1. ウィンドウ配置ルール (Workspace Assignment) ---
  dconf.settings = {
    # auto-move-windows 拡張を有効化（これが無いと割当ルールは一切効かない）。
    # 既存の appindicator と併記する。
    "org/gnome/shell" = {
      # ユーザー拡張の全体無効化フラグ。true だと enabled-extensions に
      # 登録しても拡張が INITIALIZED 止まりで起動しない。明示的に false にする。
      disable-user-extensions = false;
      # 実ユーザーが1人だと GNOME は電源メニューの「ログアウト」を隠す。
      # 常に表示させる。
      always-show-log-out = true;
      enabled-extensions = [
        "appindicatorsupport@rgcjonas.gmail.com"
        "auto-move-windows@gnome-shell-extensions.gcampax.github.com"
      ];
    };

    # 固定ワークスペースにして WS1〜WS4 を常設する。
    # 動的(dynamic)のままだとログイン時に WS2 以降が存在せず割当が安定しない。
    "org/gnome/mutter" = {
      dynamic-workspaces = false;
    };
    "org/gnome/desktop/wm/preferences" = {
      num-workspaces = 4;
    };

    # アプリをどのワークスペースで開くか指定 (1始まり)。
    # .desktop ID は実際のファイル名と完全一致が必須。
    "org/gnome/shell/extensions/auto-move-windows" = {
      application-list = [
        "floorp.desktop:1" # WS 1: ブラウザ
        "com.mitchellh.ghostty.desktop:2" # WS 2: ターミナル
        "code.desktop:2" # WS 2: コード
        "dev.zed.Zed.desktop:3" # WS 3: エディタ
        "obsidian.desktop:3" # WS 3: ノート
        "slack.desktop:4" # WS 4: チャット
      ];
    };
  };

  # --- 2. 自動起動 (systemd user services) ---
  # 旧来の XDG autostart(.desktop + sleep) から移行。診断性とセッション連動を改善。
  systemd.user.services = builtins.mapAttrs mkService autostartApps;
}
