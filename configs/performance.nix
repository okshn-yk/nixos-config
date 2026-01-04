{ config, pkgs, ... }:

{
  # ===========================================================================
  # System Performance Optimization
  # ===========================================================================

  # --- ZRAM (圧縮スワップ) ---
  # 課題: ノートPCはRAMが限られ、スワップ発生時にSSD寿命とパフォーマンスに影響
  # 解決: メモリ内で圧縮スワップを作成。物理スワップへのアクセスを大幅削減
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # --- Earlyoom (メモリ枯渇対策) ---
  # 課題: メモリ枯渇時、LinuxのOOM Killerは遅く、システムがフリーズ状態になる
  # 解決: メモリ残量5%以下で即座に重いプロセスを終了。デスクトップの応答性を維持
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    enableNotifications = true;
  };

  # --- Swappiness (スワップ頻度) ---
  # 課題: デフォルト(60)はサーバー向け。デスクトップでは頻繁なスワップで体感速度低下
  # 解決: 値を10に下げ、可能な限りRAMを使用。スワップは最後の手段に
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
  };
}
