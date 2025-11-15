local M = {}

-- Open split window with difftastic output
function M.show_split_diff(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  if filepath == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end

  local main = require("difftastic-nvim")

  if not main.ensure_difftastic() then
    return
  end

  local target = main.config.target_branch or "main"

  local git_dir = vim.fn.system("git rev-parse --git-dir 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return
  end

  local current_branch = vim.fn.system("git branch --show-current 2>/dev/null"):gsub("\n", "")

  -- Check if file is tracked (shellescape handles paths with spaces/special chars)
  local is_tracked = vim.fn.system(string.format("git ls-files --error-unmatch %s 2>/dev/null", vim.fn.shellescape(filepath)))
  local tracked = vim.v.shell_error == 0

  local cmd
  local comparison_info

  if current_branch == target then
    if not tracked then
      vim.notify("File not tracked by git (use 'git add' first)", vim.log.levels.WARN)
      return
    end
    cmd = string.format("GIT_EXTERNAL_DIFF=difft git diff HEAD -- %s 2>&1", vim.fn.shellescape(filepath))
    comparison_info = string.format("HEAD vs working tree: %s", vim.fn.fnamemodify(filepath, ":t"))
  else
    cmd = string.format("GIT_EXTERNAL_DIFF=difft git diff %s...HEAD -- %s 2>&1", target, vim.fn.shellescape(filepath))
    comparison_info = string.format("%s vs %s: %s", target, current_branch, vim.fn.fnamemodify(filepath, ":t"))
  end

  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 or output == "" or output:match("^fatal:") then
    local diff_check = vim.fn.system(string.format("git diff HEAD -- %s", vim.fn.shellescape(filepath)))
    if diff_check == "" then
      vim.notify("No changes in this file", vim.log.levels.INFO)
    else
      vim.notify("Could not generate diff", vim.log.levels.WARN)
    end
    return
  end

  vim.cmd("botright new")
  local diff_bufnr = vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_set_option(diff_bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(diff_bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(diff_bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(diff_bufnr, "filetype", "diff")

  vim.api.nvim_buf_set_name(diff_bufnr, string.format("difftastic://%s", comparison_info))

  -- Split output into lines and set buffer content (preserve blank lines)
  local lines = vim.split(output, "\n", { plain = true, trimempty = false })

  vim.api.nvim_buf_set_lines(diff_bufnr, 0, -1, false, lines)

  vim.api.nvim_buf_set_option(diff_bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(diff_bufnr, "readonly", true)

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(win, math.floor(vim.o.lines * 0.3))

  vim.api.nvim_buf_set_keymap(diff_bufnr, "n", "q", ":q<CR>", {
    noremap = true,
    silent = true,
    desc = "Close difftastic split",
  })

  vim.api.nvim_buf_set_keymap(diff_bufnr, "n", "<Esc>", ":q<CR>", {
    noremap = true,
    silent = true,
    desc = "Close difftastic split",
  })

  vim.notify("Difftastic split view opened (press q or Esc to close)", vim.log.levels.INFO)
end

-- Close any open difftastic split windows
function M.close_split_diff()
  local buffers = vim.api.nvim_list_bufs()
  for _, buf in ipairs(buffers) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match("^difftastic://") then
      local windows = vim.fn.win_findbuf(buf)
      for _, win in ipairs(windows) do
        vim.api.nvim_win_close(win, true)
      end
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
end

return M
