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

  outputs = { self, nixpkgs, home-manager, xremap-flake, sops-nix, rust-overlay, ... }@inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; }; # inputsをconfiguration.nixへ渡す
      modules = [
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
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.okshin = import ./home.nix; # ここでユーザー設定ファイルを指定
        }

        # xremapモジュールを読み込み
        xremap-flake.nixosModules.default

        # sopsモジュールの読み込み
        sops-nix.nixosModules.sops
      ];
    };
  };
}
