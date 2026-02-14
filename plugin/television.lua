local function television_complete(arg_lead, cmd_line, cursor_pos)
  local channels = require("television").list_channels()
  return vim.tbl_filter(function(item)
    return item:find(arg_lead, 1, true) ~= nil
  end, channels)
end

vim.api.nvim_create_user_command("Television", function(opts)
  local channel = opts.args
  if channel == "" then
    channel = "files"
  end
  require("television").run({ channel = channel })
end, {
  nargs = "?",
  complete = television_complete,
})

-- Shorthand commands
vim.api.nvim_create_user_command("Tv", function(opts)
    vim.cmd("Television " .. opts.args)
end, {
    nargs = "?",
    complete = television_complete,
})
