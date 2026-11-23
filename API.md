# chr1stoss.lua — API

Internal API reference for extending the script. All names are file-local; there is no exported global namespace.

---

## 1. Widget functions

All widgets share the signature `(m, x, y, …, dt, …)`, return the **y coordinate of the next row**, and mutate `state[key]` directly.

```lua
draw_checkbox(m, x, y, label, key, dt, disabled?)                               -> y + 22
draw_slider  (m, x, y, label, key, mn, mx, dt, fmt?, w?, disabled?)             -> y + 38
draw_combo   (m, x, y, label, key, items, just_closed, w?, disabled?)           -> y + 30
draw_multicombo(m, x, y, label, key, items, just_closed, exclusive_idx?, w?)    -> y + 30
draw_text_input(m, x, y, label, key, w, dt)                                     -> y + 30
draw_color_button(m, x, y, w, h, key)                                           -> nil
```

| Argument        | Type     | Meaning                                                                |
|-----------------|----------|------------------------------------------------------------------------|
| `m`             | table    | mouse state `{x, y, down, clicked, wheel}`. Pass `DEAD_MOUSE` to freeze input |
| `x, y`          | number   | top-left in menu-local coords                                          |
| `label`         | string   | row label                                                              |
| `key`           | string   | `state[key]` field name                                                |
| `dt`            | number   | frame delta                                                            |
| `mn, mx`        | number   | slider bounds                                                          |
| `fmt`           | function | `fn(value) -> string`                                                  |
| `w`             | number   | widget width (default 200)                                             |
| `items`         | array    | list of strings for combo / multicombo                                 |
| `just_closed`   | bool     | suppress open this frame                                               |
| `exclusive_idx` | number   | multicombo: index that deselects all others when toggled on            |
| `disabled`      | bool     | greys out, blocks input (and dims combo arrow)                         |

---

## 2. Content functions (card body)

Every card body is a plain Lua function with the signature:

```lua
function(m, x, y, cw, dt, jc) -> y_next
```

- `m` — mouse state (may be `DEAD_MOUSE` when frozen)
- `x, y` — top-left of the card's inner clip area
- `cw` — inner content width (already minus scrollbar and padding)
- `dt` — frame delta (for animations)
- `jc` — `just_closed` flag from main paint (passed to `draw_combo` / `draw_multicombo`)
- **return value** — y of the next row (used to compute natural content height for scrolling)

Inside, call widgets sequentially and track `cy`:

```lua
local function content_mycard(m, x, y, cw, dt, jc)
    local cy = y
    local ix, iw = x + 20, cw - 20   -- indented children

    cy = draw_checkbox(m, x, cy, "Enable", "my_en", dt)
    cy = draw_slider(m, ix, cy, "Radius", "my_r", 10, 200, dt, nil, iw)
    cy = draw_combo(m, ix, cy, "Mode", "my_m", {"A", "B"}, jc, iw)

    if state.my_en then
        cy = draw_multicombo(m, ix, cy, "Flags", "my_flags",
            {"X", "Y"}, jc, nil, iw)
    end

    return cy
end
```

Wrapping a widget in `if state.<flag> then … end` is how conditional rows work (there is no row-schema engine — conditional rows are plain Lua control flow).

---

## 3. Adding a card

```lua
-- 1. add fields to `state = { … }`
--    my_en = false, my_r = 60, my_m = 1, my_flags = {false, false},

-- 2. define content function (see section 2)

-- 3. register scroll key in `scroll` + `last_max_scroll`
--    scroll.my_card = 0
--    last_max_scroll.my_card = 0

-- 4. draw inside a tab branch of main paint
draw_scrollable_block(cm, cxs, cys, col_w, left_h,
    "My Card", "subtitle", "my_card", content_mycard)
```

`draw_scrollable_block` signature:

```lua
draw_scrollable_block(m, x, y, w, h, hdr, ttl, key, content_fn)
```

`ttl` (subtitle) is currently unused inside the function but kept for API compatibility.

---

## 4. State

`state` is a flat table. Conventions:

| Value type     | Convention                            |
|----------------|---------------------------------------|
| `number`       | sliders, combo indices                |
| `bool`         | checkboxes                            |
| `string`       | inputs, selected option name          |
| `{r,g,b,a}`    | colors                                |
| `{bool, …}`    | multicombo arrays (dense)             |
| `{idx = bool}` | never — sparse crashes `storage.set`  |

Adding a field: append to `state = { … }`. It persists automatically.

