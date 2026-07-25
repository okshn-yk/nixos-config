{ ... }:

{
  # ===========================================================================
  # AMD 固有ハードウェア設定 (Ryzen CPU + Radeon iGPU)
  # ===========================================================================
  # docs/migrate-t14-gen6-intel.md の Intel 機（T14 Gen6）へ移行する際は、
  # configuration.nix の imports からこのファイルを外すだけでよい。
  # （amd_pstate=active は Intel では無効、mem_sleep_default=s2idle は
  #  AMD GPU のスリープ復帰対策なので Intel では不要）
  #
  # ここに含めていないもの:
  # - kvm-amd: hardware-configuration.nix（nixos-generate-config 生成）側にあり、
  #   機種変更時はファイルごと再生成されるため移動しない。
  # - タッチパッドの RMI4 設定（configs/laptop.nix）: Synaptics 側の話であり
  #   AMD 固有ではないため移していない。

  # AMD GPU スリープ復帰問題対策
  boot.kernelParams = [
    "mem_sleep_default=s2idle"
    "amd_pstate=active"
  ];
}
