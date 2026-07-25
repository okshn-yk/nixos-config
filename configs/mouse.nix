{ config, pkgs, ... }:
let
  cfgFormat = pkgs.formats.libconfig { };
  inherit (cfgFormat.lib) mkHex;
in
{
  # Bluetooth 接続だと起動時(graphical.target)に logid が先に立ち上がり、まだ HID++
  # 接続が確立していないため "Failed to add device after 5 tries" で諦めてしまう。
  # マウスが接続され logitech-hidpp-device ドライバが bind された時点で logid を
  # 再起動し、確実に設定を適用させる（スリープ復帰後の再接続にも有効）。
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="hidraw", DRIVERS=="logitech-hidpp-device", RUN+="${pkgs.systemd}/bin/systemctl --no-block restart logid.service"
  '';

  # === Solaar 移行 Phase 1（logiops と併存中）===
  # logiops は 2024-09-28 の v0.3.5 以降コード更新が無く（以後のコミットは docs のみ）、
  # 触覚フィードバック(HID++ feature HAPTIC 0x19B0)も未実装。MX Master 4 の触覚を
  # 使うため Solaar へ一本化する方針。Phase 1 では CLI 検証のみ行うため logiops は残す。
  #
  # hardware.logitech.wireless モジュールは使わない: Unifying レシーバ用の ltunify を
  # 巻き込むが、本機は Bluetooth 接続で不要なため、必要な 2 つだけを明示的に入れる。
  #
  # Phase 2 で rules.yaml によるボタン/ジェスチャー移植、Phase 3 で logiops 撤去。
  environment.systemPackages = [ pkgs.solaar ];

  # 非 root の solaar から hidraw / HID++ デバイスへアクセスするための udev ルール。
  # solaar 本体とは別派生に分離されている（pkgs.solaar.udev の再エクスポート）。
  services.udev.packages = [ pkgs.logitech-udev-rules ];

  # Logitech MX Master シリーズ（Bluetooth 接続）のボタンカスタマイズ。
  # MX Master 3 と MX Master 4 は標準ボタン（進む/戻る/ホイール切替/ジェスチャー系）の
  # CID を共有しているため、共通設定を両デバイスに適用する。
  # services.logiops が attrset を libconfig 形式へ変換し、logid.service（root）を起動する。
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
      enable = true;
      config = {
        inherit devices;
      };
    };
}
