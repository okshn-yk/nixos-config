# ChatGPT デスクトップアプリ（OpenAI 公式 Linux 版 .deb の再パッケージ）
#
# nixpkgs の `chatgpt` は macOS 専用（platforms = darwin）のため自前で持つ。
# 中身は Electron ベースのクローズドソースバイナリ一式（ChatGPT / Work / Codex 統合）。
# .deb の postinst は apt リポジトリ登録と AppArmor プロファイル読み込みだけなので
# NixOS では何も再現しない。chrome-sandbox は同梱されず user namespace で動く。
#
# 引込み元: hm/apps.nix
# 更新: CLAUDE.md の「自前パッケージ (pkgs/)」節の手順で version / hash を差し替える。
#   アプリ内の自動更新は Nix ストアが読み取り専用なので効かない。
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  bubblewrap,
  coreutils,
  dpkg,
  makeShellWrapper,
  perl,
  wrapGAppsHook3,
  gsettings-desktop-schemas,
  xdg-utils,

  # ELF の NEEDED に現れるもの（patchelf --print-needed で実測）
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libgbm,
  libusb1,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nspr,
  nss,
  pango,
  systemd,

  # NEEDED には無いが Chromium が実行時に dlopen するもの（nixpkgs の google-chrome に準拠）
  libdrm,
  libglvnd,
  libnotify,
  libpulseaudio,
  libsecret,
  libva,
  libxcursor,
  libxi,
  libxrender,
  libxscrnsaver,
  libxshmfence,
  libxtst,
  pipewire,
  vulkan-loader,
  wayland,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "chatgpt";
  version = "26.908.40834";

  # apt リポジトリの pool 配下は版付きで再現可能（latest/ の URL は中身が差し替わる）
  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${finalAttrs.version}_amd64.deb";
    hash = "sha256-2je457zvquoBnEeMrL5sc+4d3RXg4euzx+8KQt2BisI=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeShellWrapper
    perl
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gsettings-desktop-schemas
    gtk3
    libgbm
    libusb1
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
    stdenv.cc.cc.lib # libstdc++ / libgcc_s
    systemd # libudev
  ];

  # LD_LIBRARY_PATH ではなく RUNPATH に入れる。環境変数で渡すと、アプリ内ターミナル
  # （node-pty）や Codex が起動する子プロセスにまで漏れて別バイナリのリンクを乱すため。
  runtimeDependencies = map lib.getLib [
    libdrm
    libglvnd
    libnotify
    libpulseaudio
    libsecret
    libva
    libxcursor
    libxi
    libxrender
    libxscrnsaver
    libxshmfence
    libxtst
    pipewire
    systemd
    vulkan-loader
    wayland
  ];

  autoPatchelfIgnoreMissingDeps = [
    # Qt テーマ連携用の shim。--ui-toolkit=qt 指定時のみ dlopen され、無ければ GTK にフォールバック
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
    # node ネイティブモジュールの musl 版 prebuild。glibc 環境では選ばれない
    "libc.musl-x86_64.so.1"
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile "$src" | tar -x --no-same-owner --no-same-permissions
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;
  # 同梱の node / codex 等は署名・埋め込みデータを持つ可能性があり、strip で壊さない
  dontStrip = true;
  # ラッパーは gappsWrapperArgs を取り込んで自前で作る（ELF を二重に包まない）
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/share/applications $out/share/icons/hicolor/1024x1024/apps
    cp -a usr/lib/chatgpt $out/lib/chatgpt

    # 同梱の Vulkan ローダーは NixOS の ICD（/run/opengl-driver）を見つけられないので差し替える
    rm $out/lib/chatgpt/libvulkan.so.1
    ln -s ${lib.getLib vulkan-loader}/lib/libvulkan.so.1 $out/lib/chatgpt/libvulkan.so.1

    # この Electron は process.report.getReport() を呼ぶとメインスレッドでも Worker でも
    # SIGILL で落ちる（ELECTRON_RUN_AS_NODE=1 で実測。同梱の単体 node では落ちない）。
    # app.asar 内の detect-libc は libc 判定を
    #   (1) /proc/self/exe 先頭 2048 バイト内の PT_INTERP
    #   (2) /usr/bin/ldd の中身
    #   (3) process.report.getReport()
    #   (4) getconf / ldd --version の出力
    # の順に試す。patchelf がインタプリタを長いストアパスに差し替えると PT_INTERP が
    # ファイル末尾へ移って (1) が外れ、NixOS には (2) も無いため (3) に到達し、
    # @parcel/watcher を読み込む git ワーカーの起動時にアプリごと落ちる（Ubuntu 等では (1) で確定する）。
    # 呼び出しを同じ長さの空オブジェクト式に置き換えて (4) へ進ませる。asar はヘッダに
    # 各ファイルのオフセットを持つのでバイト長は変えない。整合性検証の fuse は無効
    # （EnableEmbeddedAsarIntegrityValidation=0）なので書き換えても読み込める。
    # 件数が変わったら（上流の修正・detect-libc の更新）ビルドを止めて見直す。
    asar=$out/lib/chatgpt/resources/app.asar
    count=$(grep -a -o -F 'process.report.getReport()' "$asar" | wc -l)
    if [ "$count" -ne 1 ]; then
      echo "app.asar: process.report.getReport() が $count 件（想定は 1 件）。置換処理を見直すこと" >&2
      exit 1
    fi
    perl -0777 -pi -e 's|process\.report\.getReport\(\)|({}/*nixos:no getReport*/)|g' "$asar"

    cp usr/share/pixmaps/chatgpt.png $out/share/icons/hicolor/1024x1024/apps/chatgpt.png
    cp -a usr/share/metainfo $out/share/metainfo

    # MimeType は codex:// だけ残す。上流は http/https や CSV・Office 文書まで登録しており、
    # 既定アプリ未指定の型（home.nix の xdg.mimeApps に無いもの）を ChatGPT に奪われるため。
    # Exec は上流の "chatgpt"（PATH 解決）のまま触らない。GNOME Shell は読み込んだ .desktop を
    # 保持し、nixos-rebuild で /etc/profiles 配下が差し替わっても再読込しない（inotify は旧ストアの
    # ディレクトリを見続ける）。Exec をストアパスにすると、再ログインするまで旧ビルドが起動し続ける。
    substitute usr/share/applications/chatgpt.desktop $out/share/applications/chatgpt.desktop \
      --replace-fail "$(grep '^MimeType=' usr/share/applications/chatgpt.desktop)" \
        "MimeType=x-scheme-handler/codex;"

    # 同梱プラグインを書き込み可能な場所へ複製する起動前処理（理由はスクリプト冒頭のコメント）
    mkdir -p $out/libexec/chatgpt
    substitute ${./chatgpt-prepare-plugins.sh} $out/libexec/chatgpt/prepare-plugins.sh \
      --subst-var-by name "$(basename $out)" \
      --subst-var-by resources "$out/lib/chatgpt/resources" \
      --subst-var-by coreutils "${coreutils}"

    runHook postInstall
  '';

  # gappsWrapperArgs は preFixup で組み立てられるので、ラッパー生成は postFixup で行う。
  # NIXOS_OZONE_WL が立っている Wayland セッションだけネイティブ Wayland で起動する
  # （nixpkgs の Electron アプリと同じ慣習。未設定なら XWayland）。
  # wrapGAppsHook3 が makeWrapper をバイナリラッパーに差し替えるが、バイナリラッパーは
  # --add-flags の ''${...} を展開せず文字列のまま渡すため、シェルラッパーを明示する。
  postFixup = ''
    makeShellWrapper $out/lib/chatgpt/ChatGPT $out/bin/chatgpt \
      "''${gappsWrapperArgs[@]}" \
      --run ". $out/libexec/chatgpt/prepare-plugins.sh" \
      --suffix PATH : ${
        lib.makeBinPath [
          xdg-utils
          bubblewrap
        ]
      } \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
  '';

  meta = {
    description = "ChatGPT desktop app (ChatGPT, ChatGPT Work and Codex) from OpenAI";
    homepage = "https://chatgpt.com/download/linux";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "chatgpt";
  };
})
