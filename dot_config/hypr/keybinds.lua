-------------------
--- KEYBINDINGS ---
-------------------
-- See https://wiki.hypr.land/configuring/core/binds/ and .../core/dispatchers/

local terminal    = "kitty"
local fileManager = "dolphin"
local noctalia    = "qs -c noctalia-shell ipc call "
local lock        = "hyprlock"
local scripts     = "~/.config/hypr/scripts/"

local function mod(keys) return "SUPER + " .. keys end
local function exec(cmd) return hl.dsp.exec_cmd(cmd) end

hl.bind(mod("Return"),        exec(terminal))
hl.bind(mod("Q"),             exec(scripts .. "toggle_kitty.sh"))
hl.bind(mod("W"),             exec(scripts .. "toggle_notes.sh")) -- raycast-style notes popup
hl.bind(mod("C"),             hl.dsp.window.close())
hl.bind(mod("E"),             exec(fileManager))
hl.bind(mod("T"),             hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod("SHIFT + P"),     hl.dsp.window.pin())    -- pin floating window across all workspaces
hl.bind(mod("ALT + C"),       hl.dsp.window.center()) -- center the current floating window
hl.bind(mod("SHIFT + F"),     hl.dsp.window.fullscreen_state({ internal = 0, client = 2, action = "toggle" })) -- fake fullscreen (keeps the shell bar visible)
hl.bind(mod("F"),             hl.dsp.window.fullscreen())
hl.bind(mod("P"),             hl.dsp.window.pseudo())          -- dwindle
hl.bind(mod("O"),             hl.dsp.layout("togglesplit"))    -- dwindle
hl.bind(mod("Escape"),        exec(lock))
hl.bind(mod("Y"),             exec("emacs"))

-- Noctalia replaces the rofi/vicinae/swaync/wlogout/waypaper shell surfaces.
hl.bind(mod("V"),             exec(noctalia .. "launcher clipboard"))
hl.bind(mod("space"),         exec(noctalia .. "launcher toggle"))
hl.bind(mod("S"),             exec(noctalia .. "controlCenter toggle"))
hl.bind(mod("comma"),         exec(noctalia .. "settings toggle"))
hl.bind(mod("period"),        exec(noctalia .. "launcher emoji"))
hl.bind(mod("SHIFT + space"), exec(noctalia .. "launcher command"))
hl.bind(mod("ALT + space"),   exec(noctalia .. "controlCenter toggle"))
hl.bind(mod("ALT + W"),       exec(noctalia .. "wallpaper toggle"))
hl.bind(mod("ALT + N"),       exec(noctalia .. "network togglePanel"))
hl.bind(mod("ALT + B"),       exec(noctalia .. "bluetooth togglePanel"))
hl.bind(mod("ALT + M"),       exec(noctalia .. "volume togglePanel"))
hl.bind(mod("ALT + P"),       exec(noctalia .. "sessionMenu toggle"))
hl.bind(mod("ALT + J"),       exec(noctalia .. "plugin:jisho toggle"))          -- jisho launcher (history)
hl.bind(mod("ALT + SHIFT + J"), exec(noctalia .. "plugin:jisho lookupSelection")) -- jisho lookup of highlighted text
hl.bind(mod("N"),             exec(noctalia .. "notifications toggleHistory"))

-- Screenshots & screen tools (scripts/screenshot.sh)
hl.bind("CTRL + ALT + S",         exec(scripts .. "screenshot.sh copy"))   -- quick region -> clipboard
hl.bind("CTRL + SHIFT + ALT + S", exec(scripts .. "screenshot.sh region")) -- region -> annotate -> save+copy
hl.bind("CTRL + SHIFT + ALT + A", exec(scripts .. "screenshot.sh output")) -- whole screen -> save+copy
hl.bind(mod("ALT + S"),           exec(scripts .. "screenshot-menu.sh"))   -- full menu: window/ocr/colour/pin/browse
hl.bind("CTRL + SUPER + space",   exec(scripts .. "screenshot-menu.sh"))   -- quick menu (pin, etc.)

-- Handy dictation (push-to-talk): its own global shortcut can't grab keys under Wayland, so
-- Hyprland owns it. Press starts recording, release stops it.
hl.bind("CTRL + ALT + Q", exec("handy --toggle-transcription"))
hl.bind("CTRL + ALT + Q", exec("handy --toggle-transcription"), { release = true })

-- Focus
hl.bind(mod("h"), hl.dsp.focus({ direction = "left" }))
hl.bind(mod("j"), hl.dsp.focus({ direction = "down" }))
hl.bind(mod("k"), hl.dsp.focus({ direction = "up" }))
hl.bind(mod("l"), hl.dsp.focus({ direction = "right" }))

-- Workspaces: SUPER + [0-9] switches, SUPER + SHIFT + [0-9] moves the window there
for i = 1, 10 do
    local key = tostring(i % 10) -- 10 maps to key 0
    hl.bind(mod(key),             hl.dsp.focus({ workspace = i }))
    hl.bind(mod("SHIFT + " .. key), hl.dsp.window.move({ workspace = i, follow = true }))
end

hl.bind(mod("CTRL + left"),   hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mod("CTRL + right"),  hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mod("SHIFT + left"),  hl.dsp.window.move({ workspace = "r-1", follow = true }))
hl.bind(mod("SHIFT + right"), hl.dsp.window.move({ workspace = "r+1", follow = true }))

-- Move/resize windows with SUPER + LMB/RMB and dragging
hl.bind(mod("mouse:272"), hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod("mouse:273"), hl.dsp.window.resize(), { mouse = true })

-- Multimedia keys routed through Noctalia for shell-native OSD/panels
local media = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume",  exec(noctalia .. "volume increase"),       media)
hl.bind("XF86AudioLowerVolume",  exec(noctalia .. "volume decrease"),       media)
hl.bind("XF86AudioMute",         exec(noctalia .. "volume muteOutput"),     media)
hl.bind("XF86AudioMicMute",      exec(noctalia .. "volume muteInput"),      media)
hl.bind("XF86MonBrightnessUp",   exec(noctalia .. "brightness increase"),   media)
hl.bind("XF86MonBrightnessDown", exec(noctalia .. "brightness decrease"),   media)
-- Keyboard backlight stays on brightnessctl; Noctalia controls the display backlight.
hl.bind("XF86KbdBrightnessUp",   exec("brightnessctl -d asus::kbd_backlight set +1"), media)
hl.bind("XF86KbdBrightnessDown", exec("brightnessctl -d asus::kbd_backlight set 1-"), media)
