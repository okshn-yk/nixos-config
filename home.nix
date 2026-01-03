{ config, pkgs, ... }:

{
  # 分割したファイルをインポート
  imports = [
    ./hm/shell.nix
    ./hm/vscode.nix
    ./hm/git.nix
    ./hm/apps.nix
    ./hm/claude.nix
    ./autostart.nix
  ];

  # 基本情報
  home.username = "okshin";
  home.homeDirectory = "/home/okshin";

  # 環境変数 (全体に関わるもの)
  home.sessionVariables = {
    EDITOR = "vim";
    BROWSER = "firefox";
    DEFAULT_BROWSER = "firefox";
  };
  
  # Path (全体)
  home.sessionPath = [
    "$HOME/.bun/bin"
  ];

  # 設定ファイルのリンク (Starship等は各モジュールに移してもOKですが、ここでもOK)
  xdg.configFile."starship.toml".source = ./dotfiles/starship.toml;
  xdg.configFile."wezterm/wezterm.lua".source = ./dotfiles/wezterm/wezterm.lua;

  home.stateVersion = "26.05";
}
