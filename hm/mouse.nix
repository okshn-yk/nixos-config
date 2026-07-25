{ pkgs, ... }:

let
  # ===========================================================================
  # Solaar によるマウス設定（logiops から移行）
  #
  # Solaar のルールは HID++ 通知に対して発火する。通常の HID 出力を出すボタンは
  # まず「diverted」に設定して HID++ 通知を出すよう変えないとルールが動かない。
  # その diversion 設定はデバイス側＋Solaar の ~/.config/solaar/config.yaml に
  # 永続化されるため、下の solaar-apply-settings を一度実行して設定する。
  #
  # 実機（MX Master 4, WPID B042）の `solaar show` で確認したキー名と CID:
  #   Back Button          0x0053  divertable
  #   Forward Button       0x0056  divertable
  #   Smart Shift          0x00C4  divertable  （ホイール後ろの切替スイッチ）
  #   Mouse Gesture Button 0x00C3  divertable, raw_xy （親指の大きなボタン）
  #   Haptic               0x01A0  divertable, raw_xy （Action Ring の感圧部）
  # ===========================================================================

  # divert-keys の値: Regular=0 / Diverted=1 / Mouse Gestures=2 / Sliding DPI=3
  #
  # Mouse Gesture Button と Haptic は「押しながらの移動」を取りたいので
  # Mouse Gestures(2)、残りは単純な押下を取りたいので Diverted(1)。
  #
  # DPI と SmartShift は旧 logiops 設定と同じ値に揃える
  # （dpi=1500 / ラチェット速度=30 / トルク=50）。
  # 高解像度スクロールは MX Master 4 では 1 ノッチの移動量を MX Master 3 に
  # 近づけるため無効のままにする（scroll-wheel-resolution=False）。
  applySettings = pkgs.writeShellApplication {
    name = "solaar-apply-settings";
    runtimeInputs = [ pkgs.solaar ];
    text = ''
      dev="MX Master 4"
      conf="''${XDG_CONFIG_HOME:-$HOME/.config}/solaar/config.yaml"

      # デーモンが動いたまま CLI がレシーバを触ると競合しうるうえ、
      # 設定はデーモンの起動時／デバイス接続時に config.yaml から読み込まれるため、
      # 「止める → 設定 → 検証 → 起動」の順で行う。
      echo "Stopping solaar daemon ..."
      systemctl --user stop solaar.service || true

      # 選択肢型の設定は必ず「名前」で指定すること。
      # solaar の select_choice() は裸の整数を渡すと choices[N-1] を引くが、
      # NamedInts の [] は添字ではなく「値」による参照なので、N を渡すと
      # 値 N-1 の選択肢が選ばれて 1 つずれる（Diverted のつもりが Regular 等）。
      # 名前での完全一致が最優先で評価されるため、名前指定なら曖昧さがない。
      echo "Applying Solaar settings to '$dev' ..."

      # ボタンの diversion（これが無いとルールは一切発火しない）
      solaar config "$dev" divert-keys 'Back Button' 'Diverted'
      solaar config "$dev" divert-keys 'Forward Button' 'Diverted'
      solaar config "$dev" divert-keys 'Smart Shift' 'Diverted'
      solaar config "$dev" divert-keys 'Mouse Gesture Button' 'Mouse Gestures'
      solaar config "$dev" divert-keys 'Haptic' 'Mouse Gestures'

      # 旧 logiops 相当のデバイス設定。
      # scroll-ratchet は smart-shift より先に設定すること: Freespinning のままだと
      # smart-shift の read() が常に MIN_VALUE(1) を返し、検証が通らない。
      solaar config "$dev" dpi 1500
      solaar config "$dev" scroll-ratchet 'Ratcheted'
      solaar config "$dev" smart-shift 30 # ラチェット速度（旧 logiops threshold）
      solaar config "$dev" scroll-ratchet-torque 50
      solaar config "$dev" hires-smooth-resolution false

      # --- 検証 ---
      # 値の指定方法を間違えると黙って別の値が入るため、必ず突き合わせる。
      echo
      echo "Verifying ..."
      failed=0

      # (1) デバイスから読み戻せる設定
      actual=$(solaar config "$dev" 2>/dev/null)
      check() {
        if grep -qF "$1" <<<"$actual"; then
          echo "  OK   $1"
        else
          echo "  FAIL $1"
          echo "       actual: $(grep -E "^''${1%% =*} =" <<<"$actual" || echo '(not found)')"
          failed=1
        fi
      }
      check "dpi = 1500"
      check "scroll-ratchet = Ratcheted"
      check "smart-shift = 30"
      check "scroll-ratchet-torque = 50"
      check "hires-smooth-resolution = False"

      # (2) divert-keys は config.yaml で検証する。
      # DivertKeys.read() はデバイスの DIVERTED フラグしか見ないため
      # Regular(0) と Diverted(1) しか返せず、Mouse Gestures(2) は必ず
      # Diverted に見える。「どのキーをジェスチャー起点にするか」は
      # Solaar 側だけが持つ状態で、config.yaml が唯一の正となる。
      dk=$(grep -oE 'divert-keys: \{[^}]*\}' "$conf" 2>/dev/null || echo "")
      check_divert() {
        # $1=CID $2=期待値 $3=表示名
        if grep -qE "(\{|, )$1: $2(,|\})" <<<"$dk"; then
          echo "  OK   divert-keys $3 ($1) = $2"
        else
          echo "  FAIL divert-keys $3 ($1) = $2"
          echo "       actual: $dk"
          failed=1
        fi
      }
      check_divert 83 1 'Back Button'
      check_divert 86 1 'Forward Button'
      check_divert 196 1 'Smart Shift'
      check_divert 195 2 'Mouse Gesture Button'
      check_divert 416 2 'Haptic'

      echo
      echo "Starting solaar daemon ..."
      systemctl --user start solaar.service

      echo
      if [ "$failed" -ne 0 ]; then
        echo "!! 一部の設定が意図した値になっていません。上の FAIL を確認してください。"
        exit 1
      fi
      echo "全ての設定が意図どおり適用されました。"
    '';
  };

  # ---------------------------------------------------------------------------
  # ルール定義
  #
  # KeyPress は Linux の KEY_* ではなく X11 keysym 名を取る（logiops からの差分）。
  #   KEY_LEFTCTRL -> Control_L / KEY_LEFTMETA -> Super_L
  #   KEY_PAGEUP   -> Page_Up   / KEY_PAGEDOWN -> Page_Down
  #   KEY_BACK     -> XF86_Back （アンダースコア付きが正しい名前）
  #
  # Mouse Gestures に設定したボタンは押下〜移動〜離すまでを 1 つの
  # MouseGesture 通知にまとめる。第 1 引数にキー名を書くと「どのボタンで
  # 開始したか」を判定でき、方向を書かなければ「動かさずに押しただけ」に
  # マッチする。
  #
  # Haptic ボタンには Mouse Gesture Button と同じ動作を割り当てる（ユーザー要望）。
  # 両方に同じ挙動を持たせるため Or でまとめている。
  # ---------------------------------------------------------------------------
  rulesYaml = ''
    %YAML 1.3
    ---
    # 進む（親指・前側）→ Ctrl+R
    - Key: [Forward Button, pressed]
    - KeyPress: [Control_L, r]
    ...
    ---
    # 戻る（親指・後側）→ Back
    - Key: [Back Button, pressed]
    - KeyPress: XF86_Back
    ...
    ---
    # ホイール切り替えスイッチ（ホイール後ろ）→ Ctrl+W
    - Key: [Smart Shift, pressed]
    - KeyPress: [Control_L, w]
    ...
    ---
    # ジェスチャー: 押すだけ（動かさない）→ GNOME アクティビティ画面
    - Or:
      - MouseGesture: [Mouse Gesture Button]
      - MouseGesture: [Haptic]
    - KeyPress: Super_L
    ...
    ---
    # ジェスチャー: 上 → ウィンドウ最大化
    - Or:
      - MouseGesture: [Mouse Gesture Button, Mouse Up]
      - MouseGesture: [Haptic, Mouse Up]
    - KeyPress: [Super_L, Up]
    ...
    ---
    # ジェスチャー: 下 → 最小化 / 復帰
    - Or:
      - MouseGesture: [Mouse Gesture Button, Mouse Down]
      - MouseGesture: [Haptic, Mouse Down]
    - KeyPress: [Super_L, Down]
    ...
    ---
    # ジェスチャー: 左 → 前のワークスペース
    - Or:
      - MouseGesture: [Mouse Gesture Button, Mouse Left]
      - MouseGesture: [Haptic, Mouse Left]
    - KeyPress: [Super_L, Page_Up]
    ...
    ---
    # ジェスチャー: 右 → 次のワークスペース
    - Or:
      - MouseGesture: [Mouse Gesture Button, Mouse Right]
      - MouseGesture: [Haptic, Mouse Right]
    - KeyPress: [Super_L, Page_Down]
    ...
  '';
in
{
  home.packages = [
    pkgs.solaar
    applySettings
  ];

  # ルールファイルは宣言的に管理する。
  # 注意: これは読み取り専用シンボリックリンクになるため、Solaar GUI の
  # 「Rule Editor」からの編集は保存できない。ルールの変更はこのファイルを
  # 編集して nixos-rebuild switch する。
  xdg.configFile."solaar/rules.yaml".text = rulesYaml;

  # Solaar デーモン。ルール処理はデーモンが常駐していないと動かない。
  # --window=hide でウィンドウを出さずトレイのみで起動する。
  systemd.user.services.solaar = {
    Unit = {
      Description = "Solaar (Logitech device manager) daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.solaar}/bin/solaar --window=hide";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
