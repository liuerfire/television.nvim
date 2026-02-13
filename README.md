# television.nvim

A Neovim integration for [television](https://github.com/alexpasmantier/television), a fast, portable, and hackable fuzzy finder.

## Requirements

- Neovim 0.5+
- `television` (executable as `tv`) installed on your system.

## Configuration

You can configure `television.nvim` using the `setup` function:

```lua
require("television").setup({
  tv_command = "tv", -- default
  window = {
    width = 0.8,     -- default
    height = 0.8,    -- default
    border = "rounded", -- default
  },
  mappings = {
    t = {
      -- default mappings to close the window
      ["<C-[>"] = "<C-\\><C-n>:q<CR>",
      ["<Esc>"] = "<C-\\><C-n>:q<CR>",
    },
  },
})
```

