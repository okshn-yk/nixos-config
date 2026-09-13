{
  description = "My NixOS Configuration with xremap";

  inputs = {
    # NixOSのパッケージリポジトリ (Unstable版を使用)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home Manager設定
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Code設定
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      # 依存関係（nixpkgs）をシステムと合わせる
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Codex CLI（OpenAI）設定
    # nixpkgs の codex は上流リリースから数日遅れるため、上流を追従するこの flake を使う。
    # 公式のビルド済みバイナリを取得するのでコンパイルは走らない。
    # 引込み元: hm/claude.nix。更新: update-codex（hm/shell.nix）。
    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      # 依存関係（nixpkgs）をシステムと合わせる
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #Rust Overlay
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # xremapの公式Flakeを取り込み
    xremap-flake.url = "github:xremap/nix-flake";
    xremap-flake.inputs.nixpkgs.follows = "nixpkgs";

    # sops-nix
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      xremap-flake,
      sops-nix,
      rust-overlay,
      ...
    }@inputs:
    let
      # ホスト固有値を一箇所に集約。複数ホスト化や T14 移行時はここだけ差し替える。
      # configuration.nix / home.nix / aws-config.nix / claude.nix へ specialArgs 経由で配布。
      username = "okshin";
      hostName = "nixos";
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        # inputs とホスト固有値を各モジュールへ渡す
        specialArgs = {
          inherit
            inputs
            username
            hostName
            system
            ;
        };
        modules = [
          { nixpkgs.hostPlatform = system; }

          ./configuration.nix

          # システム全体でrust-binを使用可能に
          ({ ... }: {
            nixpkgs.overlays = [
              rust-overlay.overlays.default

              # Solaar に不足している実行時依存を足す overlay。
              # overlay に置くのは configs/mouse.nix と hm/mouse.nix の両方から
              # 同一の派生を参照するため。
              #
              # 版の上書き（version / src）は 2026-08-26 に撤去した。当初は nixpkgs が
              # 1.1.19 で、Bolt レシーバ(046d:C548)配下の MX Master 4 が
              # "Protocol: unknown (device is offline)" になり HID++ ping が返らない
              # 問題を 1.1.20 の "Correctly handle timeout in Bolt discovery" で
              # 回避していたが、nixpkgs 側が 1.1.20 に追いついた。上書き後の src は
              # nixpkgs のものと同一で、派生も出力パスも一致していた（実測）ので、
              # 効果のない記述として削除した。
              #
              # 解除条件: pycairo と libnotify が nixpkgs の solaar の依存に入ったら
              # この overlay ごと削除する（下の 2 つの理由がそのまま確認項目）。
              (final: prev: {
                solaar = prev.solaar.overridePythonAttrs (old: {
                  # pycairo は 1.1.20 の install_requires に追加されたが nixpkgs 側は
                  # 未追従（実測: propagatedBuildInputs に含まれない）。
                  propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [
                    final.python3Packages.pycairo
                  ];
                  # libnotify を足して gi.require_version("Notify", "0.7") を満たす。
                  # 無いと solaar の実行ごとに
                  # "Notification service is not available: Namespace Notify not available"
                  # が出力される（wrapGAppsHook3 が buildInputs の typelib を拾う）。
                  buildInputs = (old.buildInputs or [ ]) ++ [ final.libnotify ];
                  # libnotify を入れると通知テストが skip されず実際に走るが、
                  # ビルドサンドボックスには通知デーモンが無いため
                  # 'NoneType' object has no attribute 'get_search_path' で失敗する。
                  # 環境依存の失敗なのでこのファイルのみ除外する（他 758 件は通る）。
                  disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
                    "tests/solaar/ui/test_desktop_notifications.py"
                    "tests/logitech_receiver/test_desktop_notifications.py"
                  ];
                });
              })
            ];
          })

          # Home Manager モジュールの読み込み
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # 既存の非管理ファイル（GNOME 生成の mimeapps.list 等）と衝突した際、
            # activation を失敗させず .hm-bak へ退避してから上書きする。
            home-manager.backupFileExtension = "hm-bak";
            home-manager.extraSpecialArgs = {
              inherit
                inputs
                username
                hostName
                system
                ;
            };
            home-manager.users.${username} = import ./home.nix; # ここでユーザー設定ファイルを指定
          }

          # xremapモジュールを読み込み
          xremap-flake.nixosModules.default

          # sopsモジュールの読み込み
          sops-nix.nixosModules.sops
        ];
      };

      # `nix fmt` で使われるフォーマッタを公開
      formatter.${system} = pkgs.nixfmt;

      # `nix develop` でこのリポジトリの編集に必要なツールを揃える。
      # 常用ツールは home-manager 側にも入っているが、他ホストや素の環境でも
      # 同じ道具立てで作業できるようにする。
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixfmt
          nixd
          nix-search-cli
        ];
      };

      # `nix flake check` に整形チェックを追加。未整形ファイルがあると失敗する。
      checks.${system}.nixfmt = pkgs.runCommand "nixfmt-check" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
        cd ${self}
        nixfmt --check $(find . -name '*.nix')
        touch $out
      '';
    };
}
