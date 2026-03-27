# ticky.nvim

A Neovim plugin that wraps the [ticky](https://github.com/wingitman/ticky) pomodoro timer and task scheduler.

- Opens the ticky TUI in a **floating window** inside Neovim
- **Notifies you** when a focus session ends via `vim.notify` — no raw-mode errors, no terminal fighting
- Optionally **auto-opens** the break prompt when the timer fires
- Provides a **statusline / lualine component** showing the active task and remaining time
- Polls `ticky --check` in the background — zero interference with your editing

> Made by [delbysoft](https://github.com/wingitman)

---

## Requirements

- Neovim >= 0.9
- [ticky](https://github.com/wingitman/ticky) installed and on `$PATH`

---

## Installation

### lazy.nvim

```lua
{
  "wingitman/ticky.nvim",
  config = function()
    require("ticky").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "wingitman/ticky.nvim",
  config = function()
    require("ticky").setup()
  end,
}
```

---

## Usage

| Command        | Description                             |
|----------------|-----------------------------------------|
| `:Ticky`       | Open the ticky TUI in a floating window |
| `:TickyToggle` | Toggle the ticky floating window        |

The default keymap is `<leader>tk`. Override or disable it via `setup()`.

Inside the ticky TUI, all normal ticky keybinds work as expected — navigate tasks, start timers, view reports, etc.

### Notifications

When a focus session ends, ticky.nvim:

1. Shows a `vim.notify` alert: `"ticky — focus complete"`
2. If `auto_open = true` (the default), automatically opens the ticky break-prompt TUI in a floating window

If you use [nvim-notify](https://github.com/rcarriga/nvim-notify), the alert appears as a styled notification. Any other `vim.notify` handler works too.

### Statusline

The active task and remaining time are available for your statusline.

#### lualine

```lua
require("lualine").setup({
  sections = {
    lualine_x = {
      require("ticky.statusline").component,
      "encoding",
      "fileformat",
      "filetype",
    },
  },
})
```

#### Vanilla statusline

```lua
vim.o.statusline = "%{%v:lua.require('ticky.statusline').str()%} %f"
```

The component returns `""` when no session is active, so it takes up no space when idle.

---

## Configuration

```lua
require("ticky").setup({
  -- Path to the ticky binary (default: "ticky" from $PATH).
  bin = "ticky",

  -- Floating window dimensions as a fraction of editor size.
  width  = 0.85,
  height = 0.85,

  -- Border style: "rounded", "single", "double", "shadow", "none", …
  border = "rounded",

  -- Window transparency 0–100 (0 = opaque).
  winblend = 0,

  -- How often (seconds) to poll ticky --check for session completion.
  -- Lower = faster notification, slightly more CPU. 10s is a good balance.
  poll_interval = 10,

  -- When true, automatically open the break-prompt TUI when focus ends.
  -- When false, only a vim.notify alert is shown.
  auto_open = true,

  -- Keymap to toggle the ticky window. Set to false to disable.
  keymap = "<leader>tk",
})
```

---

## Highlight Groups

| Group        | Default link | Purpose           |
|--------------|--------------|-------------------|
| `TickyNormal` | `NormalFloat` | Window background |
| `TickyBorder` | `FloatBorder` | Window border     |

Override them after `setup()`:

```lua
vim.api.nvim_set_hl(0, "TickyBorder", { fg = "#7C9EF0" })
```

---

## How it works

**TUI window:** ticky is launched in a Neovim floating terminal buffer using `vim.fn.termopen`. The window is sized as a fraction of the editor and centred. The notification poller is paused while ticky is open (ticky manages its own session state while running) and restarted when the window closes.

**Notification poller:** A `vim.uv` timer calls `ticky --check` (asynchronously via `vim.fn.jobstart`) every `poll_interval` seconds. When `ticky --check` exits with code `0` (session due), a `vim.notify` alert fires once per session. If `auto_open = true`, the ticky TUI opens automatically after a short delay.

**Statusline:** `ticky.statusline` calls `ticky --status` synchronously with a 2-second TTL cache so it's safe to use in frequently-redrawn statuslines.

**Why not raw-mode relaunch?** Running a BubbleTea TUI inside Neovim's terminal emulator fails because Neovim controls the PTY and rejects `tcsetattr` calls. ticky.nvim avoids this entirely by using Neovim's own terminal buffer API, which gives ticky a proper PTY with no conflict.

---

## Ko-fi

<a href='https://ko-fi.com/W7W21WP5L7' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi4.png?v=6' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>

---

## License

MIT — Copyright (c) 2026 [delbysoft](https://github.com/wingitman)
