#!/usr/bin/env bash
# CI 用の検査。`nix flake check` の代わりに使う。
#
# `nix flake check` は nixosConfigurations を評価するが、configs/security.nix の
# system.replaceDependencies は参照を調べるため評価中にシステム全体（約 22GiB）を
# 実体化する（IFD）。GitHub Actions のランナーでは時間・ディスクとも収まらない。
# ここでは差し替えを外した設定を IFD 禁止で評価し（ビルドしない）、
# 差し替え先の派生も評価だけ確認する。差し替え固有の失敗は手元の
# `nix flake check` / `nixos-rebuild` で検出する。
#
# replaceDependencies を撤去したら、CI は通常の `nix flake check` に戻してよい。
set -euo pipefail

system=x86_64-linux

echo "==> flake checks をビルド"
mapfile -t checks < <(nix eval --json ".#checks.$system" --apply builtins.attrNames | jq -r '.[]')
nix build --no-link --print-build-logs "${checks[@]/#/.#checks.$system.}"

echo "==> NixOS 設定を評価（replaceDependencies なし、IFD 禁止）"
nix eval --json --option allow-import-from-derivation false .#nixosConfigurations --apply '
  configs:
  builtins.mapAttrs (
    _: c:
    let
      ci = c.extendModules {
        modules = [ { system.replaceDependencies.replacements = c.pkgs.lib.mkForce [ ]; } ];
      };
    in
    {
      toplevel = ci.config.system.build.toplevel.drvPath;
      replacements = map (r: r.newDependency.drvPath) c.config.system.replaceDependencies.replacements;
    }
  ) configs
' | jq '.[] | {toplevel, replacements: (.replacements | unique | length)}'

echo "==> devShell を評価"
nix eval --raw ".#devShells.$system.default.drvPath"
echo
