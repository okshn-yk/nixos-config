{ config, pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        bbenoist.nix
        ms-python.python
        charliermarsh.ruff
        hashicorp.terraform
        ms-azuretools.vscode-docker
        eamodio.gitlens
        esbenp.prettier-vscode
        dracula-theme.theme-dracula
      ];
      userSettings = {
        "workbench.colorTheme" = "Dracula Theme";
        "editor.fontSize" = 14;
        "editor.fontFamily" = "'HackGen Console', monospace";
        "terminal.integrated.fontFamily" = "'HackGen Console NF', 'HackGen Console', monospace";
        "terminal.integrated.fontSize" = 14;
        "editor.formatOnSave" = true;
        "files.autoSave" = "onFocusChange";
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nil";
        "nix.serverSettings" = {
          "nil" = {
            "formatting" = { "command" = [ "nixfmt" ]; };
          };
        };
        "[python]" = {
          "editor.defaultFormatter" = "charliermarsh.ruff";
        };
      };
    };
  };
}
