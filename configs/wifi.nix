{ config, ... }:

{
  # WiFi Configuration via Sops
  #
  # 上流の networking.networkmanager.ensureProfiles で接続プロファイルを生成する。
  # NetworkManager-ensure-profiles.service が、下の環境変数ファイルを読んで
  # $WIFI_SSID / $WIFI_PSK を envsubst で置換し、/run/NetworkManager/system-connections
  # へ書き出してから nmcli connection reload する。
  # 以前は自前の NetworkManager-pre / NetworkManager-reload-profiles で sops の
  # レンダリング結果を /etc 側へ symlink していたが、同じ処理が上流にあるため置き換えた。

  sops.secrets.wifi_ssid = { };
  sops.secrets.wifi_psk = { };

  # systemd の EnvironmentFile として読まれる（値は envsubst でそのまま差し込まれる）。
  sops.templates."home-wifi.env" = {
    content = ''
      WIFI_SSID=${config.sops.placeholder.wifi_ssid}
      WIFI_PSK=${config.sops.placeholder.wifi_psk}
    '';
    mode = "0400";
    # シークレット変更時にプロファイルを再生成・再読込する。接続の切断はしない。
    restartUnits = [ "NetworkManager-ensure-profiles.service" ];
  };

  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ config.sops.templates."home-wifi.env".path ];
    # キー名がファイル名（/run/.../home-wifi-sops.nmconnection）になる。旧方式の
    # /etc/.../home-wifi.nmconnection と同名だと /etc 側が優先されて隠れるため名前を変えた。
    profiles.home-wifi-sops = {
      connection = {
        id = "HomeWiFi-Sops";
        type = "wifi";
        autoconnect = true;
        autoconnect-priority = 100;
        permissions = "";
      };
      wifi = {
        ssid = "$WIFI_SSID";
        mode = "infrastructure";
      };
      wifi-security = {
        key-mgmt = "sae";
        psk = "$WIFI_PSK";
        password-flags = 0;
      };
      ipv4.method = "auto";
      ipv6 = {
        addr-gen-mode = "default";
        method = "auto";
      };
    };
  };
}
