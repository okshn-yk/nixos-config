# 2026-10-24 の依存CVE監査に基づく一時的な修正。
# 複数モジュールから使う共有ライブラリ・ランタイムなのでoverlayで統一する。
# 解除条件: 各修正版と同じ修正がnixpkgsに入り、closureの再監査が通ること。
final: prev:
let
  githubSource =
    owner: repo: tag: hash:
    prev.fetchFromGitHub {
      inherit
        owner
        repo
        tag
        hash
        ;
    };
in
{
  # curl / Node / Python等: CVE-2026-111497。
  securityFixes.brotli = prev.brotli.overrideAttrs {
    version = "1.2.1";
    src = githubSource "google" "brotli" "v1.2.1" "sha256-llY72cYffDv0ugsH0p89xIPEbElV4L8u7U/Fe8hT3gI=";
  };

  # CLI / MCP / 回帰テスト: 2026-10-21のNode 24セキュリティリリース。
  # 24.22.1はbrotli 1.2.1で追加された定数を参照するため、修正版brotliでビルドする。
  # brotliはv24.nixではなく内側のnodejs.nixの引数なので、callPackage経由で差し込む。
  securityFixes.nodejs =
    (prev.nodejs-slim_24.override {
      callPackage = fn: args: prev.callPackage fn ({ brotli = final.securityFixes.brotli; } // args);
    }).overrideAttrs
      (old: {
        version = "24.22.1";
        src = prev.fetchurl {
          url = "https://nodejs.org/dist/v24.22.1/node-v24.22.1.tar.xz";
          sha256 = "4f5379796280cdaeb0c2f358fd04b6a16cc4fb7dfa83b5a8c91a9d963b435231";
        };
        passthru = (old.passthru or { }) // {
          tests = (old.passthru.tests or { }) // {
            version = prev.testers.testVersion {
              package = final.securityFixes.nodejs;
              version = "v24.22.1";
            };
          };
        };
      });

  # Slackの同梱Electronも更新する（システムElectronだけでは更新されない）。
  slack = prev.slack.overrideAttrs {
    version = "4.52.182";
    src = prev.fetchurl {
      url = "https://downloads.slack-edge.com/desktop-releases/linux/x64/4.52.182/slack-desktop-4.52.182-amd64.deb";
      hash = "sha256-Vo+edqFDperWlkUZLjgTGJf4WvdkXX2BiX82/arI9wA=";
    };
  };

  # 音声デコーダ: CVE-2026-37555。上流PR #1123の実際の修正コミット。
  securityFixes.libsndfile = prev.libsndfile.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (prev.fetchurl {
        url = "https://github.com/libsndfile/libsndfile/commit/cdadf9a65fdc1f28da9d235eb443d5f5e57010d2.patch";
        hash = "sha256-GYKM/cF7gPE8jR/Mi4KOpcMoBx2RFxxtgPlKLhSZtxk=";
      })
    ];
  });

  # 互換ABIを必要とする利用元向け。CVE-2026-6732。
  securityFixes.libxml2_13 = prev.libxml2_13.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (prev.fetchurl {
        url = "https://github.com/GNOME/libxml2/commit/226b560837b90dea9b14431eca6e6fda8fb01ab4.patch";
        hash = "sha256-kbsuJKwWHuWlYFPW2zj0PANDuGxEMFiCrs/sulaSRCk=";
      })
    ];
  });

  # Python certifiの既定CA。NixOS用の追加blacklistはconfigs/security.nixで管理。
  securityFixes.cacert = prev.cacert.override {
    blacklist = [
      "emSign Root CA - G1"
      # NixOS標準CAと同じCVE-2026-111943対策を、certifiの既定CAにも適用。
      "Comodo AAA Services root"
    ];
  };

  # 印刷サービス: CVE-2026-55480 / 61702 / 55453 / 55467等。
  # 既存のUTF-32・大文字小文字判定パッチは2.4.20に取り込み済み。
  securityFixes.cups = prev.cups.overrideAttrs {
    version = "2.4.20";
    src = prev.fetchurl {
      url = "https://github.com/OpenPrinting/cups/releases/download/v2.4.20/cups-2.4.20-source.tar.gz";
      hash = "sha256-q02c1/PlgGAJHSsklyIj1kAWdfEcSbZav09u8x3qIv8=";
    };
    patches = [ ];
  };

  # Playwright WebKitのlibjxl 0.8 ABIを維持したバックポート。
  # CVE-2024-11498のヘッダ挿入位置のみ0.8.2に合わせ、修正ロジックは上流と同一。
  securityFixes.libjxl_08 =
    let
      original = prev.lib.findFirst (
        p: (p.pname or "") == "libjxl"
      ) (throw "Playwright WebKitのlibjxl依存を再確認すること") prev.playwright-driver.components.webkit.buildInputs;
    in
    assert original.version == "0.8.2";
    original.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ./patches/libjxl-0.8.2-CVE-2024-11498.patch
        (prev.fetchurl {
          # CVE-2024-11403: JPEG再圧縮時のHuffmanテーブル境界。
          url = "https://github.com/libjxl/libjxl/commit/9cc451b91b74ba470fd72bd48c121e9f33d24c99.patch";
          hash = "sha256-U+Bt611mGoMnXm1h50a8+9N4UHRZG+QCq+3iPavGYAs=";
        })
      ];
      passthru = (old.passthru or { }) // {
        inherit original;
      };
    });

  # Checkov等の実行時依存。ビルド用Sphinx/LLVM等への波及を避け、
  # 独立scopeで修正版をテストした後、最終closureへ差し替える。
  securityPython = prev.python3Packages.overrideScope (
    pyFinal: pyPrev: {
      brotli = pyPrev.brotli.override { brotli = final.securityFixes.brotli; };
      urllib3 = pyPrev.urllib3.overridePythonAttrs {
        version = "2.8.0";
        src =
          githubSource "urllib3" "urllib3" "2.8.0"
            "sha256-/EABIEAZDr5936K5Utjlx0nsGHWsHoimqC6dGDuOJAo=";
      };
      aiohttp = pyPrev.aiohttp.overridePythonAttrs (old: {
        version = "3.14.4";
        src =
          githubSource "aio-libs" "aiohttp" "v3.14.4"
            "sha256-ArlEDpuUQJ6Ueup7tL9H1Nd3/TgajMaHtg4pJiSGOy8=";
        # nixpkgsのCython 3.3.0対応パッチ（aiohttp#13520）は3.14.4に取り込み済み。
        patches = [ ];
        # 3.14.4でpytest設定がsetup.cfgからpytest.iniへ移ったため、置換先を合わせる。
        postPatch =
          prev.lib.replaceStrings
            [ "substituteInPlace setup.cfg" ]
            [
              "substituteInPlace pytest.ini"
            ]
            old.postPatch
          # Cython 3.3.0がFinal注釈とpxdのcdef宣言の衝突でクラッシュする。上流masterと同じく注釈を外す。
          + ''
            substituteInPlace aiohttp/_websocket/reader_py.py \
              --replace-fail "MSG_SIZE_OVERHEAD: Final[int] = 128" "MSG_SIZE_OVERHEAD = 128"
          '';
      });
      # aiohttp 3.14.4はyarl 1.25.1で追加されたquery_to_pairsを使う（下限 >=1.25.1）。
      yarl = pyPrev.yarl.overridePythonAttrs {
        version = "1.25.1";
        src =
          githubSource "aio-libs" "yarl" "v1.25.1"
            "sha256-cQsVglP3OqaQW95OYPlbWCFTs5p6L5wOzx7QCIqqJ9U=";
      };
      multidict = pyPrev.multidict.overridePythonAttrs (old: {
        version = "6.9.1";
        src =
          githubSource "aio-libs" "multidict" "v6.9.1"
            "sha256-Xe8n3Y8x5fOS+xme5pKJuiiU6y+oXosZLoEA1Rkp+Qw=";
        # 6.9.1の隔離リークテストはcoverageを直接実行する。
        nativeCheckInputs = (old.nativeCheckInputs or [ ]) ++ [
          pyFinal.coverage
          pyFinal.hypothesis
        ];
      });
      gitpython = pyPrev.gitpython.overridePythonAttrs {
        version = "3.2.1";
        # replaceDependenciesの同一パス長制約。配布METADATAは実際の3.2.1。
        name = "${pyPrev.gitpython.pname}-${pyPrev.gitpython.version}";
        src =
          githubSource "gitpython-developers" "GitPython" "3.2.1"
            "sha256-LqHpvJLe5LqPca6FIH3NoOXVdV7LPojixg4sLPgLC8Q=";
      };
      certifi = pyPrev.certifi.overridePythonAttrs {
        version = "2026.10.19";
        src =
          githubSource "certifi" "python-certifi" "2026.10.19"
            "sha256-eiNK0yRcaOr0HW/kCc+0oOUXOl0jh+2rT41qBdDrVK8=";
      };
    }
  );
}