Migration for a renamed/restructured field: add logic inside `load_state()` (called once at load) — transform `saved.<old>` → `saved.<new>` before the generic copy loop. No migrations currently shipped; the only exception is `nc_tag_presets` densification, kept as a safety net so legacy configs don't crash `storage.set`.

Do not create sparse numeric tables in `state`. The save path (`flush_state_if_changed`) densifies pure-numeric tables, but sparse tables with string keys are passed through as-is — use only dense arrays or pure maps.

---

## 5. Helper functions

```lua
animate(current, target, speed, dt)              -> number                     -- exponential ease, speed ≈ 1/time_const
lerp_col(c1, c2, t)                              -> {r,g,b,a}                  -- t in [0,1]
is_hover(m, x, y, w, h)                          -> bool                       -- respects active scrollable clip
measure_w(str)                                   -> number
cursor_at_x(str, local_x)                        -> index
ti_get(key)                                      -> internal                   -- text-input cursor / selection state
ti_press(key, name, is_down, now, no_repeat?)    -> bool                       -- first press + auto-repeat gate
copy_to_clipboard(text)                          -> ok(bool), source(string)   -- "loader"|"win32"|"buffer_only"
read_clipboard()                                 -> string|nil                 -- script-local buffer only
api_safe(fn)                                     -> void                       -- runs under api.protect if available
log(msg)                                         -> void                       -- writes to loader log with [chr1stoss] prefix
_pcall(fn, a, b, c, d, e)                        -> ok, result                 -- sandbox-safe pcall
nc_sanitize_nick(str)                            -> string                     -- strips invalid chars for names
nc_get_valid_names()                             -> array                      -- returns list of stealable names
```

---

## 6. Events registered

| Event          | Purpose                                                                     | Location                   |
|----------------|-----------------------------------------------------------------------------|----------------------------|
| `paint` (many) | per-feature rendering (chat spam, kill fx, tracers, watermark, main UI, …)  | throughout                 |
| `pre_rage`     | per-tick targeting / awall / backtrack / crosshair scan / trail capture      | feature blocks             |
| `create_move`  | anti-aim overrides + enemy arrows camera capture                            | feature blocks             |
| `game_event`   | `player_death`, `round_start` handlers                                       | chat / trashtalk / autobuy |
| `frame_stage`  | namechanger tick                                                            | NC block                   |
| `shutdown`     | flush `state` → storage, release AA, disable NC, clear queues                | end                        |

`events.on("event", fn)` — loader API. Multiple handlers allowed.

---

## Adding a tab

Tabs are hardcoded as `1..7` in the sidebar loop and dispatched in `main paint` by `active_tab`.

```lua
-- 1. add icon: tab_icons[8] = try_icon("icon_mytab.png") inside icons_loaded block

-- 2. dispatch in main paint, after "elseif active_tab == 7 then …"
elseif active_tab == 8 then
    local avail_h = h - 25 - 20
    local full_w  = w - 74 - padding * 2
    draw_scrollable_block(cm, cxs, cys, full_w, avail_h,
        "My Tab", "subtitle", "v_mytab", content_mytab)
end

-- 3. extend the sidebar loop range: `for i = 1, 7 do` → `for i = 1, 8 do`

-- 4. register scroll key v_mytab = 0 in scroll + last_max_scroll
```

Reserved tab indices: `1=RAGEBOT`, `2=ANTI-AIM`, `3=CROSSHAIR`, `4=VISUALS`, `5=MISCELLANEOUS`, `6=NETWORK`, `7=AUTHOR`. New tabs start at 8.

---

## 8. Config

```lua
CONFIG_KEY = "state"        -- storage key
storage.get(CONFIG_KEY)     -- load
storage.set(CONFIG_KEY, state)  -- save (called by flush_state_if_changed)
```

`flush_state_if_changed()` runs at the end of every `paint` and on `shutdown`. It skips saving while:

- `dragging_slider` is set
- `focused_text` is set
- any picker is being dragged (`any_picker_dragging()`)

Fingerprint is computed by `state_fingerprint()` — sorted key=value string; change detection is exact.

Manual reset: `storage.set("state", nil)` or delete `chr1stoss.lua.json`.

---

## 9. NameChanger

```lua
NC_TAG_PRESETS = {
    { name = "skeet",  postfixes = {"None", ".cc"} },  -- postfixes optional
    { name = "enigma", postfixes = nil },              -- no postfix combo
    -- …
}

NC_STATUS = "init" | "ok" | "no_ffi" | "no_dll" | "dll_init_failed"
```

State fields:

