local M = {}
local ansi = require("difftastic-nvim.ansi")

-- Define highlight groups for syntax-aware difftastic output
local function setup_highlights()
  vim.api.nvim_set_hl(0, "DifftasticAddGreen", { fg = "#5fd787", bold = true, bg = "#1a3a1a" })
  vim.api.nvim_set_hl(0, "DifftasticAddGreenKeyword", { fg = "#5fd787", bold = true })
  vim.api.nvim_set_hl(0, "DifftasticAddGreenNormal", { fg = "#87d787" })
  vim.api.nvim_set_hl(0, "DifftasticDeleteRed", { fg = "#ff5f5f", bg = "#3a1a1a" })
  vim.api.nvim_set_hl(0, "DifftasticModifyYellow", { fg = "#ffd75f" })
  vim.api.nvim_set_hl(0, "DifftasticString", { fg = "#d787ff" })
  vim.api.nvim_set_hl(0, "DifftasticDeletedLine", { fg = "#ff5f5f", italic = true })
  vim.api.nvim_set_hl(0, "DifftasticHeader", { fg = "#87afff", bold = true })
  vim.api.nvim_set_hl(0, "DifftasticNormal", { fg = "#d0d0d0" })
end

-- Parse a single line with ANSI codes into segments with highlights
local function parse_line_segments(line_text)
  local segments = {}
  local pos = 1
  local current_hl = nil
  local is_emphasized = false

  while pos <= #line_text do
    local esc_start, esc_end, codes = line_text:find("\27%[([%d;]*)m", pos)

    if esc_start then
      if esc_start > pos then
        local text = line_text:sub(pos, esc_start - 1)
        local hl = current_hl
        if is_emphasized and current_hl == "DifftasticAddGreenKeyword" then
          hl = "DifftasticAddGreen"
        end
        table.insert(segments, { text, hl or "DifftasticNormal" })
      end

      if codes == "0" or codes == "" or codes == "39" then
        current_hl = nil
        is_emphasized = false
      elseif codes == "92;1;4" then
        current_hl = "DifftasticAddGreen"
        is_emphasized = true
      elseif codes == "92;1" or codes == "92" then
        current_hl = "DifftasticAddGreenKeyword"
        is_emphasized = false
      elseif codes == "91;1;4" then
        current_hl = "DifftasticDeleteRed"
        is_emphasized = true
      elseif codes == "91;1" or codes == "91" then
        current_hl = "DifftasticDeleteRed"
        is_emphasized = false
      elseif codes == "93;1" or codes == "93" then
        current_hl = "DifftasticModifyYellow"
        is_emphasized = false
      elseif codes == "95" then
        current_hl = "DifftasticString"
        is_emphasized = false
      elseif codes == "1" then
        current_hl = "Bold"
        is_emphasized = false
      elseif codes == "2" then
        current_hl = "Comment"
        is_emphasized = false
      end

      pos = esc_end + 1
    else
      local text = line_text:sub(pos)
      if #text > 0 then
        local hl = current_hl
        if is_emphasized and current_hl == "DifftasticAddGreenKeyword" then
          hl = "DifftasticAddGreen"
        end
        table.insert(segments, { text, hl or "DifftasticNormal" })
      end
      break
    end
  end

  return segments
end

-- Parse difftastic output and extract all diff lines with their positions
local function parse_difftastic_for_inline(output)
  local diff_lines = {}  -- { line_num, segments, is_deletion }
  local lines = vim.split(output, "\n", { plain = true, trimempty = false })

  for _, line in ipairs(lines) do
    local clean = ansi.strip_ansi(line)

    -- Skip separator lines
    if not line:match("%-%-%-") and not clean:match("^%s*$") then
      -- Extract line number (format: "  123" for context or "   123" for changes)
      local line_num = clean:match("^%s*(%d+)")

      if line_num then
        line_num = tonumber(line_num)
        local is_deletion = line:find("\27%[91") ~= nil  -- Red = deletion
        local is_addition = line:find("\27%[92") ~= nil  -- Green = addition

        if is_deletion or is_addition then
          -- Parse the line content (everything after the line number)
          local content = clean:match("^%s*%d+%s+(.*)")
          if content then
            local segments = parse_line_segments(line:match("%d+%s+(.*)") or "")

            table.insert(diff_lines, {
              line_num = line_num,
              segments = segments,
              is_deletion = is_deletion,
              content = content,
            })
          end
        end
      end
    end
  end

  return diff_lines
end

-- Show inline diff using virtual text (no split window)
function M.show_split_diff(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  if filepath == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return false
  end

  local main = require("difftastic-nvim")

  if not main.ensure_difftastic() then
    return false
  end

  local target = main.config.target_branch or "main"

  local git_dir = vim.fn.system("git rev-parse --git-dir 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return false
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
      return false
    end
    cmd = string.format("GIT_EXTERNAL_DIFF='difft --display inline --color always' git diff HEAD -- %s 2>&1", vim.fn.shellescape(filepath))
    comparison_info = "HEAD vs working tree"
  else
    cmd = string.format("GIT_EXTERNAL_DIFF='difft --display inline --color always' git diff %s...HEAD -- %s 2>&1", target, vim.fn.shellescape(filepath))
    comparison_info = string.format("%s vs %s", target, current_branch)
  end

  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 or output == "" or output:match("^fatal:") then
    local diff_check = vim.fn.system(string.format("git diff HEAD -- %s", vim.fn.shellescape(filepath)))
    if diff_check == "" then
      vim.notify("No changes in this file", vim.log.levels.INFO)
    else
      vim.notify("Could not generate diff", vim.log.levels.WARN)
    end
    return false
  end

  -- Setup highlights
  setup_highlights()

  -- Parse the output into diff lines
  local diff_lines = parse_difftastic_for_inline(output)

  -- Create namespace for virtual text
  local ns_id = vim.api.nvim_create_namespace("difftastic_split_" .. bufnr)
  main.state.namespaces[bufnr] = ns_id

  -- Apply virtual text for each diff line
  for _, diff_line in ipairs(diff_lines) do
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local target_line = diff_line.line_num - 1  -- 0-indexed

    -- Clamp to valid range
    if target_line >= line_count then
      target_line = line_count - 1
    end
    if target_line < 0 then
      target_line = 0
    end

    -- Build virtual text from segments
    local virt_text = {}
    for _, seg in ipairs(diff_line.segments) do
      local text, hl = seg[1], seg[2]
      table.insert(virt_text, { text, hl or "DifftasticNormal" })
    end

    if #virt_text > 0 then
      -- Show deletions above, additions below
      local virt_above = diff_line.is_deletion

      pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, target_line, 0, {
        virt_lines = {{ virt_text }},
        virt_lines_above = virt_above,
      })
    end
  end

  main.state.buffers[bufnr] = {
    in_overlay = true,
    comparison_info = comparison_info,
    filepath = filepath,
  }

  vim.notify("Difftastic inline diff enabled (use :DifftasticCloseSplit to hide)", vim.log.levels.INFO)
  return true
end

-- Close inline diff (clear virtual text)
function M.close_split_diff(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local main = require("difftastic-nvim")

  local state = main.state.buffers[bufnr]
  if not state or not state.in_overlay then
    vim.notify("No difftastic inline diff active in this buffer", vim.log.levels.INFO)
    return false
  end

  local ns_id = main.state.namespaces[bufnr]
  if ns_id then
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  end

  main.state.buffers[bufnr] = nil
  main.state.namespaces[bufnr] = nil

  vim.notify("Difftastic inline diff hidden", vim.log.levels.INFO)
  return true
end

return M
