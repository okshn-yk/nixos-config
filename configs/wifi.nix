{ config, ... }:

{
  # WiFi Configuration via Sops

  sops.secrets.wifi_ssid = { };
  sops.secrets.wifi_psk = { };

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
    # シークレット変更時に接続プロファイルを再読込する。接続の切断はしない。
    restartUnits = [ "NetworkManager-reload-profiles.service" ];
  };

  # Hook to deploy the connection file
  systemd.services."NetworkManager-pre" = {
    script = ''
      mkdir -p /etc/NetworkManager/system-connections/
      ln -sf ${
        config.sops.templates."home-wifi.nmconnection".path
      } /etc/NetworkManager/system-connections/home-wifi.nmconnection
      chmod 600 /etc/NetworkManager/system-connections/home-wifi.nmconnection
    '';
    serviceConfig = {
      # Type=simple だと fork 直後に「起動完了」と見なされ、before= の順序保証が
      # 実効を持たない（リンク作成前に NetworkManager が走りうる）。oneshot に
      # することで「スクリプト終了まで待ってから NetworkManager を起動」になる。
      Type = "oneshot";
      RemainAfterExit = true;
    };
    before = [ "NetworkManager.service" ];
    after = [ "sops-install-secrets.service" ];
    wantedBy = [ "multi-user.target" ];
  };
  # 起動時と sops 更新時の共通処理。NetworkManager 本体の再起動を避ける。
  systemd.services.NetworkManager-reload-profiles = {
    description = "Reload NetworkManager connection profiles after secret changes";
    requires = [
      "NetworkManager.service"
      "NetworkManager-pre.service"
    ];
    after = [
      "NetworkManager.service"
      "NetworkManager-pre.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${config.networking.networkmanager.package}/bin/nmcli connection reload";
    };
  };
}
