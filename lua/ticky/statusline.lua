--- ticky.nvim – statusline / lualine integration
---
--- Provides a cached status component that calls `ticky --status` at most
--- once per `cache_ttl` seconds, avoiding excessive subprocess spawning when
--- the statusline redraws frequently (e.g. lualine with globalstatus).
---
--- Usage (lualine):
---
---   require("lualine").setup({
---     sections = {
---       lualine_x = { require("ticky.statusline").component },
---     },
---   })
---
--- Usage (vanilla statusline):
---
---   vim.o.statusline = "%{%v:lua.require('ticky.statusline').str()%}"
---
--- Both call require("ticky").status() which delegates to `ticky --status`.

local M = {}

-- Simple TTL cache so we don't spawn a process on every statusline redraw.
local _cache     = ""
local _cache_at  = 0
local _cache_ttl = 2  -- seconds; configurable via M.setup_cache(ttl)

--- Update the cache if it has expired.
local function refresh()
  local now = vim.uv.now() / 1000  -- ms → s
  if now - _cache_at < _cache_ttl then
    return
  end
  _cache_at = now

  -- Avoid calling if ticky isn't set up yet.
  local ok, ticky = pcall(require, "ticky")
  if not ok then
    _cache = ""
    return
  end
  _cache = ticky.status()
end

--- Set the cache TTL in seconds (default 2).
--- @param ttl number  Seconds between subprocess calls.
function M.setup_cache(ttl)
  _cache_ttl = ttl or 2
end

--- Return the current ticky status string (cached).
--- Returns "" when no session is active.
--- @return string
function M.str()
  refresh()
  return _cache
end

--- lualine component table.
--- Add to lualine sections:
---   lualine_x = { require("ticky.statusline").component }
M.component = {
  function()
    return M.str()
  end,
  cond = function()
    return M.str() ~= ""
  end,
  color = { fg = "#7C9EF0" },  -- matches ticky's primary blue
}

return M
