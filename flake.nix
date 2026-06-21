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
          ({ pkgs, ... }: {
            nixpkgs.overlays = [ rust-overlay.overlays.default ];
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
