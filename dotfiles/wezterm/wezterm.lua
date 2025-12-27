local wezterm = require 'wezterm'
local config = wezterm.config_builder()


config.enable_wayland = false

-- =================================================
-- OS判定ロジック (MacかLinuxか)
-- =================================================
local is_mac = wezterm.target_triple == 'x86_64-apple-darwin' or wezterm.target_triple == 'aarch64-apple-darwin'
local is_linux = wezterm.target_triple:find("linux") ~= nil

-- =================================================
-- 基本設定
-- =================================================
config.automatically_reload_config = true
-- フォントはNixOS側でインストール必須
config.font = wezterm.font("HackGen35 Console NF", {weight="Regular", stretch="Normal", style="Normal"})
config.font_size = 16.0
config.use_ime = true
config.window_background_opacity = 0.9

-- Mac特有の設定
if is_mac then
  config.macos_window_background_blur = 20
  config.window_decorations = "RESIZE"
end

-- Linux特有の設定 (Wayland対策)
if is_linux then
  -- ウィンドウを動かせるようにタイトルバーを表示
  config.window_decorations = "TITLE | RESIZE"
end

config.show_new_tab_button_in_tab_bar = false
config.audible_bell = "SystemBeep" -- Linuxだと鳴らないこともあります

-- =================================================
-- タブの装飾 (元のコードのまま)
-- =================================================
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local background = "#5c6d74"
  local foreground = "#FFFFFF"

  if tab.is_active then
    background = "#ae8b2d"
    foreground = "#FFFFFF"
  end

  local title = "   " .. wezterm.truncate_right(tab.active_pane.title, max_width - 1) .. "   "

  return {
    { Background = { Color = background } },
    { Foreground = { Color = foreground } },
    { Text = title },
  }
end)

-- =================================================
-- キーバインド
-- =================================================
local act = wezterm.action

-- OSに合わせて修飾キーを変える
-- MacならCMD, LinuxならCTRL (または 'SUPER' でWindowsキー)
local mod_key = is_mac and 'CMD' or 'CTRL' 

config.keys = {
  {
    key = 's',
    mods = 'SHIFT|' .. mod_key, -- Mac: CMD+Shift+s, Linux: Ctrl+Shift+s
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = "d",
    mods = "SHIFT|" .. mod_key,
    action = wezterm.action.CloseCurrentPane { confirm = true },
  },
  {
    key = 'Enter',
    mods = 'SHIFT',
    action = wezterm.action.SendString('\n'),
  },
}

return config
