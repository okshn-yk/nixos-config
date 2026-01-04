{ pkgs, ... }:

{
  # ===========================================================================
  # Terminal Emulators & Multiplexers
  # ===========================================================================

  # Ghostty
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
      background-opacity = 0.9;
      # GNOMEネイティブな見た目を維持 (Linux)
      gtk-titlebar = true;

      # コピー時に末尾の空白を自動削除 (YAML/Pythonのインデント事故防止！)
      clipboard-trim-trailing-spaces = true;

      # --- システム連携 (NixOS向け) ---
      # アップデート通知を無効化 (NixOSはパッケージ管理側で更新するため不要)
      auto-update = "off";
      # シェル統合機能の有効化
      shell-integration = "detect";

      # キーバインド設定
      "keybind" = [
        "shift+enter=text:\\x1b\\x0d"  # Claude Code改行
        "ctrl+shift+d=close_surface"   # ペインを閉じる
      ];
    };
  };

  # Zellij
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
}
