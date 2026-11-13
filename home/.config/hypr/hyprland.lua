-- the-script: Hyprland, set up like GNOME without the dock, workspaces or app grid.
--
--   * every window opens maximized under the top bar (the "maxi" layout below); dialogs float
--   * Noctalia is the bar, notifications, lock screen and idle (~/.config/noctalia)
--   * Super (tap) opens the overview: a search box over all open windows (Quickshell, ~/.config/quickshell)
--   * Alt+Tab / Alt+Shift+Tab switch windows (Noctalia's switcher, most recently used first),
--     Super+Left/Right snap a window to half the screen, Super+Up maximizes it again
--   * desktops (no battery): variable refresh rate and tearing for fullscreen games
--
-- Changes here apply as soon as the file is saved. Personal additions go in ~/.config/hypr/local.lua
-- (loaded last, never touched by the-script). Keys are listed in the-script's README.

local HOME = os.getenv("HOME")
local BIN = HOME .. "/.local/bin/"

local function exists(p)
    local f = io.open(p, "r")
    if f then f:close() return true end
    return false
end
local LAPTOP = exists("/sys/class/power_supply/BAT0/type") or exists("/sys/class/power_supply/BAT1/type")

------------------------------------------------------------------ screens
-- the-script-displays picks each screen's mode and scale at login and when one is plugged in, and
-- writes them to monitors.lua; this line covers a screen until then.
hl.monitor({ output = "", mode = "highres", position = "auto", scale = "auto" })
pcall(dofile, HOME .. "/.config/hypr/monitors.lua")

------------------------------------------------------------------ environment
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")         -- Qt apps (KeePassXC, Anki): dark Fusion, ~/.config/qt6ct
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")  -- Element, Discord: native Wayland, sharp when scaled
hl.env("MOZ_ENABLE_WAYLAND", "1")

------------------------------------------------------------------ look: dark, square, quick
hl.config({
    general = {
        layout = "lua:maxi",
        gaps_in = 0,
        gaps_out = 0,
        border_size = 1,
        col = {
            active_border = "rgb(5e5e5e)",
            inactive_border = "rgb(2a2a2a)",
        },
        resize_on_border = true,
        allow_tearing = not LAPTOP,
    },
    decoration = {
        rounding = 0,
        shadow = { enabled = false },
        blur = { enabled = false },
        dim_inactive = false,
    },
    animations = { enabled = true },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        background_color = "rgb(000000)",
        vrr = LAPTOP and 0 or 2,        -- 2: variable refresh rate only for fullscreen windows (games)
        focus_on_activate = true,       -- a link opened from another app brings the browser forward
        key_press_enables_dpms = true,
        mouse_move_enables_dpms = true,
        enable_anr_dialog = true,
        disable_watchdog_warning = true,
    },
    xwayland = {
        force_zero_scaling = true,      -- X11 games render at the screen's real resolution, not blurry
    },
    render = {
        direct_scanout = LAPTOP and 0 or 2,  -- fullscreen games skip the compositor (2: games only)
    },
    cursor = {
        no_break_fs_vrr = 1,
        hide_on_key_press = false,
    },
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        accel_profile = "flat",
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
        },
    },
    binds = {
        -- Alt+Tab handles focus history itself; plain focus changes shouldn't jump the cursor.
        focus_preferred_method = 0,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})

