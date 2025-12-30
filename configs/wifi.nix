{ config, pkgs, ... }:

{
  # WiFi Configuration via Sops
  
  sops.secrets.wifi_ssid = {};
  sops.secrets.wifi_psk = {};

  # Template Definition
  sops.templates."home-wifi.nmconnection" = {
    content = ''
      [connection]
      id=HomeWiFi-Sops
      type=wifi
      autoconnect=true
      autoconnect-priority=100
      permissions=

      [wifi]
      ssid=${config.sops.placeholder.wifi_ssid}
      mode=infrastructure

      [wifi-security]
      key-mgmt=sae
      psk=${config.sops.placeholder.wifi_psk}
      password-flags=0

      [ipv4]
      method=auto

      [ipv6]
      addr-gen-mode=default
      method=auto
    '';
    mode = "0600";
  };

  # Hook to deploy the connection file
  systemd.services."NetworkManager-pre" = {
    script = ''
      mkdir -p /etc/NetworkManager/system-connections/
      ln -sf ${config.sops.templates."home-wifi.nmconnection".path} /etc/NetworkManager/system-connections/home-wifi.nmconnection
      chmod 600 /etc/NetworkManager/system-connections/home-wifi.nmconnection
    '';
    before = [ "NetworkManager.service" ];
    wantedBy = [ "multi-user.target" ];
  };
}
