{
  description = "My NixOS Configuration with xremap";

  inputs = {
    # NixOSのパッケージリポジトリ (Unstable版を使うかStable版を使うか指定できます。今回はStable 24.11ベースで)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home Manager設定
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # xremapの公式Flakeを取り込み
    xremap-flake.url = "github:xremap/nix-flake";
    xremap-flake.inputs.nixpkgs.follows = "nixpkgs";

    # soap-nix
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, xremap-flake, sops-nix, ... }@inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; }; # inputsをconfiguration.nixへ渡す
      modules = [
        ./configuration.nix

        # Home Manager モジュールの読み込み
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
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
