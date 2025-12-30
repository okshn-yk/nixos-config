{ config, pkgs, ... }:

{
  # Laptop Hardware Tweaks (Power & Fingerprint)

  # Power Management (TLP)
  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
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
