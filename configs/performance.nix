{ ... }:

{
  # ===========================================================================
  # System Performance Optimization
  # ===========================================================================

  # --- ZRAM (圧縮スワップ) ---
  # 課題: ノートPCはRAMが限られ、スワップ発生時にSSD寿命とパフォーマンスに影響
  # 解決: メモリ内で圧縮スワップを作成。物理スワップへのアクセスを大幅削減
  #
  # 25% に抑える理由（ハイバネート対策）:
  # ハイバネート時、カーネルはイメージ縮小のため匿名ページをスワップへ追い出すが、
  # zram(prio 5 > ディスクswap prio -2)が高優先度だと追い出し先が zram=RAM内になり、
  # アトミックコピー用の空きRAMが確保できずイメージ作成に失敗する（Error -12）。
  # 上限を下げることで zram が吸収しきれない分がディスクswapへ逃げ、RAMが実際に空く。
  # RAM 27GiB・常用 ~6.5GiB のため通常動作への影響は無視できる。
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  # --- Earlyoom (メモリ枯渇対策) ---
  # 約37GiBある swap の枯渇を待たず、MemAvailable 5%で SIGTERM、2%で SIGKILL。
  # swap 側は両方100%にする（片方だけだと SIGKILL は swap 50%未満まで待つ）。
  # systemd-oomd はアプリが指定した cgroup の PSI 監視を担当し、こちらは全体の
  # 空きメモリを守る最後の保護。強制終了では未保存データが失われ得る。
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeMemKillThreshold = 2;
    freeSwapThreshold = 100;
    freeSwapKillThreshold = 100;
    enableNotifications = true;
  };

  # --- Swappiness (匿名ページとファイルキャッシュの回収コスト比) ---
  # zram を使いにくくする10からカーネル既定の60へ戻す。
  # ディスクswapも併用するので、まず保守的な値で負荷時の挙動を確認する。
  # 省電力の本体は laptop.nix の suspend-then-hibernate（30分後にディスクへ保存）。
  # zram は通常動作中の圧縮swapであり休止先ではない。上限25%と image_size=0 は
  # 休止時のメモリ不足対策として維持。高負荷時の休止・復帰は実機で再確認する。
  boot.kernel.sysctl = {
    "vm.swappiness" = 60;
  };
}
