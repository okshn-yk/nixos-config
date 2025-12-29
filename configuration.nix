{ config, pkgs, input, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ==========================================
  # 1. System Core & Nix Settings
  # ==========================================
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Nixの設定 (Flakes, Garbage Collection)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  
  # 非フリーパッケージの許可
  nixpkgs.config.allowUnfree = true;
  
  # Nix-ld (VSCode Server等のための互換レイヤー)
  programs.nix-ld.enable = true;

  # State Version
  system.stateVersion = "25.11";

  # ==========================================
  # 2. Hardware & Power Management
  # ==========================================
  # 省電力設定 (TLP)
  services.power-profiles-daemon.enable = false; # GNOME標準機能を無効化
  services.tlp = {
    enable = true;
    settings = {
      # 基本設定
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # ThinkPad特有のバッテリー保護設定
      START_CHARGE_THRESH_BAT0 = 85;
      STOP_CHARGE_THRESH_BAT0 = 95;
    };
  };

  # ファームウェア更新
  services.fwupd.enable = true;

  # 指紋認証リーダー
  services.fprintd.enable = true;
  security.pam.services.login.fprintAuth = pkgs.lib.mkForce true; # ログイン時
  security.pam.services.gdm-fingerprint.fprintAuth = true;        # GDM時

  # ==========================================
  # 3. Networking & Localization
  # ==========================================
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Tokyo";

  i18n.defaultLocale = "ja_JP.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ja_JP.UTF-8";
    LC_IDENTIFICATION = "ja_JP.UTF-8";
    LC_MEASUREMENT = "ja_JP.UTF-8";
    LC_MONETARY = "ja_JP.UTF-8";
    LC_NAME = "ja_JP.UTF-8";
    LC_NUMERIC = "ja_JP.UTF-8";
    LC_PAPER = "ja_JP.UTF-8";
    LC_TELEPHONE = "ja_JP.UTF-8";
    LC_TIME = "ja_JP.UTF-8";
  };

  # 日本語入力 (IBus + Mozc -> fcitx5 + Mozc)
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
    ];
  };

  # ==========================================
  # 4. Desktop Environment (GNOME / Audio / Fonts)
  # ==========================================
  # X11 & GNOME
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  
  # キーボードレイアウト
  services.xserver.xkb = {
    layout = "jp";
    variant = "";
  };

  # XDG Desktop Portal
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    config.common.default = "gnome";
  };

  # Audio (Pipewire)
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Printing
  services.printing.enable = true;

  # Fonts
  fonts = {
    packages = with pkgs; [
      noto-fonts-cjk-serif
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      nerd-fonts.fira-code
      hackgen-font
    ];
    fontconfig = {
      defaultFonts = {
        monospace = [ "HackGen Console" "Noto Sans Mono CJK JP" ];
        sansSerif = [ "HackGen" "Noto Sans CJK JP" ];
        serif = [ "Noto Serif CJK JP" ];
      };
    };
  };

  # ==========================================
  # 5. User & Applications
  # ==========================================
  users.users.okshin = {
    isNormalUser = true;
    description = "okshin";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };

  # Default Apps & Env
  # programs.firefox.enable = true;
  programs.starship.enable = true;
   
  environment.sessionVariables = {
    # DEFAULT_BROWSER = "${pkgs.firefox}/bin/firefox";
    # BROWSER = "${pkgs.firefox}/bin/firefox";
  };
  environment.variables.EDITOR = "vim";
    

  # System Packages
  environment.systemPackages = with pkgs; [
    # Basic Tools
    vim
    wget
    git
    curl
    rclone      # Mount Google Drive 
    sops        # sops-nix

    # VSCode (Customized)
    (vscode-with-extensions.override {
      vscodeExtensions = with vscode-extensions; [
        bbenoist.nix                # Nix
        ms-python.python            # Python
        charliermarsh.ruff          # Ruff
        hashicorp.terraform         # Terraform
        ms-azuretools.vscode-docker # Docker
        eamodio.gitlens             # GitLens
        esbenp.prettier-vscode      # Prettier
        dracula-theme.theme-dracula # Theme
      ];
    })
  ];

  # sops-nix
  sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";

    # 復号に使う鍵（ホストのSSH秘密鍵）の場所
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # 1. 秘密情報の定義 ( /run/secrets/wifi_psk 等に展開される)
    secrets.wifi_ssid = {};
    secrets.wifi_psk = {};

    # 2. 設定ファイルのテンプレート作成
    # 復号された値を埋め込んで NetworkManager 用のファイルを生成
    templates."home-wifi.nmconnection" = {
      content = ''
        [connection]
        id=HomeWiFi-Sops
        type=wifi
        # interface-name=wlp0s20f3  # 必要ならインターフェース名を指定 (ip a で確認)、不要なら行削除

        [wifi]
        ssid=${config.sops.placeholder.wifi_ssid}
        mode=infrastructure

        [wifi-security]
        key-mgmt=wpa-psk
        auth-alg=open
        psk=${config.sops.placeholder.wifi_psk}

        [ipv4]
        method=auto

        [ipv6]
        method=auto
      '';
      # NetworkManager が読めるように権限設定
      mode = "0600";
    };
  };

  # 生成された設定ファイルを NetworkManager に認識させる
  # sopsが出力するファイルは /run/secrets/rendered/ にあるため、
  # システム起動時に NetworkManager の設定ディレクトリへリンクを貼る
  systemd.services."NetworkManager-pre" = {
    script = ''
      mkdir -p /etc/NetworkManager/system-connections/
      ln -sf ${config.sops.templates."home-wifi.nmconnection".path} /etc/NetworkManager/system-connections/home-wifi.nmconnection
      chmod 600 /etc/NetworkManager/system-connections/home-wifi.nmconnection
    '';
    # NetworkManager起動前に実行
    before = [ "NetworkManager.service" ];
    wantedBy = [ "multi-user.target" ];
  };

  # ==========================================
  # 6. Custom Services
  # ==========================================
  # Google Drive Auto-mount (Rclone)
  systemd.user.services.rclone-gdrive = {
    description = "rclone mount for Google Drive";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "default.target" ];
    path = [ "/run/wrappers" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.rclone}/bin/rclone mount gdrive: %h/gdrive --vfs-cache-mode full";
      ExecStop = "/run/wrappers/bin/fusermount -u %h/gdrive";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  # Keyboard Remap (xremap)
  services.xremap = {
    enable = true;
    withGnome = true;
    userName = "okshin";
    deviceNames = [ "AT Translated Set 2 keyboard" ]; 
    yamlConfig = ''
      modmap:
        - name: Onishi Layout (Base)
          remap:
            minus: slash
            # --- Upper ---
            w: l
            e: u
            r: f
            t: dot
            y: comma
            u: w
            i: r
            o: y
            # --- Middle ---
            a: e
            s: i
            d: a
            f: o
            g: minus
            h: k
            j: t
            k: n
            l: s
            semicolon: h
            # --- Lower ---
            b: semicolon
            n: g
            m: d
            comma: m
            dot: j
            slash: b
    '';
  };
}
