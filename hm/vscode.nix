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

        # --- Rust Additions ---
        rust-lang.rust-analyzer   # 言語サーバークライアント
        tamasfe.even-better-toml  # TOMLファイルのサポート
        fill-labs.dependi         # 依存クレートのバージョン管理

        vscode-icons-team.vscode-icons
      ];
      userSettings = {
        "workbench.colorTheme" = "Dracula Theme";
        "workbench.iconTheme" = "vscode-icons";
        "editor.fontSize" = 16;
        "editor.fontFamily" = "'HackGen Console', monospace";
        "terminal.integrated.fontFamily" = "'HackGen Console NF', 'HackGen Console', monospace";
        "terminal.integrated.fontSize" = 16;
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
        "[rust]" = {
          "editor.defaultFormatter" = "rust-lang.rust-analyzer";
        };
        
        # 保存時に自動でclippy（リンター）を走らせる
        "rust-analyzer.check.command" = "clippy";
        
        # Nixで入れた rust-analyzer バイナリを強制的に使わせる設定
        "rust-analyzer.server.path" = "rust-analyzer";
        "rust-analyzer.cargo.buildScripts.enable" = true;
      };
    };
  };
}
