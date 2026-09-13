{ pkgs, config, ... }:

let
  # ===========================================================================
  # Firefox 系ブラウザ共有設定 (Firefox / Floorp で共用)
  # programs.floorp は programs.firefox と同一スキーマのため設定を流用できる
  # ===========================================================================

  sharedSettings = {
    # ▼ スペルチェックを完全に無効化
    # 0: 無効
    # 1: 複数行の入力ボックスのみ有効 (デフォルト)
    # 2: すべての入力ボックスで有効
    "layout.spellcheckDefault" = 0;
    "network.dns.disableIPv6" = true;
    "privacy.resistFingerprinting" = false;

    # ▼ 標準の翻訳機能を有効化
    "browser.translations.enable" = true;
    "browser.translations.panelShown" = true;
    "browser.translations.automaticallyPopup" = true;

    # ▼ フォント表示 (macOS 風の滑らかな描画)
    # ページが Arial 等を指定した場合の代替は fontconfig 側の alias に任せる
    # (configs/desktop.nix の localConf)。ここは総称ファミリの実体を決める。
    "font.default.x-western" = "sans-serif";
    "font.default.ja" = "sans-serif";
    "font.name-list.sans-serif.x-western" = "Inter, Noto Sans, Noto Sans CJK JP";
    "font.name-list.sans-serif.ja" = "Inter, Noto Sans CJK JP";
    "font.name-list.serif.x-western" = "Noto Serif, Noto Serif CJK JP";
    "font.name-list.serif.ja" = "Noto Serif CJK JP";
    "font.name-list.monospace.x-western" = "HackGen Console, Noto Sans Mono CJK JP";
    "font.name-list.monospace.ja" = "HackGen Console, Noto Sans Mono CJK JP";
    # グリフを整数ピクセルに丸めず配置する (macOS のような字間の均一さ)
    "gfx.text.subpixel-position.force-enabled" = true;
    # fontconfig の代替チェーンを深くたどる (既定 3 だと alias が届かないことがある)
    "gfx.font_rendering.fontconfig.max_generic_substitutions" = 127;

    # ▼ 新しいタブページのスポンサー広告を無効化
    "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
    "browser.newtabpage.activity-stream.showSponsored" = false;
  };

  # ポリシー設定 (企業向けの管理機能を使ってテレメトリ等を強制オフにする)
  sharedPolicies = {
    DisableTelemetry = true;
    DisableFirefoxStudies = true;
    EnableTrackingProtection = {
      Value = true;
      Locked = true;
    };
    DisablePocket = true;
    DisableFirefoxAccounts = false; # Syncを使いたい場合は false
    DisableAccounts = false;
    DisableAppUpdate = true; # Nixで管理するため

    # "New Tab" ページの広告などを消す
    FirefoxHome = {
      Search = true;
      Pocket = false;
      Snippets = false;
      TopSites = true;
      Highlights = false;
      SponsoredPocket = false;
      SponsoredTopSites = false;
    };
    Preferences = {
      "media.hardwaremediakeys.enabled" = false;
    };
  };
in
{
  # ===========================================================================
  # Web Browser Configuration
  # ===========================================================================
  # Firefox: 既定ブラウザではなく、Floorp が壊れたとき用のフォールバック。
  # Floorp は Firefox ESR に追従するフォークで、上流の更新が遅れたり
  # プロファイル移行に失敗したりしうるため、同じ sharedSettings /
  # sharedPolicies を適用した素の Firefox を常備しておく。
  # 常用側の指定（BROWSER / xdg.mimeApps / autostart / ワークスペース割当）は
  # すべて Floorp のみを指しており、Firefox が既定に戻ることはない。
  programs.firefox = {
    enable = true;
    # プロファイルを XDG パス (~/.config/mozilla/firefox) に配置
    configPath = "${config.xdg.configHome}/mozilla/firefox";
    # 1Password連携
    nativeMessagingHosts = [ pkgs._1password-gui ];
    profiles.default = {
      id = 0;
      name = "default";
      isDefault = true;
      settings = sharedSettings;
    };
    policies = sharedPolicies;
  };

  # Floorp (Firefox フォーク): こちらが常用の既定ブラウザ。
  # programs.floorp は programs.firefox と同一スキーマなので設定を流用している。
  programs.floorp = {
    enable = true;
    # 1Password連携
    nativeMessagingHosts = [ pkgs._1password-gui ];
    profiles.default = {
      id = 0;
      name = "default";
      isDefault = true;
      settings = sharedSettings;
    };
    policies = sharedPolicies;
  };
}
