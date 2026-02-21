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

  # tmux
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    shell = "\${pkgs.bash}/bin/bash";
    prefix = "C-s";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;
    mouse = true;
    keyMode = "vi";
    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
    ];
    extraConfig = ''
      # True Color対応
      set -ag terminal-overrides ",xterm-256color:RGB"

      # ペイン分割 (カレントディレクトリを引き継ぐ)
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # ペイン移動 (vim風)
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # ペインリサイズ
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # 新規ウィンドウ (カレントディレクトリを引き継ぐ)
      bind c new-window -c "#{pane_current_path}"

      # ステータスバー
      set -g status-position top
      set -g status-style "bg=#1a1b26,fg=#c0caf5"
      set -g status-left "#[fg=#7aa2f7,bold] #S "
      set -g status-right "#[fg=#565f89] %Y-%m-%d %H:%M "
      set -g window-status-format "#[fg=#565f89] #I:#W "
      set -g window-status-current-format "#[fg=#7aa2f7,bold] #I:#W "
    '';
  };
}
