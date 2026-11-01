{ pkgs, lib, ... }:

{
  # NSS 3.131.1でC1/C3/G3は削除済み。残るemSign G1も信頼しない。
  # GHSA-6q48-6c7w-9gw2。上流のルートストアからG1が消えたら削除する。
  security.pki.caCertificateBlacklist = [ "emSign Root CA - G1" ];

  # セキュリティ修正の一時差し替え。共有ライブラリのABI・出力名長を維持し、
  # ビルド用ツールまで再構築せず最終closureの参照を修正版へ置換する。
  # 上流nixpkgsの修正済み派生へ更新できたらsecurityFixesと共に撤去する。
  system.replaceDependencies.replacements =
    lib.concatMap
      (
        name:
        map (output: {
          oldDependency = pkgs.${name}.${output};
          newDependency = pkgs.securityFixes.${name}.${output};
        }) pkgs.${name}.outputs
      )
      [
        "brotli"
        "libsndfile"
        "libxml2_13"
        "cacert"
        "cups"
      ]
    ++ map (output: {
      oldDependency = pkgs.nodejs-slim_24.${output};
      newDependency = pkgs.securityFixes.nodejs.${output};
    }) pkgs.nodejs-slim_24.outputs
    ++
      lib.concatMap
        (
          name:
          map (output: {
            oldDependency = pkgs.python3Packages.${name}.${output};
            newDependency = pkgs.securityPython.${name}.${output};
          }) pkgs.python3Packages.${name}.outputs
        )
        [
          "brotli"
          "urllib3"
          "aiohttp"
          "yarl"
          "multidict"
          "gitpython"
          "certifi"
        ]
    ++ map (output: {
      oldDependency = pkgs.securityFixes.libjxl_08.original.${output};
      newDependency = pkgs.securityFixes.libjxl_08.${output};
    }) pkgs.securityFixes.libjxl_08.outputs
    # services.pipewire.alsa.support32Bit が i686 の pipewire → ffmpeg → freetype/curl を
    # 引き込むため、32ビット版も同じ修正へ差し替える（pkgsi686Linux にも overlay が効く）。
    ++
      lib.concatMap
        (
          name:
          map (output: {
            oldDependency = pkgs.pkgsi686Linux.${name}.${output};
            newDependency = pkgs.pkgsi686Linux.securityFixes.${name}.${output};
          }) pkgs.pkgsi686Linux.${name}.outputs
        )
        [
          "brotli"
          "libsndfile"
        ];

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
