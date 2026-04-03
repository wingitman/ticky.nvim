--- ticky.nvim – notification poller
---
--- Polls `ticky --check` on a configurable interval using a Neovim timer.
--- When the focus session is due (exit code 0), it:
---   1. Shows a vim.notify alert so the user sees it inline in their editor.
---   2. Optionally opens the ticky break-prompt TUI in a floating window
---      (controlled by the `auto_open` config option).
---
--- The poller is started by notify.start() and stopped by notify.stop().
--- It is automatically stopped while the ticky TUI window is open (to avoid
--- double-notifications) and restarted when it closes.

local M = {}

-- Timer handle (vim.uv timer).
local timer    = nil
local notified = false  -- true once we've fired for the current session,
                         -- cleared when the session becomes idle again.

--- Run `ticky --check` asynchronously and call cb(exit_code, lines).
--- @param bin  string    Path to ticky binary
--- @param cb   function  Called with (exit_code: integer, output: string[])
local function check_async(bin, cb)
  local output = {}
  vim.fn.jobstart({ bin, "--check" }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          table.insert(output, line)
        end
      end
    end,
    on_exit = function(_, code)
      cb(code, output)
    end,
  })
end

--- Parse a task name from the first line of `ticky --check` output.
--- Example line: `due: focus session complete for "Write tests" — open ticky`
--- @param lines string[]
--- @return string
local function parse_task_name(lines)
  if not lines or #lines == 0 then
    return ""
  end
  local first = lines[1] or ""
  -- Match the quoted task name after "for ".
  local name = first:match('for "([^"]+)"')
  return name or ""
end

--- Parse the remaining time from the first line of `ticky --check` output.
--- Example line: `running: 18:42 remaining in focus for "Write tests"`
--- @param lines string[]
--- @return string  e.g. "18:42"
local function parse_remaining(lines)
  if not lines or #lines == 0 then return "" end
  return (lines[1] or ""):match("(%d+:%d+)") or ""
end

--- Show a vim.notify break alert.
--- @param task_name string
--- @param open_fn   function  Called if the user should open ticky
local function fire_notification(task_name, open_fn, auto_open)
  local title = "ticky — focus complete"
  local msg   = task_name ~= "" and ("Task: " .. task_name .. "\n") or ""
  msg = msg .. "Open ticky to start your break."

  vim.notify(msg, vim.log.levels.INFO, { title = title })

  if auto_open then
    -- Small delay so the notification renders before the float opens.
    vim.defer_fn(open_fn, 300)
  end
end

--- Start the background poller.
--- If the ticky binary is not found in PATH, a single warning is shown and
--- the poller is NOT started — preventing a silent loop of failing jobstart
--- calls on every poll interval.
--- @param cfg     table     Plugin config (bin, poll_interval, auto_open)
--- @param open_fn function  Called when the break prompt should open
function M.start(cfg, open_fn)
  if timer then
    return -- already running
  end

  -- Guard: if the binary is not found, warn once and do not start the loop.
  if vim.fn.executable(cfg.bin) == 0 then
    vim.notify(
      "ticky: binary '" .. (cfg.bin or "ticky") .. "' not found in PATH.\n"
        .. "Install ticky from: https://github.com/wingitman/ticky\n"
        .. "The ticky.nvim plugin will not poll until the binary is available.",
      vim.log.levels.WARN,
      { title = "ticky.nvim" }
    )
    return
  end

  local interval_ms = (cfg.poll_interval or 10) * 1000

  timer = vim.uv.new_timer()
  timer:start(interval_ms, interval_ms, vim.schedule_wrap(function()
    check_async(cfg.bin, function(code, lines)
      if code == 2 then
        -- Idle — reset notified flag so we fire again next session.
        notified = false
        return
      end

      if code == 1 then
        -- Timer still running (or paused) — nothing to do yet.
        -- Exit code 1 covers both "running" and "paused" states.
        return
      end

      if code == 0 and not notified then
        -- Focus session is due — fire once per session.
        notified = true
        local task_name = parse_task_name(lines)
        fire_notification(task_name, open_fn, cfg.auto_open)
      end
    end)
  end))
end

--- Stop the background poller.
function M.stop()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
end

--- Reset the notified flag. Call this when the ticky window opens so that
--- the poller starts fresh for the next session after the window closes.
function M.reset()
  notified = false
end

--- Returns true if the poller is currently running.
function M.is_running()
  return timer ~= nil
end

--- Synchronous status line helper — runs `ticky --status` and returns the
--- result as a string. Intended for use in statusline / lualine components
--- where an async call is impractical.
--- @param bin string
--- @return string
function M.status_sync(bin)
  local result = vim.fn.system({ bin, "--status" })
  if vim.v.shell_error ~= 0 then
    return ""
  end
  return vim.trim(result or "")
end

--- Returns a human-readable remaining time string from `ticky --check`,
--- suitable for embedding in a statusline. Returns "" when no session active.
--- @param bin string
--- @return string  e.g. "▶ Write tests  ⏱ 18:42" or ""
function M.check_sync(bin)
  local result = vim.fn.system({ bin, "--status" })
  if vim.v.shell_error ~= 0 then
    return ""
  end
  return vim.trim(result or "")
end

return M