hl.curve("snap", { type = "bezier", points = { {0.2, 0.9}, {0.1, 1} } })
hl.animation({ leaf = "global",     enabled = true,  speed = 3,   bezier = "snap" })
hl.animation({ leaf = "windowsIn",  enabled = true,  speed = 2.5, bezier = "snap", style = "popin 95%" })
hl.animation({ leaf = "windowsOut", enabled = true,  speed = 2,   bezier = "snap", style = "popin 95%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.5, bezier = "snap" })
hl.animation({ leaf = "border",     enabled = false })
hl.animation({ leaf = "layers",     enabled = true,  speed = 2,   bezier = "snap", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = false })

------------------------------------------------------------------ the "maxi" layout
-- Every tiled window fills the area under the bar; the focused one is on top. A window snapped with
-- Super+Left/Right takes that half instead, so two snapped windows sit side by side.
local snapped = {}   -- window address -> "left" | "right"

hl.layout.register("maxi", {
    recalculate = function(ctx)
        local a = ctx.area
        for _, t in ipairs(ctx.targets) do
            local side = t.window and snapped[t.window.address]
            if side == "left" then
                t:place({ x = a.x, y = a.y, w = math.floor(a.w / 2), h = a.h })
            elseif side == "right" then
                local half = math.floor(a.w / 2)
                t:place({ x = a.x + half, y = a.y, w = a.w - half, h = a.h })
            else
                t:place(a)
            end
        end
    end,
    layout_msg = function(ctx, msg)
        local w = hl.get_active_window()
        if not w then return false end
        if msg == "left" or msg == "right" then
            snapped[w.address] = msg
        elseif msg == "max" then
            snapped[w.address] = nil
        else
            return false
        end
        return true
    end,
})
hl.on("window.destroy", function(w) if w then snapped[w.address] = nil end end)

-- Super+Left/Right/Up on a floating window: make it a normal window first.
local function snap(side)
    return function()
        local w = hl.get_active_window()
        if not w then return end
        if w.fullscreen and w.fullscreen ~= 0 then
            hl.dispatch(hl.dsp.window.fullscreen({ action = "unset" }))
        end
        if w.floating then
            hl.dispatch(hl.dsp.window.float({ action = "disable" }))
        end
        hl.dispatch(hl.dsp.layout(side))
    end
end

------------------------------------------------------------------ window rules
-- Apps asking to be maximized or un-maximized: every window is already as big as it gets.
hl.window_rule({ name = "ignore-maximize", match = { class = ".*" }, suppress_event = "maximize" })
-- Small helper windows float in the middle.
for _, c in ipairs({ "pavucontrol", "org.pulseaudio.pavucontrol", "blueman-manager", "nm-connection-editor",
    "hyprland-share-picker", "xdg-desktop-portal-gtk", "org.keepassxc.KeePassXC.*Dialog", "qt6ct" }) do
    hl.window_rule({ match = { class = "^" .. c .. "$" }, float = true, size = {"monitor_w*0.5", "monitor_h*0.6"}, center = true })
end
hl.window_rule({ match = { title = "^(Picture-in-Picture|Picture in picture)$" }, float = true, pin = true })
-- Steam's friends list and other small Steam windows float; the main window stays maximized.
hl.window_rule({ match = { class = "^steam$", title = "^(Friends List|Steam Settings|Steam - News.*)$" }, float = true, center = true })
-- Games: tearing allowed (desktops only; general.allow_tearing), never idle while one is fullscreen.
hl.window_rule({ name = "games", match = { class = "^(steam_app_.*|gamescope|cs2|Minecraft.*|.*\\.exe)$" }, immediate = true, idle_inhibit = "fullscreen" })
hl.window_rule({ match = { content = "game" }, immediate = true, idle_inhibit = "fullscreen" })
hl.window_rule({ match = { content = "video" }, idle_inhibit = "fullscreen" })
-- XWayland drag-and-drop helper windows.
hl.window_rule({
    name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Noctalia's settings window floats; its bar, panels and popups animate themselves (Noctalia's docs
-- say Hyprland's own layer animation makes them glitch). The overview fades.
hl.window_rule({ match = { class = "^dev\\.noctalia\\.Noctalia$" }, float = true, size = { 1080, 920 }, center = true })
hl.layer_rule({
    name = "noctalia-no-anim",
    match = { namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$" },
    no_anim = true,
})
hl.layer_rule({ match = { namespace = "^the-script-overview$" }, animation = "fade" })

------------------------------------------------------------------ keys
local function sh(cmd) return hl.dsp.exec_cmd(cmd) end
local function qs(name) return hl.dsp.global("quickshell:" .. name) end

-- Super alone: the overview (search + all windows). Release, so Super+key shortcuts don't open it.
hl.bind("Super_L", qs("overview"), { release = true })
hl.bind("Super_R", qs("overview"), { release = true })
hl.bind("SUPER + A", qs("overview"))
hl.bind("SUPER + Space", qs("overview"))

-- Alt+Tab: Noctalia's window switcher, most recently used first; let go of Alt to switch.
local noct = "noctalia msg "
hl.bind("ALT + Tab", sh(noct .. "window-switcher hold"))
hl.bind("ALT + SHIFT + Tab", sh(noct .. "window-switcher hold reverse"))

hl.bind("SUPER + Return", sh("foot"))
hl.bind("SUPER + T", sh(BIN .. "todo-pick"))
hl.bind("SUPER + E", sh("thunar"))
hl.bind("SUPER + B", sh("librewolf"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind("SUPER + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + Left", snap("left"))
hl.bind("SUPER + Right", snap("right"))
hl.bind("SUPER + Up", snap("max"))
hl.bind("SUPER + Down", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + L", sh(noct .. "session lock"))
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshots (Noctalia): Print the screen, Super+Shift+S an area; saved to ~/Pictures and copied.
hl.bind("Print", sh(noct .. "screenshot-fullscreen"))
hl.bind("SUPER + SHIFT + S", sh(noct .. "screenshot-region"))

-- Volume and brightness keys (Noctalia shows the change).
hl.bind("XF86AudioRaiseVolume", sh(noct .. "volume-up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", sh(noct .. "volume-down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", sh(noct .. "volume-mute"), { locked = true })
hl.bind("XF86AudioMicMute", sh(noct .. "mic-mute"), { locked = true })
hl.bind("XF86MonBrightnessUp", sh(noct .. "brightness-up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", sh(noct .. "brightness-down"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay", sh("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", sh("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", sh("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", sh("playerctl previous"), { locked = true })

------------------------------------------------------------------ session start
-- the-script-session starts Noctalia (bar, notifications, lock, idle), the overview and the services
-- that wait for a graphical session (bedtime, history-cleaner).
hl.on("hyprland.start", function()
    if os.getenv("THE_SCRIPT_TEST") then return end
    hl.exec_cmd(BIN .. "the-script-session")
end)
hl.on("monitor.added", function()
    if os.getenv("THE_SCRIPT_TEST") then return end
    hl.exec_cmd("sleep 1; " .. BIN .. "the-script-displays")
end)

-- Your own additions (not part of the-script).
pcall(dofile, HOME .. "/.config/hypr/local.lua")
