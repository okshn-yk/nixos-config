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

  # Logitech MX Master 3（Bluetooth 接続）のボタンカスタマイズ。
  # services.logiops が attrset を libconfig 形式へ変換し、logid.service（root）を起動する。
  services.logiops = {
    enable = true;
    config = {
      devices = [
        {
          # `sudo logid -v` で確認した実機の認識名（Bluetooth 接続）。
          name = "Wireless Mouse MX Master 3";

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
            # ジェスチャーボタン（親指の大きなボタン）
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
        }
      ];
    };
  };
}
