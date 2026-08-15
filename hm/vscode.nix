{ pkgs, ... }:

let
  # hashicorp.terraform: nixpkgs が 2.40.0 に記録した src ハッシュが実際の配信物と
  # 食い違いビルド不能（マーケットプレイスの vsix は複数回取得しても同一なので、
  # nixpkgs 側の更新ミス）。実測値で上書きする。
  # 解除条件: nixpkgs が正しいハッシュへ修正、または次バージョンへ更新されたら削除。
  #   （バージョンが上がれば下の条件式が外れて自動的に素の派生へ戻る）
  terraformExtension =
    let
      ext = pkgs.vscode-extensions.hashicorp.terraform;
    in
    if ext.version == "2.40.0" then
      ext.overrideAttrs (old: {
        src = old.src.overrideAttrs (_: {
          outputHash = "sha256-UsyKO7zTSDovproPUaIWfqmJxIjZfNTwhaQuH2xIzyE=";
        });
      })
    else
      ext;
in
{
  programs.vscode = {
    enable = true;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        bbenoist.nix
        ms-python.python
        charliermarsh.ruff
        terraformExtension
        ms-azuretools.vscode-docker
        eamodio.gitlens
        esbenp.prettier-vscode
        dracula-theme.theme-dracula

        # --- Rust ---
        rust-lang.rust-analyzer # 言語サーバークライアント
        tamasfe.even-better-toml # TOMLファイルのサポート
        fill-labs.dependi # 依存クレートのバージョン管理

        # --- Go ---
        golang.go # Go言語サポート (gopls使用)

        # --- Mermaid ---
        bierner.markdown-mermaid # Markdownプレビューでmermaid図表示

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
        "nix.serverPath" = "nixd";
        "nix.serverSettings" = {
          "nixd" = {
            "formatting" = {
              "command" = [ "nixfmt" ];
            };
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

        # Nixで入れた gopls を使う設定
        "go.alternateTools" = {
          "gopls" = "gopls";
        };
        "[go]" = {
          "editor.defaultFormatter" = "golang.go";
        };

        # ウィンドウズームレベル（約120%）
        "window.zoomLevel" = 1;

        # Nixで管理しているためアップデート通知を無効化
        "update.mode" = "none";
        "update.showReleaseNotes" = false;
      };
    };
  };
}
