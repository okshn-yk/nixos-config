{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./configs/aws-config.nix
    ./configs/desktop.nix
    ./configs/dev-env.nix
    ./configs/laptop.nix
    ./configs/wifi.nix
    ./configs/keymap.nix
    ./configs/performance.nix
    ./configs/security.nix
  ];

  # ==========================================
  # System Core
  # ==========================================
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Nix Settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # nix-community バイナリキャッシュ（ビルド時間短縮）
    substituters = [ "https://nix-community.cachix.org" ];
    trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  
  # 非フリーパッケージ許可（ホワイトリスト方式）
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "vscode"
    "vscode-extension-ms-vscode-remote-remote-ssh"
    "vscode-extension-fill-labs-dependi"
    "slack"
    "obsidian"
    "1password"
    "1password-cli"
    "1password-gui"
    "terraform"
  ];

  # State Version
  system.stateVersion = "25.11";

  # Networking Core
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # ==========================================
  # User & Global Settings
  # ==========================================
  users.users.okshin = {
    isNormalUser = true;
    description = "okshin";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };


  # Sops General Settings (Keys)
  sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  # ==========================================
  # Services (Others)
  # ==========================================
  # Google Drive Auto-mount
  systemd.user.services.rclone-gdrive = {
    description = "rclone mount for Google Drive";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "default.target" ];
    path = [ "/run/wrappers" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.rclone}/bin/rclone mount gdrive: %h/gdrive --vfs-cache-mode full";
      ExecStop = "/run/wrappers/bin/fusermount -u %h/gdrive";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };
  
  # Rclone package itself
  environment.systemPackages = [ pkgs.rclone ];

  # --- Locate (ファイル検索高速化) ---
  # 毎日DBを更新し、locateコマンドで瞬時検索
  services.locate = {
    enable = true;
    package = pkgs.plocate;
    interval = "daily";
    prunePaths = [
      "/tmp"
      "/var/tmp"
      "/var/cache"
      "/var/lock"
      "/var/spool"
      "/nix/store"
      "/nix/var/log"
    ];
  };
}
