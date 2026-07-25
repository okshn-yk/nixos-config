{ config, pkgs, ... }:

{
  # Laptop Hardware Tweaks (Touchpad, Power, Sleep & Fingerprint)

  # ==========================================
  # タッチパッド: PS/2 → RMI4(SMBus) へ切り替え
  # ==========================================
  # 既定では psmouse が PS/2 プロトコルで駆動しており、カーネル自身が
  # 「別バスに対応している」と警告を出していた:
  #   psmouse serio1: synaptics: Your touchpad (PNP: LEN2073 PNP0f13) says it
  #   can support a different bus. ... try setting psmouse.synaptics_intertouch to 1
  # PS/2 は座標分解能・レポートレートが低く、圧力情報も出ないためパーム
  # リジェクションとポインタ追従が甘い。RMI4 に切り替えると本来の分解能と
  # 圧力データが得られ、libinput の加速カーブ（adaptive）も素直に効く。
  # SMBus 側は i2c_piix4(AMD) が担当。rmi_smbus は本来 udev が自動ロード
  # するが、psmouse の probe と競合しないよう明示的に読み込む。
  #
  # 万一 RMI4 化でタッチパッドが動かなくなった場合は、この 2 行を削除して
  # rebuild すれば PS/2 に戻る（暫定回避はブートローダで
  # psmouse.synaptics_intertouch=0 を指定）。TrackPoint は別デバイス
  # (Elan TrackPoint on serio2) なので、切り分け中も操作手段は残る。
  boot.kernelParams = [ "psmouse.synaptics_intertouch=1" ];
  boot.kernelModules = [ "rmi_smbus" ];

  # ==========================================
  # Hibernate / Suspend-then-Hibernate
  # ==========================================
  # スワップパーティションをハイバネート先に指定（RAM 27GB に対して 30GB swap）
  # UUID をここにも書くと hardware-configuration.nix の swapDevices と二重管理になり、
  # ディスク再作成時に片方だけ古くなってハイバネート復帰が静かに壊れる。
  # 唯一の正である swapDevices から導出する。
  boot.resumeDevice = (builtins.head config.swapDevices).device;

  # s2idle で30分経過後、自動的にハイバネートへ移行
  systemd.sleep.settings.Sleep = {
    AllowSuspendThenHibernate = "yes";
    HibernateDelaySec = "30min";
  };

  # ハイバネートイメージを最小化（=積極的にメモリ解放）して確実に成功させる。
  # 既定値(RAMの約2/5)では、保存対象がRAMの約半分に達するとアトミックコピー用の
  # 空きRAMが枯渇し "PM: hibernation: Error -12 creating image" で失敗、
  # 消費電力の大きい s2idle に戻ってバッテリーを使い切る事象が発生したため。
  # 0 = カーネルが可能な限り小さいイメージを作る。ハイバネート時のみ作用し通常動作に影響なし。
  systemd.tmpfiles.rules = [ "w /sys/power/image_size - - - - 0" ];

  # フタ閉じ・電源ボタン・アイドル時の動作
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
    # 電源ボタンは GNOME(gsd-media-keys) が握るため、実際の動作は
    # hm/apps.nix の dconf power-button-action="hibernate" で決まる。
    # これは GNOME 不在(TTY等)時のフォールバック。
    HandlePowerKey = "hibernate";
  };

  # ==========================================
  # 低バッテリー保護（UPower）
  # ==========================================
  # バッテリー残量3%でハイバネート実行 → データ喪失防止
  services.upower = {
    enable = true;
    criticalPowerAction = "Hibernate";
    percentageLow = 15;
    percentageCritical = 5;
    percentageAction = 3;
  };

  # ==========================================
  # Power Management (TLP)
  # ==========================================
  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      # CPU ガバナー
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # ターボブースト（バッテリー時は無効で省電力）
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      # プラットフォームプロファイル
      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "balanced";

      # WiFi 省電力
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";

      # USB 自動サスペンド
      USB_AUTOSUSPEND = 1;

      # PCIe ランタイム省電力
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "auto";

      # 有線NIC(Realtek RTL8168/r8169)をランタイムPMから除外。
      # ランタイムPMでサスペンドするとケーブル挿入時の復帰が不安定になり
      # carrier が上がらず(NO-CARRIER)リンクできない問題が起きるため常時通電。
      # 0000:05:00.0=本体RJ45(enp5s0), 0000:02:00.0=もう一方のRTL8168(enp2s0f0)
      RUNTIME_PM_DISABLE = "0000:05:00.0 0000:02:00.0";

      # ストレージ省電力
      AHCI_RUNTIME_PM_ON_AC = "on";
      AHCI_RUNTIME_PM_ON_BAT = "auto";

      # オーディオ省電力
      SOUND_POWER_SAVE_ON_AC = 0;
      SOUND_POWER_SAVE_ON_BAT = 1;

      # バッテリー充電閾値
      START_CHARGE_THRESH_BAT0 = 85;
      STOP_CHARGE_THRESH_BAT0 = 95;
    };
  };

  # Firmware Updates
  services.fwupd.enable = true;

  # Fingerprint Reader
  services.fprintd.enable = true;
  security.pam.services.login.fprintAuth = pkgs.lib.mkForce true;
  security.pam.services.gdm-fingerprint.fprintAuth = true;
}
