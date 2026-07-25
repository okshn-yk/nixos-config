{ config, pkgs, ... }:
let
  cfgFormat = pkgs.formats.libconfig { };
  inherit (cfgFormat.lib) mkHex;

in
{
  # === Solaar 移行 Phase 2（logiops から切り替え）===
  # logiops は v0.3.5(2024-09-28) 以降コード更新が無く（以後のコミットは docs のみ）、
  # MX Master 4 の触覚フィードバック(HID++ HAPTIC 0x19B0)も Action Ring の感圧ボタン
  # (CID 0x01A0 "Haptic") も扱えない。Solaar は両方を扱えるため一本化する。
  #
  # logid と Solaar は同じレシーバの hidraw を奪い合うため併存できない。
  # ボタン/ジェスチャーの割り当ては hm/mouse.nix の Solaar ルールへ移植済み。
  #
  # hardware.logitech.wireless モジュールは使わない: Unifying レシーバ用の ltunify を
  # 巻き込むが不要なため、必要なものだけを明示的に入れる。
  environment.systemPackages = [ pkgs.solaar ];

  # 非 root の solaar から hidraw / HID++ デバイスへアクセスするための udev ルール
  # （TAG+="uaccess" で ACL 付与）。solaar 本体とは別 output に分離されている。
  # pkgs.logitech-udev-rules ではなく上書き版の udev output を使い、本体と版を揃える。
  services.udev.packages = [ pkgs.solaar.udev ];

  # Solaar のルール（KeyPress 等）は /dev/uinput へ書き込んで入力を合成するため必須。
  # solaar の udev ルールにも uinput の uaccess 指定はあるが、モジュールのロードと
  # グループ整備はこのオプションが行う。
  hardware.uinput.enable = true;

  # --- 以下は旧 logiops 設定（無効化済み・Phase 3 で削除予定）---
  # Solaar と logid はレシーバの hidraw を奪い合うため、enable = false で停止させる。
  # Solaar 側の動作が安定するまでは切り戻せるよう設定本体を残しておく。
  # 切り戻す場合は enable = true に戻し、hm/mouse.nix の Solaar サービスを止める。
  #
  # 旧 udev ルール（削除済み）についての記録:
  #   ACTION=="add", SUBSYSTEM=="hidraw", DRIVERS=="logitech-hidpp-device", RUN+=...
  #   で logid を再起動していたが、実機のレシーバ 046d:C548 は kernel 6.18.39 の
  #   hid-logitech-dj の ID 表に無く hid-generic/hid-multitouch が bind されるため、
  #   この条件は元から発火していなかった（コメントの「Bluetooth 接続」も誤りで、
  #   実際は USB Bolt レシーバ接続）。
  services.logiops =
    let
      # --- 両機種共通の挙動 ---
      commonDeviceSettings = {
        # --- DPI（カーソル速度）---
        dpi = 1500; # 200〜4000。お好みで調整

        # --- SmartShift（ラチェット/フリースピン自動切替）---
        smartshift = {
          on = true;
          threshold = 30; # 値が小さいほど軽い力でフリースピンへ移行
          torque = 50;
        };

        # --- 高解像度スクロール ---
        hiresscroll = {
          hires = true;
          invert = false;
          target = false;
        };

        buttons = [
          # 進む（親指・前側）→ Ctrl+R
          {
            cid = mkHex "0x56";
            action = {
              type = "Keypress";
              keys = [
                "KEY_LEFTCTRL"
                "KEY_R"
              ];
            };
          }
          # 戻る（親指・後側）
          {
            cid = mkHex "0x53";
            action = {
              type = "Keypress";
              keys = [ "KEY_BACK" ];
            };
          }
          # ホイール切り替えスイッチ（ホイール後ろ）→ Ctrl+W
          {
            cid = mkHex "0xc4";
            action = {
              type = "Keypress";
              keys = [
                "KEY_LEFTCTRL"
                "KEY_W"
              ];
            };
          }
          # ジェスチャーボタン（親指の大きなボタン）。
          # MX Master 4 では同位置が Action Ring になるが、まずは同じ CID 0xc3 /
          # 同じ Gestures 設定を流用し、実機で動作するか確認する。
          {
            cid = mkHex "0xc3";
            action = {
              type = "Gestures";
              gestures = [
                # 押すだけ（動かさない）: GNOME アクティビティ画面
                {
                  direction = "None";
                  mode = "OnRelease";
                  action = {
                    type = "Keypress";
                    keys = [ "KEY_LEFTMETA" ];
                  };
                }
                # 上: ウィンドウ最大化
                {
                  direction = "Up";
                  mode = "OnRelease";
                  action = {
                    type = "Keypress";
                    keys = [
                      "KEY_LEFTMETA"
                      "KEY_UP"
                    ];
                  };
                }
                # 下: 最小化 / 復帰
                {
                  direction = "Down";
                  mode = "OnRelease";
                  action = {
                    type = "Keypress";
                    keys = [
                      "KEY_LEFTMETA"
                      "KEY_DOWN"
                    ];
                  };
                }
                # 左: 前のワークスペース
                {
                  direction = "Left";
                  mode = "OnRelease";
                  action = {
                    type = "Keypress";
                    keys = [
                      "KEY_LEFTMETA"
                      "KEY_PAGEUP"
                    ];
                  };
                }
                # 右: 次のワークスペース
                {
                  direction = "Right";
                  mode = "OnRelease";
                  action = {
                    type = "Keypress";
                    keys = [
                      "KEY_LEFTMETA"
                      "KEY_PAGEDOWN"
                    ];
                  };
                }
              ];
            };
          }
        ];
      };

      # `sudo logid -v` / journalctl -u logid.service で確認した実機の認識名。
      devices = [
        # MX Master 3 は従来どおり高解像度スクロールを使用する。
        (
          commonDeviceSettings
          // {
            name = "Wireless Mouse MX Master 3";
          }
        )

        # MX Master 4 は1ノッチ当たりの移動量をMX Master 3へ近づけるため、
        # 高解像度スクロールを無効化して通常のホイールイベントを使用する。
        (
          commonDeviceSettings
          // {
            name = "MX Master 4";
            hiresscroll = commonDeviceSettings.hiresscroll // {
              hires = false;
            };
          }
        )
      ];
    in
    {
      # Solaar へ移行したため無効化（Phase 3 でこのブロックごと削除する）
      enable = false;
      config = {
        inherit devices;
      };
    };
}
