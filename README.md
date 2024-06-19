# Neovim Config Using Lazy (Windows 10 Compatible)

- [Neovim Config Using Lazy (Windows 10 Compatible)](#neovim-config-using-lazy-windows-10-compatible)
  - [Notes](#notes)
  - [Git Installation Notes](#git-installation-notes)
  - [Visual Studio Build Utils (Windows Specific)](#visual-studio-build-utils-windows-specific)
    - [Lua Language Server](#lua-language-server)
    - [pylsp (Windows Specific)](#pylsp-windows-specific)
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

##### Lua Language Server

- Go to the lua_ls releases page and download the latest zipped copy for Windows: https://github.com/LuaLS/lua-language-server/releases

- Unzip the file to your desired location

- The executable is located in the bin folder. Create a PATH variable pointing to it

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

##### Marksman

- Download the latest marksman.exe file from the repo's releases page, placing it in your location of choice: https://github.com/artempyanykh/marksman/releases

- Create a PATH variable pointing to its location

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
