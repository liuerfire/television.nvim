local M = {}

M.config = {
  tv_command = "tv",
  window = {
    width = 0.8,
    height = 0.8,
    border = "rounded",
  },
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
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

function M.run(opts)
  if vim.fn.executable(M.config.tv_command) == 0 then
    vim.api.nvim_err_writeln("television: command '" .. M.config.tv_command .. "' not found. Please install it: https://github.com/alexpasmantier/television")
    return
  end

  opts = opts or {}
  local channel = opts.channel or ""
  local temp_file = vim.fn.tempname()
  
  -- We use --expect to handle different open actions
  local expect = "ctrl-v;ctrl-x;ctrl-t"
  
  local full_cmd = string.format("%s %s --expect=%s > %s",
    M.config.tv_command,
    channel ~= "" and vim.fn.shellescape(channel) or "",
    vim.fn.shellescape(expect),
    vim.fn.shellescape(temp_file))
    
  -- vim.api.nvim_echo({{ "Running: " .. full_cmd, "None" }}, false, {})
    
  local cmd = { vim.o.shell, "-c", full_cmd }

  local buf, win = create_float()

  vim.fn.termopen(cmd, {
    on_exit = function(_, exit_code)
      if exit_code ~= 0 and exit_code ~= 130 then
        vim.api.nvim_err_writeln(string.format("television: command '%s' failed with exit code %d", full_cmd, exit_code))
        return
      end

      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      
      if exit_code == 0 or exit_code == 130 then -- 130 is usually SIGINT/Esc
        local file = io.open(temp_file, "r")
        if file then
          local lines = {}
          for line in file:lines() do
            table.insert(lines, line)
          end
          file:close()
          os.remove(temp_file)

          if #lines > 0 then
            local key = "enter"
            local selection = lines[1]
            if #lines > 1 then
                key = lines[1]
                selection = lines[2]
            end
            
            if selection and selection ~= "" then
                if opts.callback then
                    opts.callback(selection, key)
                else
                    M.default_handler(selection, key, channel)
                end
            end
          end
        end
      end
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

    -- Basic parsing for common channels
    -- text channel usually outputs file:line:col:text or similar
    if channel == "text" then
        local parts = vim.split(selection, ":")
        if #parts >= 2 then
            local file = parts[1]
            local line = parts[2]
            local col = parts[3]
            vim.cmd(cmd .. " " .. vim.fn.fnameescape(file))
            vim.api.nvim_win_set_cursor(0, {tonumber(line), tonumber(col or 0)})
            return
        end
    end

    -- Default: just open the file
    -- Check if selection is a file
    if vim.fn.filereadable(selection) == 1 or vim.fn.isdirectory(selection) == 1 then
        vim.cmd(cmd .. " " .. vim.fn.fnameescape(selection))
    else
        -- If it's not a file, maybe it's just a string (like in 'env' channel)
        print("Selected: " .. selection)
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
