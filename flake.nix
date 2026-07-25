{
  description = "My NixOS Configuration with xremap";

  inputs = {
    # NixOSのパッケージリポジトリ (Unstable版を使用)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # ble.sh ピン留め専用 nixpkgs（blesh 以外には未使用）。
    # 2026-06-21 nightly(0.4.0-devel4, 6cffa91) はアタッチ処理の回帰で
    # 端末に文字入力できなくなるため、既知の正常版(2026-03-10 nightly,
    # 0.4.0-devel3, b99cadb) を含むこのリビジョンに固定する。
    # 利用箇所: 下の nixpkgs.overlays（blesh 差し替え）。引込み元: hm/shell.nix。
    # 解除条件: 上流 nightly でアタッチ回帰が修正されたら、この input と
    # overlay を削除して通常の nixpkgs の blesh に戻し、端末入力を再検証する。
    # 経緯と解除手順の詳細: docs/blesh-pin.md
    nixpkgs-blesh.url = "github:nixos/nixpkgs/567a49d1913ce81ac6e9582e3553dd90a955875f";

    # checkov ピン留め専用 nixpkgs（checkov 以外には未使用）。
    # 2026-07-23 更新の nixpkgs（e2587caef70cea85dd97d7daab492899902dbf5d 以降）では
    # checkov の依存 pycep-parser / policy-sentry が pythonMetadataCheckPhase の
    # 版数一致チェックに失敗しビルド不能（派生の version と wheel の
    # .dist-info/METADATA の version が食い違う、nixpkgs 側の回帰）。
    # 直前の正常なリビジョン（2026-07-19、稼働中システムと同一）に固定する。
    # 利用箇所: 下の nixpkgs.overlays（checkov 差し替え）。
    # 解除条件: 上流 nixpkgs で当該版数不整合が修正されたら、この input と
    # overlay を削除して通常の nixpkgs の checkov に戻す。
    nixpkgs-checkov.url = "github:nixos/nixpkgs/241313f4e8e508cb9b13278c2b0fa25b9ca27163";

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
      nixpkgs-blesh,
      nixpkgs-checkov,
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
          ({ pkgs, ... }: {
            nixpkgs.overlays = [
              rust-overlay.overlays.default

              # blesh ピン留め: 上の nixpkgs-blesh input 参照。
              # 新しい nightly のアタッチ回帰で端末入力不能になるのを回避するため、
              # 既知の正常版 blesh に固定する。解除条件は input のコメントを参照。
              (final: prev: {
                blesh = nixpkgs-blesh.legacyPackages.${system}.blesh;
              })

              # checkov ピン留め: 上の nixpkgs-checkov input 参照。
              # 新しい nixpkgs での pycep-parser / policy-sentry の版数不整合
              # 回帰でビルド不能になるのを回避するため、既知の正常版 nixpkgs の
              # checkov に固定する。解除条件は input のコメントを参照。
              # permittedInsecurePackages は configuration.nix と同じ内容を
              # ここでも明示（別 nixpkgs 評価のため設定が引き継がれない）。
              (final: prev: {
                checkov =
                  (import nixpkgs-checkov {
                    inherit system;
                    config.permittedInsecurePackages = [ "python3.14-ecdsa-0.19.2" ];
                  }).checkov;
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

      # `nix flake check` に整形チェックを追加。未整形ファイルがあると失敗する。
      checks.${system}.nixfmt = pkgs.runCommand "nixfmt-check" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
        cd ${self}
        nixfmt --check $(find . -name '*.nix')
        touch $out
      '';
    };
}
