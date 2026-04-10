## Big Picture Neovim Core Projects

- minibuffer (Unified Floating Window Interface)
  * https://github.com/neovim/neovim/issues/35456
  * https://github.com/simifalaye/minibuffer.nvim
  * ui2-based finder: https://github.com/comfysage/artio.nvim

- Issues and PRs related to how to update and standardize LSP configuration.
  * https://github.com/neovim/neovim/issues/38858

## Neovim Issues:

- https://github.com/neovim/neovim/issues/16166 - Virt lines above scroll issue

## Code Info/Snippets:

- https://github.com/tjdevries/lazy-require.nvim
- `export NVIM_APPNAME=some-other-thing` will make the config .config/some-other-thing
- `TEST_FILE=test/functional/autocmd/win_scrolled_resized_spec.lua make functionaltest`
- Build with PUC Lua:
  `make CMAKE_EXTRA_FLAGS="-DPREFER_LUA=ON" DEPS_CMAKE_FLAGS="-DUSE_BUNDLED_LUAJIT=OFF -DUSE_BUNDLED_LUA=ON"`
  - Delete .deps and build, build with this, then tests will run with PUC Lua

## Cmds

luajit -bl input.lua output.txt # Dump bytecode

## How-tos

- https://neo451.github.io/blog/posts/in-process-lsp-guide/
  * vim.pack buffers do this as well

## Other Info

- https://gitspartv.github.io/LuaJIT-Benchmarks/
- At least in the case of the vim.pack in-process LSP, while it does use callbacks, it is not true async. This can cause timing issues with co-routines since the in-process callbacks fire earlier than ususual. Example: https://github.com/ibhagwan/fzf-lua/issues/2654

## Dot Files

- https://github.com/folke/dot/tree/master/nvim
- https://github.com/stevearc/dotfiles/tree/master/.config/nvim
- https://github.com/b0o/nvim-conf/tree/main
- https://nvim-mini.org/MiniMax/configs/nvim-0.11/
