local M = {}

-- Strip ANSI codes from text
function M.strip_ansi(text)
  return text:gsub("\27%[[%d;]*m", "")
end

-- Parse ANSI codes to get highlight groups
local ansi_to_hl = {
  ["92"] = "DiffAdd",       -- Green (additions)
  ["92;1"] = "DiffAdd",     -- Bright green
  ["91"] = "DiffDelete",    -- Red (deletions)
  ["91;1"] = "DiffDelete",  -- Bright red
  ["93"] = "DiffChange",    -- Yellow (modifications)
  ["93;1"] = "DiffChange",  -- Bright yellow
  ["95"] = "String",        -- Magenta (strings)
  ["1"] = "Bold",           -- Bold
  ["2"] = "Comment",        -- Dim/comment
}

-- Parse text with ANSI codes into segments with highlight groups
function M.parse_with_highlights(text)
  local segments = {}
  local current_hl = nil
  local current_text = ""
  local pos = 1

  while pos <= #text do
    local escape_start, escape_end, code = text:find("\27%[([%d;]*)m", pos)

    if escape_start then
      if current_text ~= "" then
        table.insert(segments, { text = current_text, hl = current_hl })
        current_text = ""
      end

      if code == "0" or code == "39" then
        current_hl = nil  -- Reset
      else
        current_hl = ansi_to_hl[code] or current_hl
      end

      pos = escape_end + 1
    else
      current_text = current_text .. text:sub(pos)
      break
    end
  end

  if current_text ~= "" then
    table.insert(segments, { text = current_text, hl = current_hl })
  end

  return segments
end

return M
