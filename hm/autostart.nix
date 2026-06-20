{ pkgs, ... }:

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
        "floorp.desktop:1"                 # WS 1: ブラウザ
        "com.mitchellh.ghostty.desktop:2"  # WS 2: ターミナル
        "code.desktop:2"                   # WS 2: コード
        "dev.zed.Zed.desktop:3"            # WS 3: エディタ
        "slack.desktop:4"                  # WS 4: チャット
      ];
    };
  };

  # ===========================================================================
  # XDG Autostart Configuration
  # ログイン時に自動起動するアプリケーションを定義します。
  # 重いアプリ(Electron系)には sleep を挟んで、起動ラッシュ(Thundering Herd)を防ぎます。
  # ===========================================================================

  xdg.configFile = {

    # --- 1. 即時起動 (軽量・最優先) ---

    # Browser: メインツールなので即時 (WS1)
    "autostart/floorp.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Floorp
      Exec=${pkgs.floorp-bin}/bin/floorp
      X-GNOME-Autostart-enabled=true
    '';

    # Terminal: すぐに作業を開始したいので遅延なし (WS2)
    "autostart/ghostty.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Ghostty
      Exec=${pkgs.ghostty}/bin/ghostty
      X-GNOME-Autostart-enabled=true
    '';

    # --- 2. 遅延起動 (重量級・バックグラウンド) ---

    # VSCode: 3秒待機 (WS2)
    "autostart/vscode.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=VSCode
      Exec=sh -c "sleep 3 && ${pkgs.vscode}/bin/code"
      X-GNOME-Autostart-enabled=true
    '';

    # Zed: 4秒待機 (WS3)
    "autostart/zed.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Zed
      Exec=sh -c "sleep 4 && ${pkgs.zed-editor}/bin/zeditor"
      X-GNOME-Autostart-enabled=true
    '';

    # Slack: 6秒待機 (WS4)
    "autostart/slack.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Slack
      Exec=sh -c "sleep 6 && ${pkgs.slack}/bin/slack"
      X-GNOME-Autostart-enabled=true
    '';

  };
}
