{
  config,
  pkgs,
  lib,
  username,
  hostName,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./configs/aws-config.nix
    ./configs/desktop.nix
    ./configs/dev-env.nix
    ./configs/laptop.nix
    ./configs/wifi.nix
    ./configs/keymap.nix
    ./configs/mouse.nix
    ./configs/ollama.nix
    ./configs/performance.nix
    ./configs/security.nix
  ];

  # ==========================================
  # System Core
  # ==========================================
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # AMD GPU スリープ復帰問題対策
  boot.kernelParams = [
    "mem_sleep_default=s2idle"
    "amd_pstate=active"
  ];
  hardware.graphics.enable = true;

  # Nix Settings
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # nix-community バイナリキャッシュ（ビルド時間短縮）
    substituters = [ "https://nix-community.cachix.org" ];
    trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # 非フリーパッケージ許可（ホワイトリスト方式）
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "vscode"
      "vscode-extension-ms-vscode-remote-remote-ssh"
      "vscode-extension-fill-labs-dependi"
      "slack"
      "obsidian"
      "1password"
      "1password-cli"
      "1password-gui"
      "terraform"
      "xmind"
      "google-chrome"
    ];

  # 一時的に許可するinsecureパッケージ
  # python3.13-ecdsa-0.19.2: CVE-2024-23342 (ECDSA P-256のタイミング攻撃)
  #   引き込み元: awscli2 の依存チェーン経由
  #   判断: ローカルCLI用途のみで、攻撃者が署名処理を外部計測する経路がないため許可
  #   削除条件: nixpkgs側で警告対象外になったら（python-ecdsa更新 or 代替実装移行時）
  #   見直しタイミング: `nix flake update` 実行後にこのエントリの要否を確認
  nixpkgs.config.permittedInsecurePackages = [
    "python3.13-ecdsa-0.19.2"
  ];

  # State Version
  system.stateVersion = "25.11";

  # Networking Core
  networking.hostName = hostName;
  networking.networkmanager.enable = true;

  # ==========================================
  # User & Global Settings
  # ==========================================
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  # Sops General Settings (Keys)
  sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  # ==========================================
  # Services (Others)
  # ==========================================
  # Google Drive はブラウザ(drive.google.com)で運用する。
  # 以前は rclone で ~/gdrive に FUSE マウントしていたが、ネット依存のFUSEが
  # 張られたままサスペンドすると読み込み中プロセスが D 状態で固着し、
  # プロセスのフリーズに失敗 → suspend-then-hibernate が失敗ループして
  # バッテリーを使い切る問題があったため自動マウントは廃止。
  # rclone コマンドと認証情報(~/.config/rclone)は手動同期用に残してある。

  # Rclone package (手動の同期/マウント用。自動マウントはしない)
  environment.systemPackages = with pkgs; [
    rclone
    wl-clipboard
  ];

  # --- Playwright互換: Chromeシンボリックリンク ---
  # PlaywrightはLinuxで /opt/google/chrome/chrome をハードコードで参照する。
  # NixOSではChromeがnix store配下にあるため、tmpfilesでシンボリックリンクを作成。
  systemd.tmpfiles.rules = [
    "d /opt/google/chrome 0755 root root -"
    "L+ /opt/google/chrome/chrome - - - - ${pkgs.google-chrome}/bin/google-chrome-stable"
  ];

  # --- Locate (ファイル検索高速化) ---
  # 毎日DBを更新し、locateコマンドで瞬時検索
  services.locate = {
    enable = true;
    package = pkgs.plocate;
    interval = "daily";
    prunePaths = [
      "/tmp"
      "/var/tmp"
      "/var/cache"
      "/var/lock"
      "/var/spool"
      "/nix/store"
      "/nix/var/log"
    ];
  };
}
