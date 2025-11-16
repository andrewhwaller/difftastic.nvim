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
end

-- Parse a single line with ANSI codes into segments with highlights
local function parse_line_segments(line_text)
  local segments = {}
  local pos = 1
  local current_hl = nil
  local is_emphasized = false  -- Track bold+underline (92;1;4)

  while pos <= #line_text do
    local esc_start, esc_end, codes = line_text:find("\27%[([%d;]*)m", pos)

    if esc_start then
      if esc_start > pos then
        local text = line_text:sub(pos, esc_start - 1)
        local hl = current_hl
        if is_emphasized and current_hl == "DifftasticAddGreenKeyword" then
          hl = "DifftasticAddGreen"  -- Brighter highlight for the changed part
        end
        table.insert(segments, { text, hl or "Normal" })
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
        table.insert(segments, { text, hl or "Normal" })
      end
      break
    end
  end

  return segments
end

-- Parse difftastic output and extract changes with line mapping
local function parse_difftastic_for_overlay(output)
  local changes = {
    additions = {},      -- { line_num, segments } - pure new lines
    modifications = {},  -- { line_num, segments } - changed portions of existing lines
    deletions = {},      -- { line_num, content } - deleted lines
  }

  -- Use vim.split to preserve blank lines (important for empty line additions/deletions)
  local lines = vim.split(output, "\n", { plain = true })

  -- First pass: collect all red (deleted) lines with their content and position
  local deleted_content = {}
  local deleted_lines = {}  -- Track which lines were deleted
  for _, line in ipairs(lines) do
    if line:find("\27%[91") then
      local clean = ansi.strip_ansi(line)
      local old_num = clean:match("^%s*(%d+)")
      if old_num then
        local content = clean:match("^%s*%d+%s+(.*)")
        if content and content ~= "" then
          deleted_content[content] = tonumber(old_num)
          table.insert(deleted_lines, {
            line_num = tonumber(old_num),
            content = content,
          })
        end
      end
    end
  end

  -- Second pass: process green lines
  for _, line in ipairs(lines) do
    if not line:match("%-%-%-") then
      local clean = ansi.strip_ansi(line)

      if clean:match("^   %d+") and line:find("\27%[92") then
        local line_num = clean:match("^   (%d+)")
        if line_num then
          line_num = tonumber(line_num)
          local content = clean:match("^   %d+%s+(.*)")
          if content and content ~= "" then
            local segments = parse_line_segments(line:match("%d+%s+(.*)") or "")

            -- Check if this is similar to a deleted line (modification)
            -- Look for lines that start with similar structure
            local is_modification = false
            for deleted, _ in pairs(deleted_content) do
              -- Simple heuristic: if they start with the same ~20 chars, it's likely a modification
              local prefix_len = math.min(20, #deleted, #content)
              local deleted_prefix = deleted:sub(1, prefix_len)
              local content_prefix = content:sub(1, prefix_len)

              -- If more than 70% of the prefix matches, consider it a modification
              local matches = 0
              for j = 1, prefix_len do
                if deleted_prefix:sub(j, j) == content_prefix:sub(j, j) then
                  matches = matches + 1
                end
              end

              if matches / prefix_len > 0.7 then
                is_modification = true
                break
              end
            end

            if is_modification then
              table.insert(changes.modifications, {
                line_num = line_num,
                segments = segments,
              })
              for deleted, _ in pairs(deleted_content) do
                local prefix_len = math.min(20, #deleted, #content)
                local deleted_prefix = deleted:sub(1, prefix_len)
                local content_prefix = content:sub(1, prefix_len)
                local matches = 0
                for j = 1, prefix_len do
                  if deleted_prefix:sub(j, j) == content_prefix:sub(j, j) then
                    matches = matches + 1
                  end
                end
                if matches / prefix_len > 0.7 then
                  deleted_content[deleted] = nil  -- Remove from deletions
                  break
                end
              end
            else
              table.insert(changes.additions, {
                line_num = line_num,
                segments = segments,
              })
            end
          end
        end
      end
    end
  end

  -- Third pass: remaining deleted lines are pure deletions (not modifications)
  for _, deletion in ipairs(deleted_lines) do
    if deleted_content[deletion.content] then  -- Still in the map, wasn't matched
      table.insert(changes.deletions, {
        line_num = deletion.line_num,
        content = deletion.content,
      })
    end
  end

  return changes
end

-- Show syntax-highlighted diff by replacing changed lines only
function M.show_overlay(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  if filepath == "" then
    return false
  end

  local main = require("difftastic-nvim")

  if not main.ensure_difftastic() then
    return false
  end

  local target = main.config.target_branch or "main"
  local current_branch = vim.fn.system("git branch --show-current 2>/dev/null"):gsub("\n", "")

  local cmd
  local comparison_info

  if current_branch == target then
    cmd = string.format("GIT_EXTERNAL_DIFF='difft --display inline --color always' git diff HEAD -- %s 2>&1", vim.fn.shellescape(filepath))
    comparison_info = "HEAD vs working tree"
  else
    cmd = string.format("GIT_EXTERNAL_DIFF='difft --display inline --color always' git diff %s...HEAD -- %s 2>&1", target, vim.fn.shellescape(filepath))
    comparison_info = string.format("%s vs %s", target, current_branch)
  end

  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 or output == "" then
    return false
  end

  setup_highlights()

  local changes = parse_difftastic_for_overlay(output)

  -- Create namespace for highlights and virtual text
  local ns_id = vim.api.nvim_create_namespace("difftastic_overlay_" .. bufnr)
  main.state.namespaces[bufnr] = ns_id

  -- Show pure additions as virtual lines (don't modify buffer)
  for _, change in ipairs(changes.additions) do
    local line_count = vim.api.nvim_buf_line_count(bufnr)

    local insert_line = change.line_num - 1  -- 0-indexed
    local virt_above = true

    -- If adding at/after the last line, show below the last line instead
    if insert_line >= line_count then
      insert_line = line_count - 1  -- Last line
      virt_above = false  -- Show below
    elseif insert_line < 0 then
      insert_line = 0
      virt_above = true
    end

    local virt_text = {}
    for _, seg in ipairs(change.segments) do
      local text, hl = seg[1], seg[2]
      table.insert(virt_text, {text, hl or "Normal"})
    end

    if #virt_text > 0 then
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, insert_line, 0, {
        virt_lines = { virt_text },
        virt_lines_above = virt_above,
      })
    end
  end

  -- For modifications, DON'T replace the line - only add green highlights
  -- This preserves Neovim's original syntax highlighting
  for _, change in ipairs(changes.modifications) do
    if change.line_num > 0 and change.line_num <= vim.api.nvim_buf_line_count(bufnr) then
      local current_line = vim.api.nvim_buf_get_lines(bufnr, change.line_num - 1, change.line_num, false)[1]
      local search_start = 1  -- Track where to start searching to handle duplicate tokens

      -- Find and highlight only the green (changed) portions
      for _, seg in ipairs(change.segments) do
        local text, hl = seg[1], seg[2]
        if hl and (hl == "DifftasticAddGreen" or hl == "DifftasticAddGreenKeyword") and #text > 0 then
          -- Search for this text starting from where we left off (plain=true so no escaping needed)
          local start_col = current_line:find(text, search_start, true)
          if start_col then
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, change.line_num - 1, start_col - 1, {
              end_col = start_col - 1 + #text,
              hl_group = hl,
              priority = 200,
            })
            -- Move search position past this match for next iteration
            search_start = start_col + #text
          end
        else
          -- For non-highlighted segments, still advance the search position
          -- to maintain correct positioning for subsequent tokens
          if #text > 0 then
            local pos = current_line:find(text, search_start, true)
            if pos then
              search_start = pos + #text
            end
          end
        end
      end
    end
  end

  -- Show deletions as virtual text above where they would have been
  for _, deletion in ipairs(changes.deletions) do
    local insert_at_line = deletion.line_num - 1  -- 0-indexed position where deletion was

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if insert_at_line >= line_count then
      insert_at_line = line_count - 1
    end
    if insert_at_line < 0 then
      insert_at_line = 0
    end

    vim.api.nvim_buf_set_extmark(bufnr, ns_id, insert_at_line, 0, {
      virt_lines = { { {"  - " .. deletion.content, "DifftasticDeletedLine"} } },
      virt_lines_above = true,  -- Show above the current line
    })
  end

  main.state.buffers[bufnr] = {
    in_overlay = true,
    comparison_info = comparison_info,
    filepath = filepath,
  }

  return true
end

-- Clear overlay (remove virtual text and highlights only, don't restore content)
function M.clear_overlay(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local main = require("difftastic-nvim")

  local state = main.state.buffers[bufnr]
  if not state or not state.in_overlay then
    return false
  end

  local ns_id = main.state.namespaces[bufnr]
  if ns_id then
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  end

  main.state.buffers[bufnr] = nil

  return true
end

return M
