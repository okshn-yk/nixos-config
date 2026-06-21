{
  config,
  pkgs,
  username,
  ...
}:

{
  # 分割したファイルをインポート
  imports = [
    ./hm/shell.nix
    ./hm/vscode.nix
    ./hm/zed.nix
    ./hm/git.nix
    ./hm/apps.nix
    ./hm/terminal.nix
    ./hm/browser.nix
    ./hm/claude.nix
    ./hm/autostart.nix
    ./hm/rust.nix
    ./hm/go.nix
  ];

  # 基本情報
  home.username = username;
  home.homeDirectory = "/home/${username}";

  # 環境変数 (全体に関わるもの)
  # 既定ブラウザは Floorp に統一（autostart / xdg.mimeApps と一致させる）
  home.sessionVariables = {
    EDITOR = "vim";
    BROWSER = "floorp";
    DEFAULT_BROWSER = "floorp";
  };

  # 既定アプリ関連付け（既存の ~/.config/mimeapps.list を宣言的に取り込み）。
  # ブラウザは Floorp に統一しつつ、claude-cli / slack の URL ハンドラも維持する。
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # ブラウザ系（Floorp に統一）
      "text/html" = "floorp.desktop";
      "application/xhtml+xml" = "floorp.desktop";
      "x-scheme-handler/http" = "floorp.desktop";
      "x-scheme-handler/https" = "floorp.desktop";
      "x-scheme-handler/chrome" = "floorp.desktop";
      "application/x-extension-htm" = "floorp.desktop";
      "application/x-extension-html" = "floorp.desktop";
      "application/x-extension-shtml" = "floorp.desktop";
      "application/x-extension-xhtml" = "floorp.desktop";
      "application/x-extension-xht" = "floorp.desktop";
      # アプリ固有の URL ハンドラ（消えると Claude Code / Slack のリンク連携が壊れる）
      "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      "x-scheme-handler/slack" = "slack.desktop";
    };
  };

  # Path (全体)
  home.sessionPath = [
    "$HOME/.bun/bin"
  ];

  # 設定ファイルのリンク (Starship等は各モジュールに移してもOKですが、ここでもOK)
  xdg.configFile."starship.toml".source = ./dotfiles/starship.toml;

  home.stateVersion = "24.11";
}
