{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./configs/aws-config.nix
    ./configs/desktop.nix
    ./configs/dev-env.nix
    ./configs/laptop.nix
    ./configs/wifi.nix
    ./configs/keymap.nix
  ];

  # ==========================================
  # System Core
  # ==========================================
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Nix Settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  
  # 非フリーパッケージ許可
  nixpkgs.config.allowUnfree = true;

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

  # Global Apps
  programs.starship.enable = true;

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
}
