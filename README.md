## chr1stoss.lua

**SKEET by Raze** Multi Lua.

Version **1.3.3.7**.

---

### Folder structure

```text
build-folder/
├── README.md
└── skeet/
    ├── chr1stoss.lua               # script
    ├── chr1stoss.lua.json          # script config
    ├── native/
    │   └── namechanger.dll         # required dll for name changer func
    └── skeetles/                   # required icons for better visual & author info
        ├── icon_ragebot.png
        ├── icon_antiaim.png
        ├── icon_crosshair.png
        ├── icon_visuals.png
        ├── icon_miscellaneous.png
        ├── icon_network.png
        ├── icon_author.png
        ├── icon_roll.png
        └── author_avatar.png
```

---

### The `skeet/` folder lives at:

```text
%LOCALAPPDATA%\skeet\

i.e. `C:\Users\<user>\AppData\Local\skeet\`.
```

---

### Installation

1. Create `%LOCALAPPDATA%\skeet\` if it does not exist.
2. Copy `chr1stoss.lua` into it.
3. Create subfolder `native\` and place `namechanger.dll` inside.
4. Create subfolder `skeetles\` and place all PNG icons inside.
5. Launch CS2 through the loader. `chr1stoss.lua` is picked up automatically.
6. `chr1stoss.lua.json` is created next to the script on the first settings change.

**Required minimum:** `chr1stoss.lua`. Without `native\namechanger.dll` the NameChanger section displays `DLL not found` and is inert. Without `skeetles\` the tab icons fall back to plain circles.

---

### Requirements

| Item | Required | Notes                                                                         |
|---|---|---|
| `chr1stoss.lua` | yes | Main script                                                                   |
| `native/namechanger.dll` | for NameChanger | x64, VC++ runtime                                                             |
| `skeetles/*.png` | recommended | 9 icons, any size (rendered at 512x512 / 256×256 / 128×128 depending on slot) |
| `chr1stoss.lua.json` | auto | Generated, do not edit manually                                               |
| Lua loader with `render`, `imgui`, `ffi`, `storage`, `entity`, `combat`, `cmd`, `engine`, `cvar`, `trace`, `client`, `ui`, `utils`, `events` APIs | yes | skeet loader                                                                  |

`io`, `os`, `debug`, `package` are **not** used — the script runs under a sandboxed environment and resolves file paths via `kernel32` `GetCurrentDirectoryA` / `ExpandEnvironmentStringsA`.

---

### Features

| Tab | Contents |
|---|---|
| **RAGEBOT** | Autowall (truth / visual), Knife & Zeus Bot (visual placeholder) |
| **ANTI AIM** | Per-state (stand / crouch / move / air): enable, at-target, yaw, pitch, spin, jitter |
| **CROSSHAIR** | Crosshair, DoubleTap Indicator |
| **VISUALS** | Backtrack, Enemy Arrows, Player Trail, Menu Background, Watermark |
| **MISCELLANEOUS** | Autobuy, Messages (Chat Spammer + TrashTalk), Name Changer |
| **NETWORK** | HvH server list (filterable, `connect` on click) |
| **AUTHOR** | Credits, socials (copy-to-clipboard), build info |

---

### Controls

| Action | Input |
|---|---|
| Open / close menu | managed by loader |
| Collapse / expand menu | click bottom-left roll button |
| Drag menu | drag toolbar area |
| Change tab | click sidebar icon |
| Scroll card content | mouse wheel over card |

**Text input fields** support:
- `Backspace` / `Delete`
- `← → Home End` cursor movement
- `Shift + ←/→` selection
- `Ctrl + A` select all
- `Ctrl + C` copy (script-local buffer)
- `Ctrl + V` paste (script-local buffer)

**Clipboard**: in-game copy/paste works through an internal buffer. Copying *out* to the OS (e.g. Author → browser) works via the loader's `set_clipboard` if available, with a `win32` write fallback. Copying *from* the OS (browser → in-game) is **not supported** in this environment — the sandbox blocks `win32` clipboard reads (`GlobalSize` returns 0).

---

### NameChanger

**DLL search order** (first hit wins):

1. `storage.get("nc_dll_override")` — manual override via console
2. `%LOCALAPPDATA%\skeet\native\namechanger.dll`
3. `%APPDATA%\skeet\native\namechanger.dll`
4. `%USERPROFILE%\AppData\Local\skeet\native\namechanger.dll`
5. `<cwd>\native\namechanger.dll`
6. `<exe_dir>\namechanger.dll`
7. `native/namechanger.dll`, `namechanger.dll` (relative fallback)

**Name Changer Types:**
- **Default** — Custom nickname input field.
- **Stealer** — Auto-parses nicknames of all valid players on the server. Includes two modes:
  - **Certain** — Select one specific player's nickname from a dropdown.
  - **Few** — Select multiple nicknames to rotate between, with a `Swap delay` slider.

---

### Clantag modes:

- **Custom** — single free-form text field
- **One** — one preset + optional postfix (`.cc`, `.pub`, …)
- **Few** — multi-select presets, each with its own postfix, plus `Swap delay` slider (rotates tags in order of appearance in `NC_TAG_PRESETS`, not random)

**Shared modifiers (applied to every selected tag):**

- **Tag Wrapper** — `Square []`, `Curly {}`, `Angle <>`, `Equals = =`
- **Tag Animation** — `Typing` (with cursor `|`, `/`, `\`, `_`), `Jitter`, `Sliding`
- **Tag Position** — `Before` nickname / `After` nickname
- **Tag Speed** — animation speed

---

### Config

`chr1stoss.lua.json` is written automatically after any setting change (with 0 ms debounce, but suppressed while a slider / text input / picker is being dragged). It is a JSON object with a single root key `state`, containing every field from the `state` table.

*Never edit this file while the script is running. Edits made outside the game are applied on next load.*

*Delete the file to reset all settings to defaults.*

Sparse arrays are forbidden by the loader's serializer. The script densifies all numeric tables before saving (`flush_state_if_changed`), and sanitizes `nc_tag_presets` on load as a safety net (`load_state`).

---

### Troubleshooting

| Symptom | Cause | Fix                                                                                                                                                                                |
|---|---|---|
| `NameChanger` shows `DLL not found` | DLL not in any search path | Place `namechanger.dll` in `%LOCALAPPDATA%\skeet\native\`, or set `nc_dll_override`                                                                                                |
| `NameChanger` shows `DLL init failed` | DLL incompatible (32-bit on 64-bit, missing VC++ Redistributable, `nc_init()` returned error) | Rebuild / reinstall DLL                                                                                                                                                            |
| `NameChanger` shows `FFI unavailable` | Loader does not expose `ffi` | Not fixable from script side                                                                                                                                                       |
| Tabs show circles instead of icons | `skeetles\` missing, wrong filename, or non-PNG | Check folder + filenames exactly: `icon_ragebot.png`, `icon_antiaim.png`, `icon_crosshair.png`, `icon_visuals.png`, `icon_miscellaneous.png`, `icon_network.png`, `icon_author.png`, `icon_roll.png` |
| `mixed or sparse arrays are not supported` at `storage.set` | Corrupted config with sparse numeric table | Delete `chr1stoss.lua.json` and reload                                                                                                                                             |
| Author copy fails silently | Loader has no `set_clipboard` and `win32` blocked | URL is still shown in the panel; type it manually                                                                                                                                  |
| Browser `Ctrl+V` into in-game field is empty | `win32` clipboard read is blocked by sandbox | Not supported — use **in-game** copy (`Ctrl+C`) then paste (`Ctrl+V`)                                                                                                              |

Log output (if enabled) goes to the loader log file, not the CS2 console. Look for [chr1stoss] prefix.

---

### Notes

- Knife & Zeus Bot is a static visual placeholder. Controls are rendered but cannot be toggled or changed. Nothing executes.
- Anti-Aim suppresses all native anti-aim modifiers (settings.list("anti aim") filtered) and overrides `rotation`, `pitch mode`, `custom pitch` per tick. On release (`anti aim` disabled or player dead), all overrides are cleared.
- Awall uses `combat.hitboxes` + `combat.damage` for the last tick only. Visual square position is smoothed with `1 - exp(-smooth * 20 * dt)`.
- Watermark reads FPS from `client.frametime`, jitter from a rolling stddev of 30 samples, speed from `local_player.velocity` (2D magnitude), map from `client.map_name`, time from `kernel32.GetLocalTime`.
- Menu scale follows `ui.get_menu_rect()`. If the game window is narrower than 680 px, the menu collapses automatically and the roll button is disabled until the window is wide enough.
- Server list is a static array inside the script (`HVH_SERVERS`). `CONNECT` runs `console.exec("connect [ip:port]")`.

---

### Version

Current build: `1.3.3.7`, channel `stable`, `2026-11-13`