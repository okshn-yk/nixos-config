{ config, pkgs, ... }:

{
  home.username = "okshin";
  home.homeDirectory = "/home/okshin";


  # 1. パッケージ管理

  # configuration.nix からユーザー固有のものをここに移してもOKです
  home.packages = with pkgs; [
    # ここにはGUIアプリやCLIツールなどを記述
    bun
    nodejs_24
  ];

  # PATH
  home.sessionPath = [
    "$HOME/.bun/bin"
  ];

  # 2. 設定ファイルの配置 (Symlink作成)
  
  # Starship: ~/.config/starship.toml に配置
  xdg.configFile."starship.toml".source = ./dotfiles/starship.toml;

  # WezTerm: ~/.config/wezterm/wezterm.lua に配置
  xdg.configFile."wezterm/wezterm.lua".source = ./dotfiles/wezterm/wezterm.lua;

  # 3. プログラムの有効化
  
  #
  programs.bash = {
    enable = true;
    # 既存の .bashrc に追記したい設定があればここに書けます
  };
  
  # Starship の有効化設定もこちらに移管できます
  programs.starship = {
    enable = true;
    # 既に設定ファイルは上で配置しているので、ここでは enable だけでOK
  }; 

  # Git設定などもここで書けます (今回は省略)

  # Home Manager のバージョン (変更しない)
  home.stateVersion = "24.11"; 
}

