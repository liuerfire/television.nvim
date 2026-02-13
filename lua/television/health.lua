local M = {}

local health = vim.health or require("health")

function M.check()
  health.start("television.nvim report")

  if vim.fn.executable("tv") == 1 then
    health.ok("television: 'tv' executable is found.")
    local handle = io.popen("tv --version")
    if handle then
      local result = handle:read("*a")
      handle:close()
      health.info("television: version: " .. result:gsub("
", ""))
    end
  else
    health.error("television: 'tv' executable is not found. Please install it: https://github.com/alexpasmantier/television")
  end
end

return M
