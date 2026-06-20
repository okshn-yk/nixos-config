{ pkgs, ... }:

{
  # ===========================================================================
  # Zed Editor
  # Home Manager で宣言的に管理（VSCode 寄りの最小構成）
  # ===========================================================================

  programs.zed-editor = {
    enable = true;

    # --- 拡張機能（Nix / Go / Markdown / Catppuccin Icons） ---
    extensions = [
      "nix"
      "go"
      "markdown"
      "catppuccin-icons"
    ];

    # settings.json 相当
    userSettings = {
      # Vim モードは無効
      vim_mode = false;

      # アイコンテーマ（catppuccin-icons 拡張が提供）
      icon_theme = "Catppuccin Latte";

      # インライン補完（Edit Prediction）: ローカル Ollama + Qwen2.5-Coder(FIM)
      # ※ バックエンドは configs/ollama.nix の services.ollama が供給
      edit_predictions = {
        provider = "ollama";
        ollama = {
          api_url = "http://localhost:11434";
          model = "qwen2.5-coder:1.5b-base";
          prompt_format = "qwen"; # Qwen の FIM トークン形式
          # 補完は短文中心。大きいと毎回大量生成し遅くなるため小さめに。
          max_output_tokens = 64;
        };
      };

      # --- フォント（HackGen Console = システム既定 monospace） ---
      ui_font_family = "HackGen Console";
      ui_font_size = 16;
      buffer_font_family = "HackGen Console";
      buffer_font_size = 16;

      terminal = {
        font_family = "HackGen Console NF";
      };

      # 保存時に自動フォーマット
      format_on_save = "on";

      # --- Nix: nixd を LSP、nixfmt をフォーマッタに ---
      languages.Nix = {
        language_servers = [ "nixd" ];
        formatter = {
          external = {
            command = "nixfmt";
            arguments = [ ];
          };
        };
      };

      # --- LSP バイナリは Nix で供給（Zed の npm 自動DLを回避） ---
      lsp = {
        # JSON: registry.npmjs.org への接続に依存させない
        json-language-server = {
          binary = {
            path = "${pkgs.vscode-langservers-extracted}/bin/vscode-json-language-server";
            arguments = [ "--stdio" ];
          };
        };
      };

      # Nixで管理しているため自動アップデートを無効化
      auto_update = false;

      # テレメトリ無効化
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
    };
  };
}
