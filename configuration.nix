{
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
    ./configs/hardware-amd.nix
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
  # ESP は 1GB しかないため、世代が増えてもブートエントリで溢れさせない上限。
  # 実際は週次 GC で世代が抑えられているが、GC が止まった場合の保険。
  boot.loader.systemd-boot.configurationLimit = 10;

  # 起動時に /tmp を掃除し、前回セッションの残骸を持ち越さない
  boot.tmp.cleanOnBoot = true;

  # AMD 固有のカーネルパラメータ（amd_pstate 等）は configs/hardware-amd.nix に分離した。

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
  # ストア内の重複ファイルをハードリンク化してディスクを節約する。
  # GC が「不要な世代を消す」のに対し、こちらは「残す世代の中身を重複排除する」
  # 役割で、両者は補完関係。ルートは 438G 中 203G 使用のため効果が見込める。
  nix.optimise.automatic = true;

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
  # python3.14-ecdsa-0.19.2: CVE-2024-23342 (ECDSA P-256のタイミング攻撃)
  #   引き込み元: awscli2 の依存チェーン経由
  #   判断: ローカルCLI用途のみで、攻撃者が署名処理を外部計測する経路がないため許可
  #   削除条件: nixpkgs側で警告対象外になったら（python-ecdsa更新 or 代替実装移行時）
  #   見直しタイミング: `nix flake update` 実行後にこのエントリの要否を確認
  #   （nixpkgs更新で既定Pythonが 3.13→3.14 に上がったためバージョン名を追随）
  nixpkgs.config.permittedInsecurePackages = [
    "python3.14-ecdsa-0.19.2"
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
      # Solaar のルールが /dev/uinput へ入力を合成するため。
      # hardware.uinput.enable（configs/mouse.nix）が GROUP="uinput" を設定する。
      "uinput"
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

  # --- GPaste (GNOME 用クリップボードマネージャ) ---
  # これまで hm/apps.nix で systemd user unit を手書きして起動していたが、
  # 上流オプションが D-Bus activation と gsettings schema まで面倒を見るため置き換えた。
  # キーバインド（履歴呼び出し）は hm/apps.nix の dconf 側に残る。
  programs.gpaste.enable = true;

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
