{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    gh 
    lazygit
    ghq
  ];

  programs.git = {
    enable = true;
    settings = {
      # ユーザー情報
      user = {
        name = "okshin";
        email = "156062140+okshn-yk@users.noreply.github.com";
      };

      # その他の設定
      credential.helper = "!gh auth git-credential";
      init.defaultBranch = "main";

      # 大きなプッシュ用のHTTP設定
      http = {
        postBuffer = 524288000; # 500MB
        lowSpeedLimit = 1000; # 1KB/s 未満を異常とみなす
        lowSpeedTime = 60; # 60秒続いたらタイムアウト
      };

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
