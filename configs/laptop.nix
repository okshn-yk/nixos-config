{ config, pkgs, ... }:

{
  # Laptop Hardware Tweaks (Power, Sleep & Fingerprint)

  # ==========================================
  # Hibernate / Suspend-then-Hibernate
  # ==========================================
  # スワップパーティションをハイバネート先に指定（RAM 27GB に対して 30GB swap）
  boot.resumeDevice = "/dev/disk/by-uuid/c40808f8-c3ca-4189-b3db-c0f6dcd1a9aa";

  # s2idle で30分経過後、自動的にハイバネートへ移行
  systemd.sleep.settings.Sleep = {
    AllowSuspendThenHibernate = "yes";
    HibernateDelaySec = "30min";
  };

  # フタ閉じ・電源ボタン・アイドル時の動作
  services.logind = {
    lidSwitch = "suspend-then-hibernate";
    lidSwitchExternalPower = "suspend";
    lidSwitchDocked = "ignore";
    settings.Login = {
      HandlePowerKey = "suspend-then-hibernate";
    };
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
