local M = {}

function M.setup()
  local main = require("difftastic-nvim")
  local overlay = require("difftastic-nvim.overlay")
  local group = vim.api.nvim_create_augroup("DifftasticNvim", { clear = true })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(args)
      if main.state.buffers[args.buf] then
        main.state.buffers[args.buf] = nil
      end
      if main.state.namespaces[args.buf] then
        main.state.namespaces[args.buf] = nil
      end
    end,
    desc = "Clean up difftastic data on buffer delete",
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(args)
      local filepath = vim.api.nvim_buf_get_name(args.buf)
      if filepath:match("difftastic%-nvim/") then
        return
      end

      local state = main.state.buffers[args.buf]
      if state and state.in_overlay then
        vim.defer_fn(function()
          local ns_id = main.state.namespaces[args.buf]
          if ns_id then
            vim.api.nvim_buf_clear_namespace(args.buf, ns_id, 0, -1)
          end
          overlay.show_overlay(args.buf)
        end, 100)
      end
    end,
    desc = "Refresh difftastic overlay after save",
  })
end

return M
