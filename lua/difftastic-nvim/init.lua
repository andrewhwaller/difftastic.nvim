local M = {}

M.config = {
  target_branch = "main",
}

M.state = {
  namespaces = {},
  buffers = {},
}

local function is_difftastic_installed()
  local handle = io.popen("which difft 2>/dev/null")
  if handle then
    local result = handle:read("*a")
    handle:close()
    return result ~= ""
  end
  return false
end

function M.ensure_difftastic()
  if not is_difftastic_installed() then
    vim.notify(
      "Difftastic not found. Please install it:\n" ..
      "  macOS/Linux: brew install difftastic\n" ..
      "  Or: cargo install difftastic",
      vim.log.levels.ERROR
    )
    return false
  end
  return true
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  require("difftastic-nvim.commands").setup()
  require("difftastic-nvim.autocmds").setup()
end

return M
