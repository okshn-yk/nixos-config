{ config, pkgs, ... }:

{
  # ローカルLLM（Ollama）— Zed のインライン補完（edit prediction）バックエンド
  services.ollama = {
    enable = true;

    # Vega iGPU(RADV RENOIR) は Vulkan で動く。ROCm は gfx90c 非対応で
    # CPU フォールバックだったため Vulkan 版に変更し iGPU オフロードを狙う。
    # 効果が無い/不安定なら package を pkgs.ollama（CPU版）へ戻す。
    # 選択肢: pkgs.ollama[-rocm|-vulkan|-cuda|-cpu]
    package = pkgs.ollama-vulkan;

    environmentVariables = {
      # 統合GPU(iGPU)は既定で除外されるため明示的に有効化（Vulkanオフロード）
      OLLAMA_IGPU_ENABLE = "1";
      # モデルを常駐保持し、アイドル後の再ロード遅延を回避
      OLLAMA_KEEP_ALIVE = "30m";
    };

    # 補完用モデルを宣言的に pull（起動時に取得）
    # FIM 学習済みの Qwen2.5-Coder ベース。速度↔品質: 1.5b-base / 3b-base / 7b-base
    loadModels = [ "qwen2.5-coder:1.5b-base" ];
  };
}
