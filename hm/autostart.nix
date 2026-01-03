{ pkgs, ... }:

{
  # ===========================================================================
  # XDG Autostart Configuration
  # ログイン時に自動起動するアプリケーションを定義します。
  # 重いアプリ(Electron系)には sleep を挟んで、起動ラッシュ(Thundering Herd)を防ぎます。
  # ===========================================================================

  xdg.configFile = {

    # --- 1. 即時起動 (軽量・最優先) ---

    # Terminal: すぐに作業を開始したいので遅延なし
    "autostart/ghostty.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Ghostty
      Exec=${pkgs.ghostty}/bin/ghostty
      X-GNOME-Autostart-enabled=true
    '';

    # Browser: メインツールなので即時
    "autostart/firefox.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Firefox
      Exec=${pkgs.firefox}/bin/firefox
      X-GNOME-Autostart-enabled=true
    '';

    # --- 2. 遅延起動 (重量級・バックグラウンド) ---

    # VSCode: 3秒待機動
    "autostart/vscode.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=VSCode
      Exec=sh -c "sleep 3 && ${pkgs.vscode}/bin/code"
      X-GNOME-Autostart-enabled=true
    '';

    # Slack: 6秒待機
    "autostart/slack.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Slack
      Exec=sh -c "sleep 6 && ${pkgs.slack}/bin/slack"
      X-GNOME-Autostart-enabled=true
    '';

  };
}
