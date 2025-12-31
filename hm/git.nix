{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    gh 
    lazygit
    ghq
  ];

  programs.git = {
    enable = true;

    userName = "okshin";
    userEmail = "156062140+okshn-yk@users.noreply.github.com";

    extraConfig = {
      # 認証ヘルパー
      credential.helper = "!gh auth git-credential";
      init.defaultBranch = "main";

      # ghqの設定
      ghq = {
        root = "~/src";
      };

      # URLの書き換え設定
      url = {
        "https://github.com/" = {
          insteadOf = [ "git@github.com:" "ssh://git@github.com/" ];  
        };
      };
    };
  };
}
