{ config, pkgs, ... }:

{
  # Development Environment

  # System Packages for Dev
  environment.systemPackages = with pkgs; [
    # Basic Tools
    vim
    wget
    git
    curl
    
    # Encryption Tools
    sops
    age
    ssh-to-age

    # Container Tools
    podman-compose

  ];

  # Nix-ld (VSCode Server compatibility)
  programs.nix-ld.enable = true;

  # Podman
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };
  
  # Editor Variable
  environment.variables.EDITOR = "vim";
}