| Field                 | Type      | Meaning                             |
|-----------------------|-----------|-------------------------------------|
| `nc_on`               | bool      | master enable                       |
| `nc_type`             | 1/2       | `1=Default`, `2=Stealer`            |
| `nc_name`             | string    | nickname override (Default mode)    |
| `nc_steal_mode`       | 1/2       | `1=Certain`, `2=Few` (Stealer mode) |
| `nc_steal_single`     | number    | Selected index (Certain mode)       |
| `nc_steal_multi`      | {bool}    | Selected array (Few mode, dense)    |
| `nc_steal_delay`      | number    | Rotation delay for Few mode         |
| `nc_tag_on`           | bool      | clantag enable                      |
| `nc_tag_source`       | 1/2/3     | `1=Custom`, `2=One`, `3=Few`        |
| `nc_tag`              | string    | Custom-mode text                    |
| `nc_tag_single`       | number    | One-mode preset index               |
| `nc_pfx_single`       | number    | One-mode postfix index              |
| `nc_tag_presets`      | {bool}    | Few-mode selection (dense)          |
| `nc_pfx_N`            | number    | Few-mode postfix for preset N       |
| `nc_swap_delay`       | number    | Few-mode rotation delay (seconds)   |
| `nc_tag_wrap_enabled` | bool      | apply wrapper                       |
| `nc_tag_wrap`         | 1..4      | `[]` `{}` `<>` `==`                 |
| `nc_tag_anim_enabled` | bool      | apply animation                     |
| `nc_tag_mode`         | 1..3      | `Typing` / `Jitter` / `Sliding`     |
| `nc_cursor`           | 1..4      | `\|`, `/`, `\`, `_`                 |
| `nc_tag_pos`          | 1/2       | Before / After                      |
| `nc_tag_spd`          | number    | animation step                      |

DLL override (before first load):

```lua
storage.set("nc_dll_override", "C:/full/path/to/namechanger.dll")
```

---

## 10. Anti-Aim

Per-state fields follow prefix pattern `aa_<state>_<field>`:

```text
| aa_stand_* | aa_crouch_* | aa_move_* | aa_air_* |
```

Common fields per state:

`enabled, at_target, extra_yaw_enabled, aa_types, yaw, yaw_custom, pitch, pitch_custom, spin_dir, spin_speed, jitter_mode, jitter_degree, jitter_speed, flick_enabled, flick_axes, flick_yaw_delay, flick_pitch_delay`.

Air state additionally: `aa_air_only_space`, `aa_air_space_threshold`.

Tick hook: `create_move`. Native AA modifiers (from `settings.list("anti aim")`) are suppressed automatically via `settings.override` while the script's AA is active, restored on disable / death / shutdown.

---

## 11. Threading / perf notes

- All rendering is on the `paint` callback — do not block.
- `combat.hitboxes`, `combat.damage`, `combat.hitchance`, `trace.*` are **hot paths**. Cache per-tick, never per-frame.
- `paint` handlers for main UI assume `ui.is_menu_opened()` is true after the first check; the early-return path resets all interaction state.
- `_clip` is set while drawing a scrollable block's content — is_hover respects it, so widgets outside the visible clip area do not respond to clicks.
- `state_fingerprint` runs on every frame (O(fields)). If state grows past ~1000 fields, cache and recompute only on `state` change.
- When a dropdown is open, `cm` is forced to `DEAD_MOUSE` for the content rendering block if the cursor hovers over the dropdown. This prevents click-through bugs.

---

## 12. Known sandbox restrictions

| Feature                                                 | Status                                   | Workaround                                                                                          |
|---------------------------------------------------------|------------------------------------------|-----------------------------------------------------------------------------------------------------|
| `io.open`, `os.getenv`, `debug.getinfo`, `package.path` | blocked                                  | resolved via `kernel32` `GetCurrentDirectoryA` / `ExpandEnvironmentStringsA` / `GetFileAttributesA` |
| `pcall`                                                 | unavailable in `paint`                   | use `_pcall` (captured at load)                                                                     |
| `require`                                               | may be blocked                           | wrapped in `_pcall(require, "ffi")`                                                                 |
| `Win32` clipboard read                                  | GetClipboardData returns empty / blocked | internal `CLIPBOARD_BUFFER`                                                                         |
| `Win32` clipboard write                                 | works                                    | used as fallback in `copy_to_clipboard`                                                             |
| Native crashes in `LoadLibraryA` / DLL calls            | **not** caught by any `pcall`            | risk of crash — must be compatible DLL                                                              |

---

### Version

Current build: `1.3.3.7`, channel `stable`, `2026-11-23`