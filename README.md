# Neovim Config Using Lazy (Windows 10 Compatible)

- [Neovim Config Using Lazy (Windows 10 Compatible)](#neovim-config-using-lazy-windows-10-compatible)
  - [Notes](#notes)
  - [Git Installation Notes](#git-installation-notes)
  - [Visual Studio Build Utils (Windows Specific)](#visual-studio-build-utils-windows-specific)
    - [Node Installation for JavaScript and Copilot (Windows Specific)](#node-installation-for-javascript-and-copilot-windows-specific)
    - [Install JavaScript LSP Stack](#install-javascript-lsp-stack)
    - [Docker LSP](#docker-lsp)
    - [Lua Language Server](#lua-language-server)
    - [pylsp (Windows Specific)](#pylsp-windows-specific)
    - [OmniSharp](#omnisharp)
    - [rust-analyzer and taplo](#rust-analyzer-and-taplo)
    - [Marksman](#marksman)
  - [Other Setup Notes](#other-setup-notes)
  - [Windows Terminal Notes](#windows-terminal-notes)

### Notes

- Uses system environment variables (see global_env.lua) for machine-specific settings
- When installing on Windows, avoid running as Administrator or using an elevated terminal if possible (accepting UAC prompts is still fine). If the nvim-data files have mixed ownership, permissions conflicts might cause plugins to fail

### Git Installation Notes

- When installing Git for Windows, depending on how your computer's environment is configured (e.g. a managed business network), you might need to bind Git to Windows's SSL tools rather than using OpenSSL

- If, when using Git, you see issues with verifying SSL keys, check how Git's SSL is configured first. Git can be switched from OpenSSL to Windows SSL by re-running the installer and changing the installation

### Visual Studio Build Utils (Windows Specific)

- To install the Telescope fzf extension and rustup, you need the Visual Studio C++ Build Tools installed

- This can be done either by installing Visual Studio or the build tools individually

- To install the build tools individually:

  - Go to: https://visualstudio.microsoft.com/visual-cpp-build-tools/

  - Click the "Download Build Tools" button on the page and open the installer when it's finished downloading

  - In the Visual Studio installer, click "Desktop development with C++". In the right pane of the installer, you should see MSVC, the Windows SDK, and C++ CMake Tools selected for install

  - Click the "Install" button

##### Node Installation for JavaScript and Copilot (Windows Specific)

- Perform a clean install of NVM for Windows as described here: https://github.com/coreybutler/nvm-windows

- Install Node and npm using <code>nvm install lts</code>

- Type <code>nvm list</code> and find the latest installed LTS node.js version

- Type <code>nvm use [version_number]</code> to point the %NVM_SYMLINK% path to the proper Node installation

- Update npm by typing <code>npm i -g npm</code>

- The highest version of Node.js that Copilot is guaranteed to be compatible with is 16.15.0 (see the g:copilot_node_command entry in the copilot readme)

- Install it with <code>nvm install 16.15.0</code>

- For this config, create an environment variable called <code>NvimCopilotNode</code> containing the fully-qualified name of your v16.15.0 node.exe file

  - If this is not set, Copilot will look for the default Node path if it exists. Versions above v16.15.0 are not guaranteed to be supported

- For this config, Copilot can be disabled by creating an environment variable called <code>DisableCopilot</code> and setting it to <code>true</code>

##### Install JavaScript LSP Stack

- This config opts for global installation where possible. This is to ensure a fallback is always present if <code>eslint --init</code> has not been run

- Run these installation commands below in the order listed:

  - <code>npm i -g typescript-language-server typescript</code>

    - tsserver should then work with the provided lsp config. It will operate in single file mode unless a jsconfig.json file is present

  - <code>npm i -g eslint</code>

  - <code>npm i -g vscode-langservers-extracted</code>

    - Because ESLint is installed globally, the ESLint LSP should be able to interface with it once a .eslintrc file is in your project directory. It should still work after running <code>eslint --init</code>

  - <code>npm install -g --save-dev prettier</code>

  - This config uses conform.nvim to interface with prettier, with the intention of avoiding ESLint for formatting

  - To handle contradictory rules between ESLint and prettier:

    - In the root directory of your project (global install does not work), run: <code>npm install --save-dev eslint-config-prettier</code>

    - The eslint-config-prettier repo describes how to configure and check your .eslintrc files to use it

    - To test that it's properly installed for your project, run <code>npx eslint-config-prettier main.js</code>. If you get an error that the prettier config is missing, eslint-config-prettier is not properly installed

##### Docker LSP

- Install the Docker Language server with <code>npm install -g dockerfile-language-server-nodejs</code>

- Run the following in your JS project to add the components:
  <code><pre>
  npm install dockerfile-ast
  npm install dockerfile-language-service
  npm install dockerfile-utils
  </pre></code>

##### Lua Language Server

- Go to the lua_ls releases page and download the latest zipped copy for Windows: https://github.com/LuaLS/lua-language-server/releases

- Unzip the file to your desired location

- The executable is located in the bin folder. Create a PATH variable pointing to it

- This config uses the nvim-lspconfig boilerplate for checking the project workspace. If neither a .luarc.json nor a .luarc.jsonc file are found, the Neovim runtime files will be loaded

##### pylsp (Windows Specific)

- Install Python using the executable from the org's official website

- Windows might have pre-placed Python files already in C:\Users\\%username%\AppData\Local\Microsoft\WindowsApps. These files and their associated paths can interfere with your Python installation

  - To check for these, search for "app execution aliases" in the task bar and open "Manage app execution aliases"

  - If you see any aliases related to Python or Python 3, deselect them

- Check that pip and wheel are installed by typing <code>pip</code> and <code>wheel</code> into the terminal without options

- If either of them are missing:

  - Place the following script into your Python install directory and run it: https://bootstrap.pypa.io/get-pip.py

  - The script's output should confirm that pip and wheel were installed

  - If the output warns that pip and/or wheel were not added to PATH, manually add them

    - It might also be possible that there are conflicting paths to pip and wheel in your environment variables. If those are present, remove the incorrect paths

  - If you get an SSL error when installing pip/wheel:

    - Run this command instead to install them: <code>py get-pip.py --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org</code>

    - Get the filepaths pip looks at for configuration using this command: <code>pip config -v list</code>

    - In one of the listed directories, make a pip.ini file containing the following:
      <code><pre>[global]
      trusted-host = pypi.python.org
      &nbsp;&nbsp;&nbsp;&nbsp;pypi.python.org
      &nbsp;&nbsp;&nbsp;&nbsp;files.pythonhosted.org</pre></code>

    - Note that this does not fix the underlying issue of Python being unable to bind property to an SSL utility, and is merely a workaround

- Install pylsp by running <code>pip install python-lsp-server[all]</code> (the [all] syntax will install the various libraries and linters that make pylsp function as an LSP would be expected to)

- Confirm that pylsp is installed by running <code>pylsp --help</code>

##### OmniSharp

- Go to the OmniSharp releases page: https://github.com/OmniSharp/omnisharp-roslyn/releases

- Under the latest version, look for the Windows file targeted for your processor type with a .NET version in the file name. The files without .NET versions do not contain the .dll file that interfaces with Neovim. Do not download a file with http in the name (Neovim uses JSON for its LSP interface)

- Unzip the file contents to your desired location

- By default, Omnisharp cannot decompile .NET's built-in binaries. This is handled using the OmniSharp-Extended LSP plugin

- To configure the OmniSharp-Extended LSP, create an omnisharp.json file in the same folder as your OmniSharp.dll file. Paste in the following:
  <code><pre>{
  &nbsp;&nbsp;"RoslynExtensionsOptions": {
  &nbsp;&nbsp;&nbsp;&nbsp;"enableDecompilationSupport": true
  &nbsp;&nbsp;}
  }
  </pre></code>

- For this config, create an <code>OmniSharpDLL</code> system environment variable containing the fully-qualified name of your OmniSharp.dll file. If this is not present, OmniSharp will fail to attach

- If the LSP still fails to attach, try typing <code>dotnet</code> in your command line without options to make sure it's available

##### rust-analyzer and taplo

- Download <code>rustup-init.exe</code> from <code>rustup.rs</code>. Run the file to install rustup

  - This will also install clippy and RustFmt

- Once rustup is installed, run the following to install rust-analyzer: <code>rustup component add rust-analyzer</code>

- To install taplo: <code>cargo install --features lsp --locked taplo-cli</code>

- clippy is configured to run on save

- RustFmt is handled using Neovim's built-in command. It uses the rust.vim plugin to interface with the installed copy of RustFmt

- This config has all cargo features enabled for rust-analyzer

##### Marksman

- Download the latest marksman.exe file from the repo's releases page, placing it in your location of choice: https://github.com/artempyanykh/marksman/releases

- Create a PATH variable pointing to its location

- conform.nvim + prettier is used for formatting Markdown. Marksman does not contain a built-in formatter

### Other Setup Notes

- For Telescope, ripgrep is required for certain functions and fd is recommended

  - Their GitHub repos contain compiled binaries

  - After placing them on your computer, update your PATH. They should then be recognized by Telescope

- To be able to install the Telescope fzf extension, install CMake using the Windows binary distribution

- In this config, Undotree's path is setup using Windows's built-in home directory path + "\\AppData\\local\\nvim\"

- Using Neovim or configuring Undotree through a symlink is not recommended. This can cause inconsistent behavior with whether the undo histories are renamed based on their symlink path or absolute path

- For this config, a "MainBrowser" environment variable can be created containing the fully-qualified name of the Browser you want Markdown Preview to use. If this variable does not exist, Markdown Preview will attempt to use your default browser

- By default, this config uses the Fluoromachine "delta" theme. This can be changed by creating an "NvimTheme" environment variable. Set to "blue" to use a custom blue theme or "green" to use zenburn

- To use Zig as an alternative compiler for Treesitter:

  - Download and unzip Zig to your preferred directory. Create a Windows PATH to the zig.exe

  - Delete any Treesitter parser data already present

  - Set <code>require('nvim-treesitter.install').compilers = { "zig" }</code> above the default <code>require('nvim-treesitter.configs').setup</code> line

  - Restart Neovim and see if the parsers try re-installing

### Windows Terminal Notes

- Installing through Windows Store is easiest. Windows Terminal will be set to be your default terminal and Windows Store will automatically check for updates

  - Alternatively, the project's GitHub repo contains manual installation instructions

- Windows Terminal uses shift to override the mouse settings of the program running in the terminal Window. It does not currently have an option to disable this

  - Otherwise, this config enables the mouse in Neovim then uses keymaps to disable the various controls, limiting mouse functionality only to Windows Terminal overrides

- By default, Windows Terminal binds ctrl+v to Paste, overwriting Visual Block Mode. This binding can be removed in Windows Terminal's settings in favor of an alternative like ctrl+shift+v

  - By default, Neovim also binds ctrl+q to enter Visual Block Mode. If needed, the keymap to disable this can be removed

- A nerd font is required for viewing symbols (https://www.nerdfonts.com/)

- After installing your font of choice, restart Windows Terminal then go to Settings to select it. Otherwise, the font will show as available but not actually be recognized

- The appearance of Neovim in Windows Terminal is affected by the font size, padding, and if the scroll bar is enabled

  - To most easily see the difference between Neovim itself and Windows Terminal's padding, set Windows Terminal and Neovim to have different backgrounds

- The guicursor style configs work in Windows Terminal. However, any highlight settings are overwritten by Windows Terminal's cursor color settings, so no highlight configs are present here

- This config might not work properly in the GUI or a different terminal environment
