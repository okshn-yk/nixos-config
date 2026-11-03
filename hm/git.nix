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

  # delta: git の diff / show / log -p をシンタックスハイライト・行内差分・行番号付きで表示。
  # enableGitIntegration で core.pager と interactive.diffFilter（add -p）に設定される。
  # 横並び表示は分割ペインで折り返して読みにくいので既定は縦。必要なときは `git diff | delta -s`。
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true; # n / N でファイル単位に移動
      line-numbers = true;
      syntax-theme = "Dracula"; # bat と揃える
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

      # pull は merge コミットを作らず rebase。作業中の変更は自動で退避・復元する。
      pull.rebase = true;
      rebase.autoStash = true;
      # 新しいブランチの初回 push で -u（upstream 設定）を不要にする
      push.autoSetupRemote = true;
      # fetch のたびにリモートで消えたブランチの追跡参照を掃除する
      fetch.prune = true;
      # 一度解決したコンフリクトの解決方法を記録し、同じものが再発したら自動適用
      rerere.enabled = true;
      # 差分の精度向上（関数の境界などでずれにくい）と、移動した行の色分け
      diff.algorithm = "histogram";
      diff.colorMoved = "default";
      # コンフリクト表示に共通祖先（base）も出す。delta も対応
      merge.conflictStyle = "zdiff3";

      alias = {
        graph = "log --graph --oneline --decorate --all";
        st = "status -sb";
        # 直前のコミットを取り消して変更はステージに残す
        undo = "reset --soft HEAD~1";
      };

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
