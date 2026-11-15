## chr1stoss.lua

**SKEET by Raze** Multi Lua.

Версия **1.3.3.7**.

---

### Структура папок

```text
build-folder/
├── README.md
└── skeet/
    ├── chr1stoss.lua               # скрипт
    ├── chr1stoss.lua.json          # конфиг скрипта
    ├── native/
    │   └── namechanger.dll         # обязательная dll для смены ника
    └── skeetles/                   # обязательные иконки для визуала и автора
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

### Папка `skeet/` должна лежать по пути:

```text
%LOCALAPPDATA%\skeet\

то есть `C:\Users\<user>\AppData\Local\skeet\`.
```

---

### Установка

1. Создай `%LOCALAPPDATA%\skeet\`, если её нет.
2. Скопируй `chr1stoss.lua` в неё.
3. Создай подпапку `native\` и положи `namechanger.dll` внутрь.
4. Создай подпапку `skeetles\` и положи туда все PNG-иконки.
5. Запусти CS2 через лоадер. `chr1stoss.lua` подхватится автоматически.
6. `chr1stoss.lua.json` создастся рядом со скриптом при первом изменении настроек.

**Минимально необходимо:** `chr1stoss.lua`. Без `native\namechanger.dll` блок NameChanger показывает `DLL not found` и не работает. Без `skeetles\` иконки табов отображаются обычными кружками.

---

### Требования

| Компонент | Обязательно | Примечание |
|---|---|---|
| `chr1stoss.lua` | да | Основной скрипт |
| `native/namechanger.dll` | для NameChanger | x64, VC++ runtime |
| `skeetles/*.png` | рекомендуется | 9 иконок, размер любой (рендерятся в 512x512 / 256×256 / 128×128 в зависимости от слота) |
| `chr1stoss.lua.json` | авто | Создаётся сам, руками не редактировать |
| Lua-лоадер с `render`, `imgui`, `ffi`, `storage`, `entity`, `combat`, `cmd`, `engine`, `cvar`, `trace`, `client`, `ui`, `utils`, `events` | да | skeet loader |

`io`, `os`, `debug`, `package` **не используются** — скрипт работает в песочнице и определяет пути через `kernel32` `GetCurrentDirectoryA` / `ExpandEnvironmentStringsA`.

---

### Функционал

| Таб | Содержимое |
|---|---|
| **RAGEBOT** | Autowall (truth / visual), Knife & Zeus Bot (визуальная заглушка) |
| **ANTI AIM** | По состояниям (stand / crouch / move / air): включение, at-target, yaw, pitch, spin, jitter |
| **CROSSHAIR** | Crosshair, DoubleTap Indicator |
| **VISUALS** | Backtrack, Enemy Arrows, Player Trail, Menu Background, Watermark |
| **MISCELLANEOUS** | Autobuy, Messages (Chat Spammer + TrashTalk), Name Changer |
| **NETWORK** | Список HvH серверов (с фильтром, `connect` по клику) |
| **AUTHOR** | Автор, соцсети (копирование в буфер), информация о сборке |

---

### Управление

| Действие | Ввод |
|---|---|
| Открыть / закрыть меню | управляется лоадером |
| Свернуть / развернуть меню | клик по roll-кнопке в левом нижнем углу |
| Перетащить меню | тянуть за область тулбара |
| Сменить таб | клик по иконке в сайдбаре |
| Скроллить содержимое карточки | колесо мыши над карточкой |

**Поля ввода** поддерживают:
- `Backspace` / `Delete`
- `← → ↑ Home End` перемещение курсора
- `Shift + ←/→` выделение
- `Ctrl + A` выделить всё
- `Ctrl + C` копировать (внутренний буфер скрипта)
- `Ctrl + V` вставить (внутренний буфер скрипта)

**Буфер обмена**: копирование/вставка **внутри игры** работает через внутренний буфер. Копирование **наружу** в систему (например Author → браузер) работает через лоадерный `set_clipboard`, если он есть, с fallback-ом на `win32` запись. Копирование **из** системы (браузер → в игру) **не поддерживается** в этой среде — песочница блокирует `win32` чтение clipboard (`GlobalSize` возвращает 0).

---

### NameChanger

**Порядок поиска DLL** (первое совпадение выигрывает):

1. `storage.get("nc_dll_override")` — ручной override через консоль
2. `%LOCALAPPDATA%\skeet\native\namechanger.dll`
3. `%APPDATA%\skeet\native\namechanger.dll`
4. `%USERPROFILE%\AppData\Local\skeet\native\namechanger.dll`
5. `<cwd>\native\namechanger.dll`
6. `<exe_dir>\namechanger.dll`
7. `native/namechanger.dll`, `namechanger.dll` (относительный fallback)

**Режимы Name Changer:**
- **Default** — стандартное поле ввода для кастомного ника.
- **Stealer** — парсит ники всех доступных игроков на сервере. Два режима:
  - **Certain** — выбор одного конкретного ника из списка.
  - **Few** — выбор нескольких ников для ротации, со слайдером `Swap delay`.

---

### Режимы Clantag:

- **Custom** — одно свободное текстовое поле
- **One** — один пресет + опциональный постфикс (`.cc`, `.pub`, …)
- **Few** — мультивыбор пресетов, каждый со своим постфиксом, плюс слайдер `Swap delay` (переключает теги в порядке их появления в `NC_TAG_PRESETS`, не рандомно)

**Общие модификаторы (применяются к каждому выбранному тегу):**

- **Tag Wrapper** — `Square []`, `Curly {}`, `Angle <>`, `Equals = =`
- **Tag Animation** — `Typing` (с курсором `|`, `/`, `\`, `_`), `Jitter`, `Sliding`
- **Tag Position** — `Before` никнейма / `After` никнейма
- **Tag Speed** — скорость анимации

---

### Конфиг

`chr1stoss.lua.json` записывается автоматически после любого изменения настроек (с задержкой 0 мс, но сохранение блокируется, пока тянешь слайдер / вводишь текст / двигаешь color picker). Это JSON-объект с единственным корневым ключом `state`, содержащим все поля из таблицы `state`.

*Никогда не редактируй этот файл при запущенном скрипте. Правки, сделанные вне игры, применятся при следующей загрузке.*

*Удали файл, чтобы сбросить все настройки на дефолт.*

Разреженные (sparse) массивы запрещены сериализатором лоадера. Скрипт уплотняет все числовые таблицы перед сохранением (`flush_state_if_changed`) и дополнительно санитизирует `nc_tag_presets` при загрузке как страховку (`load_state`).

---

### Устранение проблем

| Симптом | Причина | Решение |
|---|---|---|
| `NameChanger` показывает `DLL not found` | DLL не найдена ни по одному пути | Положи `namechanger.dll` в `%LOCALAPPDATA%\skeet\native\` или задай `nc_dll_override` |
| `NameChanger` показывает `DLL init failed` | DLL несовместима (32-bit на 64-bit, нет VC++ Redistributable, `nc_init()` вернул ошибку) | Пересобери / переустанови DLL |
| `NameChanger` показывает `FFI unavailable` | Лоадер не даёт доступ к `ffi` | Не решается со стороны скрипта |
| Табы отображаются кружками вместо иконок | Нет папки `skeetles\`, неверные имена файлов или не PNG | Проверь папку + имена файлов точно: `icon_ragebot.png`, `icon_antiaim.png`, `icon_crosshair.png`, `icon_visuals.png`, `icon_miscellaneous.png`, `icon_network.png`, `icon_author.png`, `icon_roll.png` |
| `mixed or sparse arrays are not supported` при `storage.set` | Повреждённый конфиг с разреженным числовым массивом | Удали `chr1stoss.lua.json` и перезагрузи |
| Author copy молча не работает | У лоадера нет `set_clipboard`, а `win32` заблокирован | URL всё равно показан в панели; введи его вручную |
| `Ctrl+V` из браузера в поле остаётся пустым | `win32` чтение clipboard заблокировано песочницей | Не поддерживается — используй **внутриигровое** копирование (`Ctrl+C`) и затем вставку (`Ctrl+V`) |

Вывод лога (если включён) идёт в файл-лог лоадера, а не в консоль CS2. Ищи префикс `[chr1stoss]`.

---

### Примечания

- Таб Knife & Zeus Bot — статичный превью. Контролы отрисовываются, но их нельзя переключить или изменить. Ничего не исполняется.
- Anti-Aim подавляет все нативные модификаторы анти-аима (`settings.list("anti aim")` с фильтрацией) и переопределяет `rotation`, `pitch mode`, `custom pitch` каждый тик. При релизе (`anti aim` выключен или игрок мёртв) все override-ы снимаются.
- Awall использует `combat.hitboxes` + `combat.damage` только для последнего тика. Позиция визуального квадрата сглаживается через `1 - exp(-smooth * 20 * dt)`.
- Watermark читает FPS из `client.frametime`, jitter — как rolling stddev из 30 семплов, speed — из `local_player.velocity` (2D-магнитуда), map — из `client.map_name`, time — через `kernel32.GetLocalTime`.
- Масштаб меню следует за `ui.get_menu_rect()`. Если окно игры уже 680 px, меню автоматически сворачивается, а roll-кнопка блокируется до тех пор, пока окно не станет достаточно широким.
- Список серверов — статичный массив внутри скрипта (`HVH_SERVERS`). `CONNECT` выполняет `console.exec("connect [ip:port]")`.

---

### Версия

Текущая сборка: `1.3.3.7`, канал `stable`, `2026-11-13`