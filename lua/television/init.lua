local M = {}

M.config = {
  tv_command = "tv",
  window = {
    width = 0.8,
    height = 0.8,
    border = "rounded",
  },
  mappings = {
    t = {
      ["<C-[>"] = "<C-\\><C-n>:q<CR>",
      ["<Esc>"] = "<C-\\><C-n>:q<CR>",
    },
  },
}

local is_tv_executable = nil
M.channels_cache = nil

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  is_tv_executable = nil
  M.channels_cache = nil
end

local function apply_mappings(buf)
  if M.config.mappings and M.config.mappings.t then
    for lhs, rhs in pairs(M.config.mappings.t) do
      vim.keymap.set("t", lhs, rhs, { buffer = buf, silent = true })
    end
  end
end

local function create_float()
  local stats = vim.api.nvim_list_uis()[1]
  local width = math.floor(stats.width * M.config.window.width)
  local height = math.floor(stats.height * M.config.window.height)
  local col = math.floor((stats.width - width) / 2)
  local row = math.floor((stats.height - height) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = M.config.window.border,
  })

  return buf, win
end

function M.list_channels()
  if M.channels_cache then return M.channels_cache end

  -- Check if executable
  if vim.fn.executable(M.config.tv_command) ~= 1 then
    return { "files", "text", "git-repos", "env" }
  end

  local handle = io.popen(M.config.tv_command .. " list-channels")
  local channels = {}
  if handle then
    for line in handle:lines() do
      table.insert(channels, line)
    end
    handle:close()
  end

  if #channels == 0 then
    -- Fallback default channels
    channels = { "files", "text", "git-repos", "env" }
  end

  M.channels_cache = channels
  return channels
end

function M.run(opts)
  if is_tv_executable == nil then
    is_tv_executable = vim.fn.executable(M.config.tv_command) == 1
  end

  if not is_tv_executable then
    vim.api.nvim_err_writeln("television: command '" .. M.config.tv_command .. "' not found. Please install it: https://github.com/alexpasmantier/television")
    return
  end

  opts = opts or {}
  local channel = opts.channel or ""
  -- Trim channel name
  channel = channel:match("^%s*(.-)%s*$") or channel
  
  -- We use a marker to reliably find the result in the terminal buffer
  local marker = "___TV_RESULT___:"
  local expect = "ctrl-v;ctrl-x;ctrl-t"
  
  local full_cmd = string.format("%s %s --expect=%s --source-output=%s",
    M.config.tv_command,
    channel ~= "" and vim.fn.shellescape(channel) or "",
    vim.fn.shellescape(expect),
    vim.fn.shellescape(marker .. "{}"))
    
  local cmd = { vim.o.shell, "-c", full_cmd }

  local original_win = vim.api.nvim_get_current_win()
  local buf, win = create_float()
  apply_mappings(buf)

  vim.fn.termopen(cmd, {
    on_exit = function(_, exit_code)
      vim.schedule(function()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
        
        -- Restore original window focus before handling selection
        if vim.api.nvim_win_is_valid(original_win) then
            vim.api.nvim_set_current_win(original_win)
        end
        
        -- Process output from buffer
        local selection = nil
        local key = "enter"
        
        -- Search from bottom to find the marker
        for i = #lines, 1, -1 do
            local line = lines[i]
            -- Use a more flexible match to find the marker
            local match = line:match(marker .. "(.*)")
            if match then
                -- Trim trailing whitespace from selection
                selection = match:gsub("%s+$", "")
                
                -- The line above might be the key from --expect
                if i > 1 then
                    -- Clean up the potential key line as well
                    local prev_line = lines[i-1]:match("^%s*(.-)%s*$")
                    if prev_line == "ctrl-v" or prev_line == "ctrl-x" or prev_line == "ctrl-t" then
                        key = prev_line
                    end
                end
                break
            end
        end

        if selection and selection ~= "" then
            if opts.callback then
                opts.callback(selection, key)
            else
                M.default_handler(selection, key, channel)
            end
        elseif exit_code ~= 0 and exit_code ~= 130 then
            vim.api.nvim_err_writeln(string.format("television: command '%s' failed with exit code %d", full_cmd, exit_code))
        end
      end)
    end,
  })

  vim.cmd("startinsert")
end

function M.default_handler(selection, key, channel)
    local cmd = "edit"
    if key == "ctrl-v" then
        cmd = "vsplit"
    elseif key == "ctrl-x" then
        cmd = "split"
    elseif key == "ctrl-t" then
        cmd = "tabedit"
    end

    -- Trim channel for comparison
    local clean_channel = channel and channel:match("^%s*(.-)%s*$") or ""

    -- Basic parsing for common channels
    -- text channel usually outputs file:line:col:text or similar
    if clean_channel == "text" then
        -- Try to match path:line:col
        local file, line, col = string.match(selection, "^(.-):(%d+):(%d+)")
        if not file then
             -- Try path:line
             file, line = string.match(selection, "^(.-):(%d+)")
        end

        if file and line then
            -- Verify the file exists before trying to open it as a text match
            if vim.fn.filereadable(file) == 1 or vim.fn.isdirectory(file) == 1 then
                if file:sub(1, 1) == "+" then
                    file = "./" .. file
                end
                vim.cmd(cmd .. " " .. vim.fn.fnameescape(file))

                local l = tonumber(line)
                local c = tonumber(col or 0)
                if l then
                    pcall(vim.api.nvim_win_set_cursor, 0, {l, c or 0})
                end
                return
            end
        end
    end

    -- Default: just open the file
    -- Check if selection is a file
    if vim.fn.filereadable(selection) == 1 or vim.fn.isdirectory(selection) == 1 then
        -- Prepend ./ to filenames starting with + to prevent arbitrary command execution
        if selection:sub(1, 1) == "+" then
            selection = "./" .. selection
        end
        vim.cmd(cmd .. " " .. vim.fn.fnameescape(selection))
    else
        -- If it's not a file, maybe it's just a string (like in 'env' channel)
        if clean_channel == "text" or clean_channel == "files" then
            vim.api.nvim_err_writeln("television: could not find file: " .. selection)
        else
            print("Selected: " .. selection)
        end
    end
end

-- Predefined pickers
M.pickers = setmetatable({}, {
    __index = function(_, key)
        return function()
            M.run({ channel = key:gsub("_", "-") })
        end
    end
})

return M
