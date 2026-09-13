{ pkgs, ... }:

{
  # Desktop Environment (GNOME / Audio / Fonts)

  # X11 & GNOME
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # GNOME Online Accounts は無効化。
  # Google Drive はブラウザ運用方針（configuration.nix 参照）のため不要で、
  # ログイン時の Google 再認証ポップアップも抑止する。
  services.gnome.gnome-online-accounts.enable = false;

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

  # Keyboard Layout (System)
  services.xserver.xkb = {
    layout = "jp";
    variant = "";
  };

  # Localization (Timezone / Locale)
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

  # IME (Fcitx5 + Mozc)
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
      catppuccin-fcitx5
    ];
  };

  # Fonts
  fonts = {
    packages = with pkgs; [
      noto-fonts # 欧文 Noto (Sans/Serif)。CJK 版だけだとラテン字形が来ない
      noto-fonts-cjk-serif
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      nerd-fonts.fira-code
      hackgen-font
      hackgen-nf-font
      inter # 本文用ラテン体。Helvetica/SF 系に近く Web の Arial 代替に使う
    ];
    fontconfig = {
      defaultFonts = {
        monospace = [
          "HackGen Console"
          "Noto Sans Mono CJK JP"
        ];
        # sans-serif に等幅の HackGen を置くと Web ページ（Google 検索等）が
        # 等幅で表示されて読みにくいため、プロポーショナル体を先頭にする
        sansSerif = [
          "Inter"
          "Noto Sans"
          "Noto Sans CJK JP"
        ];
        serif = [
          "Noto Serif"
          "Noto Serif CJK JP"
        ];
      };

      # macOS 風のレンダリング:
      # ヒンティングなし + グレースケール AA でアウトライン本来の字形を保つ
      # （輪郭がぼやけて見える場合は hinting.enable = true / style = "slight"）
      antialias = true;
      hinting.enable = false;
      subpixel.rgba = "none";

      # Web フォント指定でよく来る MS/Apple 系の名前を手持ちのフォントへ寄せる
      # （Google 検索は Arial 指定。alias が無いと defaultFonts へ落ちる）
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <alias binding="same">
            <family>Arial</family>
            <accept><family>Inter</family></accept>
          </alias>
          <alias binding="same">
            <family>Helvetica</family>
            <accept><family>Inter</family></accept>
          </alias>
          <alias binding="same">
            <family>Helvetica Neue</family>
            <accept><family>Inter</family></accept>
          </alias>
          <alias binding="same">
            <family>Roboto</family>
            <accept><family>Inter</family></accept>
          </alias>
          <alias binding="same">
            <family>Segoe UI</family>
            <accept><family>Inter</family></accept>
          </alias>
          <alias binding="same">
            <family>Times New Roman</family>
            <accept><family>Noto Serif</family></accept>
          </alias>
          <alias binding="same">
            <family>Courier New</family>
            <accept><family>HackGen Console</family></accept>
          </alias>
        </fontconfig>
      '';
    };
  };
}
