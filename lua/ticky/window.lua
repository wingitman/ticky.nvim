--- ticky.nvim – floating window management
--- Creates, shows, and tears down the terminal buffer that runs the ticky TUI.

local M = {}

local state = {
	buf = nil, -- terminal buffer handle
	win = nil, -- floating window handle
	job = nil, -- terminal job id
	augroup = nil, -- autocmd group id (cleared on teardown)
}

--- Returns true if the floating window is currently open and valid.
function M.is_open()
	return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

--- Returns true if a terminal buffer exists (may be hidden).
function M.has_buf()
	return state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf)
end

--- Compute floating window dimensions from config.
--- @param opts table  Plugin config (width, height, border)
--- @return table      nvim_open_win config table
local function win_config(opts)
	local total_w = vim.o.columns
	local total_h = vim.o.lines

	local w = math.floor(total_w * opts.width)
	local h = math.floor(total_h * opts.height)
	local row = math.floor((total_h - h) / 2.5)
	local col = math.floor((total_w - w) / 2)

	return {
		relative = "editor",
		style = "minimal",
		border = opts.border,
		width = w,
		height = h,
		row = row,
		col = col,
		zindex = 50,
	}
end

--- Tear down the window and buffer, then call on_exit.
--- @param on_exit  function|nil  Called after cleanup with (exit_code).
--- @param exit_code integer
local function teardown(on_exit, exit_code)
	if M.is_open() then
		-- pcall guards against double-close races (e.g. user called M.close()
		-- just before the process exit callback fires).
		pcall(vim.api.nvim_win_close, state.win, true)
		state.win = nil
	end
	if M.has_buf() then
		pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
		state.buf = nil
	end
	state.job = nil
	if state.augroup then
		pcall(vim.api.nvim_del_augroup_by_id, state.augroup)
		state.augroup = nil
	end
	-- Force a full redraw to clear any BubbleTea alt-screen artifacts that
	-- may have been left behind when the terminal process exited.
	pcall(vim.cmd, "redraw!")
	if on_exit then
		on_exit(exit_code)
	end
end

--- Open a floating terminal window running the ticky binary.
--- @param opts      table     Plugin config
--- @param cmd       string    Full shell command to run
--- @param on_exit   function  Called when the process exits with (exit_code)
function M.open(opts, cmd, on_exit)
	if M.is_open() then
		return
	end

	if not M.has_buf() then
		state.buf = vim.api.nvim_create_buf(false, true)
	end

	local wcfg = win_config(opts)
	state.win = vim.api.nvim_open_win(state.buf, true, wcfg)

	vim.wo[state.win].winblend = opts.winblend or 0
	vim.wo[state.win].winhighlight = "Normal:TickyNormal,FloatBorder:TickyBorder"
	vim.wo[state.win].cursorline = false
	vim.wo[state.win].winbar = "" -- prevent global winbar bleeding into the float
	vim.wo[state.win].statusline = " " -- prevent global statusline bleeding into the float

	state.job = vim.fn.termopen(cmd, {
		on_exit = function(_, code, _)
			-- Defer teardown to avoid races between terminal job exit,
			-- window/buffer cleanup, and any post-exit vim.schedule work.
			vim.schedule(function()
				teardown(on_exit, code)
			end)
		end,
	})

	-- Prevent accidental normal-mode escape inside the terminal float.
	vim.keymap.set("t", "<C-\\><C-n>", "<Nop>", { buffer = state.buf, silent = true })

	-- Re-enter terminal insert mode whenever this buffer is focused.
	state.augroup = vim.api.nvim_create_augroup("TickyTerminal", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
		group = state.augroup,
		buffer = state.buf,
		callback = function()
			if M.is_open() then
				vim.cmd("startinsert")
			end
		end,
	})

	vim.cmd("startinsert")
end

--- Close the floating window (does not kill the ticky process).
function M.close()
	if M.is_open() then
		vim.api.nvim_win_close(state.win, true)
		state.win = nil
	end
end

return M
