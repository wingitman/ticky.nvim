--- ticky.nvim
--- A Neovim plugin that wraps the ticky pomodoro timer TUI and delivers
--- native focus-session notifications inside Neovim.
---
--- https://github.com/wingitman/ticky

local window = require("ticky.window")
local notify = require("ticky.notify")

local M = {}

--- Default configuration.
local defaults = {
	-- Path to the ticky binary. "ticky" relies on $PATH.
	bin = "ticky",

	-- Floating window dimensions (fraction of editor size).
	width = 0.85,
	height = 0.85,

	-- Window border style. See :h nvim_open_win for valid values.
	border = "rounded",

	-- Window transparency (0–100). 0 = opaque.
	winblend = 0,

	-- How often (in seconds) to poll `ticky --check` for timer completion.
	-- Lower values = faster notification, slightly more CPU. 10s is a good default.
	poll_interval = 10,

	-- When true, automatically open the ticky break-prompt floating window
	-- when the focus session fires. When false, only a vim.notify alert is shown
	-- and the user can open ticky manually with :Ticky.
	auto_open = true,

	-- Keymap to toggle the ticky TUI. Set to false to disable.
	keymap = "<leader>tk",
}

--- Resolved config (populated by setup()).
M.config = {}

--- Ensure ticky highlight groups exist, linking to built-in float groups
--- unless the user has already defined their own.
local function define_highlights()
	if vim.fn.hlexists("TickyNormal") == 0 then
		vim.api.nvim_set_hl(0, "TickyNormal", { link = "NormalFloat" })
	end
	if vim.fn.hlexists("TickyBorder") == 0 then
		vim.api.nvim_set_hl(0, "TickyBorder", { link = "FloatBorder" })
	end
end

--- Open the ticky TUI in a floating window.
--- Stops the notification poller while the window is open (ticky handles
--- its own session state while running) and restarts it on close.
function M.open()
	if window.is_open() then
		return
	end

	if vim.fn.executable(M.config.bin) == 0 then
		vim.notify(
			"ticky: binary '"
				.. (M.config.bin or "ticky")
				.. "' not found in PATH.\n"
				.. "Install it from: https://github.com/wingitman/ticky",
			vim.log.levels.ERROR
		)
		return
	end

	define_highlights()

	-- Pause the poller while the TUI is running — ticky manages its own state
	-- and we don't want a notification firing while the user is already in ticky.
	notify.stop()

	-- Reset the notified flag so the poller starts fresh for the next session
	-- after this window closes.
	notify.reset()

	local cmd = vim.fn.shellescape(M.config.bin)

	window.open(M.config, cmd, function(_exit_code)
		-- Restart the poller after the ticky window closes.
		vim.schedule(function()
			notify.start(M.config, M.open)
		end)
	end)
end

--- Toggle the ticky floating window.
function M.toggle()
	if window.is_open() then
		window.close()
	else
		M.open()
	end
end

--- Setup — call this once from your Neovim config.
--- @param opts table|nil  Partial config table to override defaults.
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", defaults, opts or {})

	-- Register default keymap unless disabled.
	if M.config.keymap then
		vim.keymap.set("n", M.config.keymap, function()
			M.toggle()
		end, { desc = "Toggle ticky pomodoro timer", silent = true })
	end

	-- Start the background notification poller.
	-- Pass M.open as the callback so a due session opens the break prompt.
	notify.start(M.config, M.open)
end

--- Return the current ticky status as a string, for use in statuslines.
--- Returns "" when no session is active.
--- This calls `ticky --status` synchronously — suitable for statuslines that
--- are evaluated frequently. Consider using the lualine component instead,
--- which caches the result.
function M.status()
	if vim.fn.executable(M.config.bin) == 0 then
		return ""
	end
	return notify.status_sync(M.config.bin)
end

return M
