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

    # VSCode (Customized)
    #(vscode-with-extensions.override {
    #  vscodeExtensions = with vscode-extensions; [
    #    bbenoist.nix                # Nix
    #    ms-python.python            # Python
    #    charliermarsh.ruff          # Ruff
    #    hashicorp.terraform         # Terraform
    #    ms-azuretools.vscode-docker # Docker
    #    eamodio.gitlens             # GitLens
    #    esbenp.prettier-vscode      # Prettier
    #    dracula-theme.theme-dracula # Theme
    #  ];
   # })
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
