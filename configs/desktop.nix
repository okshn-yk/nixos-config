{ config, pkgs, ... }:

{
  # Desktop Environment (GNOME / Audio / Fonts)
  
  # X11 & GNOME
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

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
    ];
  };

  # Fonts
  fonts = {
    packages = with pkgs; [
      noto-fonts-cjk-serif
      noto-fonts-cjk-sans
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
}
