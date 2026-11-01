{ pkgs, ... }:

{
  home.packages = with pkgs; [
    lazygit
    ghq
  ];

  # gh 本体と git の認証ヘルパー。gitCredentialHelper（既定で有効）が
  # credential."https://github.com".helper にストアパス付きの gh を登録するので、
  # PATH 上の gh に依存しない。対象は github.com と gist.github.com。
  # ~/.config/gh/config.yml は読み取り専用の symlink になるため、
  # `gh alias set` / `gh config set` の変更はここへ書く。認証情報の hosts.yml は管理外。
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      aliases.co = "pr checkout";
    };
  };

  programs.git = {
    enable = true;
    settings = {
      # ユーザー情報
      user = {
        name = "okshin";
        email = "156062140+okshn-yk@users.noreply.github.com";
      };

      # その他の設定
      init.defaultBranch = "main";

      # 通信停止検出。postBuffer は Git の既定値を使用する。
      http = {
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
          insteadOf = [
            "git@github.com:"
            "ssh://git@github.com/"
          ];
        };
      };
    };
  };
}
