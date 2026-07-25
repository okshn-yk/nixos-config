{ pkgs, ... }:

{
  # ===========================================================================
  # Logitech MX Master 4（USB Bolt レシーバ 046d:C548 接続）
  #
  # 設定は Solaar に一本化している。旧 logiops(logid) は v0.3.5(2024-09-28) 以降
  # コード更新が無く（以後のコミットは docs のみ）、MX Master 4 の触覚フィードバック
  # (HID++ HAPTIC 0x19B0) も Action Ring の感圧ボタン (CID 0x01A0 "Haptic") も
  # 扱えないため撤去した。logid と Solaar は同じレシーバの hidraw を奪い合うので
  # 併存もできない。
  #
  # ボタン割り当て・ジェスチャー・DPI 等の実際の設定は hm/mouse.nix にある。
  #
  # 既知のハード事情: このレシーバ 046d:C548 は kernel 6.18.39 の hid-logitech-dj の
  # ID 表に無く（modules.alias の登録は hid_multitouch のみ）、hid-generic /
  # hid-multitouch が bind される。そのためレシーバは DJ モードに入らず、ペアリング
  # 済みデバイスごとの hidraw ノードも作られない（solaar show の Device path が None）。
  # Solaar は hidraw を直接叩くので実害は無いが、`DRIVERS=="logitech-hidpp-device"`
  # を条件にする udev ルールは発火しない点に注意。
  # ===========================================================================

  # Solaar 本体。hardware.logitech.wireless モジュールは使わない:
  # Unifying レシーバ用の ltunify を巻き込むが不要なため、必要なものだけを明示する。
  environment.systemPackages = [ pkgs.solaar ];

  # 非 root の solaar から hidraw / HID++ デバイスへアクセスするための udev ルール
  # （TAG+="uaccess" で ACL 付与）。solaar 本体とは別 output に分離されている。
  # pkgs.logitech-udev-rules ではなく上書き版の udev output を使い、本体と版を揃える。
  services.udev.packages = [ pkgs.solaar.udev ];

  # Solaar のルール（KeyPress 等）は /dev/uinput へ書き込んで入力を合成するため必須。
  # solaar の udev ルールにも uinput の uaccess 指定はあるが、モジュールのロードと
  # グループ整備はこのオプションが行う（ユーザーの uinput グループ所属は
  # configuration.nix 側で設定）。
  hardware.uinput.enable = true;
}
