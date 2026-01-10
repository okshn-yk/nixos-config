{ pkgs, ... }:

{
  # ===========================================================================
  # Web Browser Configuration
  # ===========================================================================

  programs.firefox = {
    enable = true;
    # 1Password連携
    nativeMessagingHosts = [ pkgs._1password-gui ];
    profiles.default = {
      id = 0;
      name = "default";
      isDefault = true;

      settings = {
        # ▼ スペルチェックを完全に無効化
        # 0: 無効
        # 1: 複数行の入力ボックスのみ有効 (デフォルト)
        # 2: すべての入力ボックスで有効
        "layout.spellcheckDefault" = 0;
        "network.dns.disableIPv6" = true;
        "privacy.resistFingerprinting" = false;

        # ▼ Firefox標準の翻訳機能を有効化
        "browser.translations.enable" = true;
        "browser.translations.panelShown" = true;
        "browser.translations.automaticallyPopup" = true;

        # ▼ 非同期クリップボード操作の許可（拡張機能の動作安定化）
        "dom.events.asyncClipboard.readText" = true;
        "dom.events.testing.asyncClipboard" = true;
      };
    };
    # ポリシー設定 (企業向けの管理機能を使ってテレメトリ等を強制オフにする)
    policies = {
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
  };
}
