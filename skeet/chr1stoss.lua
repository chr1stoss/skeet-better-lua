-- CONSTANTS
local CONFIG_KEY = "state"
local DLL_PATH   = "native/namechanger.dll"

local function log(msg)
    msg = "[chr1stoss] " .. tostring(msg)
    if type(print) == "function" then print(msg) end
    if console and type(console.exec) == "function" then
        console.exec('echo "' .. msg:gsub('"', "'") .. '"')
    end
end

local _pcall
do
    local _raw = rawget(_G, "pcall")
    if type(_raw) == "function" then
        _pcall = _raw
    else
        local _api = rawget(_G, "api")
        if _api and type(_api.protect) == "function" then
            _pcall = function(f, a, b, c, d, e)
                local success, result = false, nil
                _api.protect(function()
                    result = f(a, b, c, d, e)
                    success = true
                end)
                return success, result
            end
        else
            _pcall = function(f, a, b, c, d, e)
                return true, f(a, b, c, d, e)
            end
        end
    end
end

local DD_MAX_H = 280
local dd_scroll = {}
local dd_scroll_drag = nil

local PICKER_SQ, PICKER_STRIPE, PICKER_GAP = 140, 14, 6
local PICKER_Y_OFFSET = 8
local picker_open = nil
local picker_positions = {}
local picker_data = {}

local active_tab = 1
local dragging_slider = nil
local is_collapsed = false
local current_w = 660

local open_dropdown = nil
local dd_rect = nil
local dd_items = nil
local dd_is_multi = false
local dd_exclusive = nil

local focused_text = nil
local cursor_blink_t = 0
local CURSOR_PERIOD = 1.0

local anims = { checkboxes = {}, sliders = {},
                slider_arrows = {}, slider_minus = {}, slider_plus = {},
                roll_hover = 0, roll_disabled = 100 }
local dd_anim_height = 0
local closing_dd = nil

local tab_icons = {nil, nil, nil, nil, nil, nil, nil}
local icons_loaded = false

local scroll = {
    awall = 0, v_ragebot_kb = 0,
    aa_stand = 0, aa_crouch = 0, aa_move = 0, aa_air = 0,
    v_ch = 0, v_misc_dt = 0,
    v_bt = 0, v_ea = 0, v_trail = 0, v_misc_blur = 0, v_wm = 0,
    autobuy = 0, v_misc_msgs = 0, namechanger = 0,
    v_servers = 0,
    author = 0, build = 0,
}
local last_max_scroll = {
    awall = 0, v_ragebot_kb = 0,
    aa_stand = 0, aa_crouch = 0, aa_move = 0, aa_air = 0,
    v_ch = 0, v_misc_dt = 0,
    v_bt = 0, v_ea = 0, v_trail = 0, v_misc_blur = 0, v_wm = 0,
    autobuy = 0, v_misc_msgs = 0, namechanger = 0,
    v_servers = 0,
    author = 0, build = 0,
}
local dragging_scrollbar = nil
local scroll_drag_off    = {}

-- active scrollable clip (used by is_hover to suppress clicks outside visible area)
local _clip = nil

local state = {
    cb_weapons = false, cb_utility = false,
    combo_primary = 3, combo_secondary = 1,
    combo_armor = 2,
    multi_utility   = {false, false, false, false, false, false},
    multi_another   = {false, false, false},

    aw_truth = false, aw_visual = false,
    aw_col_through = {r = 0,   g = 255, b = 100, a = 255},
    aw_col_blocked = {r = 255, g = 50,  b = 50,  a = 255},
    aw_sq_size = 9, aw_smooth = 0.7, aw_hold = 0.25,

    nc_on = false, nc_name = "tvoi papa 200",
    nc_type = 1,            -- 1=Default, 2=Stealer
    nc_steal_mode = 1,      -- 1=Certain, 2=Few
    nc_steal_single = 1,
    nc_steal_multi = {},
    nc_steal_delay = 1.0,
    nc_tag_on = false, nc_tag = "velocity",
    nc_tag_source = 1,
    nc_tag_single = 1,
    nc_tag_presets = {},
    nc_swap_delay = 1.0,
    nc_tag_wrap_enabled = false,
    nc_tag_anim_enabled = false,
    nc_tag_wrap = 1,
    nc_tag_mode = 1,
    nc_tag_pos = 1, nc_tag_spd = 0.15,
    nc_cursor = 1,

    -- Anti-Aim per state (all OFF)
    aa_stand_enabled = false, aa_stand_at_target = false,
    aa_stand_aa_types = 1,
    aa_stand_flick_enabled = false,
    aa_stand_flick_axes = {false, false},
    aa_stand_extra_yaw_enabled = false,
    aa_stand_flick_yaw_delay = 1.0,
    aa_stand_flick_pitch_delay = 1.0,
    aa_stand_yaw = 1, aa_stand_yaw_custom = 0,
    aa_stand_pitch = 1, aa_stand_pitch_custom = 0,
    aa_stand_type = 1, aa_stand_spin_dir = 1, aa_stand_spin_speed = 30,
    aa_stand_jitter_mode = 1, aa_stand_jitter_degree = 30, aa_stand_jitter_speed = 0.1,

    aa_crouch_enabled = false, aa_crouch_at_target = false,
    aa_crouch_aa_types = 1,
    aa_crouch_flick_enabled = false,
    aa_crouch_flick_axes = {false, false},
    aa_crouch_extra_yaw_enabled = false,
    aa_crouch_flick_yaw_delay = 1.0,
    aa_crouch_flick_pitch_delay = 1.0,
    aa_crouch_yaw = 1, aa_crouch_yaw_custom = 0,
    aa_crouch_pitch = 1, aa_crouch_pitch_custom = 0,
    aa_crouch_type = 1, aa_crouch_spin_dir = 1, aa_crouch_spin_speed = 30,
    aa_crouch_jitter_mode = 1, aa_crouch_jitter_degree = 30, aa_crouch_jitter_speed = 0.1,

    aa_move_enabled = false, aa_move_at_target = false,
    aa_move_aa_types = 1,
    aa_move_flick_enabled = false,
    aa_move_flick_axes = {false, false},
    aa_move_extra_yaw_enabled = false,
    aa_move_flick_yaw_delay = 1.0,
    aa_move_flick_pitch_delay = 1.0,
    aa_move_yaw = 1, aa_move_yaw_custom = 0,
    aa_move_pitch = 1, aa_move_pitch_custom = 0,
    aa_move_type = 1, aa_move_spin_dir = 1, aa_move_spin_speed = 30,
    aa_move_jitter_mode = 1, aa_move_jitter_degree = 30, aa_move_jitter_speed = 0.1,

    aa_air_enabled = false, aa_air_at_target = false,
    aa_air_aa_types = 1,
    aa_air_flick_enabled = false,
    aa_air_flick_axes = {false, false},
    aa_air_extra_yaw_enabled = false,
    aa_air_flick_yaw_delay = 1.0,
    aa_air_flick_pitch_delay = 1.0,
    aa_air_yaw = 1, aa_air_yaw_custom = 0,
    aa_air_pitch = 1, aa_air_pitch_custom = 0,
    aa_air_type = 1, aa_air_spin_dir = 1, aa_air_spin_speed = 30,
    aa_air_jitter_mode = 1, aa_air_jitter_degree = 30, aa_air_jitter_speed = 0.1,
    aa_air_only_space = false,
    aa_air_space_threshold = 0.5,

    -- Backtrack
    bt_enabled = false, bt_mode = 1,
    bt_targets_mode = 1,      -- 1=Target, 2=All, 3=Custom
    bt_history = 1,           -- 1=Show, 2=Clear
    bt_age = 200, bt_hc = 60, bt_fov = 180,
    bt_targets = 2, bt_records = 8, bt_queries = 24,
    bt_col_ok = {r = 90,  g = 220, b = 130, a = 255},
    bt_col_bad = {r = 255, g = 80,  b = 80,  a = 255},
    bt_info_col = {r = 255, g = 255, b = 255, a = 255},
    bt_info = false, bt_mult_all = 0.15, bt_mult_one = 1.00,

    -- Crosshair / penetration
    ch_enabled = false, ch_type = 3,
    ch_col_norm = {r = 255, g = 255, b = 255, a = 255},
    ch_pen_enabled = false,
    ch_col_pen = {r = 0,   g = 255, b = 100, a = 255},
    ch_col_enemy = {r = 255, g = 255, b = 255, a = 255},

    -- Trail
    tr_enabled = false, tr_height = 0, tr_len = 30, tr_life = 0.8, tr_width = 6,
    tr_rainbow = false, tr_color = {r = 110, g = 200, b = 255, a = 220}, tr_fade = false,

    -- Enemy arrows
    ea_enabled = false, ea_offscreen = false, ea_radius = 140, ea_size = 11,
    ea_limit = 8, ea_dist = 3000, ea_eye = 64, ea_hp = false, ea_name = false,
    ea_fade = false, ea_by_health = false, ea_outline = false,
    ea_color = {r = 255, g = 120, b = 90,  a = 235},
    ea_hp_high = {r = 120, g = 220, b = 120, a = 255},
    ea_hp_low = {r = 255, g = 80,  b = 80,  a = 255},
    ea_outline_color = {r = 0, g = 0, b = 0, a = 160},
    ea_text_color = {r = 235, g = 240, b = 250, a = 255},
    ea_debug = false, ea_style = 1, ea_neon = false, ea_glow = 4,

    -- Watermark
    wm_enabled = false, wm_pos = 6, wm_size = 2, wm_pad = 3, wm_bg_en = false,
    wm_items = {false, false, false, false, false},

    -- Chat spammer
    cs_enabled = false, cs_message = "Top Lua by chr1stoss",
    cs_interval = 5, cs_team_only = false,

    -- TrashTalk
    tt_enabled = false,
    tt_situations = {false, false},   -- [kill, death]
    tt_phrases_mode = 1,              -- 1=All, 2=Custom
    tt_lang = 1,
    tt_sel_kill_en = {}, tt_sel_kill_ru = {},
    tt_sel_death_en = {}, tt_sel_death_ru = {},

    -- Background blur
    blur_enabled = false, blur_opacity = 0.55, blur_speed = 8, blur_mode = 2,
    blur_particles_enabled = false, blur_particles = 1,
    particles_speed = 8, particles_move_speed = 1.0,

    -- Autobuy delay
    buy_delay_enabled = false, buy_delay_value = 0.5,

    -- DoubleTap Indicator
    dt_ind_enabled = false,
    dt_ind_based_on = 1,           -- 1=Scope, 2=Screen
    dt_ind_type = 1,               -- 1=Circle, 2=Square, 3=Line (Scope)
    dt_ind_line_pos = 1,           -- 1=Above, 2=Below, 3=Left, 4=Right (Scope)
    dt_ind_line_offset = 60,
    dt_ind_size = 40,
    dt_ind_thickness = 2,
    dt_ind_color = {r = 255, g = 255, b = 255, a = 255},
    dt_ind_takes = 1,              -- 1=Full, 2=Above, 3=Below, 4=Left, 5=Right (Screen)
    dt_ind_screen_thickness = 4,
    dt_ind_screen_color = {r = 255, g = 255, b = 255, a = 255},

    sv_filter = {true, true, true, true, true},

    -- Knife & Zeus Bot (visual placeholder)
    kb_knife_enabled = false,
    kb_knife_silent  = false,
    kb_knife_range   = 60,
    kb_knife_fov     = 25,
    kb_knife_delay   = 0.35,
    kb_zeus_enabled  = false,
    kb_zeus_silent   = false,
    kb_zeus_range    = 190,
    kb_zeus_fov      = 15,
    kb_zeus_delay    = 0.5,

    user_collapsed = false,
}

local CURSOR_CHARS = {"|", "/", "\\", "_"}
local NC_TAG_PRESETS = {
    { name = "skeet",       postfixes = {"None", ".cc"} },
    { name = "gamesense",   postfixes = {"None", ".pub"} },
    { name = "neverlose",   postfixes = {"None", ".cc", ".crack"} },
    { name = "newerwin",    postfixes = {"None", ".crack"} },
    { name = "neverpuzo",   postfixes = {"None", ".hui"} },
    { name = "onetap",      postfixes = {"None", ".com", ".crack"} },
    { name = "fatality",    postfixes = {"None", ".win", ".swin", ".miss"} },
    { name = "nixware",     postfixes = {"None", ".cc"} },
    { name = "aimware",     postfixes = {"None", ".net", ".crack"} },
    { name = "neverfair",   postfixes = nil },
    { name = "enigma",      postfixes = nil },
    { name = "velocity",    postfixes = nil },
    { name = "primordial",  postfixes = nil },
    { name = "NAIM FREE",   postfixes = nil },
    { name = "Shark Hack",  postfixes = nil },
}

for i = 1, #NC_TAG_PRESETS do
    state["nc_pfx_" .. i] = 1
end
state.nc_pfx_single = 1

local HVH_MODES = {"Rapid Fire", "Spread", "NoSpread", "Spread DM", "NoSpread DM"}

local HVH_SERVERS = {
    {name = "Nixware HvH DM",          ip = "46.174.54.169:27015",  region = "RU", mode = 4},
    {name = "Santa HvH RapidFire",     ip = "62.122.215.78:27015",  region = "RU", mode = 1},
    {name = "DarkProject HvH",         ip = "62.122.213.101:1337",  region = "RU", mode = 2},
    {name = "OnlyTOXIC DM spread",     ip = "92.118.11.247:28605",  region = "RU", mode = 4},
    {name = "OnlyTOXIC NOSPREAD",      ip = "92.118.11.38:28816",   region = "RU", mode = 3},
    {name = "OnlyTOXIC SPREAD",        ip = "92.118.11.15:28324",   region = "RU", mode = 2},
    {name = "HvH club NS & DT",        ip = "37.230.228.237:27015", region = "RU", mode = 3},
    {name = "OnlyTOXIC DM nospread",   ip = "92.118.11.247:28907",  region = "RU", mode = 5},
    {name = "RAZE CLUB HvH",           ip = "46.174.52.196:27015",  region = "RU", mode = 2},
    {name = "KING HVH",                ip = "109.200.117.181:27015",region = "RU", mode = 2},
    {name = "Nova HVH NoSpread",       ip = "185.135.80.43:27015",  region = "RU", mode = 3},
}

local server_last_click = 0
local server_last_ip    = ""
local server_btn_hov    = {}
local server_row_hov    = {}
local author_btn_hov    = {}

local function lerp_col(c1, c2, t)
    if t < 0 then t = 0 end
    if t > 1 then t = 1 end
    return {
        math.floor(c1[1] + (c2[1] - c1[1]) * t + 0.5),
        math.floor(c1[2] + (c2[2] - c1[2]) * t + 0.5),
        math.floor(c1[3] + (c2[3] - c1[3]) * t + 0.5),
        math.floor((c1[4] or 255) + ((c2[4] or 255) - (c1[4] or 255)) * t + 0.5),
    }
end

local url_show = nil

-- In-game clipboard buffer (used by Ctrl+V inside inputs - OS clipboard not required)
local CLIPBOARD_BUFFER = ""

-- win32 WRITE only - writes CF_UNICODETEXT so external apps (browser etc.) can paste
local function win32_clipboard(text)
    local ok, res = _pcall(function()
        local ffi_mod = rawget(_G, "ffi")
        if not ffi_mod then
            local rok, r = _pcall(require, "ffi")
            if rok and r then ffi_mod = r end
        end
        if not ffi_mod then return false end
        _pcall(ffi_mod.cdef, [[
            int  __stdcall OpenClipboard(void*);
            int  __stdcall EmptyClipboard(void);
            void* __stdcall GlobalAlloc(unsigned int, size_t);
            void* __stdcall GlobalLock(void*);
            int  __stdcall GlobalUnlock(void*);
            void* __stdcall SetClipboardData(unsigned int, void*);
            int  __stdcall CloseClipboard(void);
        ]])
        local k = ffi_mod.load("kernel32")
        local u = ffi_mod.load("user32")
        if u.OpenClipboard(nil) == 0 then return false end
        u.EmptyClipboard()
        local len   = #text
        local bytes = len * 2 + 2
        local mem   = k.GlobalAlloc(0x0002, bytes)
        if mem == nil then u.CloseClipboard(); return false end
        local ptr = k.GlobalLock(mem)
        if ptr == nil then u.CloseClipboard(); return false end
        local p = ffi_mod.cast("uint8_t*", ptr)
        for i = 1, len do
            p[(i-1)*2]     = text:byte(i)
            p[(i-1)*2 + 1] = 0
        end
        p[len*2], p[len*2 + 1] = 0, 0
        k.GlobalUnlock(mem)
        u.SetClipboardData(13, mem)
        u.CloseClipboard()
        return true
    end)
    return ok and res == true
end

local function copy_to_clipboard(text)
    if not text or text == "" then return false, "empty" end

    -- Always store locally so in-game Ctrl+V works
    CLIPBOARD_BUFFER = text

    -- Try loader setter (this is what makes external paste work on your build)
    local loader_ok = false
    _pcall(function()
        if client and type(client.set_clipboard) == "function" then
            client.set_clipboard(text); loader_ok = true
        end
    end)
    if not loader_ok then
        _pcall(function()
            if utils and type(utils.set_clipboard) == "function" then
                utils.set_clipboard(text); loader_ok = true
            end
        end)
    end
    if not loader_ok then
        _pcall(function()
            if ui and type(ui.set_clipboard) == "function" then
                ui.set_clipboard(text); loader_ok = true
            end
        end)
    end

    -- win32 write fallback - only when loader setter missing
    if not loader_ok then
        if win32_clipboard(text) then return true, "win32" end
    end

    if loader_ok then return true, "loader" end
    return false, "buffer_only"
end

local function read_clipboard()
    -- only the script-local buffer - OS clipboard read was proven broken in your env
    if CLIPBOARD_BUFFER and CLIPBOARD_BUFFER ~= "" then
        return CLIPBOARD_BUFFER
    end
    return nil
end

local AUTHOR_INFO = {
    nick    = "chr1stoss",
    tagline = "Developer • Skeet Multi",
    socials = {
        {key = "Discord",    url = "https://discord.com/users/chr1stxss"},
        {key = "Telegram",   url = "https://t.me/chr1stxss"},
        {key = "TG Channel", url = "https://t.me/chr1stoss_hub"},
        {key = "GitHub",     url = "https://github.com/chr1stoss"},
        {key = "YouTube",    url = "https://youtube.com/@chr1stxss"},
    },
}

local BUILD_INFO = {
    version  = "1.3.3.7",
    channel  = "stable",
    date     = "2026-11-13",
    filename = "chr1stoss.lua",
}

local author_avatar_tex = nil

-- Save / load
local function load_state()
    local saved = storage.get(CONFIG_KEY, nil)
    if type(saved) ~= "table" then return end
    
    local COLOR_KEYS = {
        aw_col_through=true, aw_col_blocked=true, bt_col_ok=true, bt_col_bad=true,
        ch_col_norm=true, ch_col_pen=true, ch_col_enemy=true, tr_color=true,
        ea_color=true, ea_hp_high=true, ea_hp_low=true,
        ea_outline_color=true, ea_text_color=true,
        bt_info_col=true, dt_ind_color=true, dt_ind_screen_color=true,
    }
    for k, v in pairs(saved) do
        if k:sub(1, 3) ~= "kb_" and state[k] ~= nil and type(state[k]) == type(v) then
            local ok = true
            if COLOR_KEYS[k] then
                ok = type(v) == "table"
                    and type(v.r) == "number" and type(v.g) == "number"
                    and type(v.b) == "number" and type(v.a) == "number"
            end
            if ok then state[k] = v end
        end
    end
    -- sanitize: legacy sparse nc_tag_presets (crashes storage.set)
    if type(saved.nc_tag_presets) == "table" then
        local dense = {}
        for i = 1, #NC_TAG_PRESETS do
            dense[i] = (saved.nc_tag_presets[i] == true)
        end
        saved.nc_tag_presets = dense
        state.nc_tag_presets = dense
    end
end
load_state()

is_collapsed = state.user_collapsed
current_w    = is_collapsed and 75 or 660

