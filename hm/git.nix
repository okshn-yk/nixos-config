{ config, pkgs, ... }:

{
  home.packages = [ pkgs.gh pkgs.lazygit ];

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "okshin";
        email = "156062140+okshn-yk@users.noreply.github.com";
      };
      credential.helper = "!gh auth git-credential";
      init.defaultBranch = "main";
    };
  };
}
