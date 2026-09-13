# shellcheck shell=bash
# ChatGPT ラッパーから source される。同梱プラグインの書き込み可能なコピーを用意する。
#
# アプリは起動時に resources/plugins を ~/.codex/.tmp/bundled-marketplaces へ fs.cp で
# 複製し、その中の plugin.json 等を書き換える。fs.cp はパーミッションを引き継ぐため、
# Nix ストア（常に読み取り専用）から複製すると書き込みが EACCES で失敗し、browser use を
# 含む同梱プラグインが一切導入されない。
# アプリはプラグインの読み出し元だけを CODEX_ELECTRON_BUNDLED_PLUGINS_RESOURCES_PATH で
# 差し替えられるので、plugins だけ実体コピーして u+w を付けた resources を用意して向ける。
# plugins 以外はストアへのシンボリックリンクにする（参照されても同じ実体を見る）。
#
# ストアパスごとに 1 回だけ作り、旧バージョン向けのコピーは作成時に掃除する。
# 失敗しても起動は止めず、環境変数を立てないまま（= 上流の挙動のまま）起動する。

_chatgpt_cache="${XDG_CACHE_HOME:-$HOME/.cache}/chatgpt-nix"
_chatgpt_res="$_chatgpt_cache/@name@"

# if の条件部では set -e が無効になるため、失敗は各コマンドで明示的に返す
_chatgpt_prepare() {
  local entry
  for entry in @resources@/*; do
    if [ "${entry##*/}" != plugins ]; then
      @coreutils@/bin/ln -s "$entry" "$1/" || return 1
    fi
  done
  # 最後の mv は同時起動に備えた原子的な差し替え（先を越されたら失敗する）
  @coreutils@/bin/cp -r @resources@/plugins "$1/plugins" &&
    @coreutils@/bin/chmod -R u+w "$1/plugins" &&
    @coreutils@/bin/mv -T "$1" "$2"
}

if [ ! -d "$_chatgpt_res/plugins" ] && @coreutils@/bin/mkdir -p "$_chatgpt_cache" &&
  _chatgpt_tmp=$(@coreutils@/bin/mktemp -d "$_chatgpt_res.tmp.XXXXXX"); then
  if _chatgpt_prepare "$_chatgpt_tmp" "$_chatgpt_res" 2>/dev/null; then
    for _old in "$_chatgpt_cache"/*; do
      case "$_old" in
        "$_chatgpt_res" | "$_chatgpt_res".tmp.*) ;;
        *) @coreutils@/bin/rm -rf "$_old" ;;
      esac
    done
  else
    @coreutils@/bin/chmod -R u+w "$_chatgpt_tmp" 2>/dev/null
    @coreutils@/bin/rm -rf "$_chatgpt_tmp"
  fi
fi

if [ -d "$_chatgpt_res/plugins" ]; then
  export CODEX_ELECTRON_BUNDLED_PLUGINS_RESOURCES_PATH="$_chatgpt_res"
fi

unset _chatgpt_cache _chatgpt_res _chatgpt_tmp _old
unset -f _chatgpt_prepare
