local M = {}

function M.setup()
  local main = require("difftastic-nvim")
  local overlay = require("difftastic-nvim.overlay")
  local split = require("difftastic-nvim.split")

  vim.api.nvim_create_user_command("DifftasticToggle", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local state = main.state.buffers[bufnr]

    if state and state.in_overlay then
      overlay.clear_overlay(bufnr)
    else
      overlay.show_overlay(bufnr)
    end
  end, {
    desc = "Toggle difftastic syntax-highlighted overlay",
  })

  vim.api.nvim_create_user_command("DifftasticSplit", function()
    split.show_split_diff()
  end, {
    desc = "Show difftastic in split window mode",
  })
end

return M
