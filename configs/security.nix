{ ... }:

{
  # ===========================================================================
  # Security Configuration
  # ===========================================================================

  # --- Firewall ---
  # 外部からの不正アクセスをブロック
  # アウトバウンド通信（ブラウジング、API通信等）には影響なし
  networking.firewall.enable = true;

  # --- Avahi (mDNS) ---
  # GNOME が間接的に avahi を有効化し、UDP 5353 を全インターフェースで公開する。
  # ネットワークプリンタ/mDNS を使わないため明示的に無効化し、攻撃面を縮小する。
  # 将来 mDNS が必要になったら enable = true + allowInterfaces で限定すること。
  services.avahi.enable = false;
}