local function state_fingerprint()
    local parts = {}
    for k, v in pairs(state) do
        if k:sub(1, 3) ~= "kb_" then
            if type(v) == "table" then
                local inner = {}
                for kk, vv in pairs(v) do
                    inner[#inner+1] = tostring(kk) .. ":" .. tostring(vv)
                end
                table.sort(inner)
                parts[#parts+1] = k .. "{" .. table.concat(inner, ",") .. "}"
            else
                parts[#parts+1] = k .. "=" .. tostring(v)
            end
        end
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

local last_fp = state_fingerprint()

local function any_picker_dragging()
    for _, pd in pairs(picker_data) do
        if pd and pd.drag then return true end
    end
    return false
end

local function flush_state_if_changed()
    if dragging_slider or focused_text or any_picker_dragging() then return end
    local fp = state_fingerprint()
    if fp ~= last_fp then
        local to_save = {}
        for k, v in pairs(state) do
            if k:sub(1, 3) ~= "kb_" then
                if type(v) == "table" then
                    local has_str, max_idx = false, 0
                    for kk in pairs(v) do
                        if type(kk) == "string" then has_str = true; break end
                        if type(kk) == "number" and kk > max_idx then max_idx = kk end
                    end
                    if has_str then
                        to_save[k] = v
                    else
                        local dense = {}
                        for i = 1, max_idx do
                            dense[i] = (v[i] == true)
                        end
                        to_save[k] = dense
                    end
                else
                    to_save[k] = v
                end
            end
        end
        storage.set(CONFIG_KEY, to_save)
        last_fp = fp
    end
end

events.on("shutdown", function() storage.set(CONFIG_KEY, state) end)

local function api_safe(fn)
    if api and api.protect then api.protect(fn) else fn() end
end

-- Chat helpers
local function cs_sanitize(s)
    s = tostring(s or ""):gsub('[%c"\\;]', "")
    if #s > 200 then s = s:sub(1, 200) end
    return s
end

local function cs_say(text, team_only)
    text = cs_sanitize(text)
    if text == "" then return false end
    if console and type(console.say) == "function" then
        console.say(text, team_only and true or false); return true
    end
    if console and type(console.exec) == "function" then
        console.exec((team_only and "say_team " or "say ") .. text); return true
    end
    return false
end

-- Chat spammer
local cs_next_send = nil
events.on("paint", function()
    if not state.cs_enabled then
        if cs_next_send and console and type(console.clear_pending) == "function" then
            console.clear_pending()
        end
        cs_next_send = nil
        return
    end
    local me = entity.local_player()
    if not me then
        cs_next_send = nil
        if console and type(console.clear_pending) == "function" then
            console.clear_pending()
        end
        return
    end
    local now = client.time()
    if not cs_next_send then cs_next_send = now + state.cs_interval; return end
    if now < cs_next_send then return end
    cs_next_send = now + state.cs_interval
    api_safe(function() cs_say(state.cs_message, state.cs_team_only) end)
end)

-- Trashtalk
local TT_KILL = {
    EN = {
        "ez", "1nndog", "1", "nice aa dog", "better resolver", "enigma on top", "cry",
        "1kiddo", "get good", "bot_kick", "nixware?", "xone?", "gamesense.pub", "your aa is trash",
        "next", "free", "gg", "sit", {"your", "resolver", "is", "trash"}, {"gamesense", "on", "top"},
        {"1", "nn", "dog"}, {"1", "1", "1"}, {"sit", "down"}, {"that's", "a", "free"}
    },
    RU = {
        "ez", "1nndog", "1", "найс аа еблан", "лучший ресолвер", "ной в хуй", "1kiddo", "учись играть",
        "bot_kick", "nixware?", "xone?", "gamesense.pub", "у тя аа хуйни", "дальше", "free", "gg", "сядь",
        {"твой", "резолвер", "это", "хуета"}, {"skeet", "skeet", "number 1", "cheat"}, {"1", "nn", "dog"},
        {"1", "1", "1"}, {"падай", "в ноги", "королю"}, {"это", "было", "so free"}
    }
}
local TT_DEATH = {
    EN = {
        "lag", "luck", "resolver-lucky-v1", "nl moment", "lagcomp", "desync", "fake", "kiddo", "you got lucky",
        {"your", "cheat", "is", "carrying", "you"}, {"this guy", "doesn't understand", "he just got", "lucky"},
        {"imagine", "dying", "to", "lucky"}, {"lag", "comp", "moment"}
    },
    RU = {
        "лаг", "лаки", "резолвер-лаки-v1", "nl moment", "лагкомп", "десинк", "фейк", "кид", "как тебе везет ебень",
        {"твой", "чит", "тащит", "тя"}, {"этот чел", "не понимает", "что ему просто", "повезло"},
        {"представь", "умереть", "от", "лаки"}, {"лаг", "комп", "момент"}
    }
}
local TT_PART_DELAY = 0.35
local tt_queue = {}
local function tt_pick(list) return list[math.random(1, #list)] end
local function tt_send(phrase)
    if type(phrase) == "string" then cs_say(phrase, false); return end
    if type(phrase) ~= "table" or #phrase == 0 then return end
    for i, part in ipairs(phrase) do
        local when = (i - 1) * TT_PART_DELAY
        if when <= 0 then cs_say(part, false)
        else tt_queue[#tt_queue + 1] = { time = client.time() + when, text = part } end
    end
end
events.on("paint", function()
    if #tt_queue == 0 then return end
    local now = client.time()
    local i = 1
    while i <= #tt_queue do
        if now >= tt_queue[i].time then
            local txt = tt_queue[i].text
            api_safe(function() cs_say(txt, false) end)
            tt_queue[i] = tt_queue[#tt_queue]
            tt_queue[#tt_queue] = nil
        else i = i + 1 end
    end
end)
local function tt_get_pool(situation, lang)
    local base_pool = (situation == "kill") and TT_KILL[lang] or TT_DEATH[lang]
    if not base_pool then return {} end
    if state.tt_phrases_mode == 1 then return base_pool end

    local sel_key = "tt_sel_" .. situation .. "_" .. lang:lower()
    local sel = state[sel_key] or {}
    local filtered = {}
    for i = 1, #base_pool do
        if sel[i] then filtered[#filtered + 1] = base_pool[i] end
    end
    return filtered
end

events.on("game_event", function(ev)
    if not state.tt_enabled or not ev or ev.name ~= "player_death" then return end
    local lang = state.tt_lang == 2 and "RU" or "EN"
    local sit = state.tt_situations or {}
    if ev.attacker == 0 and ev.userid ~= 0 and sit[1] then
        local pool = tt_get_pool("kill", lang)
        if #pool > 0 then api_safe(function() tt_send(tt_pick(pool)) end) end
    elseif ev.userid == 0 and ev.attacker ~= 0 and sit[2] then
        local pool = tt_get_pool("death", lang)
        if #pool > 0 then api_safe(function() tt_send(tt_pick(pool)) end) end
    end
end)
events.on("shutdown", function()
    tt_queue = {}
    if console and type(console.clear_pending) == "function" then
        console.clear_pending()
    end
end)

-- Background blur + particles
local blur_fade = 0
local particles_fade = 0
local blur_particles_state = nil

local function init_blur_particles(sw, sh)
    local ps = { sw = sw, sh = sh, stars = {}, snow = {}, orbs = {} }
    for i = 1, 60 do
        ps.stars[i] = { x = math.random() * sw, y = math.random() * sh,
            size = 0.6 + math.random() * 1.8, phase = math.random() * 6.28,
            speed = 0.8 + math.random() * 1.5, base_a = 90 + math.random(0, 140),
            blink_start = nil, blink_end = nil,
            blink_next = math.random() * 3.0 }
    end
    for i = 1, 110 do
        ps.snow[i] = { x = math.random() * sw, y = math.random() * sh,
            size = 0.9 + math.random() * 2.2, vy = 20 + math.random() * 45,
            drift_phase = math.random() * 6.28, drift_amp = 0.6 + math.random() * 1.6 }
    end
    for i = 1, 35 do
        ps.orbs[i] = { x = math.random() * sw, y = math.random() * sh,
            size = 2 + math.random() * 7,
            vx = (math.random() - 0.5) * 70, vy = (math.random() - 0.5) * 70 }
    end
    blur_particles_state = ps
end

local function draw_blur_particles(idx, sw, sh, fade, dt, now)
    if idx < 1 or idx > 3 then return end
    if not blur_particles_state or blur_particles_state.sw ~= sw
       or blur_particles_state.sh ~= sh then
        init_blur_particles(sw, sh)
    end
    local ps = blur_particles_state
    local mspd = state.particles_move_speed or 1.0
    if idx == 1 then
        for i = 1, #ps.stars do
            local s = ps.stars[i]

            if s.blink_end and now >= s.blink_end then
                s.blink_start = nil; s.blink_end = nil
                s.blink_next = now + 1.2 + math.random() * 3.5
            end
            if not s.blink_start and now >= (s.blink_next or 0) then
                s.blink_start = now
                s.blink_end = now + 0.25 + math.random() * 0.6
            end

            local blink_k = 1.0
            if s.blink_start and s.blink_end then
                local t_in  = math.min(1, (now - s.blink_start) / 0.2)
                local t_out = math.min(1, (s.blink_end - now) / 0.2)
                local t = math.min(t_in, t_out)
                blink_k = 0.12 + 0.88 * (1 - t)
            end

            local twinkle = 0.5 + 0.5 * math.sin(now * s.speed * mspd + s.phase)
            local a = math.floor(s.base_a * twinkle * fade * blink_k)
            if a > 3 then
                render.circle(s.x, s.y, s.size + 1.2, {220, 235, 255, math.floor(a * 0.35)}, true)
                render.circle(s.x, s.y, s.size, {245, 250, 255, a}, true)
            end
        end
    elseif idx == 2 then
        for i = 1, #ps.snow do
            local s = ps.snow[i]
            s.y = s.y + s.vy * mspd * dt
            s.x = s.x + math.sin(now * s.drift_amp * mspd + s.drift_phase) * 18 * mspd * dt

            if s.y > sh + 20 then
                s.y = -20
                s.x = math.random() * sw
            end
            if s.x < -20 then s.x = sw + 20
            elseif s.x > sw + 20 then s.x = -20 end

            local edge = 1.0
            if s.y < 20 then edge = math.max(0, s.y / 20)
            elseif s.y > sh - 20 then edge = math.max(0, (sh - s.y) / 20) end

            local a = math.floor(210 * fade * edge)
            if a > 3 then
                render.circle(s.x, s.y, s.size, {240, 245, 255, a}, true)
            end
        end
    elseif idx == 3 then
        local orbs = ps.orbs
        for i = 1, #orbs do
            local o = orbs[i]
            o.x = o.x + o.vx * mspd * dt
            o.y = o.y + o.vy * mspd * dt
            if o.x < -o.size then o.x = sw + o.size
            elseif o.x > sw + o.size then o.x = -o.size end
            if o.y < -o.size then o.y = sh + o.size
            elseif o.y > sh + o.size then o.y = -o.size end
            o.vx = o.vx + (math.random() - 0.5) * 40 * dt
            o.vy = o.vy + (math.random() - 0.5) * 40 * dt
            if math.abs(o.vx) > 90 then o.vx = o.vx > 0 and 90 or -90 end
            if math.abs(o.vy) > 90 then o.vy = o.vy > 0 and 90 or -90 end
        end
        local LINK = 180
        for i = 1, #orbs - 1 do
            for j = i + 1, #orbs do
                local dx, dy = orbs[i].x - orbs[j].x, orbs[i].y - orbs[j].y
                local d2 = dx*dx + dy*dy
                if d2 < LINK * LINK then
                    local d = math.sqrt(d2)
                    local a = math.floor((1 - d / LINK) * 130 * fade)
                    if a > 3 then
                        render.line(orbs[i].x, orbs[i].y, orbs[j].x, orbs[j].y,
                            {150, 190, 255, math.floor(a * 0.30)}, 4)
                        render.line(orbs[i].x, orbs[i].y, orbs[j].x, orbs[j].y,
                            {200, 220, 255, a}, 1)
                    end
                end
            end
        end
        for i = 1, #orbs do
            local o = orbs[i]
            local a = math.floor(160 * fade)
            if a > 3 then
                render.circle(o.x, o.y, o.size * 3.0, {140, 180, 255, math.floor(a * 0.06)}, true)
                render.circle(o.x, o.y, o.size * 2.0, {160, 200, 255, math.floor(a * 0.14)}, true)
                render.circle(o.x, o.y, o.size * 1.4, {190, 215, 255, math.floor(a * 0.30)}, true)
                render.circle(o.x, o.y, o.size, {230, 240, 255, a}, true)
            end
        end
    end
end

-- AutoBuy
-- AutoBuy
local function do_buy()
    if not state.cb_weapons then return end
    local cmds = {}
    local prim = state.combo_primary
    if prim == 3 then cmds[#cmds+1] = "buy ssg08"
    elseif prim == 2 then cmds[#cmds+1] = "buy awp"
    elseif prim == 1 then
        local me = entity.local_player()
        if me then
            if me.team == 2 then cmds[#cmds+1] = "buy g3sg1"
            elseif me.team == 3 then cmds[#cmds+1] = "buy scar20" end
        end
    elseif prim == 4 then cmds[#cmds+1] = "buy negev" end
    if state.combo_secondary == 1 then cmds[#cmds+1] = "buy revolver"
    elseif state.combo_secondary == 2 then cmds[#cmds+1] = "buy deagle" end
    local armor = state.combo_armor or 1
    if armor == 2 then cmds[#cmds+1] = "buy vest"
    elseif armor == 3 then cmds[#cmds+1] = "buy vesthelm" end
    if state.cb_utility then
        local u = state.multi_utility
        if u[2] then cmds[#cmds+1] = "buy incgrenade; buy molotov" end
        if u[3] then cmds[#cmds+1] = "buy hegrenade" end
        if u[4] then cmds[#cmds+1] = "buy smokegrenade" end
        if u[5] then cmds[#cmds+1] = "buy flashbang" end
        if u[6] then cmds[#cmds+1] = "buy decoy" end
        local a = state.multi_another
        if a[2] then cmds[#cmds+1] = "buy taser" end
        if a[3] then cmds[#cmds+1] = "buy defuser" end
    end
    if #cmds == 0 then return end
    console.exec(table.concat(cmds, "; "))
end

local buy_pending = false
local buy_time = 0
local buy_attempts = 0
local BUY_RETRY_INTERVAL = 0.25
local BUY_MAX_ATTEMPTS = 12

events.on("game_event", function(e)
    if not e or e.name ~= "round_start" then return end
    buy_pending = true
    buy_attempts = 0
    buy_time = client.time()
    if state.buy_delay_enabled then
        buy_time = buy_time + (state.buy_delay_value or 0.5)
    end
end)

events.on("paint", function()
    if not buy_pending then return end
    local now = client.time()
    if now < buy_time then return end

    local me = entity.local_player()
    if not me or not me.alive then
        buy_attempts = buy_attempts + 1
        if buy_attempts < BUY_MAX_ATTEMPTS then
            buy_time = now + BUY_RETRY_INTERVAL
        else
            buy_pending = false
        end
        return
    end

    api_safe(do_buy)
    buy_attempts = buy_attempts + 1

    if buy_attempts < 3 then
        buy_time = now + BUY_RETRY_INTERVAL
    else
        buy_pending = false
    end
end)

-- Awall
local aw_target, aw_is_pen, aw_init = nil, false, false
local aw_pos = {x=0, y=0, z=0}
local aw_expires = 0
local function aw_reset() aw_target = nil; aw_is_pen = false; aw_init = false end
events.on("shutdown", aw_reset)
events.on("pre_rage", function()
    if not (state.aw_truth and state.aw_visual) then aw_reset(); return end
    local me = entity.local_player()
    if not me or not me.alive then aw_reset(); return end
    local best, best_s = nil, -math.huge
    for _, pl in ipairs(entity.players(true)) do
        if pl.alive then
            local dx, dy, dz = pl.origin.x - me.origin.x, pl.origin.y - me.origin.y, pl.origin.z - me.origin.z
            if dx*dx + dy*dy + dz*dz < 4000*4000 then
                local hb = combat.hitboxes(pl.id)
                if hb then
                    for _, h2 in ipairs(hb.hitboxes) do
                        local d = combat.damage(pl.id, h2.center, hb.tick)
                        if d then
                            local sc = d.damage
                            if d.penetrated then sc = sc + 20 end
                            if d.hitgroup == 1 then sc = sc + 40 end
                            if sc > best_s then
                                best = {pos = h2.center, pen = d.penetrated}
                                best_s = sc
                            end
                        end
                    end
                end
            end
        end
    end
    if best then
        aw_target = {x = best.pos.x, y = best.pos.y, z = best.pos.z}
        aw_is_pen = best.pen
        aw_expires = client.time() + state.aw_hold
    else aw_reset() end
end)
events.on("paint", function()
    if not (state.aw_truth and state.aw_visual) then aw_reset(); return end
    if client.time() > aw_expires then aw_reset(); return end
    if not aw_target then return end
    if not aw_init then
        aw_pos.x, aw_pos.y, aw_pos.z = aw_target.x, aw_target.y, aw_target.z
        aw_init = true
    else
        local k = 1 - math.exp(-state.aw_smooth * 20 * render.frame_time())
        aw_pos.x = aw_pos.x + (aw_target.x - aw_pos.x) * k
        aw_pos.y = aw_pos.y + (aw_target.y - aw_pos.y) * k
        aw_pos.z = aw_pos.z + (aw_target.z - aw_pos.z) * k
    end
    local sx, sy, on = render.world_to_screen(aw_pos)
    if not sx or not on then return end
    local sz, half = state.aw_sq_size, state.aw_sq_size * 0.5
    local b = aw_is_pen and state.aw_col_through or state.aw_col_blocked
    render.rect(sx - half, sy - half, sz, sz, {b.r, b.g, b.b, 255}, false)
    render.rect(sx - half + 1, sy - half + 1, sz - 2, sz - 2, {b.r, b.g, b.b, 80}, true)
end)

-- NAMECHANGER
local nc_data = nil

-- status: "init" | "ok" | "no_ffi" | "no_dll" | "dll_init_failed"
local NC_STATUS = "init"

local function nc_init()
    -- 1. ffi
    local ffi_mod = rawget(_G, "ffi")
    if not ffi_mod then
        local rok, r = _pcall(require, "ffi")
        if rok and r then ffi_mod = r end
    end
    if not ffi_mod then
        NC_STATUS = "no_ffi"
        return
    end

    -- 2. cdefs (kernel32 helpers)
    _pcall(ffi_mod.cdef, [[
        void* __stdcall LoadLibraryA(const char*);
        unsigned int __stdcall GetCurrentDirectoryA(unsigned int, char*);
        unsigned int __stdcall GetModuleFileNameA(void*, char*, unsigned int);
        unsigned int __stdcall ExpandEnvironmentStringsA(const char*, char*, unsigned int);
        int  nc_init(void);
        int  nc_set(const char*);
        int  nc_set_clantag(const char*, const char*);
        int  nc_disable(void);
        int  nc_tick(void);
    ]])

    local k32_ok, k32 = _pcall(ffi_mod.load, "kernel32")
    if not k32_ok or not k32 then
        NC_STATUS = "no_dll"
        return
    end

    -- 3. CWD via GetCurrentDirectoryA
    local cwd = nil
    _pcall(function()
        local buf = ffi_mod.new("char[1024]")
        local len = k32.GetCurrentDirectoryA(1024, buf)
        if len > 0 and len < 1024 then
            cwd = ffi_mod.string(buf, len)
        end
    end)

    -- 4. process exe dir via GetModuleFileNameA
    local exe_dir = nil
    _pcall(function()
        local buf = ffi_mod.new("char[1024]")
        local len = k32.GetModuleFileNameA(nil, buf, 1024)
        if len > 0 and len < 1024 then
            local full = ffi_mod.string(buf, len)
            exe_dir = full:match("^(.*)[/\\][^/\\]+$")
        end
    end)

    -- 5. env expansion via ExpandEnvironmentStringsA
    local function expand(env_str)
        local result = nil
        _pcall(function()
            local buf = ffi_mod.new("char[1024]")
            local len = k32.ExpandEnvironmentStringsA(env_str, buf, 1024)
            if len > 0 and len < 1024 then
                result = ffi_mod.string(buf, len - 1)  -- drop trailing \0
            end
        end)
        return result
    end

    local localappdata = expand("%LOCALAPPDATA%")
    local appdata      = expand("%APPDATA%")
    local userprofile  = expand("%USERPROFILE%")

    -- 6. build candidate list
    local candidates = {}
    local seen = {}
    local function add(p)
        if p and p ~= "" and not seen[p] then
            seen[p] = true
            candidates[#candidates+1] = p
        end
    end

    -- 6a. user override (highest priority)
    local ov = storage.get("nc_dll_override", nil)
    if type(ov) == "string" and ov ~= "" then
        add(ov)
    end

    -- 6b. LOCALAPPDATA\skeet\native\
    if localappdata then
        add(localappdata .. "\\skeet\\native\\namechanger.dll")
        add(localappdata .. "/skeet/native/namechanger.dll")
        add(localappdata .. "\\skeet\\namechanger.dll")
    end

    -- 6c. APPDATA\skeet\native\
    if appdata then
        add(appdata .. "\\skeet\\native\\namechanger.dll")
        add(appdata .. "/skeet/native/namechanger.dll")
    end

    -- 6d. USERPROFILE\AppData\Local\skeet\native\
    if userprofile then
        add(userprofile .. "\\AppData\\Local\\skeet\\native\\namechanger.dll")
        add(userprofile .. "/AppData/Local/skeet/native/namechanger.dll")
    end

    -- 6e. CWD-relative
    if cwd then
        add(cwd .. "\\native\\namechanger.dll")
        add(cwd .. "/native/namechanger.dll")
        add(cwd .. "\\namechanger.dll")
        add(cwd .. "/namechanger.dll")
    end

    -- 6f. exe-relative
    if exe_dir then
        add(exe_dir .. "\\namechanger.dll")
        add(exe_dir .. "/namechanger.dll")
    end

    -- 6g. last resort
    add("native/namechanger.dll")
    add("namechanger.dll")

    -- GetFileAttributesA (fast stat, no DLL loading)
    _pcall(ffi_mod.cdef, "unsigned int __stdcall GetFileAttributesA(const char*);")

    local INVALID_ATTRS = 0xFFFFFFFF

    local lib = nil
    for i, path in ipairs(candidates) do

        local attrs = INVALID_ATTRS
        _pcall(function()
            local a = k32.GetFileAttributesA(path)
            attrs = tonumber(a) or INVALID_ATTRS
        end)

        if attrs == INVALID_ATTRS or attrs == 4294967295 then
        else
            _pcall(k32.LoadLibraryA, path)
            local lok, l = _pcall(ffi_mod.load, path)
            if lok and l then
                lib = l
                break
            else
            end
        end
    end

    if not lib then
        NC_STATUS = "no_dll"
        return
    end

    -- 8. init
    local init_ok, init_ret = _pcall(lib.nc_init)
    if not init_ok then
        NC_STATUS = "dll_init_failed"
        return
    end

    -- 9. nc_data
    nc_data = {
        ffi = ffi_mod, lib = lib,
        buf_nick  = ffi_mod.new("char[256]"),
        buf_empty = ffi_mod.new("char[1]", ""),
        buf_sep   = ffi_mod.new("char[2]", " "),
        cached_base = nil, cached_frames = nil, cached_mode = nil,
        cached_wrap = nil, cached_cursor = nil,
        last_combined = nil, last_ui_poll = 0,
        cached_ui = { nc_on = false, last_n = "", last_t = "", last_pos = 1, nc_cursor = 1 },
        alive = true,
    }
    NC_STATUS = "ok"
end
_pcall(nc_init)
api_safe(nc_init)

local LOOKALIKE = {
    e="3", i="1", s={"$", "5"}, g="9", a="@", o="0", t="7", l="|", b="8", z="2",
    w="\\/\\/", v="\\/", N="/\\/", m="rn", M="/\\/\\",
}

local function nc_wrap(t, w)
    if w == 1 then return "[" .. t .. "]"
    elseif w == 2 then return "{" .. t .. "}"
    elseif w == 3 then return "<" .. t .. ">"
    elseif w == 4 then return "= " .. t .. " =" end
    return t
end

local function nc_typing(t, w, cursor_idx)
    local cur = CURSOR_CHARS[cursor_idx or 1] or "|"
    local pre, suf = "", ""
    if w == 1 then pre, suf = "[", "]"
    elseif w == 2 then pre, suf = "{", "}"
    elseif w == 3 then pre, suf = "<", ">"
    elseif w == 4 then pre, suf = "= ", " =" end
    local f = {pre .. cur .. suf, pre .. suf}
    for i = 1, #t do
        local p = pre .. t:sub(1, i) .. cur .. suf
        f[#f+1] = p
        if i==2 or i==4 or i==5 or i==7 or i==8 then
            f[#f+1] = pre .. t:sub(1, i) .. suf; f[#f+1] = p
        end
    end
    f[#f+1] = pre .. t .. suf; f[#f+1] = pre .. t .. cur .. suf; f[#f+1] = pre .. t .. suf
    for i = #t-1, 1, -1 do
        local p = pre .. t:sub(1, i) .. cur .. suf
        f[#f+1] = pre .. t:sub(1, i) .. suf; f[#f+1] = p
        if i==4 or i==2 then f[#f+1] = pre .. t:sub(1, i) .. suf; f[#f+1] = p end
    end
    f[#f+1] = pre .. suf; f[#f+1] = pre .. cur .. suf
    return f
end

local function nc_jitter(t, w)
    t = nc_wrap(t, w)
    local f = {t}
    for _ = 1, 6 do
        local c = {}
        for i = 1, #t do c[i] = t:sub(i, i) end
        for _ = 1, math.min(2, #t) do
            local p = math.random(1, #t); local r = LOOKALIKE[c[p]]
            if type(r) == "table" then r = r[math.random(1, #r)] end
            if r then c[p] = r end
        end
        f[#f+1] = table.concat(c); f[#f+1] = t
    end
    return f
end

local function nc_slide(t, w)
    t = nc_wrap(t, w)
    local f = {}
    local p = t .. "    " .. t
    for i = 1, #p - 4 do f[#f+1] = p:sub(i, i+4) end
    return f
end

local function nc_sync(now)
    if not nc_data or not nc_data.alive then return end
    local cu, lib = nc_data.cached_ui, nc_data.lib
    if not cu.nc_on then
        if nc_data.last_combined ~= nil then
            lib.nc_set_clantag(nc_data.buf_empty, nc_data.buf_sep)
            lib.nc_disable(); nc_data.last_combined = nil
        end
        return
    end
    local n = ""
    if cu.nc_type == 2 then
        local names = cu.nc_valid_names or {}
        local selected = {}
        if cu.nc_steal_mode == 1 then
            local idx = cu.nc_steal_single or 1
            if names[idx] then selected[1] = names[idx] end
        elseif cu.nc_steal_mode == 2 then
            for i = 1, #names do
                if cu.nc_steal_multi[i] then selected[#selected+1] = names[i] end
            end
        end

        if #selected > 0 then
            if cu.nc_steal_mode == 1 then
                n = selected[1]
            else
                local delay = cu.nc_steal_delay or 1.0
                n = selected[math.floor(now / delay) % #selected + 1]
            end
        end
    else
        n = cu.nc_name or ""
    end
    if n == "" then n = " " end
    local t = ""
    local wrap = cu.tag_wrap_enabled and (cu.tag_wrap or 1) or 0
    local cursor = cu.nc_cursor or 1
    if cu.tag_on then
        local base = ""
        if cu.tag_source == 3 then
            local selected = {}
            local presets = cu.tag_presets or {}
            local pfx_t = cu.tag_pfx or {}
            for i = 1, #NC_TAG_PRESETS do
                if presets[i] then
                    local preset = NC_TAG_PRESETS[i]
                    local pfx = ""
                    if preset.postfixes then
                        local si = pfx_t[i] or 1
                        if si > 1 then pfx = preset.postfixes[si] or "" end
                    end
                    selected[#selected + 1] = preset.name .. pfx
                end
            end
            if #selected > 0 then
                if #selected > 1 and (cu.swap_delay or 1.0) > 0.01 then
                    base = selected[math.floor(now / cu.swap_delay) % #selected + 1]
                else
                    base = selected[1]
                end
            end
        elseif cu.tag_source == 2 then
            local idx = cu.tag_single or 1
            local preset = NC_TAG_PRESETS[idx]
            if preset then
                local pfx = ""
                if preset.postfixes then
                    local si = cu.nc_pfx_single or 1
                    if si > 1 then pfx = preset.postfixes[si] or "" end
                end
                base = preset.name .. pfx
            end
        else
            base = cu.tag_txt or ""
        end

        local mode = cu.tag_anim_enabled and (cu.tag_mode or 1) or 0
        if base ~= "" then
            if nc_data.cached_base ~= base or nc_data.cached_mode ~= mode
               or nc_data.cached_wrap ~= wrap or nc_data.cached_cursor ~= cursor then
                nc_data.cached_base, nc_data.cached_mode, nc_data.cached_wrap, nc_data.cached_cursor
                    = base, mode, wrap, cursor
                if mode == 1 then nc_data.cached_frames = nc_typing(base, wrap, cursor)
                elseif mode == 2 then nc_data.cached_frames = nc_jitter(base, wrap)
                elseif mode == 3 then nc_data.cached_frames = nc_slide(base, wrap)
                else nc_data.cached_frames = {nc_wrap(base, wrap)} end
            end
            if mode >= 1 and #base >= 2 then
                local sp = math.max(0.01, cu.tag_speed * 0.3)
                t = nc_data.cached_frames[math.floor(now / sp) % #nc_data.cached_frames + 1]
            else
                t = nc_data.cached_frames[1]
            end
        end
    end
    if n ~= cu.last_n or t ~= cu.last_t or cu.tag_pos ~= cu.last_pos then
        cu.last_n, cu.last_t, cu.last_pos = n, t, cu.tag_pos
        local comb = n
        if t ~= "" then
            if cu.tag_pos == 2 then comb = n .. " " .. t else comb = t .. " " .. n end
        end
        if #comb > 127 then comb = comb:sub(1, 127) end
        if comb ~= nc_data.last_combined then
            lib.nc_set_clantag(nc_data.buf_empty, nc_data.buf_sep)
            nc_data.ffi.copy(nc_data.buf_nick, comb)
            nc_data.buf_nick[#comb] = 0
            if lib.nc_set(nc_data.buf_nick) == 0 then nc_data.last_combined = comb end
        end
    end
end

local nc_sanitize_nick
do
    function nc_sanitize_nick(s)
        s = tostring(s or ""):gsub('[%c"\\;]', "")
        if #s > 64 then s = s:sub(1, 64) end
        return s
    end
end

-- Кеш реального controller ID локального игрока
local nc_local_real_id = nil
local nc_local_id_last_poll = 0

local function nc_find_local_real_id(players)
    local me = entity.local_player()
    if not me then return nil end

    -- Быстрый путь: кеш ещё валиден?
    if nc_local_real_id then
        for _, pl in ipairs(players) do
            if pl.id == nc_local_real_id then return nc_local_real_id end
        end
        nc_local_real_id = nil
    end

    -- Прямой ID, если API вдруг отдал не 0
    if me.id and me.id ~= 0 then
        nc_local_real_id = me.id
        return me.id
    end

    -- Основной путь: match по origin (не анимируется)
    if me.origin and me.origin.x then
        local best_pl, best_d2 = nil, math.huge
        for _, pl in ipairs(players) do
            if pl.origin and pl.origin.x then
                local dx = pl.origin.x - me.origin.x
                local dy = pl.origin.y - me.origin.y
                local dz = pl.origin.z - me.origin.z
                local d2 = dx*dx + dy*dy + dz*dz
                if d2 < best_d2 then
                    best_d2, best_pl = d2, pl
                end
            end
        end
        if best_pl and best_d2 < 100 * 100 then
            nc_local_real_id = best_pl.id
            return best_pl.id
        end
    end

    -- Fallback: точное совпадение ника (сработает, если анимация паузует)
    if me.name then
        for _, pl in ipairs(players) do
            if pl.name == me.name then
                nc_local_real_id = pl.id
                return pl.id
            end
        end
    end

    return nil
end

local function nc_get_valid_names()
    local players = entity.players()
    if not players or #players == 0 then return {} end

    local my_real_id = nc_find_local_real_id(players)

    local names, seen = {}, {}
    for _, pl in ipairs(players) do
        local skip = (pl.id == 0) or (my_real_id ~= nil and pl.id == my_real_id)
        if not skip then
            local sname = nc_sanitize_nick(pl.name)
            if #sname > 0 and not seen[sname] then
                seen[sname] = true
                names[#names+1] = sname
            end
        end
    end
    table.sort(names)
    return names
end

local function nc_tick_paint()
    if not nc_data or not nc_data.alive then return end
    local now = client.time()
    if now - nc_data.last_ui_poll > 0.1 then
        nc_data.last_ui_poll = now
        local cu = nc_data.cached_ui
        cu.nc_on = state.nc_on
        if cu.nc_on then
            cu.nc_type = state.nc_type
            cu.nc_name = state.nc_name:sub(1, 64)
            cu.nc_steal_mode = state.nc_steal_mode
            cu.nc_steal_single = state.nc_steal_single
            cu.nc_steal_multi = state.nc_steal_multi or {}
            cu.nc_steal_delay = state.nc_steal_delay or 1.0
            if state.nc_type == 2 then
                cu.nc_valid_names = nc_get_valid_names()
            end
            cu.tag_txt = state.nc_tag:sub(1, 64)
            cu.tag_on, cu.tag_wrap, cu.tag_mode, cu.tag_pos =
                state.nc_tag_on, state.nc_tag_wrap, state.nc_tag_mode, state.nc_tag_pos
            cu.tag_speed = state.nc_tag_spd
            cu.nc_cursor = state.nc_cursor or 1
            cu.tag_source = state.nc_tag_source or 1
            cu.tag_single = state.nc_tag_single or 1
            cu.nc_pfx_single = state.nc_pfx_single or 1
            cu.tag_presets = state.nc_tag_presets or {}
            cu.swap_delay = state.nc_swap_delay or 1.0
            cu.tag_wrap_enabled = state.nc_tag_wrap_enabled == true
            cu.tag_anim_enabled = state.nc_tag_anim_enabled == true
            local pfx = {}
            for i = 1, #NC_TAG_PRESETS do
                pfx[i] = state["nc_pfx_" .. i] or 1
            end
            cu.tag_pfx = pfx
        end
    end
    nc_sync(now)
end
events.on("paint", function() api_safe(nc_tick_paint) end)
events.on("frame_stage", function()
    if not nc_data or not nc_data.alive then return end
    if nc_data.cached_ui.nc_on then
        api_safe(function() nc_data.lib.nc_tick() end)
    end
end)
events.on("shutdown", function()
    if not nc_data then return end
    nc_data.alive = false
    api_safe(function()
        nc_data.lib.nc_set_clantag(nc_data.buf_empty, nc_data.buf_sep)
        nc_data.lib.nc_disable()
    end)
end)

-- ANTI-AIM
local aa_rt = {
    spin_angle     = { aa_stand=0, aa_crouch=0, aa_move=0, aa_air=0 },
    spin_last      = { aa_stand=0, aa_crouch=0, aa_move=0, aa_air=0 },
    jit_phase      = { aa_stand=false, aa_crouch=false, aa_move=false, aa_air=false },
    jit_last       = { aa_stand=0, aa_crouch=0, aa_move=0, aa_air=0 },
    jit_rand       = { aa_stand=0, aa_crouch=0, aa_move=0, aa_air=0 },
    jit_idx        = { aa_stand=0, aa_crouch=0, aa_move=0, aa_air=0 },
    flick_yaw_last = { aa_stand=0, aa_crouch=0, aa_move=0, aa_air=0 },
    flick_yaw_val  = { aa_stand=0, aa_crouch=0, aa_move=0, aa_air=0 },
    flick_yaw_active = { aa_stand=false, aa_crouch=false, aa_move=false, aa_air=false },
    flick_pit_last = { aa_stand=0, aa_crouch=0, aa_move=0, aa_air=0 },
    flick_pit_val  = { aa_stand=0, aa_crouch=0, aa_move=0, aa_air=0 },
    flick_pit_active = { aa_stand=false, aa_crouch=false, aa_move=false, aa_air=false },
}
-- Order: Off(1), Camera(2), Up(3), Down(4), Custom(5)
local AA_PITCH_MAP = { [1] = 3, [2] = 0, [3] = 2, [4] = 1, [5] = 3 }

local AA_RESERVED = {
    ["anti aim"] = true, ["anti-aim"] = true,
    ["rotation"] = true, ["pitch mode"] = true, ["custom pitch"] = true,
}
local AA_MODIFIERS = {}
do
    local try_cats = {"anti aim", "anti-aim", "antiaim", "aa"}
    local seen = {}
    for _, cat in ipairs(try_cats) do
        local ok, list = api.protect(function() return settings.list(cat) end)
        if ok and type(list) == "table" and #list > 0 then
            for _, f in ipairs(list) do
                local real_cat = tostring(f.category or cat)
                local nl = tostring(f.name or ""):lower()
                local key = real_cat .. "/" .. nl
                if not seen[key] then
                    seen[key] = true
                    if not AA_RESERVED[nl] then
                        local t = tostring(f.type or ""):lower()
                        local neutral = nil
                        if t == "boolean" or t == "bool" or t == "checkbox" then neutral = false
                        elseif t == "number" or t == "slider" or t == "float" or t == "int" then neutral = 0 end
                        if neutral ~= nil then
                            AA_MODIFIERS[#AA_MODIFIERS+1] = {
                                cat = real_cat, name = f.name, value = neutral,
                                type = t, writable = f.writable,
                            }
                        end
                    end
                end
            end
        end
    end
end

local function aa_suppress_modifiers()
    for _, m in ipairs(AA_MODIFIERS) do
        if m.writable ~= false then
            api.protect(function() settings.override(m.cat, m.name, m.value) end)
        end
    end
end
local function aa_release_modifiers()
    for _, m in ipairs(AA_MODIFIERS) do
        if m.writable ~= false then
            api.protect(function() settings.override(m.cat, m.name, nil) end)
        end
    end
end
local function aa_release()
    settings.override("anti aim", "rotation", nil)
    settings.override("anti aim", "pitch mode", nil)
    settings.override("anti aim", "custom pitch", nil)
    aa_release_modifiers()
end
local function aa_neutralize_for_state()
    settings.override("anti aim", "rotation", 0)
    settings.override("anti aim", "pitch mode", 0)
    settings.override("anti aim", "custom pitch", nil)
end
local function aa_get_state(me)
    if (me.flags & 1) == 0 then return "aa_air" end
    if (me.flags & 2) ~= 0 then return "aa_crouch" end
    local v = me.velocity
    if math.sqrt(v.x*v.x + v.y*v.y) > 20 then return "aa_move" end
    return "aa_stand"
end

local aa_air_space_last_held = -999
events.on("create_move", function()
    local native_on = settings.get("anti aim", "anti aim")
    if not native_on then aa_release(); return end
    local me = entity.local_player()
    if not me or not me.alive then aa_release(); return end
    aa_suppress_modifiers()

    local sk = aa_get_state(me)
    local interim_stand = false

    if sk == "aa_air" and state.aa_air_only_space then
        local space_down = false
        if client and type(client.key_down) == "function" then
            local ok, res = _pcall(client.key_down, 0x20)  -- VK_SPACE
            if ok and (res == true or (type(res) == "number" and res > 0)) then
                space_down = true
            end
        end
        local now_t = client.time()
        if space_down then
            aa_air_space_last_held = now_t
        end
        local within_threshold = (now_t - aa_air_space_last_held) <= (state.aa_air_space_threshold or 0.5)
        if not space_down and not within_threshold then
            sk = "aa_stand"
            interim_stand = true
        end
    end

    if not state[sk .. "_enabled"] and not interim_stand then
        aa_neutralize_for_state()
        return
    end

    local cs = cmd.get()
    local view_yaw = (cs and cs.angles and cs.angles.y) or 0

    local base_yaw = nil
    if state[sk .. "_at_target"] and cs and cs.angles then
        local look = math.angle_vectors(cs.angles)
        local best_enemy, best_fov = nil, math.huge
        for _, pl in ipairs(entity.players(true)) do
            if pl.alive then
                local to = math.angle_vectors(math.calc_angle(me.origin, pl.origin))
                local fov = math.calc_fov(look, to)
                if fov < best_fov then best_enemy, best_fov = pl, fov end
            end
        end
        if best_enemy then
            local to_enemy = math.calc_angle(me.origin, best_enemy.origin)
            base_yaw = math.normalize_angle(to_enemy.y - view_yaw)
        end
    end
    if base_yaw == nil then
        local yaw_idx = state[sk .. "_yaw"]
        if     yaw_idx == 1 then base_yaw = 0
        elseif yaw_idx == 2 then base_yaw = -90
        elseif yaw_idx == 3 then base_yaw = 90
        elseif yaw_idx == 4 then base_yaw = 0
        else                      base_yaw = state[sk .. "_yaw_custom"] end
    end

    -- Spin / Jitter / Flick (yaw) - types: [1]=Spin, [2]=Jitter, [3]=Random Flick
    local aa_type = state[sk .. "_aa_types"] or 1
    local yaw_aa_on = state[sk .. "_extra_yaw_enabled"] == true
    local spin_on = yaw_aa_on and (aa_type == 1)
    local jitter_on = yaw_aa_on and (aa_type == 2)
    local flick_enabled = state[sk .. "_flick_enabled"] == true
    local flick_axes = state[sk .. "_flick_axes"] or {false, false}
    local flick_yaw_on = flick_enabled and flick_axes[1] == true and not spin_on
    local flick_pit_on = flick_enabled and flick_axes[2] == true

    local off = 0
    local now = client.time()
    if spin_on then
        local dt_spin = now - (aa_rt.spin_last[sk] or now)
        aa_rt.spin_last[sk] = now
        if dt_spin > 0.5 then dt_spin = 0 end
        local dir = state[sk .. "_spin_dir"] == 1 and -1 or 1
        local spd = state[sk .. "_spin_speed"] * 20
        aa_rt.spin_angle[sk] = (aa_rt.spin_angle[sk] + spd * dir * dt_spin) % 360
        off = aa_rt.spin_angle[sk]
    elseif jitter_on then
        local mode = state[sk .. "_jitter_mode"]
        local deg  = state[sk .. "_jitter_degree"]
        local spd  = state[sk .. "_jitter_speed"]
        if mode == 3 then
            if now - aa_rt.jit_last[sk] >= spd then
                aa_rt.jit_last[sk] = now
                aa_rt.jit_rand[sk] = (math.random() * 2 - 1) * deg
            end
            off = aa_rt.jit_rand[sk]
        elseif mode == 4 then
            if now - aa_rt.jit_last[sk] >= spd then
                aa_rt.jit_last[sk] = now
                aa_rt.jit_idx[sk] = (aa_rt.jit_idx[sk] + 1) % 3
            end
            off = ({ -deg, 0, deg })[aa_rt.jit_idx[sk] + 1]
        else
            if now - aa_rt.jit_last[sk] >= spd then
                aa_rt.jit_last[sk] = now
                aa_rt.jit_phase[sk] = not aa_rt.jit_phase[sk]
            end
            if mode == 1 then off = aa_rt.jit_phase[sk] and deg or -deg
            else off = aa_rt.jit_phase[sk] and deg or 0 end
        end
    end

    -- Random Flick (yaw)
    local flick_yaw = 0
    if flick_yaw_on then
        local delay = state[sk .. "_flick_yaw_delay"] or 1.0
        if now - (aa_rt.flick_yaw_last[sk] or 0) >= delay then
            aa_rt.flick_yaw_last[sk] = now
            aa_rt.flick_yaw_active[sk] = true
        end
        if aa_rt.flick_yaw_active[sk] then
            flick_yaw = 180
            aa_rt.flick_yaw_active[sk] = false
        end
    end

    settings.override("anti aim", "rotation", math.normalize_angle(base_yaw + off + flick_yaw))

    -- Pitch (base + flick)
    -- Pitch options: 1=Off, 2=Camera, 3=Up, 4=Down, 5=Custom
    local pitch_idx = state[sk .. "_pitch"]
    local native_mode = AA_PITCH_MAP[pitch_idx] or 3
    local pitch_custom = math.floor((state[sk .. "_pitch_custom"] or 0) + 0.5)

    local flick_pit = 0
    if flick_pit_on then
        local delay = state[sk .. "_flick_pitch_delay"] or 1.0
        if now - (aa_rt.flick_pit_last[sk] or 0) >= delay then
            aa_rt.flick_pit_last[sk] = now
            aa_rt.flick_pit_active[sk] = true
        end
        if aa_rt.flick_pit_active[sk] then
            flick_pit = 1  -- marker: "this is flick tick"
            aa_rt.flick_pit_active[sk] = false
        end
    end

    -- Compute base_pitch (only needed to determine flick direction)
    local vp = (cs and cs.angles and cs.angles.x) or 0
    local base_pitch = nil
    if pitch_idx == 1 then
        base_pitch = 0                                   -- Off
    elseif pitch_idx == 2 then
        base_pitch = math.floor(vp + 0.5)                -- Camera
    elseif pitch_idx == 3 then
        base_pitch = 89                                  -- Up
    elseif pitch_idx == 4 then
        base_pitch = -89                                 -- Down
    elseif pitch_idx == 5 then
        base_pitch = pitch_custom                        -- Custom
    end

    if flick_pit ~= 0 and base_pitch ~= nil then
        -- Flip to opposite of current base
        if base_pitch > 0 then
            settings.override("anti aim", "pitch mode", 1)  -- Down
        else
            settings.override("anti aim", "pitch mode", 2)  -- Up
        end
        settings.override("anti aim", "custom pitch", nil)
    elseif pitch_idx == 1 then
        settings.override("anti aim", "pitch mode", 3)
        settings.override("anti aim", "custom pitch", 50)   -- horizontal
    elseif pitch_idx == 5 then
        settings.override("anti aim", "pitch mode", 3)
        settings.override("anti aim", "custom pitch", pitch_custom)
    else
        settings.override("anti aim", "pitch mode", native_mode)
        settings.override("anti aim", "custom pitch", nil)
    end
end)
events.on("shutdown", aa_release)

-- VISUALS - BACKTRACK / CROSSHAIR / TRAIL / ARROWS
local function as_arr(c) return {c.r, c.g, c.b, c.a} end

local bt_scan, bt_chosen, bt_eye = {}, nil, nil
local function bt_lerp(bad, good, t)
    return {
        math.floor(bad[1] + (good[1] - bad[1]) * t),
        math.floor(bad[2] + (good[2] - bad[2]) * t),
        math.floor(bad[3] + (good[3] - bad[3]) * t),
        math.floor(bad[4] + (good[4] - bad[4]) * t),
    }
end
local function bt_scale_alpha(c, k) return math.floor(math.min(255, math.max(0, c[4] * k))) end
local function bt_fov(look, point, from)
    local to = math.angle_vectors(math.calc_angle(from, point))
    return math.calc_fov(look, to)
end
local function bt_usable(recs, now)
    local out = {}
    for i = 1, #recs do
        local r = recs[i]
        local age = (now - r.time) * 1000
        if not r.future and age >= 0 and age <= state.bt_age then
            out[#out+1] = { rec = r, age = age }
        end
    end
    table.sort(out, function(a,b) return a.age > b.age end)
    while #out > state.bt_records do out[#out] = nil end
    return out
end

local bt_death_snap = nil

-- Backtrack: for scanning while dead (Continue mode)
local last_alive_game_time = 0
local last_alive_client_time = 0

-- Globals for scan tracking
local bt_last_gametime = 0
local bt_last_walltime = 0
local bt_paint_last = 0
local bt_hb_cache = {}

local function bt_scan_tick()
    local ctx = combat.context()
    if not ctx or not ctx.valid or not ctx.eye then return end
    bt_scan, bt_chosen = {}, nil
    bt_eye = ctx.eye
    local snap = cmd.get()
    if not snap or not snap.angles then return end
    local look = math.angle_vectors(snap.angles)
    local enemies = entity.players(true)
    local q, q_limit = 0, state.bt_queries
    local mode = state.bt_targets_mode or 1

    local candidates = {}
    for _, e in ipairs(enemies) do
        if e.alive and e.enemy then
            local recs = combat.records(e.id)
            if recs and #recs > 0 then
                local to = math.angle_vectors(math.calc_angle(ctx.eye, e.origin))
                local fov = math.calc_fov(look, to)
                candidates[#candidates+1] = { e = e, fov = fov }
            end
        end
    end
    table.sort(candidates, function(a, b) return a.fov < b.fov end)

    local target_limit
    if mode == 1 then target_limit = 1
    elseif mode == 2 then target_limit = #candidates
    else target_limit = state.bt_targets or 1 end

    local scanned = 0
    for i = 1, #candidates do
        if scanned >= target_limit then break end
        local e = candidates[i].e
        local recs = combat.records(e.id)
        if recs and #recs > 0 then
            local list = bt_usable(recs, ctx.time)
            if state.bt_mode == 2 and #list > 0 then list = { list[1] } end
            if #list > 0 then scanned = scanned + 1 end
            for k = 1, #list do
                if q >= q_limit then break end
                local r = list[k].rec
                local geo = combat.hitboxes(e.id, r.tick)
                if geo and geo.hitboxes and #geo.hitboxes > 0 then
                    local best_box, best_h = nil, -math.huge
                    for _, b in ipairs(geo.hitboxes) do
                        local h = b.center.z - r.origin.z
                        if h > best_h then best_h = h; best_box = b end
                    end
                    if best_box then
                        local fov = bt_fov(look, best_box.center, ctx.eye)
                        if fov <= state.bt_fov then
                            local hc = combat.hitchance(e.id, best_box.center, best_box.index, r.tick)
                            q = q + 1
                            if hc and hc > 0 then
                                if hc >= state.bt_hc and
                                   (not bt_chosen or hc > bt_chosen.hc
                                    or (hc == bt_chosen.hc and fov < bt_chosen.fov)) then
                                    bt_chosen = { hc=hc, age=list[k].age, fov=fov,
                                                  id=e.id, tick=r.tick, point=best_box.center }
                                end
                                bt_scan[#bt_scan+1] = { hitboxes = geo.hitboxes, hc = hc,
                                                        age = list[k].age, id = e.id, tick = r.tick }
                            end
                        end
                    end
                end
            end
        end
    end
end
events.on("pre_rage", function()
    if not state.bt_enabled then bt_scan, bt_chosen = {}, nil; return end

    local me = entity.local_player()
    if not me or not me.alive then return end

    -- Live scan (used while alive and drawn in paint when alive)
    bt_scan_tick()

    -- Snapshot newest records for "Last pos" (used when dead)
    local full = {}
    for _, e in ipairs(entity.players(true)) do
        if e.alive and e.enemy then
            local recs = combat.records(e.id)
            if recs and #recs > 0 then
                local newest = nil
                for _, r in ipairs(recs) do
                    if not r.future then newest = r; break end
                end
                if newest then
                    local geo = combat.hitboxes(e.id, newest.tick)
                    if geo and geo.hitboxes then
                        full[#full+1] = {
                            hitboxes = geo.hitboxes, hc = 0, age = 0,
                            id = e.id, tick = newest.tick,
                        }
                    end
                end
            end
        end
    end
    bt_death_snap = full
end)
events.on("shutdown", function() bt_scan, bt_chosen, bt_death_snap = {}, nil, nil end)
local function bt_draw_capsule(hb, fill, outline)
    local ax, ay = render.world_to_screen(hb.capsule_a)
    local bx, by = render.world_to_screen(hb.capsule_b)
    if not ax or not ay or not bx or not by then return end
    local dx, dy, dz = hb.capsule_b.x - hb.capsule_a.x, hb.capsule_b.y - hb.capsule_a.y, hb.capsule_b.z - hb.capsule_a.z
    local wd = math.sqrt(dx*dx + dy*dy + dz*dz)
    local sd = math.sqrt((bx-ax)^2 + (by-ay)^2)
    local sr = (wd > 1) and hb.radius * (sd / wd) or hb.radius
    if sr < 1 then sr = 1 end
    if fill[4] > 0 then
        render.line(ax, ay, bx, by, fill, math.max(1, sr * 2))
        render.circle(ax, ay, sr, fill, true); render.circle(bx, by, sr, fill, true)
    end
    if outline[4] > 0 then
        render.circle(ax, ay, sr, outline, false, 1)
        render.circle(bx, by, sr, outline, false, 1)
        if sd > 0.1 then
            local ang = math.atan(by - ay, bx - ax)
            local nx, ny = math.cos(ang + math.pi/2), math.sin(ang + math.pi/2)
            render.line(ax+nx*sr, ay+ny*sr, bx+nx*sr, by+ny*sr, outline, 1)
            render.line(ax-nx*sr, ay-ny*sr, bx-nx*sr, by-ny*sr, outline, 1)
        end
    end
end
events.on("paint", function()
    if not state.bt_enabled then return end

    local me = entity.local_player()
    local alive = me and me.alive

    local to_draw, is_death_view
    if alive then
        to_draw = bt_scan
        is_death_view = false
    else
        if state.bt_history == 1 then
            -- Last pos: snapshot of death tick
            to_draw = bt_death_snap or {}
            is_death_view = true
        else
            -- Clear
            to_draw = {}
            is_death_view = false
        end
    end
    if #to_draw == 0 then return end

    local good, bad = as_arr(state.bt_col_ok), as_arr(state.bt_col_bad)
    local info_col = as_arr(state.bt_info_col)
    local m_all, m_one = state.bt_mult_all, state.bt_mult_one

    for i = 1, #to_draw do
        local rec = to_draw[i]
        local c, fill, outline
        if is_death_view then
            c = info_col
            fill    = {c[1], c[2], c[3], math.floor(c[4] * 0.12 * m_all)}
            outline = {c[1], c[2], c[3], math.floor(c[4] * m_all)}
        else
            local is_chosen = bt_chosen and (rec.tick == bt_chosen.tick and rec.id == bt_chosen.id)
            local t = math.max(0, math.min(1, rec.hc / 100))
            c = bt_lerp(bad, good, t)
            if is_chosen then
                fill    = {c[1], c[2], c[3], bt_scale_alpha(c, 0.15 * m_one)}
                outline = {c[1], c[2], c[3], bt_scale_alpha(c, m_one)}
            else
                fill    = {c[1], c[2], c[3], 0}
                outline = {c[1], c[2], c[3], bt_scale_alpha(c, m_all)}
            end
        end
        for _, hb in ipairs(rec.hitboxes) do bt_draw_capsule(hb, fill, outline) end
    end

    -- Info label: only for live scan (not death view, not Last pos, not Clear)
    if not is_death_view and bt_chosen and bt_eye and state.bt_info then
        local tx, ty = render.world_to_screen(bt_chosen.point)
        if tx and ty then
            local label = string.format("bt %dms  hc %d%%",
                math.floor(bt_chosen.age + 0.5), math.floor(bt_chosen.hc + 0.5))
            render.text(tx + 10, ty - 14, label, info_col)
        end
    end
end)

-- Crosshair / penetration
local CH = {
    NORMAL = 0, PEN = 1, ENEMY = 2,
    INTERVAL = 0.05, HOLD = 0.15, MAXD = 4096, PAD = 4,
}
local ch_state, ch_expires, ch_next = CH.NORMAL, 0, 0
local ch_last_cmd = 0

local function ch_pt_seg(px,py,pz, ax,ay,az, bx,by,bz)
    local abx, aby, abz = bx-ax, by-ay, bz-az
    local apx, apy, apz = px-ax, py-ay, pz-az
    local ab2 = abx*abx + aby*aby + abz*abz
    local t = 0
    if ab2 > 1e-6 then
        t = (apx*abx + apy*aby + apz*abz) / ab2
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
    end
    local dx, dy, dz = px - (ax + t*abx), py - (ay + t*aby), pz - (az + t*abz)
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end
local function ch_ray_hit(eye, fwd, hb)
    local cx, cy, cz = hb.center.x-eye.x, hb.center.y-eye.y, hb.center.z-eye.z
    local t = cx*fwd.x + cy*fwd.y + cz*fwd.z
    if t < 0 or t > CH.MAXD then return false, 0 end
    local d = ch_pt_seg(eye.x + fwd.x*t, eye.y + fwd.y*t, eye.z + fwd.z*t,
        hb.capsule_a.x, hb.capsule_a.y, hb.capsule_a.z,
        hb.capsule_b.x, hb.capsule_b.y, hb.capsule_b.z)
    return d < (hb.radius + CH.PAD), t
end
local function ch_try_hb(pid, hb, hb_data, eye, fwd)
    local hit, t = ch_ray_hit(eye, fwd, hb)
    if not hit then return nil, 0 end
    local d = combat.damage(pid, hb.center, hb_data.tick)
    if d then return d, t end
    d = combat.damage(pid, hb.capsule_a, hb_data.tick); if d then return d, t end
    d = combat.damage(pid, hb.capsule_b, hb_data.tick); if d then return d, t end
    return nil, 0
end
local function ch_scan()
    local ctx, c = combat.context(), cmd.get()
    if not ctx or not ctx.valid or not c then return CH.NORMAL end
    local eye, fwd = ctx.eye, math.angle_vectors(c.angles)
    local closest_t, best_pen = math.huge, false
    for _, player in ipairs(entity.players(true)) do
        if player.alive then
            local dx, dy, dz = player.origin.x-eye.x, player.origin.y-eye.y, player.origin.z-eye.z
            if dx*dx+dy*dy+dz*dz < CH.MAXD*CH_MAXD then
                local hb_data = combat.hitboxes(player.id)
                if hb_data then
                    for _, hb in ipairs(hb_data.hitboxes) do
                        local d, t = ch_try_hb(player.id, hb, hb_data, eye, fwd)
                        if d and t < closest_t then closest_t, best_pen = t, d.penetrated end
                    end
                end
            end
        end
    end
    if closest_t < math.huge then return best_pen and CH.PEN or CH.ENEMY end
    return CH.NORMAL
end
events.on("pre_rage", function()
    ch_last_cmd = client.time()
    if not state.ch_enabled or not state.ch_pen_enabled then ch_state = CH.NORMAL; return end
    local now = client.time()
    if now < ch_next then return end
    ch_next = now + CH.INTERVAL
    ch_state = ch_scan()
    ch_expires = now + CH.HOLD
end)
local ch_has_run = false
events.on("paint", function()
    if not state.ch_enabled or not ch_has_run then return end
    if client.time() - ch_last_cmd > 0.5 then return end
    if client.time() > ch_expires then ch_state = CH.NORMAL end
    local sw, sh = render.screen_size()
    local cx, cy = sw * 0.5, sh * 0.5
    local size = math.floor(state.ch_type) - 1
    local color
    if ch_state == CH.PEN then color = as_arr(state.ch_col_pen)
    elseif ch_state == CH.ENEMY then color = as_arr(state.ch_col_enemy)
    else color = as_arr(state.ch_col_norm) end
    render.rect(cx - size, cy, size * 2 + 1, 1, color, true)
    render.rect(cx, cy - size, 1, size * 2 + 1, color, true)
end)

-- Trail
local tr_points = {}
local tr_lx, tr_ly, tr_lz = 0, 0, 0
local tr_mind2 = 25
local function tr_clamp(v)
    v = math.floor(tonumber(v) or 0)
    return v < 0 and 0 or (v > 255 and 255 or v)
end
local function tr_rainbow(t, alpha)
    local phase = t * 2
    local function c(sh) return math.floor(127.5 + 127.5 * math.sin(phase + sh)) end
    return {c(0), c(2.0944), c(4.1888), tr_clamp(alpha or 255)}
end
events.on("pre_rage", function()
    ch_has_run = true
    ch_last_cmd = client.time()
    if not state.tr_enabled then tr_points = {}; return end
    local lp = entity.local_player()
    if not lp or not lp.alive then tr_points = {}; return end
    local now = client.time()
    local ox = lp.origin.x; local oy = lp.origin.y
    local oz = lp.origin.z + state.tr_height
    local dx, dy, dz = ox-tr_lx, oy-tr_ly, oz-tr_lz
    if dx*dx + dy*dy + dz*dz >= tr_mind2 then
        tr_points[#tr_points+1] = {x=ox, y=oy, z=oz, t=now}
        tr_lx, tr_ly, tr_lz = ox, oy, oz
        local maxn = math.floor(state.tr_len)
        while #tr_points > maxn do table.remove(tr_points, 1) end
    end
    local lf = state.tr_life
    for i = #tr_points, 1, -1 do
        if now - tr_points[i].t > lf then table.remove(tr_points, i) else break end
    end
end)
events.on("paint", function()
    if not state.tr_enabled or #tr_points < 2 then return end
    local now = client.time()
    local lf = state.tr_life
    local w = state.tr_width
    local fade_on = state.tr_fade
    local base = state.tr_color
    for i = 1, #tr_points - 1 do
        local a, b = tr_points[i], tr_points[i+1]
        local fa = 1 - math.min(1, (now - a.t) / lf)
        local fb = 1 - math.min(1, (now - b.t) / lf)
        local aa = fade_on and (fa * 255) or 255
        local ab = fade_on and (fb * 255) or 255
        local ca, cb
        if state.tr_rainbow then
            ca, cb = tr_rainbow(a.t, aa), tr_rainbow(b.t, ab)
        else
            ca = {base.r, base.g, base.b, tr_clamp(aa)}
            cb = {base.r, base.g, base.b, tr_clamp(ab)}
        end
        local ax, ay, av = render.world_to_screen(a)
        local bx, by, bv = render.world_to_screen(b)
        if ax and ay and av and bx and by and bv then
            local uw = math.max(1, ((w*fa) + (w*fb)) / 2)
            render.line(ax, ay, bx, by, {ca[1], ca[2], ca[3], tr_clamp((aa+ab)/2)}, uw)
            render.line(ax, ay, bx, by, {255, 255, 255, tr_clamp((aa+ab)/4)}, math.max(1, uw*0.4))
        end
    end
end)
events.on("shutdown", function() tr_points = {} end)

-- Enemy arrows
local ea_has_concave = render.concave_polygon ~= nil
local ea_has_circle_fade = render.circle_fade ~= nil
local ea_has_poly_line = render.poly_line ~= nil
local ea_vangles = nil
local function ea_lerp(a, b, t) return a + (b - a) * t end
local function ea_mix(c1, c2, t)
    return {
        math.floor(ea_lerp(c1[1], c2[1], t)), math.floor(ea_lerp(c1[2], c2[2], t)),
        math.floor(ea_lerp(c1[3], c2[3], t)), math.floor(ea_lerp(c1[4], c2[4], t)),
    }
end
local function ea_scale(c, k) return {c[1], c[2], c[3], math.floor(math.max(0, math.min(255, c[4] * k)))} end
local function ea_with_alpha(c, a) return {c[1], c[2], c[3], math.floor(math.max(0, math.min(255, c[4] * a)))} end
local function ea_lighten(c, t) return {
    math.floor(c[1] + (255 - c[1]) * t), math.floor(c[2] + (255 - c[2]) * t),
    math.floor(c[3] + (255 - c[3]) * t), c[4] } end
local function ea_mk(x, y, ux, uy, lp)
    local px, py = -uy, ux
    local out = {}
    for i = 1, #lp do
        local lf, lp_ = lp[i][1], lp[i][2]
        out[i] = {x = x + ux*lf + px*lp_, y = y + uy*lf + py*lp_}
    end
    return out
end
local function ea_chevron(x, y, ux, uy, s)
    return ea_mk(x, y, ux, uy, {{s,0}, {-s*0.5, s*0.82}, {-s*0.1,0}, {-s*0.5, -s*0.82}})
end
local EA_STYLES = {
    function(x, y, ux, uy, s) return {{pts = ea_chevron(x, y, ux, uy, s), concave = true}} end,
    function(x, y, ux, uy, s) return {{pts = ea_mk(x, y, ux, uy, {{s*1.2,0},{-s*0.85,s*0.36},{-s*0.85,-s*0.36}})}} end,
    function(x, y, ux, uy, s)
        return {
            {pts = ea_chevron(x, y, ux, uy, s), concave = true},
            {pts = ea_chevron(x + ux*s*0.55, y + uy*s*0.55, ux, uy, s*0.5), concave = true},
        }
    end,
    function(x, y, ux, uy, s) return {{pts = ea_mk(x, y, ux, uy, {{s,0},{0,s*0.78},{-s,0},{0,-s*0.78}})}} end,
}
local function ea_scaled(pts, cx, cy, k)
    local out = {}
    for i = 1, #pts do out[i] = {x = cx + (pts[i].x - cx)*k, y = cy + (pts[i].y - cy)*k} end
    return out
end
local function ea_draw_part(pts, concave, col)
    if concave and ea_has_concave then render.concave_polygon(pts, col)
    else render.polygon(pts, col) end
end
local function ea_vec_ok(v) return type(v) == "table" and v.x and (v.x*v.x + v.y*v.y + v.z*v.z > 0.5) end
local function ea_cam(angles)
    if not math.angle_vectors then return nil, nil end
    local a, b = math.angle_vectors(angles)
    local f, r
    if ea_vec_ok(a) then f, r = a, b
    elseif type(a) == "table" then
        if ea_vec_ok(a.forward) then f, r = a.forward, a.right
        elseif ea_vec_ok(a.f) then f, r = a.f, a.r
        elseif type(a[1]) == "table" then f, r = a[1], a[2] end
    end
    if not f then return nil, nil end
    if not ea_vec_ok(r) then r = {x = f.z, y = 0, z = -f.x} end
    return f, r
end
events.on("create_move", function(e)
    local a = e and e.angles
    if not (a and a.x) and cmd.get then
        local snap = cmd.get(); a = snap and snap.angles
    end
    if a and a.x and ea_cam(a) then ea_vangles = a end
end)
events.on("paint", function()
    if not state.ea_enabled then return end
    local sw, sh = client.screen_size()
    local cx, cy = sw/2, sh/2
    local ring, s, h_off, dist_limit = state.ea_radius, state.ea_size, state.ea_eye, state.ea_dist
    local arrow_color = as_arr(state.ea_color)
    local hi = as_arr(state.ea_hp_high)
    local lo = as_arr(state.ea_hp_low)
    local line_color = as_arr(state.ea_outline_color)
    local txt = as_arr(state.ea_text_color)
    local me = entity.local_player()
    if not me then return end
    local eye = me.eye or me.origin
    local fwd, rgt
    if ea_vangles then fwd, rgt = ea_cam(ea_vangles) end
    if eye and not eye.x then eye = nil end
    local enemies = entity.players(true)
    if #enemies == 0 then return end
    local marks = {}
    for i = 1, #enemies do
        local e = enemies[i]
        if e.alive and e.enemy then
            local dxw = e.origin.x - me.origin.x
            local dyw = e.origin.y - me.origin.y
            local dzw = e.origin.z - me.origin.z
            local range = math.sqrt(dxw*dxw + dyw*dyw + dzw*dzw)
            if range <= dist_limit then
                local head = {x = e.origin.x, y = e.origin.y + h_off, z = e.origin.z}
                local dx, dy, px, py, shown = 0, -1, nil, nil, false
                if fwd and rgt and eye then
                    local ddx, ddy, ddz = head.x-eye.x, head.y-eye.y, head.z-eye.z
                    local along  = ddx*fwd.x + ddy*fwd.y + ddz*fwd.z
                    local across = ddx*rgt.x + ddy*rgt.y + ddz*rgt.z
                    if along > 0 then
                        px, py = render.world_to_screen(head)
                        if px and py then
                            dx, dy = px-cx, py-cy
                            if px >= 0 and px <= sw and py >= 0 and py <= sh then shown = true end
                        else dx, dy = across, -along end
                    else dx, dy = across, -along end
                else
                    px, py = render.world_to_screen(head)
                    if px and py then
                        dx, dy = px-cx, py-cy
                        if px >= 0 and px <= sw and py >= 0 and py <= sh then shown = true end
                    end
                end
                if not shown or not state.ea_offscreen then
                    local l = math.sqrt(dx*dx + dy*dy)
                    if l < 0.0001 then dx, dy, l = 0, -1, 1 end
                    local ux, uy = dx/l, dy/l
                    if shown then
                        marks[#marks+1] = {x=px, y=py, ux=ux, uy=uy, e=e, len=l, range=range, off=false}
                    else
                        local k = ring/l
                        marks[#marks+1] = {x=cx+dx*k, y=cy+dy*k, ux=ux, uy=uy, e=e, len=ring, range=range, off=true}
                    end
                end
            end
        end
    end
    table.sort(marks, function(a,b) return a.range < b.range end)
    for i = 1, math.min(#marks, state.ea_limit) do
        local m, e = marks[i], marks[i].e
        local frac = math.max(0, math.min(1, e.health/100))
        local tint = state.ea_by_health and ea_mix(lo, hi, frac) or arrow_color
        if state.ea_fade then
            local k = 1
            if m.off then k = 1 - 0.55 * math.max(0, math.min(1, (m.len-200)/1400)) end
            tint = ea_scale(tint, k)
        end
        local style_idx = math.max(1, math.min(#EA_STYLES, state.ea_style))
        local parts = EA_STYLES[style_idx](m.x, m.y, m.ux, m.uy, s)
        if state.ea_neon then
            if ea_has_circle_fade then
                local hx, hy = m.x + m.ux*s*0.35, m.y + m.uy*s*0.35
                render.circle_fade(hx, hy, s*2.6, ea_with_alpha(tint, 0.55), ea_with_alpha(tint, 0))
            end
            for pi = 1, #parts do
                for g = state.ea_glow, 1, -1 do
                    ea_draw_part(ea_scaled(parts[pi].pts, m.x, m.y, 1+g*0.2),
                        parts[pi].concave, ea_with_alpha(tint, 0.55/g))
                end
            end
        end
        for pi = 1, #parts do
            if state.ea_outline and not state.ea_neon then
                ea_draw_part(ea_scaled(parts[pi].pts, m.x, m.y, 1.22), parts[pi].concave, line_color)
            end
            ea_draw_part(parts[pi].pts, parts[pi].concave,
                state.ea_neon and ea_lighten(tint, 0.35) or tint)
        end
        if state.ea_neon and ea_has_poly_line then
            for pi = 1, #parts do
                render.poly_line(parts[pi].pts, ea_lighten(tint, 0.6), 1, true)
            end
        end
        if state.ea_hp or state.ea_name then
            local label = ""
            if state.ea_name then label = e.name end
            if state.ea_hp then label = label ~= "" and (label .. " " .. e.health) or tostring(e.health) end
            local tw = render.measure_text(label)
            render.text(m.x + m.ux*(s+6) - tw*0.5, m.y + m.uy*(s+6) + 3, label, txt)
        end
    end
end)

-- WATERMARK
local wm_ffi = require("ffi")
wm_ffi.cdef[[
    typedef struct {
        uint16_t wYear; uint16_t wMonth; uint16_t wDayOfWeek;
        uint16_t wDay; uint16_t wHour; uint16_t wMinute;
        uint16_t wSecond; uint16_t wMilliseconds;
    } SYSTEMTIME;
    void GetLocalTime(SYSTEMTIME*);
]]
local wm_k32 = wm_ffi.load("kernel32")
local wm_sys = wm_ffi.new("SYSTEMTIME")
local WM_WHITE = {255, 255, 255, 255}
local WM_EXTRA_Y = 1
local wm_rt = {
    fps_frames = 0, fps_time = 0, fps_val = 0,
    jit_samples = {}, jit_max = 30, jit_val = 0,
    speed_val = 0, bg_tex = nil, loaded = false,
}

local function wm_measure()
    wm_rt.fps_frames = wm_rt.fps_frames + 1
    local now = client.time()
    if now - wm_rt.fps_time >= 1.0 then
        wm_rt.fps_val = wm_rt.fps_frames; wm_rt.fps_frames = 0; wm_rt.fps_time = now
    end
    local ft = client.frametime()
    if ft > 0 then
        wm_rt.jit_samples[#wm_rt.jit_samples+1] = ft * 1000
        if #wm_rt.jit_samples > wm_rt.jit_max then table.remove(wm_rt.jit_samples, 1) end
        if #wm_rt.jit_samples >= 3 then
            local s = 0
            for i = 1, #wm_rt.jit_samples do s = s + wm_rt.jit_samples[i] end
            local avg = s / #wm_rt.jit_samples
            local var = 0
            for i = 1, #wm_rt.jit_samples do
                local d = wm_rt.jit_samples[i] - avg
                var = var + d*d
            end
            wm_rt.jit_val = math.floor(math.sqrt(var / #wm_rt.jit_samples))
        end
    end
    local lp = entity.local_player()
    if lp and lp.alive then
        local v = lp.velocity
        wm_rt.speed_val = math.floor(math.sqrt(v.x*v.x + v.y*v.y))
    else wm_rt.speed_val = 0 end
end

local function wm_time_str()
    wm_k32.GetLocalTime(wm_sys)
    return string.format("%02d:%02d:%02d", wm_sys.wHour, wm_sys.wMinute, wm_sys.wSecond)
end

local function wm_icon_fps(cx, cy, r, col)
    local w, h = r*1.9, r*1.25
    if wm_rt.bg_tex then render.texture(wm_rt.bg_tex, cx-w/2, cy-h/2, w, h, col, math.floor(r*0.25))
    else render.rect(cx-w/2, cy-h/2, w, h, col, true) end
    render.rect(cx - r*0.08, cy + h/2, r*0.16, r*0.35, col, true)
    render.rect(cx - r*0.45, cy + h/2 + r*0.35, r*0.9, r*0.15, col, true)
end
local function wm_icon_speed(cx, cy, r, col)
    render.arc(cx, cy, r, math.pi, 2*math.pi, col, math.max(1.2, r*0.22), 24)
    render.line(cx, cy, cx + r*0.7, cy - r*0.5, col, math.max(1.2, r*0.2))
end
local function wm_icon_jitter(cx, cy, r, col)
    render.poly_line({
        {x=cx-r*0.95,y=cy+r*0.35},{x=cx-r*0.45,y=cy-r*0.45},
        {x=cx+r*0.05,y=cy+r*0.55},{x=cx+r*0.55,y=cy-r*0.55},
        {x=cx+r*0.95,y=cy+r*0.25},
    }, col, math.max(1.2, r*0.28), false)
end
local function wm_icon_map(cx, cy, r, col)
    render.circle(cx, cy, r, col, false)
    render.line(cx, cy-r, cx, cy+r, col, 1)
    render.line(cx-r, cy, cx+r, cy, col, 1)
    local lr = r*0.5; local dy = r*0.866
    render.line(cx-lr, cy-dy, cx+lr, cy-dy, col, 1)
    render.line(cx-lr, cy+dy, cx+lr, cy+dy, col, 1)
end
local function wm_icon_clock(cx, cy, r, col)
    render.circle(cx, cy, r, col, false)
    render.line(cx, cy, cx, cy-r*0.6, col, math.max(1.2, r*0.22))
    render.line(cx, cy, cx+r*0.45, cy, col, math.max(1.2, r*0.22))
end
local function wm_item_w(icon_r, gi, gl, pad, label, value)
    local lw = label ~= "" and render.measure_text(label) or 0
    local vw = render.measure_text(value)
    return pad + icon_r*2 + gi + lw + (lw > 0 and gl or 0) + vw + pad
end
local function wm_draw_item(x, y, H, icon_fn, label, value, scale, yoff)
    local pad = math.floor(4 * scale)
    local icon_r = math.floor(4 * scale)
    local gi = math.floor(4 * scale)
    local gl = math.floor(3 * scale)
    local icx = x + pad + icon_r
    local icy = y + H/2 + (yoff or 0)
    icon_fn(icx, icy, icon_r, WM_WHITE)
    local lx = icx + icon_r + gi
    local _, th = render.measure_text(label ~= "" and label or value)
    local ly = y + (H - th) / 2
    if label ~= "" then
        render.text(lx, ly, label, WM_WHITE)
        lx = lx + render.measure_text(label) + gl
    end
    render.text(lx, ly, value, WM_WHITE)
    return wm_item_w(icon_r, gi, gl, pad, label, value)
end

events.on("paint", function()
    if not wm_rt.loaded then
        wm_rt.loaded = true
        wm_rt.bg_tex = render.setup_texture_rgba(string.char(255,255,255,255), 1, 1)
    end
    wm_measure()
    if not state.wm_enabled then return end

    local base_size = state.wm_size == 1 and 10 or (state.wm_size == 2 and 16 or 20)
    local scale = base_size / 10
    local PAD_X = state.wm_pad

    local items = {}
    local wi = state.wm_items or {}
    if wi[1] then items[#items+1] = {icon=wm_icon_fps,    label="FPS",    value=tostring(wm_rt.fps_val), icon_y=0} end
    if wi[2] then items[#items+1] = {icon=wm_icon_speed,  label="SPEED",  value=tostring(wm_rt.speed_val).." u/s", icon_y=3} end
    if wi[3] then items[#items+1] = {icon=wm_icon_jitter, label="JITTER", value=tostring(wm_rt.jit_val).."ms", icon_y=0} end
    if wi[4] then
        local map = client.map_name()
        if not map or map == "" then map = "unknown"
        else map = map:match("([^/\\]+)$") or map; map = map:gsub("%.bsp$","") end
        items[#items+1] = {icon=wm_icon_map, label="MAP", value=map, icon_y=0}
    end
    if wi[5] then items[#items+1] = {icon=wm_icon_clock, label="", value=wm_time_str(), icon_y=0} end
    if #items == 0 then return end

    local icon_r = math.floor(4*scale); local gi = math.floor(4*scale)
    local gl = math.floor(3*scale);     local pad = math.floor(4*scale)
    local pad_item = math.floor(8*scale); local pad_out = math.floor(6*scale)
    local total_w = pad_out * 2 + PAD_X * 2
    for i = 1, #items do
        total_w = total_w + wm_item_w(icon_r, gi, gl, pad, items[i].label, items[i].value)
        if i < #items then total_w = total_w + pad_item end
    end
    local H = math.floor(14*scale) + PAD_X * 2
    local round = math.floor(4*scale)
    local sw, sh = client.screen_size()
    sw = sw or 1920; sh = sh or 1080
    local m_side = 15; local m_top = 8
    local x, y
    local pos = state.wm_pos
    if     pos == 1 then x = m_side; y = m_top + WM_EXTRA_Y
    elseif pos == 2 then x = m_side; y = sh - H - m_side - WM_EXTRA_Y
    elseif pos == 3 then x = (sw - total_w)/2; y = m_top + WM_EXTRA_Y
    elseif pos == 4 then x = (sw - total_w)/2; y = sh - H - m_side - WM_EXTRA_Y
    elseif pos == 5 then x = sw - total_w - m_side - 35.5; y = m_top + WM_EXTRA_Y
    elseif pos == 6 then x = sw - total_w - m_side; y = sh - H - m_side - WM_EXTRA_Y end
    if state.wm_bg_en then
        local bg = {18, 18, 22, 100}
        if wm_rt.bg_tex then render.texture(wm_rt.bg_tex, x, y, total_w, H, bg, round)
        else render.rect(x, y, total_w, H, bg, true) end
    end
    local cx = x + PAD_X + pad_out
    local cy = y + PAD_X
    local ch = H - PAD_X * 2
    for i = 1, #items do
        local w = wm_draw_item(cx, cy, ch, items[i].icon, items[i].label, items[i].value, scale, items[i].icon_y)
        cx = cx + w
        if i < #items then
            cx = cx + pad_item / 2
            render.rect(cx, cy + math.floor(3*scale), 1, ch - math.floor(6*scale), {255,255,255,45}, true)
            cx = cx + pad_item / 2
        end
    end
end)

-- DoubleTap Indicator render (separate paint handler - draws on game screen)
events.on("paint", function()
    if not state.dt_ind_enabled then return end
    local dts = (combat and combat.double_tap) and combat.double_tap() or nil
    if not dts or not dts.active then return end

    local charge = math.max(0, math.min(1, dts.charge or 0))
    local ready = dts.ready == true

    local sw, sh = render.screen_size()

    -- Screen mode
    if state.dt_ind_based_on == 2 then
        local function eff_charge(c)
            if c >= 0.95 then return 1.0 end
            return c
        end

        local c = eff_charge(charge)
        local takes = state.dt_ind_takes or 1
        local th    = math.max(1, state.dt_ind_screen_thickness or 4)
        local base_col = state.dt_ind_screen_color or {r = 255, g = 255, b = 255, a = 255}
        local col = ready and {120, 220, 140, 255}
                    or {base_col.r, base_col.g, base_col.b, base_col.a}
        local bg = {60, 60, 60, 180}
        local h_th = th / 2

        local function px(n) return math.min(sw, math.ceil(n + 0.5)) end
        local function py(n) return math.min(sh, math.ceil(n + 0.5)) end

        if takes == 1 then
            -- Full perimeter outline (4 lines at h_th offset - always inside screen)
            if c >= 1.0 then
                render.line(0, h_th, sw, h_th, col, th)
                render.line(sw - h_th, 0, sw - h_th, sh, col, th)
                render.line(0, sh - h_th, sw, sh - h_th, col, th)
                render.line(h_th, 0, h_th, sh, col, th)
            else
                render.line(0, h_th, sw, h_th, bg, th)
                render.line(sw - h_th, 0, sw - h_th, sh, bg, th)
                render.line(0, sh - h_th, sw, sh - h_th, bg, th)
                render.line(h_th, 0, h_th, sh, bg, th)

                local perim    = 2 * (sw + sh)
                local fill_len = perim * c
                local drawn    = 0

                -- top: L -> R
                local seg = math.min(fill_len, sw)
                if seg > 0 then
                    render.line(0, h_th, px(seg), h_th, col, th)
                    drawn = drawn + seg
                end
                -- right: T -> B
                if drawn < fill_len then
                    seg = math.min(fill_len - drawn, sh)
                    render.line(sw - h_th, 0, sw - h_th, py(seg), col, th)
                    drawn = drawn + seg
                end
                -- bottom: R -> L
                if drawn < fill_len then
                    seg = math.min(fill_len - drawn, sw)
                    render.line(sw, sh - h_th, sw - px(seg), sh - h_th, col, th)
                    drawn = drawn + seg
                end
                -- left: B -> T
                if drawn < fill_len then
                    seg = math.min(fill_len - drawn, sh)
                    render.line(h_th, sh, h_th, sh - py(seg), col, th)
                end
            end

        elseif takes == 2 then
            -- Above: top full-width strip, fill L -> R
            if c >= 1.0 then
                render.line(0, h_th, sw, h_th, col, th)
            else
                render.line(0, h_th, sw, h_th, bg, th)
                if c > 0.005 then
                    render.line(0, h_th, px(sw * c), h_th, col, th)
                end
            end

        elseif takes == 3 then
            -- Below: bottom full-width strip, fill L -> R
            if c >= 1.0 then
                render.line(0, sh - h_th, sw, sh - h_th, col, th)
            else
                render.line(0, sh - h_th, sw, sh - h_th, bg, th)
                if c > 0.005 then
                    render.line(0, sh - h_th, px(sw * c), sh - h_th, col, th)
                end
            end

        elseif takes == 4 then
            -- Left: left full-height strip, fill B -> T
            if c >= 1.0 then
                render.line(h_th, sh, h_th, 0, col, th)
            else
                render.line(h_th, 0, h_th, sh, bg, th)
                if c > 0.005 then
                    render.line(h_th, sh, h_th, sh - py(sh * c), col, th)
                end
            end

        else
            -- Right: right full-height strip, fill B -> T
            if c >= 1.0 then
                render.line(sw - h_th, sh, sw - h_th, 0, col, th)
            else
                render.line(sw - h_th, 0, sw - h_th, sh, bg, th)
                if c > 0.005 then
                    render.line(sw - h_th, sh, sw - h_th, sh - py(sh * c), col, th)
                end
            end
        end
        return
    end

    -- Scope mode (existing)
    local cx, cy = sw * 0.5, sh * 0.5

    local base_col = state.dt_ind_color or {r = 255, g = 255, b = 255, a = 255}
    local c_ready = {120, 220, 140, 255}
    local col = ready and c_ready or {base_col.r, base_col.g, base_col.b, base_col.a}

    local size = state.dt_ind_size or 40
    local th   = math.max(1, state.dt_ind_thickness or 2)
    local itype = state.dt_ind_type or 1

    if itype == 1 then
        local r = size * 0.5
        render.arc(cx, cy, r, -math.pi/2, math.pi * 1.5, {60, 60, 60, 180}, th, 64)
        if charge >= 0.995 then
            render.circle(cx, cy, r, col, false, th)
        elseif charge > 0.005 then
            local segs = math.max(48, math.floor(r * 4))
            render.arc(cx, cy, r, -math.pi/2, -math.pi/2 + math.pi * 2 * charge, col, th, segs)
        end

    elseif itype == 2 then
        local half = size * 0.5
        local x1, y1 = cx - half, cy - half
        local x2, y2 = cx + half, cy + half
        render.rect(x1, y1, size, size, {60, 60, 60, 180}, false, th)

        if charge >= 0.995 then
            render.rect(x1, y1, size, size, col, false, th)
        elseif charge > 0.005 then
            local perim = size * 4
            local fill_len = perim * charge
            local side = size
            local drawn = 0

            local seg = math.min(fill_len, side)
            if seg > 0 then
                render.line(x1, y1, x1 + seg, y1, col, th)
                drawn = drawn + seg
            end
            if drawn < fill_len then
                seg = math.min(fill_len - drawn, side)
                render.line(x2, y1, x2, y1 + seg, col, th)
                drawn = drawn + seg
            end
            if drawn < fill_len then
                seg = math.min(fill_len - drawn, side)
                render.line(x2, y2, x2 - seg, y2, col, th)
                drawn = drawn + seg
            end
            if drawn < fill_len then
                seg = math.min(fill_len - drawn, side)
                render.line(x1, y2, x1, y2 - seg, col, th)
            end
        end

    elseif itype == 3 then
        local pos = state.dt_ind_line_pos or 1
        local len = size
        local offset = state.dt_ind_line_offset or 60
        local x_start, y_start, x_end, y_end
        if pos == 1 then
            x_start = cx - len/2; y_start = cy - offset
            x_end   = cx + len/2; y_end   = cy - offset
        elseif pos == 2 then
            x_start = cx - len/2; y_start = cy + offset
            x_end   = cx + len/2; y_end   = cy + offset
        elseif pos == 3 then
            x_start = cx - offset; y_start = cy + len/2
            x_end   = cx - offset; y_end   = cy - len/2
        else
            x_start = cx + offset; y_start = cy + len/2
            x_end   = cx + offset; y_end   = cy - len/2
        end

        render.line(x_start, y_start, x_end, y_end, {60, 60, 60, 180}, th)
        if charge > 0.005 then
            local fx = x_start + (x_end - x_start) * charge
            local fy = y_start + (y_end - y_start) * charge
            render.line(x_start, y_start, fx, fy, col, th)
        end
    end
end)

-- UI HELPERS
local function is_hover(m, x, y, w, h)
    if _clip then
        if m.x < _clip.x or m.x > _clip.x + _clip.w
           or m.y < _clip.y or m.y > _clip.y + _clip.h then
            return false
        end
    end
    return m.x >= x and m.x <= x + w and m.y >= y and m.y <= y + h
end
local function animate(c, t, s, dt) return c + (t - c) * (1 - math.exp(-s * dt)) end

local DEAD_MOUSE = {x = -9999, y = -9999, down = false, clicked = false, wheel = 0}

-- Keyboard capture
local key_fn = (client and type(client.key_down) == "function") and client.key_down or nil
local VK = {
    SPACE = 0x20, BACKSPACE = 0x08, ENTER = 0x0D, SHIFT = 0x10,
    CONTROL = 0x11, LCONTROL = 0xA2, RCONTROL = 0xA3, LSHIFT = 0xA0,
    RSHIFT = 0xA1, CAPSLOCK = 0x14, END = 0x23, HOME = 0x24,
    LEFT = 0x25, UP = 0x26, RIGHT = 0x27, DOWN = 0x28,
    DELETE = 0x2E, A = 0x41, C = 0x43, V = 0x56,
}
local function char_to_vk(c)
    if c == " " then return VK.SPACE end
    local b = c:lower():byte()
    if b >= 97 and b <= 122 then return 0x41 + (b - 97) end
    if b >= 48 and b <= 57 then return 0x30 + (b - 48) end
    return nil
end
local function raw_key(vk)
    if not key_fn or type(vk) ~= "number" then return false end
    local res = key_fn(vk)
    if res == true then return true end
    if type(res) == "number" and res > 0 then return true end
    return false
end
local keys_prev = {}
local function just_pressed(name, detector)
    local now = detector()
    if now and not keys_prev[name] then keys_prev[name] = true; return true end
    if not now then keys_prev[name] = nil end
    return false
end
local function is_key_down(vk)
    if not key_fn then return false end
    local ok, res = _pcall(key_fn, vk)
    if ok then
        if res == true then return true end
        if type(res) == "number" and res > 0 then return true end
    end
    if input and type(input.is_key_down) == "function" then
        local ok2, res2 = _pcall(input.is_key_down, vk)
        if ok2 and res2 then return true end
    end
    return false
end

local function is_ctrl_down()
    return is_key_down(VK.CONTROL)
        or is_key_down(VK.LCONTROL)
        or is_key_down(VK.RCONTROL)
end

local function is_shift_down()
    return is_key_down(VK.SHIFT)
        or is_key_down(VK.LSHIFT)
        or is_key_down(VK.RSHIFT)
end

-- Text input internal state
local TI = {}  -- TI[key] = { cursor, sel_start, sel_end, held = {name -> {t0, t_last}} }

local function ti_get(key)
    if not TI[key] then
        local cur = state[key] and #state[key] or 0
        TI[key] = {
            cursor = cur,
            sel_start = nil, sel_end = nil,
            held = {},
            drag_start = nil, drag_mx = 0,
            drag_moved = false, dragging = false,
        }
    end
    return TI[key]
end

-- single press / auto-repeat gate.
-- returns true only on first press or after 350ms then every 40ms
local function ti_press(key, name, is_down, now, no_repeat)
    local s = ti_get(key)
    local h = s.held[name]
    if is_down then
        if not h then
            s.held[name] = { t0 = now, t_last = now }
            return true
        elseif not no_repeat then
            if now - h.t0 > 0.5 and now - h.t_last > 0.04 then
                h.t_last = now
                return true
            end
        end
        return false
    else
        if h then s.held[name] = nil end
        return false
    end
end

-- measure a substring safely
local function measure_w(str)
    if not str or str == "" then return 0 end
    local w = render.measure_text(str)
    return type(w) == "number" and w or 0
end

-- which cursor index corresponds to local x within text
local function cursor_at_x(s, local_x)
    if local_x <= 0 then return 0 end
    local best = 0
    for i = 0, #s do
        local pw = measure_w(s:sub(1, i))
        if pw > local_x then return math.max(0, i - 1) end
        best = i
    end
    return best
end

-- Widgets
local function draw_checkbox(m, x, y, lbl, key, dt, dis)
    if dis then m = DEAD_MOUSE end
    if is_hover(m, x, y, 170, 16) and m.clicked then
        state[key] = not state[key]; m.clicked = false
    end
    local tg = state[key] and 1 or 0
    anims.checkboxes[key] = anims.checkboxes[key] or tg
    anims.checkboxes[key] = animate(anims.checkboxes[key], tg, 20, dt)
    local a = anims.checkboxes[key]
    local bg   = dis and {18,18,18,255} or {24,24,24,255}
    local br   = dis and {36,36,36,255} or {50,50,50,255}
    local fill = dis and {120,120,120,255} or {255,255,255,255}
    local txt  = dis and {115,115,115,255} or {200,200,200,255}
    render.rect(x, y, 7, 7, bg, true)
    render.rect(x, y, 7, 7, br, false)
    if a > 0.01 then
        render.rect(x + 1, y + 1, 6, 6,
            {fill[1], fill[2], fill[3], math.floor(fill[4] * a)}, true)
    end
    render.text(x + 20, y - 2, lbl, txt)
    return y + 22
end

local function draw_slider(m, x, y, lbl, key, mn, mx, dt, fmt, w, dis)
    if dis then m = DEAD_MOUSE end
    w = w or 200
    local ty = y + 16
    local hov = is_hover(m, x, ty - 5, w, 12)
    local near = is_hover(m, x - 25, ty - 10, w + 50, 20)
    local mh = near and is_hover(m, x - 12, ty - 6, 11, 12)
    local ph = near and is_hover(m, x + w + 1, ty - 6, 11, 12)
    if m.clicked and not open_dropdown then
        if mh then state[key] = math.max(mn, state[key] - (mx-mn)*0.02); m.clicked = false
        elseif ph then state[key] = math.min(mx, state[key] + (mx-mn)*0.02); m.clicked = false end
    end
    if (hov and m.clicked) or (dragging_slider == key and m.down) then
        dragging_slider = key
        local pct = math.max(0, math.min(1, (m.x - x) / w))
        state[key] = mn + (mx - mn) * pct
    elseif not m.down and dragging_slider == key then dragging_slider = nil end
    anims.sliders[key] = anims.sliders[key] or state[key]
    anims.sliders[key] = animate(anims.sliders[key], state[key], (dragging_slider == key) and 30 or 12, dt)
    local av = anims.sliders[key]
    local pct = math.max(0, math.min(1, (av - mn) / (mx - mn)))
    local c_lbl  = dis and {115,115,115,255} or {200,200,200,255}
    local c_bg   = dis and {22,22,22,255}   or {30,30,30,255}
    local c_fill = dis and {105,105,105,255} or {200,200,200,255}
    local c_val  = dis and {125,125,125,255} or {255,255,255,255}
    render.text(x, y, lbl, c_lbl)
    render.rect(x, ty, w, 4, c_bg, true)
    render.rect(x, ty, w * pct, 4, c_fill, true)
    anims.slider_arrows[key] = anims.slider_arrows[key] or 0
    anims.slider_arrows[key] = animate(anims.slider_arrows[key], near and 1 or 0, 16, dt)
    anims.slider_minus[key]  = anims.slider_minus[key]  or 0
    anims.slider_minus[key]  = animate(anims.slider_minus[key], mh and 1 or 0, 22, dt)
    anims.slider_plus[key]   = anims.slider_plus[key]   or 0
    anims.slider_plus[key]   = animate(anims.slider_plus[key],  ph and 1 or 0, 22, dt)
    local arrows_a = anims.slider_arrows[key]
    if arrows_a > 0.01 and not dis then
        local base_alpha = math.floor(255 * arrows_a)
        local mg = math.floor(150 + 105 * anims.slider_minus[key])
        local pg = math.floor(150 + 105 * anims.slider_plus[key])
        render.text(x - 6, ty - 4, "-", {mg, mg, mg, base_alpha})
        render.text(x + w + 4, ty - 4, "+", {pg, pg, pg, base_alpha})
    end
    local s = fmt and fmt(av) or string.format("%d", math.floor(av))
    local tw = render.measure_text(s)
    local tx = math.max(x, math.min(x + w - tw, x + w * pct - tw/2))
    render.text(tx-1, ty, s, {0,0,0,255}); render.text(tx+1, ty, s, {0,0,0,255})
    render.text(tx, ty-1, s, {0,0,0,255}); render.text(tx, ty+1, s, {0,0,0,255})
    render.text(tx, ty, s, c_val)
    return y + 38
end

-- Marquee (max_text_length for combos/dropdowns)
local CARD_BG = {17, 17, 17, 255}

local function composite_bg(over)
    local a = (over[4] or 255) / 255
    return {
        math.floor(over[1] * a + CARD_BG[1] * (1 - a)),
        math.floor(over[2] * a + CARD_BG[2] * (1 - a)),
        math.floor(over[3] * a + CARD_BG[3] * (1 - a)),
        255,
    }
end

local function get_marquee_offset(t, delta)
    if delta <= 0 then return 0 end
    local cycle = 4.0
    local phase = (t % cycle) / cycle
    -- 15% hold | 35% fwd | 15% hold | 35% back
    if phase < 0.15 then
        return 0
    elseif phase < 0.50 then
        return delta * ((phase - 0.15) / 0.35)
    elseif phase < 0.65 then
        return delta
    elseif phase < 1.00 then
        return delta * (1 - (phase - 0.65) / 0.35)
    end
    return 0
end

-- Clips text to max_w. If overflow -> slide (marquee) + right-edge fade to bg.
local function draw_scrolled_label(x, y, text, max_w, fg, bg, line_h)
    line_h = line_h or 16
    text = tostring(text or "")
    local tw = render.measure_text(text)
    if tw <= max_w + 0.5 then
        render.text(x, y, text, fg)
        return
    end
    local delta  = tw - max_w
    local offset = get_marquee_offset(client.time(), delta)
    render.push_clip_rect(x, y, max_w, line_h)
    render.text(x - offset, y, text, fg)
    render.pop_clip_rect()
    if bg then
        local fade_w = math.min(22, math.max(8, max_w * 0.25))
        local c0 = {bg[1], bg[2], bg[3], 0}
        local c1 = {bg[1], bg[2], bg[3], 255}
        render.rect_filled_fade(x + max_w - fade_w, y, fade_w, line_h, c0, c1, c0, c1)
    end
end

local function draw_combo_arrow(cx, cy, is_open, col)
    local hw  = 3.2    -- half-width of base
    local hh  = 3.8    -- half-height
    local tip = 0.5    -- half of tip width (0.5 -> 1px tip)
    local pts
    if is_open then
        -- pointing up
        pts = {
            {x = cx - hw,  y = cy + hh * 0.55},
            {x = cx + hw,  y = cy + hh * 0.55},
            {x = cx + tip, y = cy - hh * 0.55},
            {x = cx - tip, y = cy - hh * 0.55},
        }
    else
        -- pointing down
        pts = {
            {x = cx - hw,  y = cy - hh * 0.55},
            {x = cx + hw,  y = cy - hh * 0.55},
            {x = cx + tip, y = cy + hh * 0.55},
            {x = cx - tip, y = cy + hh * 0.55},
        }
    end
    render.polygon(pts, col)
end

local function draw_combo(m, x, y, lbl, key, items, jc, w, dis)
    w = w or 200
    render.text(x, y, lbl, {200,200,200,255})
    local by = y + 16; local bh = 20
    local hov = is_hover(m, x, by, w, bh)
    local bg_over = hov and {40,40,40,45} or {24,24,24,45}
    local bg_vis  = composite_bg(bg_over)
    local txt_col = dis and {140, 140, 140, 255} or {200, 200, 200, 255}
    local arr_col = dis and {110, 110, 110, 255} or {200, 200, 200, 255}
    render.rect(x, by, w, bh, bg_over, true)
    render.rect(x, by, w, bh, {50,50,50,255}, false)
    draw_scrolled_label(x + 5, by + 4, items[state[key]] or "?", w - 22,
        txt_col, bg_vis, 16)
    draw_combo_arrow(x + w - 10, by + 10, open_dropdown == key, arr_col)
    if hov and m.clicked and not jc then
        if open_dropdown ~= key then
            dd_anim_height = 0
            closing_dd = nil
            dd_scroll[key] = 0
        end
        open_dropdown = key
        dd_rect = {x = x, y = by + bh, w = w, h = math.min(#items * 20, DD_MAX_H)}
        dd_items = items; dd_is_multi = false; dd_exclusive = nil
        m.clicked = false
    end
    return by + bh + 10
end

local function draw_multicombo(m, x, y, lbl, key, items, jc, exc, w)
    w = w or 200
    render.text(x, y, lbl, {200,200,200,255})
    local by = y + 16; local bh = 20
    local hov = is_hover(m, x, by, w, bh)
    local sel = {}
    local arr = state[key] or {}
    for i = 1, #items do if arr[i] then sel[#sel+1] = items[i] end end
    local t = #sel > 0 and table.concat(sel, ", ") or "None"
    local bg_over = hov and {40,40,40,45} or {24,24,24,45}
    local bg_vis  = composite_bg(bg_over)
    render.rect(x, by, w, bh, bg_over, true)
    render.rect(x, by, w, bh, {50,50,50,255}, false)
    draw_scrolled_label(x + 5, by + 4, t, w - 22, {200,200,200,255}, bg_vis, 16)
    draw_combo_arrow(x + w - 10, by + 10, open_dropdown == key, {200, 200, 200, 255})
    if hov and m.clicked and not jc then
        if open_dropdown ~= key then
            dd_anim_height = 0
            closing_dd = nil
            dd_scroll[key] = 0
        end
        open_dropdown = key
        dd_rect = {x = x, y = by + bh, w = w, h = math.min(#items * 20, DD_MAX_H)}
        dd_items = items; dd_is_multi = true; dd_exclusive = exc
        m.clicked = false
    end
    return by + bh + 10
end

local CHAR_SET  = "abcdefghijklmnopqrstuvwxyz0123456789"
local CHAR_LIST = {}
for c in CHAR_SET:gmatch(".") do CHAR_LIST[#CHAR_LIST+1] = c end

local function draw_text_input(m, x, y, lbl, key, w, dt)
    local now = client.time()
    local s   = state[key] or ""
    local ti  = ti_get(key)

    if ti.cursor > #s then ti.cursor = #s end
    if ti.cursor < 0   then ti.cursor = 0  end

    render.text(x, y, lbl, {200,200,200,255})
    local by = y + 16
    local bh = 20
    local text_x = x + 5
    local text_w = w - 10
    local hov = is_hover(m, x, by, w, bh)
    local foc = focused_text == key

    -- click / defocus
    if m.clicked then
        if hov then
            local was_foc = foc
            focused_text = key
            cursor_blink_t = 0
            if not was_foc then ti.held = {} end

            local local_x = m.x - text_x
            if local_x < 0 then local_x = 0 end
            if local_x > text_w then local_x = text_w end
            ti.cursor = cursor_at_x(s, local_x)
            ti.drag_start = ti.cursor
            ti.drag_mx = m.x
            ti.drag_moved = false
            ti.dragging = true
            ti.sel_start, ti.sel_end = nil, nil
            m.clicked = false
        elseif foc then
            focused_text = nil
            ti.held = {}
            ti.dragging = false
            m.clicked = false
        end
    end

    -- drag-select
    if foc and ti.dragging then
        if m.down then
            if not ti.drag_moved and math.abs(m.x - (ti.drag_mx or m.x)) > 2 then
                ti.drag_moved = true
            end
            if ti.drag_moved then
                local local_x = m.x - text_x
                if local_x < 0 then local_x = 0 end
                if local_x > text_w then local_x = text_w end
                local cur = cursor_at_x(s, local_x)
                ti.cursor = cur
                ti.sel_start = ti.drag_start
                ti.sel_end = cur
            end
        else
            ti.dragging = false
            if ti.sel_start == ti.sel_end then
                ti.sel_start, ti.sel_end = nil, nil
            end
            ti.drag_moved = false
        end
    end

    if ti.cursor > #s then ti.cursor = #s end
    if ti.cursor < 0 then ti.cursor = 0 end

    -- box
    render.rect(x, by, w, bh,
        foc and {35,35,35,255} or (hov and {30,30,30,255} or {24,24,24,255}), true)
    render.rect(x, by, w, bh,
        foc and {150,150,150,255} or {50,50,50,255}, false)

    -- selection highlight (dark gray)
    if foc and ti.sel_start and ti.sel_end and ti.sel_start ~= ti.sel_end then
        local ss = math.min(ti.sel_start, ti.sel_end)
        local ee = math.max(ti.sel_start, ti.sel_end)
        local sx = text_x + measure_w(s:sub(1, ss))
        local ex = text_x + measure_w(s:sub(1, ee))
        render.rect(sx, by + 2, ex - sx, bh - 4, {60,60,60,200}, true)
    end

    -- text
    render.text(text_x, by + 4, s, {200,200,200,255})

    -- keyboard
    if foc and key_fn then
        local ctrl  = is_ctrl_down()
        local shift = is_shift_down()

        local function has_sel()
            return ti.sel_start and ti.sel_end and ti.sel_start ~= ti.sel_end
        end
        local function sel_range()
            local ss = math.min(ti.sel_start, ti.sel_end)
            local ee = math.max(ti.sel_start, ti.sel_end)
            return ss, ee
        end
        local function delete_selection()
            if not has_sel() then return false end
            local ss, ee = sel_range()
            s = s:sub(1, ss) .. s:sub(ee + 1)
            ti.cursor = ss
            ti.sel_start, ti.sel_end = nil, nil
            return true
        end
        local function insert_str(str)
            if #s + #str > 64 then
                str = str:sub(1, math.max(0, 64 - #s))
            end
            if str == "" then return end
            if has_sel() then
                local ss, ee = sel_range()
                s = s:sub(1, ss) .. str .. s:sub(ee + 1)
                ti.cursor = ss + #str
            else
                s = s:sub(1, ti.cursor) .. str .. s:sub(ti.cursor + 1)
                ti.cursor = ti.cursor + #str
            end
            ti.sel_start, ti.sel_end = nil, nil
        end

        if ti_press(key, "backspace", is_key_down(VK.BACKSPACE), now) then
            if not delete_selection() and ti.cursor > 0 then
                s = s:sub(1, ti.cursor - 1) .. s:sub(ti.cursor + 1)
                ti.cursor = ti.cursor - 1
            end
        end

        if ti_press(key, "delete", is_key_down(VK.DELETE), now) then
            if not delete_selection() and ti.cursor < #s then
                s = s:sub(1, ti.cursor) .. s:sub(ti.cursor + 2)
            end
        end

        if ti_press(key, "left", is_key_down(VK.LEFT), now) then
            local np = math.max(0, ti.cursor - 1)
            if shift then
                if not ti.sel_start then ti.sel_start = ti.cursor end
                ti.cursor = np
                ti.sel_end = ti.cursor
            else
                ti.cursor = np
                ti.sel_start, ti.sel_end = nil, nil
            end
        end

        if ti_press(key, "right", is_key_down(VK.RIGHT), now) then
            local np = math.min(#s, ti.cursor + 1)
            if shift then
                if not ti.sel_start then ti.sel_start = ti.cursor end
                ti.cursor = np
                ti.sel_end = ti.cursor
            else
                ti.cursor = np
                ti.sel_start, ti.sel_end = nil, nil
            end
        end

        if ti_press(key, "home", is_key_down(VK.HOME), now) then
            ti.cursor = 0
            ti.sel_start, ti.sel_end = nil, nil
        end
        if ti_press(key, "end", is_key_down(VK.END), now) then
            ti.cursor = #s
            ti.sel_start, ti.sel_end = nil, nil
        end

        if ti_press(key, "ctrl_a", ctrl and is_key_down(VK.A), now, true) then
            ti.sel_start = 0
            ti.sel_end = #s
            ti.cursor = #s
        end

        if ti_press(key, "ctrl_c", ctrl and is_key_down(VK.C), now, true) then
            local copy_text = s
            if has_sel() then
                local ss, ee = sel_range()
                copy_text = s:sub(ss + 1, ee)
            end
            if copy_text ~= "" then
                copy_to_clipboard(copy_text)
            end
        end

        if ti_press(key, "ctrl_v", ctrl and is_key_down(VK.V), now, true) then
            local paste = read_clipboard()
            if paste and paste ~= "" then
                paste = paste:gsub("[%c]", "")
                insert_str(paste)
            end
        end

        if just_pressed("enter_" .. key, function() return is_key_down(VK.ENTER) end) then
            focused_text = nil
            ti.held = {}
        end

        if not ctrl and ti_press(key, "space", is_key_down(VK.SPACE), now) then
            insert_str(" ")
        end

        if not ctrl then
            local upper = shift or is_key_down(VK.CAPSLOCK)
            for _, c in ipairs(CHAR_LIST) do
                local vk = char_to_vk(c)
                if vk and ti_press(key, "ch_" .. c, is_key_down(vk), now) then
                    insert_str(upper and c:upper() or c)
                end
            end
        end
    elseif focused_text ~= key then
        ti.held = {}
        ti.dragging = false
    end

    state[key] = s

    if foc and cursor_blink_t < 0.5 and not (ti.drag_moved and ti.dragging) then
        local cw = measure_w(s:sub(1, ti.cursor))
        render.rect(text_x + cw, by + 3, 1, bh - 6, {255,255,255,255}, true)
    end

    return by + bh + 10
end

local function draw_block_header(x, y, w, h, hdr, ttl)
    render.rect(x, y, w, h, {50,50,50,255}, false)
    render.rect(x, y, w-1, h, {17,17,17,255}, true)
    render.text(x + 15, y - 7, hdr, {255,255,255,255})
    render.text(x + 14, y - 7, hdr, {255,255,255,255})
end

local function render_dropdown(m, r, items, multi, key, hh)
    if hh <= 1 then return end
    local total_h = #items * 20
    local max_s = math.max(0, total_h - hh)
    local sy = dd_scroll[key] or 0
    if sy > max_s then sy = max_s end
    if sy < 0 then sy = 0 end
    dd_scroll[key] = sy

    render.rect(r.x, r.y, r.w, hh, {17,17,17,255}, true)
    render.rect(r.x, r.y, r.w, hh, {50,50,50,255}, false)
    render.push_clip_rect(r.x, r.y, r.w, hh)
    for i, item in ipairs(items) do
        local iy = r.y + (i-1) * 20 - sy
        if iy + 20 > r.y and iy < r.y + hh then
            local hv = is_hover(m, r.x, iy, r.w, 20) and open_dropdown == key
            local item_bg
            if multi then
                if state[key] and state[key][i] then
                    render.rect(r.x, iy, r.w, 20, {45,45,45,65}, true)
                    item_bg = composite_bg({45,45,45,65})
                elseif hv then
                    render.rect(r.x, iy, r.w, 20, {30,30,30,65}, true)
                    item_bg = composite_bg({30,30,30,65})
                else
                    item_bg = CARD_BG
                end
            else
                if state[key] == i then
                    render.rect(r.x, iy, r.w, 20, {45,45,45,65}, true)
                    item_bg = composite_bg({45,45,45,65})
                elseif hv then
                    render.rect(r.x, iy, r.w, 20, {30,30,30,65}, true)
                    item_bg = composite_bg({30,30,30,65})
                else
                    item_bg = CARD_BG
                end
            end
            draw_scrolled_label(r.x + 5, iy + 3, item, r.w - 10,
                {200,200,200,255}, nil, 16)
        end
    end
    render.pop_clip_rect()

    if total_h > DD_MAX_H then
        local thumb_h = hh * (hh / total_h)
        if thumb_h >= 4 then
            if thumb_h > hh then thumb_h = hh end
            local sb_w = 3
            local sb_x = r.x + r.w - sb_w - 1
            local spy = r.y + (sy / math.max(1, max_s)) * (hh - thumb_h)
            if spy < r.y then spy = r.y end
            if spy + thumb_h > r.y + hh then spy = r.y + hh - thumb_h end
            render.rect(sb_x, spy, sb_w, thumb_h, {160, 160, 160, 220}, true)
        end
    end
end

-- Color picker
local function rgb2hsv(r, g, b)
    r, g, b = r/255, g/255, b/255
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local d = mx - mn; local h, s, v = 0, 0, mx
    if mx > 0 then s = d / mx end
    if d ~= 0 then
        if mx == r then h = (g - b) / d + ((g < b) and 6 or 0)
        elseif mx == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
        h = h / 6
    end
    return h, s, v
end
local function hsv2rgb(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h*6) % 2 - 1))
    local m = v - c
    local r, g, b
    if h < 1/6 then r,g,b = c,x,0
    elseif h < 2/6 then r,g,b = x,c,0
    elseif h < 3/6 then r,g,b = 0,c,x
    elseif h < 4/6 then r,g,b = 0,x,c
    elseif h < 5/6 then r,g,b = x,0,c
    else r,g,b = c,0,x end
    return math.floor((r+m)*255+0.5), math.floor((g+m)*255+0.5), math.floor((b+m)*255+0.5)
end
local function p_sync_from(key)
    local c = state[key]
    local h, s, v = rgb2hsv(c.r, c.g, c.b)
    picker_data[key] = picker_data[key] or {}
    picker_data[key].hue = h; picker_data[key].sat = s
    picker_data[key].val = v; picker_data[key].alpha = c.a / 255
    picker_data[key].drag = nil
end
local function p_sync_to(key)
    local p = picker_data[key]
    local r, g, b = hsv2rgb(p.hue, p.sat, p.val)
    state[key].r, state[key].g, state[key].b = r, g, b
    state[key].a = math.floor(p.alpha * 255 + 0.5)
end

local function draw_color_button(m, x, y, w, h, key)
    local c = state[key]
    local hov = is_hover(m, x, y, w, h)
    local cw, ch = w / 3, h / 2
    for cy = 0, 1 do
        for cx = 0, 2 do
            local cc = ((cx + cy) % 2 == 0) and {150,150,150,255} or {200,200,200,255}
            render.rect(x + cx * cw, y + cy * ch, cw, ch, cc, true)
        end
    end
    render.rect(x, y, w, h, {c.r, c.g, c.b, c.a}, true)
    render.rect(x, y, w, h, {50,50,50,255}, false)  -- fixed border, no hover pop
    if hov and m.clicked then
        if picker_open == key then picker_open = nil
        else picker_open = key; p_sync_from(key) end
        m.clicked = false
    end
end

local function picker_input(m, key, x, y)
    local p = picker_data[key]
    if not p then return end
    local sq, st, gp = PICKER_SQ, PICKER_STRIPE, PICKER_GAP
    local ax = x + sq + gp
    local hy = y + sq + gp
    if m.clicked then
        if is_hover(m, x, y, sq, sq) then
            p.drag = "sv"
            p.sat = math.max(0, math.min(1, (m.x - x) / sq))
            p.val = 1 - math.max(0, math.min(1, (m.y - y) / sq))
            p_sync_to(key); m.clicked = false
        elseif is_hover(m, x, hy - 3, sq, st + 6) then
            p.drag = "hue"
            p.hue = math.max(0, math.min(1, (m.x - x) / sq))
            p_sync_to(key); m.clicked = false
        elseif is_hover(m, ax - 3, y, st + 6, sq) then
            p.drag = "alpha"
            p.alpha = 1 - math.max(0, math.min(1, (m.y - y) / sq))
            p_sync_to(key); m.clicked = false
        end
    end
    if p.drag == "sv" and m.down then
        p.sat = math.max(0, math.min(1, (m.x - x) / sq))
        p.val = 1 - math.max(0, math.min(1, (m.y - y) / sq))
        p_sync_to(key)
    elseif p.drag == "hue" and m.down then
        p.hue = math.max(0, math.min(1, (m.x - x) / sq))
        p_sync_to(key)
    elseif p.drag == "alpha" and m.down then
        p.alpha = 1 - math.max(0, math.min(1, (m.y - y) / sq))
        p_sync_to(key)
    end
    if not m.down then p.drag = nil end
end

local function picker_draw(x, y, key)
    local p = picker_data[key]
    if not p then return end
    local sq, st, gp = PICKER_SQ, PICKER_STRIPE, PICKER_GAP
    local ax = x + sq + gp
    local hy = y + sq + gp
    local tw = sq + gp + st + 10
    local th = sq + gp + st + 10
    render.rect(x - 5, y - 5, tw, th, {15,15,15,255}, true)
    render.rect(x - 5, y - 5, tw, th, {50,50,50,255}, false)
    local hr, hg, hb = hsv2rgb(p.hue, 1, 1)
    render.rect_filled_fade(x, y, sq, sq, {255,255,255,255}, {255,255,255,255}, {255,255,255,255}, {255,255,255,255})
    render.rect_filled_fade(x, y, sq, sq, {hr,hg,hb,0}, {hr,hg,hb,255}, {hr,hg,hb,255}, {hr,hg,hb,0})
    render.rect_filled_fade(x, y, sq, sq, {0,0,0,0}, {0,0,0,0}, {0,0,0,255}, {0,0,0,255})
    local sx = x + p.sat * sq; local sy = y + (1 - p.val) * sq
    render.circle(sx, sy, 5, {0,0,0,255}, false, 2)
    render.circle(sx, sy, 5, {255,255,255,255}, false, 1)
    local cr, cg, cb = hsv2rgb(p.hue, p.sat, p.val)
    local chk = 6
    for cy = 0, math.floor(sq / chk) do
        for cx = 0, math.floor(st / chk) do
            local cc = ((cx + cy) % 2 == 0) and {150,150,150,255} or {200,200,200,255}
            local pw = math.min(chk, st - cx * chk)
            local ph = math.min(chk, sq - cy * chk)
            if pw > 0 and ph > 0 then render.rect(ax + cx*chk, y + cy*chk, pw, ph, cc, true) end
        end
    end
    render.rect_filled_fade(ax, y, st, sq, {cr,cg,cb,255}, {cr,cg,cb,255}, {cr,cg,cb,0}, {cr,cg,cb,0})
    render.rect(ax, y, st, sq, {0,0,0,255}, false)
    local ay = y + (1 - p.alpha) * sq
    render.rect(ax - 2, ay - 1, st + 4, 2, {255,255,255,255}, true)
    for i = 0, sq - 1 do
        local h = i / sq
        local r, g, b = hsv2rgb(h, 1, 1)
        render.rect(x + i, hy, 1, st, {r,g,b,255}, true)
    end
    render.rect(x, hy, sq, st, {0,0,0,255}, false)
    local hcx = x + p.hue * sq
    render.rect(hcx - 1, hy - 2, 2, st + 4, {255,255,255,255}, true)
end

-- Scrollable block
local function draw_scrollable_block(m, x, y, w, h, hdr, ttl, key, content_fn)
    draw_block_header(x, y, w, h, hdr, ttl)
    local sb_w = 3
    local sb_x = x + w - sb_w - 1
    local sb_y = y + 2
    local sb_h = h - 4
    local clip_x = x + 1
    local clip_y = y + 20
    local clip_w = w - sb_w - 4
    local clip_h = h - 32
    local csx = x + 15
    local csy = y + 20

    if scroll[key] == nil         then scroll[key] = 0 end
    if last_max_scroll[key] == nil then last_max_scroll[key] = 0 end
    if scroll[key] > last_max_scroll[key] then scroll[key] = last_max_scroll[key] end

    render.push_clip_rect(clip_x, clip_y, clip_w, clip_h)
    local old_clip = _clip
    _clip = {x = clip_x, y = clip_y, w = clip_w, h = clip_h}
    local draw_y = csy - scroll[key]
    local end_y = content_fn(csx, draw_y, clip_w - 30)
    _clip = old_clip
    render.pop_clip_rect()

    local natural_h = end_y - draw_y
    local max_scroll = math.max(0, natural_h - clip_h)
    last_max_scroll[key] = max_scroll
    if (scroll[key] or 0) > max_scroll then scroll[key] = max_scroll end

    if max_scroll > 0 then
        local ratio = clip_h / natural_h
        local hh = math.max(12, sb_h * ratio)
        local hy = sb_y + (scroll[key] / max_scroll) * (sb_h - hh)
        render.rect(sb_x, hy, sb_w, hh, {160, 160, 160, 220}, true)
        if m ~= DEAD_MOUSE and m.clicked and is_hover(m, sb_x - 3, sb_y, sb_w + 6, sb_h) then
            dragging_scrollbar = key
            if is_hover(m, sb_x - 3, hy, sb_w + 6, hh) then
                scroll_drag_off[key] = m.y - hy
            else
                scroll_drag_off[key] = hh / 2
                local pct = (m.y - sb_y - hh/2) / (sb_h - hh)
                scroll[key] = math.max(0, math.min(max_scroll, pct * max_scroll))
            end
            m.clicked = false
        end
        if dragging_scrollbar == key and m.down and m ~= DEAD_MOUSE then
            local local_y = m.y - sb_y - (scroll_drag_off[key] or hh/2)
            local pct = local_y / (sb_h - hh)
            scroll[key] = math.max(0, math.min(max_scroll, pct * max_scroll))
        end
        if (not m.down or m == DEAD_MOUSE) and dragging_scrollbar == key then
            dragging_scrollbar = nil
        end
    end
end

-- CONTENT FUNCTIONS
-- AutoBuy
local function content_autobuy(m, x, y, cw, dt, jc)
    local cy = y
    cy = draw_checkbox(m, x, cy, "Weapons", "cb_weapons", dt)
    local ix, iw = x + 20, cw - 20
    cy = draw_combo(m, ix, cy, "Primary weapon", "combo_primary",
        {"G3SG1 / SCAR-20", "AWP", "SSG 08", "Negev"}, jc, iw)
    cy = draw_combo(m, ix, cy, "Secondary", "combo_secondary",
        {"R8 Revolver", "Desert Eagle"}, jc, iw)
    cy = draw_combo(m, ix, cy, "Armor", "combo_armor",
        {"None", "Armor", "Armor, Helmet"}, jc, iw)
    cy = cy + 8
    cy = draw_checkbox(m, x, cy, "Utility", "cb_utility", dt)
    cy = draw_multicombo(m, ix, cy, "Grenades", "multi_utility",
        {"None", "Inferno", "HE", "Smoke", "Flash", "Decoy"}, jc, 1, iw)
    cy = draw_multicombo(m, ix, cy, "Zeus & Kits", "multi_another",
        {"None", "Zeus x27", "Defuse kits"}, jc, 1, iw)

    cy = cy + 6
    cy = draw_checkbox(m, x, cy, "Autobuy Delay", "buy_delay_enabled", dt)
    cy = draw_slider(m, ix, cy, "Delay", "buy_delay_value", 0.05, 5.0, dt,
        function(v) return string.format("%.2fs", v) end, iw)
    return cy
end

local function content_awall(m, x, y, cw, dt)
    local cy = y
    cy = draw_checkbox(m, x, cy, "Truth Awall", "aw_truth", dt)
    cy = draw_checkbox(m, x, cy, "Visual Awall", "aw_visual", dt)
    local ix, iw = x + 20, cw - 20
    local btn_x = x + cw - 16
    render.text(ix, cy, "Through color", {200,200,200,255})
    draw_color_button(m, btn_x, cy + 1, 16, 8, "aw_col_through")
    picker_positions.aw_col_through = {x = btn_x, y = cy + 12}
    cy = cy + 22
    render.text(ix, cy, "Blocked color", {200,200,200,255})
    draw_color_button(m, btn_x, cy + 1, 16, 8, "aw_col_blocked")
    picker_positions.aw_col_blocked = {x = btn_x, y = cy + 12}
    cy = cy + 22
    cy = draw_slider(m, ix, cy, "Square Size", "aw_sq_size", 4, 40, dt, nil, iw)
    cy = draw_slider(m, ix, cy, "Smoothing", "aw_smooth", 0.1, 1.0, dt,
        function(v) return string.format("%.2f", v) end, iw)
    cy = draw_slider(m, ix, cy, "Marker Hold", "aw_hold", 0.05, 2.0, dt,
        function(v) return string.format("%.2fs", v) end, iw)
    return cy
end

-- NameChanger
local function nc_sanitize_nick(s)
    s = tostring(s or ""):gsub('[%c"\\;]', "")
    if #s > 64 then s = s:sub(1, 64) end
    return s
end

local function content_namechanger(m, x, y, cw, dt, jc)
    local cy = y

    -- Status indicator
    if NC_STATUS ~= "ok" then
        local st_txt, st_col
        if NC_STATUS == "no_dll" then
            st_txt = "DLL not found — see log / set nc_dll_override"
            st_col = {220, 120, 120, 255}
        elseif NC_STATUS == "dll_init_failed" then
            st_txt = "DLL init failed (arch / missing deps?)"
            st_col = {220, 120, 120, 255}
        elseif NC_STATUS == "no_ffi" then
            st_txt = "FFI unavailable in sandbox"
            st_col = {220, 120, 120, 255}
        else
            st_txt = "initializing..."
            st_col = {220, 200, 120, 255}
        end
        render.text(x, cy, st_txt, st_col)
        cy = cy + 22
    end

    cy = draw_checkbox(m, x, cy, "Name Changer", "nc_on", dt)
    local ix, iw = x + 20, cw - 20

    -- Compute valid steal targets once (excludes self)
    local valid_names = nc_get_valid_names()
    local has_players = (#valid_names > 0)

    -- Force Default when there's nobody to steal from
    if not has_players and state.nc_type ~= 1 then
        state.nc_type = 1
    end

    -- Stealer option is non-clickable when list is empty
    local type_m = has_players and m or DEAD_MOUSE
    cy = draw_combo(type_m, ix, cy, "Type", "nc_type", {"Default", "Stealer"}, jc, iw, not has_players)

    if not has_players then
        -- render.text(ix, cy - 4, "No players to steal - wait for someone",
        --    {160, 160, 160, 255})
        -- cy = cy + 12
    end

    if state.nc_type == 2 then
        cy = draw_combo(m, ix, cy, "Stealer Mode", "nc_steal_mode", {"Certain", "Few"}, jc, iw)

        if not has_players then
            render.text(ix, cy, "No valid players found", {150,150,150,255})
            cy = cy + 22
        else
            -- Clamp index if player count shrunk since last selection
            if state.nc_steal_mode == 1 then
                if (state.nc_steal_single or 1) > #valid_names then
                    state.nc_steal_single = 1
                end
                if state.nc_steal_single < 1 then state.nc_steal_single = 1 end
                cy = draw_combo(m, ix, cy, "Select Player", "nc_steal_single", valid_names, jc, iw)
            elseif state.nc_steal_mode == 2 then
                -- Re-densify multi array to current list length
                local old = state.nc_steal_multi or {}
                local dense = {}
                for i = 1, #valid_names do
                    dense[i] = old[i] == true
                end
                state.nc_steal_multi = dense

                cy = draw_multicombo(m, ix, cy, "Select Players", "nc_steal_multi", valid_names, jc, nil, iw)
                cy = draw_slider(m, ix, cy, "Swap delay", "nc_steal_delay", 0.1, 10.0, dt,
                    function(v) return string.format("%.1fs", v) end, iw)
            end
        end
        cy = cy + 4
    else
        cy = draw_text_input(m, ix, cy, "Custom Nick", "nc_name", iw, dt)
        cy = cy + 4
    end

    -- Clantag settings (always rendered, independent of name type)
    cy = draw_checkbox(m, x, cy, "Clantag", "nc_tag_on", dt)
    cy = draw_combo(m, ix, cy, "Clantag Source", "nc_tag_source",
        {"Custom", "One", "Few"}, jc, iw)

    local preset_names = {}
    for i = 1, #NC_TAG_PRESETS do
        preset_names[i] = NC_TAG_PRESETS[i].name
    end

    if state.nc_tag_source == 3 then
        cy = draw_multicombo(m, ix, cy, "Tags", "nc_tag_presets",
            preset_names, jc, nil, iw)
        for i = 1, #NC_TAG_PRESETS do
            if state.nc_tag_presets and state.nc_tag_presets[i] then
                local preset = NC_TAG_PRESETS[i]
                if preset.postfixes then
                    local pfx_key = "nc_pfx_" .. i
                    if state[pfx_key] == nil then state[pfx_key] = 1 end
                    cy = draw_combo(m, ix, cy, preset.name .. " postfix",
                        pfx_key, preset.postfixes, jc, iw)
                end
            end
        end
        cy = draw_slider(m, ix, cy, "Swap delay", "nc_swap_delay", 0.1, 10.0, dt,
            function(v) return string.format("%.1fs", v) end, iw)
    elseif state.nc_tag_source == 2 then
        cy = draw_combo(m, ix, cy, "Tag", "nc_tag_single",
            preset_names, jc, iw)
        local preset = NC_TAG_PRESETS[state.nc_tag_single or 1]
        if preset and preset.postfixes then
            if state.nc_pfx_single == nil then state.nc_pfx_single = 1 end
            cy = draw_combo(m, ix, cy, preset.name .. " postfix",
                "nc_pfx_single", preset.postfixes, jc, iw)
        end
    else
        cy = draw_text_input(m, ix, cy, "Clantag text", "nc_tag", iw, dt)
    end

    cy = draw_checkbox(m, x, cy, "Tag Wrapper", "nc_tag_wrap_enabled", dt)
    if state.nc_tag_wrap_enabled then
        cy = draw_combo(m, ix, cy, "Wrapper Style", "nc_tag_wrap",
            {"Square []", "Curly {}", "Angle <>", "Equals =="}, jc, iw)
    end

    cy = draw_checkbox(m, x, cy, "Tag Animation", "nc_tag_anim_enabled", dt)
    if state.nc_tag_anim_enabled then
        cy = draw_combo(m, ix, cy, "Animation Type", "nc_tag_mode",
            {"Typing", "Jitter", "Sliding"}, jc, iw)
        if state.nc_tag_mode == 1 then
            cy = draw_combo(m, ix, cy, "Typing Cursor", "nc_cursor", {"|", "/", "\\", "_"}, jc, iw)
        end
        cy = draw_slider(m, ix, cy, "Tag Speed", "nc_tag_spd", 0.05, 1.0, dt,
            function(v) return string.format("%.2fs", v) end, iw)
    end
    cy = draw_combo(m, ix, cy, "Tag Position", "nc_tag_pos",
        {"Before", "After"}, jc, iw)
    return cy
end

local AA_STATE_LABELS = {
    aa_stand  = "Anti-Aim — Standing",
    aa_crouch = "Anti-Aim — Crouch",
    aa_move   = "Anti-Aim — Move",
    aa_air    = "Anti-Aim — Air",
}

local function content_aa_state(m, x, y, cw, dt, jc, sk)
    local cy = y
    local ix, iw = x + 20, cw - 20

    cy = draw_checkbox(m, x, cy, AA_STATE_LABELS[sk] or "Anti-Aim", sk .. "_enabled", dt)
    cy = draw_checkbox(m, x, cy, "At target", sk .. "_at_target", dt)
    cy = draw_combo(m, ix, cy, "Yaw", sk .. "_yaw",
        {"Off", "Left", "Right", "Back", "Custom"}, jc, iw)
    if state[sk .. "_yaw"] == 5 then
        cy = draw_slider(m, ix, cy, "Yaw angle", sk .. "_yaw_custom", -180, 180, dt,
        function(v) return string.format("%d°", math.floor(v)) end, iw)
    end
    cy = draw_combo(m, ix, cy, "Pitch", sk .. "_pitch",
        {"Off", "Camera", "Up", "Down", "Custom"}, jc, iw)
    if state[sk .. "_pitch"] == 5 then
        cy = draw_slider(m, ix, cy, "Pitch angle", sk .. "_pitch_custom", -89, 89, dt,
        function(v) return string.format("%d°", math.floor(v)) end, iw)
    end

    if sk == "aa_air" then
        cy = cy + 4
        cy = draw_checkbox(m, x, cy, "Only Space on hold", "aa_air_only_space", dt)
        cy = draw_slider(m, ix, cy, "Space Threshold", "aa_air_space_threshold", 0.5, 1.0, dt,
            function(v) return string.format("%.2fs", v) end, iw)
        cy = cy + 4
    end

    cy = cy + 6

    -- Additional AA (Spin / Jitter)
    cy = draw_checkbox(m, x, cy, "Additional AA", sk .. "_extra_yaw_enabled", dt)
    if state[sk .. "_extra_yaw_enabled"] then
        cy = draw_combo(m, ix, cy, "AA type", sk .. "_aa_types",
            {"Spin", "Jitter"}, jc, iw)
        local aa_type = state[sk .. "_aa_types"] or 1
        if aa_type == 1 then
            cy = draw_combo(m, ix, cy, "Around", sk .. "_spin_dir", {"Left", "Right"}, jc, iw)
            cy = draw_slider(m, ix, cy, "Speed", sk .. "_spin_speed", 0, 180, dt, nil, iw)
        elseif aa_type == 2 then
            cy = draw_combo(m, ix, cy, "Mode", sk .. "_jitter_mode",
                {"Center", "Offset", "Random", "Three Way"}, jc, iw)
            cy = draw_slider(m, ix, cy, "Degree", sk .. "_jitter_degree", 1, 90, dt, function(v) return string.format("%d°", math.floor(v)) end, iw)
            cy = draw_slider(m, ix, cy, "Speed", sk .. "_jitter_speed", 0.05, 1.0, dt,
                function(v) return string.format("%.2fs", v) end, iw)
        end
    end

    cy = cy + 6

    -- Random Flick (fixed flip: Yaw = 180°, Pitch = opposite)
    cy = draw_checkbox(m, x, cy, "Random Flick", sk .. "_flick_enabled", dt)
    if state[sk .. "_flick_enabled"] then
        cy = draw_multicombo(m, ix, cy, "Flick on", sk .. "_flick_axes",
            {"For Yaw", "For Pitch"}, jc, nil, iw)
        local axes = state[sk .. "_flick_axes"] or {false, false}
        if axes[1] then
            cy = draw_slider(m, ix, cy, "Yaw — Flick Delay",
                sk .. "_flick_yaw_delay", 0.5, 10.0, dt,
                function(v) return string.format("%.2fs", v) end, iw)
        end
        if axes[2] then
            cy = draw_slider(m, ix, cy, "Pitch — Flick Delay",
                sk .. "_flick_pitch_delay", 0.5, 10.0, dt,
                function(v) return string.format("%.2fs", v) end, iw)
        end
    end
    return cy
end

local function content_backtrack(m, x, y, cw, dt, jc)
    local cy = y
    local ix, iw = x + 20, cw - 20
    local btn_x = x + cw - 16

    cy = draw_checkbox(m, x, cy, "Backtrack (Visual)", "bt_enabled", dt)
    cy = draw_combo(m, ix, cy, "Mode", "bt_mode", {"Smooth", "Model"}, jc, iw)
    cy = draw_combo(m, ix, cy, "Backtrack after death", "bt_history",
        {"Last pos", "Clear"}, jc, iw)
    cy = draw_combo(m, ix, cy, "Max targets", "bt_targets_mode",
        {"Target", "All", "Custom"}, jc, iw)
    if state.bt_targets_mode == 3 then
        cy = draw_slider(m, ix, cy, "Custom targets", "bt_targets", 1, 10, dt, nil, iw)
    end

    cy = draw_slider(m, ix, cy, "Max FOV", "bt_fov", 1, 180, dt, nil, iw)
    cy = draw_slider(m, ix, cy, "Max age", "bt_age", 0, 500, dt, nil, iw)
    cy = draw_slider(m, ix, cy, "Records/target", "bt_records", 1, 16, dt, nil, iw)
    cy = draw_slider(m, ix, cy, "Min hitchance", "bt_hc", 0, 100, dt, function(v) return string.format("%d%%", math.floor(v)) end, iw)
    cy = draw_slider(m, ix, cy, "HC per tick", "bt_queries", 1, 32, dt, function(v) return string.format("%d%%", math.floor(v)) end, iw)

    render.text(ix, cy, "Good color", {200,200,200,255})
    draw_color_button(m, btn_x, cy + 1, 16, 8, "bt_col_ok")
    picker_positions.bt_col_ok = {x = btn_x, y = cy + 12}
    cy = cy + 22
    render.text(ix, cy, "Bad color", {200,200,200,255})
    draw_color_button(m, btn_x, cy + 1, 16, 8, "bt_col_bad")
    picker_positions.bt_col_bad = {x = btn_x, y = cy + 12}
    cy = cy + 22

    cy = draw_slider(m, ix, cy, "Smooth alpha multi", "bt_mult_all", 0.01, 1.0, dt,
        function(v) return string.format("%.2f", v) end, iw)
    cy = draw_slider(m, ix, cy, "Model alpha multi", "bt_mult_one", 0.01, 1.0, dt,
        function(v) return string.format("%.2f", v) end, iw)

    cy = draw_checkbox(m, x, cy, "Show info", "bt_info", dt)
    render.text(ix, cy, "Info color", {200,200,200,255})
    draw_color_button(m, btn_x, cy + 1, 16, 8, "bt_info_col")
    picker_positions.bt_info_col = {x = btn_x, y = cy + 12}
    cy = cy + 22

    return cy
end

local function content_crosshair(m, x, y, cw, dt, jc)
    local cy = y
    local ix, iw = x + 20, cw - 20
    local btn_x = x + cw - 16
    cy = draw_checkbox(m, x, cy, "Crosshair", "ch_enabled", dt)
    cy = draw_combo(m, ix, cy, "Type", "ch_type", {"Dot", "Small", "Plus"}, jc, iw)
    render.text(ix, cy, "Normal color", {200,200,200,255})
    draw_color_button(m, btn_x, cy + 1, 16, 8, "ch_col_norm")
    picker_positions.ch_col_norm = {x = btn_x, y = cy + 12}
    cy = cy + 26
    cy = draw_checkbox(m, x, cy, "Penetration", "ch_pen_enabled", dt)
    render.text(ix, cy, "Penetrable", {200,200,200,255})
    draw_color_button(m, btn_x, cy + 1, 16, 8, "ch_col_pen")
    picker_positions.ch_col_pen = {x = btn_x, y = cy + 12}
    cy = cy + 22
    render.text(ix, cy, "On enemy", {200,200,200,255})
    draw_color_button(m, btn_x, cy + 1, 16, 8, "ch_col_enemy")
    picker_positions.ch_col_enemy = {x = btn_x, y = cy + 12}
    cy = cy + 22
    return cy
end

local function content_trail(m, x, y, cw, dt, jc)
    local cy = y
    local ix, iw = x + 20, cw - 20
    local btn_x = x + cw - 16
    cy = draw_checkbox(m, x, cy, "Player trail", "tr_enabled", dt)
    cy = draw_slider(m, ix, cy, "Height offset", "tr_height", -100, 200, dt, nil, iw)
    cy = draw_slider(m, ix, cy, "Trail length", "tr_len", 5, 100, dt, nil, iw)
    cy = draw_slider(m, ix, cy, "Lifetime", "tr_life", 0.1, 3.0, dt,
        function(v) return string.format("%.2fs", v) end, iw)
    cy = draw_slider(m, ix, cy, "Width", "tr_width", 1, 30, dt, nil, iw)
    render.text(ix, cy, "Color", {200,200,200,255})
    draw_color_button(m, btn_x, cy + 1, 16, 8, "tr_color")
    picker_positions.tr_color = {x = btn_x, y = cy + 12}
    cy = cy + 22
    cy = draw_checkbox(m, x, cy, "Rainbow", "tr_rainbow", dt)
    cy = draw_checkbox(m, x, cy, "Fade out", "tr_fade", dt)
    return cy
end

local function content_enemy_arrows(m, x, y, cw, dt, jc)
    local cy = y
    local ix, iw = x + 20, cw - 20
    local btn_x = x + cw - 16
    cy = draw_checkbox(m, x, cy, "Enemy arrows", "ea_enabled", dt)
    cy = draw_checkbox(m, x, cy, "Only off-screen", "ea_offscreen", dt)
    cy = draw_slider(m, ix, cy, "Ring radius", "ea_radius", 40, 600, dt, nil, iw)
    cy = draw_slider(m, ix, cy, "Arrow size", "ea_size", 4, 40, dt, nil, iw)
    cy = draw_slider(m, ix, cy, "Max arrows", "ea_limit", 1, 16, dt, nil, iw)
    cy = draw_slider(m, ix, cy, "Max distance", "ea_dist", 100, 20000, dt, nil, iw)
    cy = draw_slider(m, ix, cy, "Target height", "ea_eye", 0, 180, dt, nil, iw)
    cy = draw_combo(m, ix, cy, "Style", "ea_style",
        {"Chevron", "Dart", "Double", "Diamond"}, jc, iw)
    cy = draw_checkbox(m, x, cy, "Show health", "ea_hp", dt)
    cy = draw_checkbox(m, x, cy, "Show name", "ea_name", dt)
    cy = draw_checkbox(m, x, cy, "Fade with distance", "ea_fade", dt)
    cy = draw_checkbox(m, x, cy, "Color by health", "ea_by_health", dt)
    cy = draw_checkbox(m, x, cy, "Outline", "ea_outline", dt)
    cy = draw_checkbox(m, x, cy, "Neon glow", "ea_neon", dt)
    cy = draw_slider(m, ix, cy, "Glow layers", "ea_glow", 1, 8, dt, nil, iw)
    render.text(ix, cy, "Arrow color", {200,200,200,255})
    draw_color_button(m, btn_x, cy + 1, 16, 8, "ea_color")
    picker_positions.ea_color = {x = btn_x, y = cy + 12}
    cy = cy + 22
    if state.ea_by_health then
        render.text(ix, cy, "Health high", {200,200,200,255})
        draw_color_button(m, btn_x, cy + 1, 16, 8, "ea_hp_high")
        picker_positions.ea_hp_high = {x = btn_x, y = cy + 12}
        cy = cy + 22
        render.text(ix, cy, "Health low", {200,200,200,255})
        draw_color_button(m, btn_x, cy + 1, 16, 8, "ea_hp_low")
        picker_positions.ea_hp_low = {x = btn_x, y = cy + 12}
        cy = cy + 22
    end
    render.text(ix, cy, "Outline color", {200,200,200,255})
    draw_color_button(m, btn_x, cy + 1, 16, 8, "ea_outline_color")
    picker_positions.ea_outline_color = {x = btn_x, y = cy + 12}
    cy = cy + 22
    render.text(ix, cy, "Text color", {200,200,200,255})
    draw_color_button(m, btn_x, cy + 1, 16, 8, "ea_text_color")
    picker_positions.ea_text_color = {x = btn_x, y = cy + 12}
    cy = cy + 22
    return cy
end

-- Watermark content
local function content_watermark(m, x, y, cw, dt, jc)
    local cy = y
    local ix, iw = x + 20, cw - 20
    cy = draw_checkbox(m, x, cy, "Watermark", "wm_enabled", dt)
    cy = draw_combo(m, ix, cy, "Position", "wm_pos",
        {"Left-Top", "Left-Bottom", "Center-Top", "Center-Bottom", "Right-Top", "Right-Bottom"}, jc, iw)
    cy = draw_combo(m, ix, cy, "Size", "wm_size", {"Small", "Medium", "Large"}, jc, iw)
    cy = draw_slider(m, ix, cy, "Padding extra", "wm_pad", 0, 12, dt, nil, iw)
    cy = draw_checkbox(m, x, cy, "Background", "wm_bg_en", dt)
    cy = draw_multicombo(m, ix, cy, "Show", "wm_items",
        {"FPS", "Speed", "Jitter", "Map", "Time"}, jc, nil, iw)
    return cy
end

local function content_cs(m, x, y, cw, dt, jc)
    local cy = y
    local ix, iw = x + 20, cw - 20
    cy = draw_checkbox(m, x, cy, "Chat Spammer", "cs_enabled", dt)
    cy = draw_text_input(m, ix, cy, "Message", "cs_message", iw, dt)
    cy = draw_slider(m, ix, cy, "Interval", "cs_interval", 1, 30, dt,
        function(v) return string.format("%.0fs", v) end, iw)
    cy = draw_checkbox(m, x, cy, "Team chat only", "cs_team_only", dt)
    return cy
end

local function tt_phrase_labels(pool)
    local out = {}
    for i = 1, #pool do
        local p = pool[i]
        if type(p) == "string" then
            out[i] = p
        else
            out[i] = "[" .. table.concat(p, " ") .. "]"
        end
    end
    return out
end

local function content_tt(m, x, y, cw, dt, jc)
    local cy = y
    local ix, iw = x + 20, cw - 20

    cy = draw_checkbox(m, x, cy, "TrashTalk", "tt_enabled", dt)

    cy = draw_multicombo(m, ix, cy, "On", "tt_situations",
        {"On Kill", "On Death"}, jc, nil, iw)

    cy = draw_combo(m, ix, cy, "TrashTalk Phrases", "tt_phrases_mode",
        {"All", "Custom"}, jc, iw)
    cy = draw_combo(m, ix, cy, "Language", "tt_lang", {"English", "Russian"}, jc, iw)

    if state.tt_phrases_mode == 2 then
        local lang_key = state.tt_lang == 2 and "RU" or "EN"
        local lang_lc  = lang_key:lower()
        local sit = state.tt_situations or {}

        if sit[1] then
            local pool = TT_KILL[lang_key] or {}
            local labels = tt_phrase_labels(pool)
            local sel_key = "tt_sel_kill_" .. lang_lc
            if type(state[sel_key]) ~= "table" then state[sel_key] = {} end
            cy = draw_multicombo(m, ix, cy, "Phrases Select - On Kill", sel_key, labels, jc, nil, iw)
        end
        if sit[2] then
            local pool = TT_DEATH[lang_key] or {}
            local labels = tt_phrase_labels(pool)
            local sel_key = "tt_sel_death_" .. lang_lc
            if type(state[sel_key]) ~= "table" then state[sel_key] = {} end
            cy = draw_multicombo(m, ix, cy, "Phrases Select - On Death", sel_key, labels, jc, nil, iw)
        end
    end
    return cy
end

local function content_blur(m, x, y, cw, dt, jc)
    local cy = y
    local ix, iw = x + 20, cw - 20

    cy = draw_checkbox(m, x, cy, "Blur", "blur_enabled", dt)
    local m = state.blur_enabled and m or DEAD_MOUSE
    cy = draw_combo(m, ix, cy, "Tint", "blur_mode", {"White", "Black"}, jc, iw)
    cy = draw_slider(m, ix, cy, "Opacity", "blur_opacity", 0.1, 1.0, dt,
        function(v) return string.format("%.2f", v) end, iw)
    cy = draw_slider(m, ix, cy, "Fade speed", "blur_speed", 1, 30, dt,
        function(v) return string.format("%.0f", v) end, iw)

    cy = cy + 6

    cy = draw_checkbox(m, x, cy, "Particles", "blur_particles_enabled", dt)
    local pm = state.blur_particles_enabled and m or DEAD_MOUSE
    cy = draw_combo(pm, ix, cy, "Type", "blur_particles", {"Stars", "Snow", "Orbs"}, jc, iw)
    cy = draw_slider(pm, ix, cy, "Fade speed", "particles_speed", 1, 30, dt,
        function(v) return string.format("%.0f", v) end, iw)
    cy = draw_slider(pm, ix, cy, "Move speed", "particles_move_speed", 0.1, 3.0, dt,
        function(v) return string.format("%.2fx", v) end, iw)
    return cy
end

local dt_check_time = 0
local dt_check_result = nil
local function content_dt_ind(m, x, y, cw, dt, jc)
    local cy = y
    local ix, iw = x + 20, cw - 20
    local btn_x = x + cw - 16

    -- detect DT enabled - settings primary, combat fallback, cached 0.5s
    local dt_active = false
    do
        local now = client.time()
        if now - (dt_check_time or 0) >= 0.5 then
            dt_check_time = now
            local tries = {
                {"rage", "double tap"}, {"ragebot", "double tap"},
                {"rage", "doubletap"},  {"double tap", "double tap"},
            }
            for _, t in ipairs(tries) do
                local ok, val = _pcall(function() return settings.get(t[1], t[2]) end)
                if ok and val ~= nil then
                    if val == true or val == 1 then dt_check_result = true
                    else dt_check_result = false end
                    break
                end
            end
            if dt_check_result == nil then
                local dts = (combat and combat.double_tap) and combat.double_tap() or nil
                if dts and (dts.active or dts.enabled or dts.ready) then
                    dt_check_result = true
                else
                    dt_check_result = false
                end
            end
        end
        dt_active = (dt_check_result == true)
    end

    cy = draw_checkbox(m, x, cy, "DoubleTap Indicator", "dt_ind_enabled", dt, not dt_active)
    if not dt_active then
        -- red hint UNDER the checkbox
        render.text(x + 20, cy - 4, "Enable Double Tap in Ragebot config", {220, 120, 120, 255})
        cy = cy + 14
        return cy
    end

    cy = draw_combo(m, ix, cy, "Based on", "dt_ind_based_on",
        {"Scope", "Screen"}, jc, iw)

    if state.dt_ind_based_on == 1 then
        -- Scope mode
        cy = draw_combo(m, ix, cy, "Indicator Type", "dt_ind_type",
            {"Circle", "Square", "Line"}, jc, iw)

        if state.dt_ind_type == 3 then
            cy = draw_combo(m, ix, cy, "Line Position", "dt_ind_line_pos",
                {"Above", "Below", "Left", "Right"}, jc, iw)
            cy = draw_slider(m, ix, cy, "Line Offset", "dt_ind_line_offset", 20, 300, dt, nil, iw)
        end

        cy = draw_slider(m, ix, cy, "Size", "dt_ind_size", 16, 120, dt, nil, iw)
        cy = draw_slider(m, ix, cy, "Thickness", "dt_ind_thickness", 1, 8, dt,
            function(v) return string.format("%.1f", v) end, iw)

        render.text(ix, cy, "Color", {200,200,200,255})
        draw_color_button(m, btn_x, cy + 1, 16, 8, "dt_ind_color")
        picker_positions.dt_ind_color = {x = btn_x, y = cy + 12}
        cy = cy + 22
    else
        -- Screen mode
        cy = draw_combo(m, ix, cy, "Takes", "dt_ind_takes",
            {"Full", "Above", "Below", "Left", "Right"}, jc, iw)
        cy = draw_slider(m, ix, cy, "Thickness", "dt_ind_screen_thickness", 1, 5, dt,
            function(v) return string.format("%.1f", v) end, iw)

        render.text(ix, cy, "Color", {200,200,200,255})
        draw_color_button(m, btn_x, cy + 1, 16, 8, "dt_ind_screen_color")
        picker_positions.dt_ind_screen_color = {x = btn_x, y = cy + 12}
        cy = cy + 22
    end
    return cy
end

-- Servers (monochrome, animated rows + buttons)
local function content_servers(m, x, y, cw, dt, jc)
    local cy = y
    local row_h   = 48
    local row_gap = 4
    local now     = client.time()
    local N_FILL, N_STROKE, N_TEXT = {26,26,26,255}, {58,58,58,255}, {180,180,180,255}
    local H_FILL, H_STROKE, H_TEXT = {42,42,42,255}, {110,110,110,255}, {255,255,255,255}
    local F_FILL, F_STROKE, F_TEXT = {62,62,62,255}, {170,170,170,255}, {255,255,255,255}
    local btn_w, btn_h = 84, 24
    local btn_x  = x + cw - btn_w - 10
    local reg_w  = 26
    local reg_x  = x + cw - 226
    local mode_x = reg_x + reg_w + 8

    cy = draw_multicombo(m, x, cy, "Servers Filter", "sv_filter",
        HVH_MODES, jc, nil, cw)
    cy = cy + 2

    local filtered = {}
    local sf = state.sv_filter or {}
    for _, sv in ipairs(HVH_SERVERS) do
        if sf[sv.mode] then filtered[#filtered + 1] = sv end
    end
    if #filtered == 0 then
        render.text(x, cy + 8, "No servers match the selected filters", {128,128,128,255})
        return cy + 30
    end

    for i, sv in ipairs(filtered) do
        local ry = cy
        local row_hov = is_hover(m, x, ry, cw, row_h)
        local row_cur = server_row_hov[sv.ip] or 0
        row_cur = animate(row_cur, row_hov and 1 or 0, 14, dt)
        server_row_hov[sv.ip] = row_cur
        local bg     = lerp_col({16,16,16,255}, {24,24,24,255}, row_cur)
        local border = lerp_col({40,40,40,255}, {70,70,70,255}, row_cur)
        render.rect(x, ry, cw, row_h, bg, true)
        render.rect(x, ry, cw, row_h, border, false)
        if row_cur > 0.02 then
            render.rect(x, ry + 4, 2, row_h - 8, {200,200,200, math.floor(255 * row_cur)}, true)
        end
        render.text(x + 12, ry + row_h/2 - 6, tostring(i), {85,85,85,255})
        local name_c = lerp_col({225,225,225,255}, {255,255,255,255}, row_cur)
        render.text(x + 30, ry + 8, sv.name, name_c)
        render.text(x + 30, ry + 26, sv.ip, {140,140,140,255})
        local reg_y = ry + (row_h - 14) / 2
        render.rect(reg_x, reg_y, reg_w, 14, {28,28,28,255}, true)
        render.rect(reg_x, reg_y, reg_w, 14, {60,60,60,255}, false)
        local rw = render.measure_text(sv.region)
        render.text(reg_x + (reg_w - rw)/2, reg_y + 1, sv.region, {210,210,210,255})
        local mode_name = HVH_MODES[sv.mode] or "?"
        render.text(mode_x, ry + row_h/2 - 6, mode_name, {160,160,160,255})
        local btn_hov = is_hover(m, btn_x, ry + (row_h - btn_h) / 2, btn_w, btn_h)
        local cur = server_btn_hov[sv.ip] or 0
        cur = animate(cur, btn_hov and 1 or 0, 14, dt)
        server_btn_hov[sv.ip] = cur
        local flash_alpha = 0
        if sv.ip == server_last_ip then
            local flash_t = now - server_last_click
            if flash_t >= 0 and flash_t < 1.2 then
                flash_alpha = (1 - flash_t / 1.2) ^ 1.8
            end
        end
        local fill   = lerp_col(lerp_col(N_FILL,   H_FILL,   cur), F_FILL,   flash_alpha)
        local stroke = lerp_col(lerp_col(N_STROKE, H_STROKE, cur), F_STROKE, flash_alpha)
        local txt_c  = lerp_col(lerp_col(N_TEXT,   H_TEXT,   cur), F_TEXT,   flash_alpha)
        local btn_y = ry + (row_h - btn_h) / 2
        render.rect(btn_x, btn_y, btn_w, btn_h, fill, true)
        render.rect(btn_x, btn_y, btn_w, btn_h, stroke, false)
        local txt = "CONNECT"
        local tw  = render.measure_text(txt)
        render.text(btn_x + (btn_w - tw)/2, btn_y + 5, txt, txt_c)
        if btn_hov and m.clicked and (now - server_last_click) > 0.4 then
            server_last_click = now
            server_last_ip    = sv.ip
            api_safe(function() console.exec("connect " .. sv.ip) end)
            m.clicked = false
        end
        cy = cy + row_h + row_gap
    end
    return cy
end

-- Knife & Zeus BETA TEST
local function content_knife_bot(m, x, y, cw, dt, jc)
    local cy = y
    local ix, iw = x + 20, cw - 20
    local dis = true

    cy = draw_checkbox(m, x, cy, "Knife Bot", "kb_knife_enabled", dt, dis)
    cy = draw_checkbox(m, ix, cy, "Silent (ignore FOV)", "kb_knife_silent", dt, dis)
    cy = draw_slider(m, ix, cy, "Range", "kb_knife_range", 30, 100, dt,
        function(v) return string.format("%du", math.floor(v)) end, iw, dis)
    if not state.kb_knife_silent then
        cy = draw_slider(m, ix, cy, "FOV", "kb_knife_fov", 5, 90, dt,
            function(v) return string.format("%d°", math.floor(v)) end, iw, dis)
    end
    cy = draw_slider(m, ix, cy, "Cooldown", "kb_knife_delay", 0.2, 1.0, dt,
        function(v) return string.format("%.2fs", v) end, iw, dis)

    cy = cy + 8
    render.rect(x, cy, cw, 1, {40, 40, 40, 255}, true)
    cy = cy + 10

    cy = draw_checkbox(m, x, cy, "Zeus Bot", "kb_zeus_enabled", dt, dis)
    cy = draw_checkbox(m, ix, cy, "Silent (ignore FOV)", "kb_zeus_silent", dt, dis)
    cy = draw_slider(m, ix, cy, "Range", "kb_zeus_range", 50, 250, dt,
        function(v) return string.format("%du", math.floor(v)) end, iw, dis)
    if not state.kb_zeus_silent then
        cy = draw_slider(m, ix, cy, "FOV", "kb_zeus_fov", 5, 90, dt,
            function(v) return string.format("%d°", math.floor(v)) end, iw, dis)
    end
    cy = draw_slider(m, ix, cy, "Cooldown", "kb_zeus_delay", 0.2, 2.0, dt,
        function(v) return string.format("%.2fs", v) end, iw, dis)

    return cy
end

-- Messages (Chat Spammer + TrashTalk merged)
local function content_messages(m, x, y, cw, dt, jc)
    local cy = y
    cy = content_cs(m, x, cy, cw, dt, jc)
    cy = cy + 4
    -- render.rect(x, cy, cw, 1, {40,40,40,255}, true) -- <hr>
    cy = cy + 8
    cy = content_tt(m, x, cy, cw, dt, jc)
    return cy
end

-- Author
local function content_author(m, x, y, cw, dt)
    local now = client.time()
    local cy  = y
    local N_FILL, N_STROKE, N_TEXT = {20,20,20,255}, {44,44,44,255}, {220,220,220,255}
    local N_HINT                   = {120,120,120,255}
    local H_FILL, H_STROKE, H_TEXT = {34,34,34,255}, {95,95,95,255}, {255,255,255,255}
    local H_HINT                   = {210,210,210,255}
    local F_FILL, F_STROKE, F_TEXT = {44,44,44,255}, {170,170,170,255}, {255,255,255,255}
    local F_HINT                   = {240,240,240,255}
    local function draw_arrow(ax, ay, col)
        render.line(ax,     ay,     ax + 7, ay,     col)
        render.line(ax + 4, ay - 3, ax + 7, ay,     col)
        render.line(ax + 4, ay + 3, ax + 7, ay,     col)
    end
    local av_r  = 32
    local av_cx = x + cw * 0.5
    local av_cy = cy + av_r + 6
    if author_avatar_tex then
        render.texture(author_avatar_tex, av_cx - av_r, av_cy - av_r,
            av_r*2, av_r*2, {255,255,255,255}, av_r)
    else
        render.circle(av_cx, av_cy, av_r + 3, {20,20,20,255}, true)
        render.circle(av_cx, av_cy, av_r + 3, {56,56,56,255}, false, 1)
        render.circle(av_cx, av_cy, av_r,     {26,26,26,255}, true)
        local initial = (AUTHOR_INFO.nick:sub(1,1)):upper()
        local iw = render.measure_text(initial)
        render.text(av_cx - iw/2,     av_cy - 6, initial, {230,230,230,255})
        render.text(av_cx - iw/2 + 1, av_cy - 6, initial, {230,230,230,255})
    end
    cy = av_cy + av_r + 12
    local nick = AUTHOR_INFO.nick
    local nw = render.measure_text(nick)
    render.text(x + cw/2 - nw/2,     cy, nick, {255,255,255,255})
    render.text(x + cw/2 - nw/2 + 1, cy, nick, {255,255,255,255})
    cy = cy + 20
    local tw = render.measure_text(AUTHOR_INFO.tagline)
    render.text(x + cw/2 - tw/2, cy, AUTHOR_INFO.tagline, {150,150,150,255})
    cy = cy + 22
    render.rect(x + 18, cy, cw - 36, 1, {42,42,42,255}, true)
    cy = cy + 12
    local btn_h, btn_gp = 32, 6
    for i, s in ipairs(AUTHOR_INFO.socials) do
        local by   = cy
        local bx   = x + 14
        local bw   = cw - 28
        local bhov = is_hover(m, bx, by, bw, btn_h)
        local cur = author_btn_hov[i] or 0
        cur = animate(cur, bhov and 1 or 0, 14, dt)
        author_btn_hov[i] = cur
        local flash_alpha = 0
        if url_show and url_show.name == s.key then
            local flash_t = now - url_show.t
            if flash_t >= 0 and flash_t < 0.8 then
                flash_alpha = (1 - flash_t / 0.8) ^ 1.8
            end
        end
        local bg     = lerp_col(lerp_col(N_FILL,   H_FILL,   cur), F_FILL,   flash_alpha)
        local br     = lerp_col(lerp_col(N_STROKE, H_STROKE, cur), F_STROKE, flash_alpha)
        local name_c = lerp_col(lerp_col(N_TEXT,   H_TEXT,   cur), F_TEXT,   flash_alpha)
        local hint_c = lerp_col(lerp_col(N_HINT,   H_HINT,   cur), F_HINT,   flash_alpha)
        render.rect(bx, by, bw, btn_h, bg, true)
        render.rect(bx, by, bw, btn_h, br, false)
        local accent_k = math.max(cur, flash_alpha)
        if accent_k > 0.02 then
            local g = math.floor(150 + 50 * flash_alpha)
            render.rect(bx, by + 6, 2, btn_h - 12, {g, g, g, math.floor(255 * accent_k)}, true)
        end
        render.text(bx + 16, by + btn_h/2 - 6, s.key, name_c)
        local open_txt = "COPY"
        local otw      = render.measure_text(open_txt)
        local arrow_x  = bx + bw - 20
        render.text(arrow_x - 8 - otw, by + btn_h/2 - 6, open_txt, hint_c)
        draw_arrow(arrow_x, by + btn_h/2, hint_c)
        if bhov and m.clicked and ((now - (url_show and url_show.t or 0)) > 0.35) then
            local target  = s.url or s.val or ""
            local ok, how = copy_to_clipboard(target)
            url_show = { url = target, t = now, name = s.key, copied = ok, how = how }
            m.clicked = false
        end
        cy = cy + btn_h + btn_gp
    end
    if url_show and (now - url_show.t) < 3 then
        local age   = now - url_show.t
        local alpha = math.min(1, age / 0.12) * math.min(1, (3 - age) / 0.4)
        local a = math.floor(255 * alpha)
        if a > 3 then
            local py = cy + 8
            local ph = 64
            local ok = url_show.copied
            render.rect(x + 14, py, cw - 28, ph, {24,24,24,a}, true)
            render.rect(x + 14, py, cw - 28, ph, {100,100,100,a}, false)
            if ok then
                render.text(x + 22, py + 8, "Copied to clipboard!", {220,220,220,a})
                render.text(x + 22, py + 26, "Paste in your browser (Ctrl+V)",
                    {160,160,160, math.floor(a * 0.85)})
            else
                render.text(x + 22, py + 8, "Copied (in-game only):", {220,220,220,a})
                render.text(x + 22, py + 26, "Retype in browser manually",
                    {160,160,160, math.floor(a * 0.85)})
            end
            render.text(x + 22, py + 44, url_show.url, {240,240,240,a})
            cy = py + ph + 6
        end
    end
    return cy + 4
end

-- Build
local function content_build(m, x, y, cw, dt)
    local cy = y
    local vh = 80
    render.rect(x + 14, cy, cw - 28, vh, {16,16,16,255}, true)
    render.rect(x + 14, cy, cw - 28, vh, {48,48,48,255}, false)
    local vt = "v" .. BUILD_INFO.version
    render.text(x + 28,     cy + 16, vt, {255,255,255,255})
    render.text(x + 28 + 1, cy + 16, vt, {255,255,255,255})
    local chw = render.measure_text(BUILD_INFO.channel) + 14
    local chx = x + cw - 28 - chw
    local chy = cy + 16
    render.rect(chx, chy, chw, 16, {26,26,26,255}, true)
    render.rect(chx, chy, chw, 16, {62,62,62,255}, false)
    render.text(chx + 7, chy + 2, BUILD_INFO.channel, {210,210,210,255})
    render.text(x + 28, cy + 42, "Last update: " .. BUILD_INFO.date, {150,150,150,255})
    render.text(x + 28, cy + 58, "File: " .. BUILD_INFO.filename,    {110,110,110,255})
    cy = cy + vh + 14
    local row_h = 26
    local rows = {
        {"Author",  AUTHOR_INFO.nick}, {"Build",   BUILD_INFO.version},
        {"Updated", BUILD_INFO.date}, {"Channel", BUILD_INFO.channel},
    }
    for i, r in ipairs(rows) do
        local rh = cy + (i - 1) * row_h
        render.text(x + 20, rh + 7, r[1], {140,140,140,255})
        local vw2 = render.measure_text(r[2])
        render.text(x + cw - 20 - vw2, rh + 7, r[2], {220,220,220,255})
        if i < #rows then
            render.rect(x + 20, rh + row_h - 1, cw - 40, 1, {36,36,36,255}, true)
        end
    end
    cy = cy + #rows * row_h
    return cy + 4
end

-- MAIN PAINT
events.on("paint", function()
    local dt = render.frame_time()
    cursor_blink_t = cursor_blink_t + dt
    if cursor_blink_t >= CURSOR_PERIOD then cursor_blink_t = cursor_blink_t - CURSOR_PERIOD end

    -- Background blur / particles
    do
        local menu_open = ui.is_menu_opened()
        local bt = (state.blur_enabled and menu_open) and 1 or 0
        local bspd = math.max(1, state.blur_speed or 8)
        blur_fade = blur_fade + (bt - blur_fade) * (1 - math.exp(-bspd * dt))
        if blur_fade < 0.005 then blur_fade = 0 end
        local pt = (state.blur_particles_enabled and menu_open) and 1 or 0
        local pspd = math.max(1, state.particles_speed or 8)
        particles_fade = particles_fade + (pt - particles_fade) * (1 - math.exp(-pspd * dt))
        if particles_fade < 0.005 then particles_fade = 0 end
        local sw, sh = render.screen_size()
        if blur_fade > 0.005 then
            local op = state.blur_opacity * blur_fade
            local a = math.floor(230 * math.max(0, math.min(1, op)))
            local white = (state.blur_mode == 1)
            local cr, cg, cb = 8, 8, 8
            if white then cr, cg, cb = 240, 240, 240 end
            if a > 2 then
                render.rect(0, 0, sw, sh, {cr, cg, cb, a}, true)
                local ba = math.floor(a * 0.12)
                if ba > 2 then
                    if white then render.rect(0, 0, sw, sh, {220, 220, 220, ba}, true)
                    else render.rect(0, 0, sw, sh, {24, 24, 24, ba}, true) end
                end
                local vh = sh * 0.35
                local va = math.floor(a * 0.35)
                if va > 2 then
                    render.rect_filled_fade(0, 0, sw, vh,
                        {0, 0, 0, va}, {0, 0, 0, va}, {0, 0, 0, 0}, {0, 0, 0, 0})
                    render.rect_filled_fade(0, sh - vh, sw, vh,
                        {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, va}, {0, 0, 0, va})
                end
            end
        end
        if particles_fade > 0.005 then
            local pidx = math.max(1, math.min(3, state.blur_particles or 1))
            draw_blur_particles(pidx, sw, sh, particles_fade, dt, client.time())
        end
    end

    if not ui.is_menu_opened() then
        open_dropdown = nil; dd_rect = nil; closing_dd = nil
        dragging_slider = nil; dragging_scrollbar = nil
        picker_open = nil; focused_text = nil
        keys_prev = {}
        flush_state_if_changed()
        return
    end

    if not icons_loaded then
        icons_loaded = true
        local function try_icon(name_or_list)
            local names = type(name_or_list) == "table" and name_or_list or { name_or_list }
            for _, base in ipairs(names) do
                local candidates = { base, "skeetles/" .. base }
                for ci = 1, #candidates do
                    local ok, tex = _pcall(render.setup_texture, candidates[ci])
                    if ok and type(tex) == "number" and tex > 0 then return tex end
                end
            end
            return nil
        end
        tab_icons[1] = try_icon({"icon_ragebot.png", "icon_aim.png"})
        tab_icons[2] = try_icon("icon_antiaim.png")
        tab_icons[3] = try_icon({"icon_crosshair.png", "icon_beta.png"})
        tab_icons[4] = try_icon("icon_visuals.png")
        tab_icons[5] = try_icon({"icon_miscellaneous.png", "icon_misc.png"})
        tab_icons[6] = try_icon("icon_network.png")
        tab_icons[7] = try_icon("icon_author.png")
        tab_icons[8] = try_icon("icon_roll.png")
        author_avatar_tex = try_icon("author_avatar.png")
    end

    local menu = ui.get_menu_rect()
    if not menu then flush_state_if_changed(); return end

    local can_expand = (menu.x >= 680)
    if not state.user_collapsed then is_collapsed = not can_expand end
    if is_collapsed and open_dropdown then
        closing_dd = {rect = dd_rect, items = dd_items, is_multi = dd_is_multi, state_key = open_dropdown}
        open_dropdown = nil; dd_rect = nil
    end

    local target_w = is_collapsed and 75 or 660
    current_w = animate(current_w, target_w, 15, dt)
    local w, h = current_w, 548
    local x = menu.x - w - 10
    local y = menu.y + 6
    local mouse = ui.mouse_state()
    local just_closed = false

    if picker_open then
        local pp = picker_positions[picker_open]
        if pp then
            local pw = PICKER_SQ + PICKER_GAP + PICKER_STRIPE + 10
            local px = pp.x
            if px + pw > x + w then px = x + w - pw end
            if px < x then px = x end
            local py = pp.y + PICKER_Y_OFFSET
            local in_interactive =
                is_hover(mouse, px, py, PICKER_SQ, PICKER_SQ) or
                is_hover(mouse, px, py + PICKER_SQ + PICKER_GAP - 3, PICKER_SQ, PICKER_STRIPE + 6) or
                is_hover(mouse, px + PICKER_SQ + PICKER_GAP - 3, py, PICKER_STRIPE + 6, PICKER_SQ)
            local was_clicked = mouse.clicked
            picker_input(mouse, picker_open, px, py)
            if was_clicked and mouse.clicked and not in_interactive then
                picker_open = nil; mouse.clicked = false
            end
        else picker_open = nil end
    end

    local roll_y = y + h - 83
    if is_hover(mouse, x, roll_y, 74, 73) and mouse.clicked then
        if is_collapsed then
            if can_expand then
                is_collapsed = false; state.user_collapsed = false; mouse.clicked = false
            end
        else
            is_collapsed = true; state.user_collapsed = true; mouse.clicked = false
        end
    end

    if open_dropdown and dd_rect and mouse.clicked then
        local total_h = #dd_items * 20
        local needs_scroll = total_h > DD_MAX_H
        local sb_w_zone = 8
        local in_sb_zone = needs_scroll
            and mouse.x >= dd_rect.x + dd_rect.w - sb_w_zone
            and mouse.x <= dd_rect.x + dd_rect.w
            and mouse.y >= dd_rect.y and mouse.y <= dd_rect.y + dd_rect.h

        if in_sb_zone then
            local max_s = total_h - DD_MAX_H
            local thumb_h = math.max(6, DD_MAX_H * (DD_MAX_H / total_h))
            local track_h = DD_MAX_H - thumb_h
            local sy_cur = math.min(dd_scroll[open_dropdown] or 0, max_s)
            local thumb_y = dd_rect.y + (sy_cur / math.max(1, max_s)) * track_h
            dd_scroll_drag = {
                key = open_dropdown,
                offset = mouse.y - thumb_y,
                max_s = max_s,
                thumb_h = thumb_h,
            }
            mouse.clicked = false
        elseif is_hover(mouse, dd_rect.x, dd_rect.y, dd_rect.w, dd_rect.h) then
            local scy = dd_scroll[open_dropdown] or 0
            local rel_y = mouse.y - dd_rect.y + scy
            local idx = math.floor(rel_y / 20) + 1
            if idx < 1 then idx = 1 end
            if idx > #dd_items then idx = #dd_items end
            if dd_is_multi then
                local arr = state[open_dropdown]
                if type(arr) ~= "table" then arr = {} end
                local dense = {}
                for i = 1, #dd_items do dense[i] = (arr[i] == true) end
                local nv = not dense[idx]
                dense[idx] = nv
                if dd_exclusive then
                    if idx == dd_exclusive then
                        if nv then
                            for i = 1, #dd_items do
                                if i ~= idx then dense[i] = false end
                            end
                        end
                    else
                        if nv then dense[dd_exclusive] = false end
                    end
                end
                -- Spin (1) is exclusive with Jitter (2) AND Random Flick (3).
                -- Enabling Spin clears both; enabling Jitter or Flick clears Spin.
                if open_dropdown:match("^aa_%w+_aa_types$") then
                    if idx == 1 and dense[1] then
                        dense[2] = false
                        dense[3] = false
                    elseif (idx == 2 or idx == 3) and dense[idx] then
                        dense[1] = false
                    end
                end
                state[open_dropdown] = dense
            else
                state[open_dropdown] = idx
                closing_dd = {rect = dd_rect, items = dd_items, is_multi = dd_is_multi, state_key = open_dropdown}
                open_dropdown = nil; dd_rect = nil
            end
            mouse.clicked = false
        else
            closing_dd = {rect = dd_rect, items = dd_items, is_multi = dd_is_multi, state_key = open_dropdown}
            open_dropdown = nil; dd_rect = nil; just_closed = true
        end
    end

    if dd_scroll_drag then
        if not mouse.down or open_dropdown ~= dd_scroll_drag.key or not dd_rect then
            dd_scroll_drag = nil
        else
            local track_h = DD_MAX_H - dd_scroll_drag.thumb_h
            local new_thumb_y = mouse.y - dd_scroll_drag.offset
            local rel = math.max(0, math.min(1, (new_thumb_y - dd_rect.y) / math.max(1, track_h)))
            dd_scroll[open_dropdown] = rel * dd_scroll_drag.max_s
        end
    end

    if open_dropdown and dd_items then
        dd_anim_height = animate(dd_anim_height, math.min(#dd_items * 20, DD_MAX_H), 25, dt)
    elseif closing_dd then
        dd_anim_height = animate(dd_anim_height, 0, 25, dt)
        if dd_anim_height < 1 then closing_dd = nil; dd_anim_height = 0 end
    end

    if open_dropdown and dd_rect and mouse.wheel and mouse.wheel ~= 0
       and is_hover(mouse, dd_rect.x, dd_rect.y, dd_rect.w, dd_rect.h) then
        local total_h = #dd_items * 20
        local max_s = math.max(0, total_h - dd_rect.h)
        if max_s > 0 then
            local cur = dd_scroll[open_dropdown] or 0
            cur = cur - mouse.wheel * 30
            dd_scroll[open_dropdown] = math.max(0, math.min(max_s, cur))
        end
    end

    render.rect(x - 6, y - 6, w + 12, h + 12, {10,10,10,255}, true)
    render.rect(x - 5, y - 5, w + 10, h + 10, {60,60,60,255}, true)
    render.rect(x - 4, y - 4, w + 8, h + 8, {40,40,40,255}, true)
    render.rect(x - 1, y - 1, w + 2, h + 2, {60,60,60,255}, true)
    render.rect(x, y, w, h, {12,12,12,255}, true)
    for bx = x + 74, x + w, 4 do render.line(bx, y, bx, y + h, {18,18,18,255}, 1) end
    render.line(x + 74, y, x + 74, y + h, {48,48,48,255}, 1)
    render.rect(x, y + 1, 74, h - 1, {12,12,12,255}, true)
    render.rect_filled_fade(x, y+1, w-1, 1, {255,255,255,255}, {255,255,255,255}, {255,255,255,255}, {255,255,255,255})
    render.rect_filled_fade(x, y+2, w-1, 1, {180,180,180,255}, {180,180,180,255}, {180,180,180,255}, {180,180,180,255})

    local tab_y = y + 10
    for i = 1, 7 do
        local act = (active_tab == i) and not is_collapsed
        if not is_collapsed and is_hover(mouse, x, tab_y, 74, 73) and mouse.clicked then
            active_tab = i; dragging_slider = nil; focused_text = nil
            picker_open = nil; dragging_scrollbar = nil
            if open_dropdown and dd_rect then
                closing_dd = {rect = dd_rect, items = dd_items, is_multi = dd_is_multi, state_key = open_dropdown}
            end
            dd_scroll_drag = nil
            open_dropdown = nil; dd_rect = nil; mouse.clicked = false
        end
        if act then
            render.line(x, tab_y + 5, x + 75, tab_y + 5, {48,48,48,255}, 1)
            render.line(x, tab_y + 68, x + 75, tab_y + 68, {48,48,48,255}, 1)
            render.rect(x, tab_y + 5, 75, 63, {12,12,12,255}, true)
            for bbx = x + 2, x + 75, 4 do render.line(bbx, tab_y + 5, bbx, tab_y + 68, {18,18,18,255}, 1) end
        end
        local cx, cy = x + 37, tab_y + 38
        local ic = act and {255,255,255,255} or {100,100,100,255}
        local tex = tab_icons[i]
        local has_tex = tex ~= nil and (type(tex) ~= "number" or tex > 0)
        if has_tex then render.texture(tex, cx - 21, cy - 21, 42, 42, ic)
        else
            render.circle(cx, cy, 12, ic, false, 2)
            render.circle(cx, cy, act and 5 or 2, ic, true)
        end
        tab_y = tab_y + 64
    end

    local roll_hov = is_hover(mouse, x, roll_y, 74, 73)
    if is_collapsed and not can_expand then roll_hov = false end
    anims.roll_hover = animate(anims.roll_hover, roll_hov and 1 or 0, 16, dt)
    local rh = anims.roll_hover

    local target_base = (is_collapsed and not can_expand) and 50 or 100
    anims.roll_disabled = animate(anims.roll_disabled, target_base, 16, dt)
    local base = anims.roll_disabled
    local r = math.floor(base + (255 - base) * rh)
    local ric = {r, r, r, 255}
    if tab_icons[8] then
        render.texture(tab_icons[8], x + 37 - 12, roll_y + 36 - 12, 24, 24, ric)
    else
        render.rect(x + 37 - 10, roll_y + 36 - 10, 20, 20, ric, false, 2)
    end

    if w > 80 then
        local cm
        if is_collapsed or picker_open then
            cm = DEAD_MOUSE
        elseif open_dropdown and dd_rect and
               mouse.x >= dd_rect.x and mouse.x <= dd_rect.x + dd_rect.w and
               mouse.y >= dd_rect.y and mouse.y <= dd_rect.y + dd_rect.h then
            -- mouse is over the open dropdown: hard-block every widget below
            cm = DEAD_MOUSE
        else
            cm = mouse
        end
        render.push_clip_rect(x + 74, y + 1, w - 74, h - 2)
        local padding, gap = 20, 20
        local col_w = (w - 74 - padding * 2 - gap) / 2
        local cxs = x + 74 + padding
        local cys = y + 25

        if active_tab == 1 then  -- RAGEBOT
            local avail_h = h - 25 - 20
            local right_x = cxs + col_w + gap
            draw_scrollable_block(cm, cxs, cys, col_w, avail_h,
                "Autowall", "Ragebot marker", "awall",
                function(cx, cy, cw2) return content_awall(cm, cx, cy, cw2, dt) end)
            draw_scrollable_block(cm, right_x, cys, col_w, avail_h,
                "Knife & Zeus Bot", "Auto melee & zeus", "v_ragebot_kb",
                function(cx, cy, cw2) return content_knife_bot(cm, cx, cy, cw2, dt, just_closed) end)

        elseif active_tab == 2 then  -- ANTI AIM
            local avail_h = h - 25 - 20
            local block_h = (avail_h - gap) / 2
            local right_x = cxs + col_w + gap
            draw_scrollable_block(cm, cxs, cys, col_w, block_h,
                "Anti-Aim — Standing", "Standing position", "aa_stand",
                function(cx, cy, cw2) return content_aa_state(cm, cx, cy, cw2, dt, just_closed, "aa_stand") end)
            draw_scrollable_block(cm, cxs, cys + block_h + gap, col_w, block_h,
                "Anti-Aim — Crouch", "Crouching position", "aa_crouch",
                function(cx, cy, cw2) return content_aa_state(cm, cx, cy, cw2, dt, just_closed, "aa_crouch") end)
            draw_scrollable_block(cm, right_x, cys, col_w, block_h,
                "Anti-Aim — Move", "Moving position", "aa_move",
                function(cx, cy, cw2) return content_aa_state(cm, cx, cy, cw2, dt, just_closed, "aa_move") end)
            draw_scrollable_block(cm, right_x, cys + block_h + gap, col_w, block_h,
                "Anti-Aim — Air", "Airborne position", "aa_air",
                function(cx, cy, cw2) return content_aa_state(cm, cx, cy, cw2, dt, just_closed, "aa_air") end)

        elseif active_tab == 3 then  -- CROSSHAIR
            if picker_open == "ch_col_pen" and not state.ch_pen_enabled then picker_open = nil end
            if picker_open == "dt_ind_color" and state.dt_ind_based_on ~= 1 then picker_open = nil end
            if picker_open == "dt_ind_screen_color" and state.dt_ind_based_on ~= 2 then picker_open = nil end
            local avail_h = h - 25 - 20
            local right_x = cxs + col_w + gap
            draw_scrollable_block(cm, cxs, cys, col_w, avail_h,
                "Crosshair", "", "v_ch",
                function(cx, cy, cw2) return content_crosshair(cm, cx, cy, cw2, dt, just_closed) end)
            draw_scrollable_block(cm, right_x, cys, col_w, avail_h,
                "DoubleTap Indicator", "", "v_misc_dt",
                function(cx, cy, cw2) return content_dt_ind(cm, cx, cy, cw2, dt, just_closed) end)

        elseif active_tab == 4 then  -- VISUALS
            if picker_open == "ea_hp_high" and not state.ea_by_health then picker_open = nil end
            if picker_open == "ea_hp_low"  and not state.ea_by_health then picker_open = nil end
            local avail_h = h - 25 - 20
            local left_h  = (avail_h - gap * 2) / 3
            local right_h = (avail_h - gap) / 2
            local right_x = cxs + col_w + gap
            draw_scrollable_block(cm, cxs, cys, col_w, left_h,
                "Backtrack", "", "v_bt",
                function(cx, cy, cw2) return content_backtrack(cm, cx, cy, cw2, dt, just_closed) end)
            draw_scrollable_block(cm, cxs, cys + left_h + gap, col_w, left_h,
                "Enemy Arrows", "", "v_ea",
                function(cx, cy, cw2) return content_enemy_arrows(cm, cx, cy, cw2, dt, just_closed) end)
            draw_scrollable_block(cm, cxs, cys + (left_h + gap) * 2, col_w, left_h,
                "Player Trail", "", "v_trail",
                function(cx, cy, cw2) return content_trail(cm, cx, cy, cw2, dt, just_closed) end)
            draw_scrollable_block(cm, right_x, cys, col_w, right_h,
                "Menu Background", "", "v_misc_blur",
                function(cx, cy, cw2) return content_blur(cm, cx, cy, cw2, dt, just_closed) end)
            draw_scrollable_block(cm, right_x, cys + right_h + gap, col_w, right_h,
                "Watermark", "", "v_wm",
                function(cx, cy, cw2) return content_watermark(cm, cx, cy, cw2, dt, just_closed) end)

        elseif active_tab == 5 then  -- MISCELLANEOUS
            local avail_h = h - 25 - 20
            local left_top_h = math.floor(avail_h / 3) + 20
            local left_bot_h = avail_h - left_top_h - gap
            local right_x = cxs + col_w + gap
            draw_scrollable_block(cm, cxs, cys, col_w, left_top_h,
                "Autobuy", "Purchases", "autobuy",
                function(cx, cy, cw2) return content_autobuy(cm, cx, cy, cw2, dt, just_closed) end)
            draw_scrollable_block(cm, cxs, cys + left_top_h + gap, col_w, left_bot_h,
                "Messages", "", "v_misc_msgs",
                function(cx, cy, cw2) return content_messages(cm, cx, cy, cw2, dt, just_closed) end)
            draw_scrollable_block(cm, right_x, cys, col_w, avail_h,
                "Name Changer", "Custom nickname & clantag", "namechanger",
                function(cx, cy, cw2) return content_namechanger(cm, cx, cy, cw2, dt, just_closed) end)

        elseif active_tab == 6 then  -- NETWORK
            local avail_h = h - 25 - 20
            local full_w  = w - 74 - padding * 2
            draw_scrollable_block(cm, cxs, cys, full_w, avail_h,
                "HvH Servers", "One-click connect", "v_servers",
                function(cx, cy, cw2) return content_servers(cm, cx, cy, cw2, dt, just_closed) end)

        elseif active_tab == 7 then  -- AUTHOR
            local avail_h = h - 25 - 20
            local right_x = cxs + col_w + gap
            draw_scrollable_block(cm, cxs, cys, col_w, avail_h,
                "Author", "Credits", "author",
                function(cx, cy, cw2) return content_author(cm, cx, cy, cw2, dt) end)
            draw_scrollable_block(cm, right_x, cys, col_w, avail_h,
                "Build", "Version info", "build",
                function(cx, cy, cw2) return content_build(cm, cx, cy, cw2, dt) end)
        end
        render.pop_clip_rect()
    end

    if open_dropdown and dd_rect then
        render_dropdown(mouse, dd_rect, dd_items, dd_is_multi, open_dropdown, dd_anim_height)
    elseif closing_dd then
        render_dropdown(mouse, closing_dd.rect, closing_dd.items, closing_dd.is_multi, closing_dd.state_key, dd_anim_height)
    end

    if picker_open then
        local pp = picker_positions[picker_open]
        if pp then
            local pw = PICKER_SQ + PICKER_GAP + PICKER_STRIPE + 10
            local px = pp.x
            if px + pw > x + w then px = x + w - pw end
            if px < x then px = x end
            picker_draw(px, pp.y + PICKER_Y_OFFSET, picker_open)
        end
    end

    flush_state_if_changed()
end)