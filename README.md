# Windows 10 Neovim Config Using Lazy

### Objectives

This config aims to accomplish the following:

- Use System Environment variables for configuration on individual machines, allowing the config files themselves to be consistent and Git-controlled from machine to machine
- Once environment variables and LSPs are configured, the config files can be dropped into the nvim config folder, and Neovim will startup with the proper settings, install plugins, and be ready to go with no tinkering required
- Use Lazy loading to minimize startup time

### Environment Variables

This config uses user-defined environment variables for the following:

- Pointing to the OmniSharp.dll file (required for OmniSharp to attach)
- (Optional) Pointing to the Node.exe file used by copilot (default Node installation will be used otherwise)
- (Optional) Pointing to the browser used by Markdown Preview
- (Optional) Disabling copilot
- (Optional) Setting the colorscheme

If any of these variables are missing, it should still be possible to clone this config and start it without issue. But you will experience problems when trying to use the plugins that depend on those variables.

Information on how to set these variables up is provided below in the relevant sections

<!-- Table of contents here -->

### General Installation Notes

- Avoid performing any of these steps as Administrator or using an elevated terminal if possible (accepting UAC prompts is still fine). If the nvim-data files have mixed ownership, permissions conflicts might cause plugins to fail

### Git Installation Notes

- When installing Git for Windows, depending on how your computer's environment is configured (e.g. a managed business network), you might need to bind Git to Windows's SSL tools rather than using OpenSSL

- If, when using Git, you see issues with verifying SSL keys, check how Git's SSL is configured first. Git can be switched from OpenSSL to Windows SSL by re-running the installer and changing the installation

### LSP Installation and Notes

This config assumes that the LSPs are manually installed rather than using Mason. While the upfront cost of this is higher, it allows for more flexibility in configuration and troubleshooting.

Instructions for installing the LSPs are below:

<i><u>Note:</u> If these instructions are out-of-date, the most up-to-date instructions can be found at the <a href="https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md">lspconfigs documentation</a> or at the repos for the LSPs themselves</i>

##### Node.js Installation (for Javascript and Copilot)

- Perform a clean install of nvm for Windows as described here: https://github.com/coreybutler/nvm-windows

- Install Node and npm using <code>nvm install lts</code>

- Type <code>nvm list</code> and find the latest installed LTS node.js version

- Type <code>nvm use [version_number]</code> to point the %NVM_SYMLINK% path to the proper node.js installation

- Update npm by typing <code>npm i -g npm</code>

- The highest version of Node.js that copilot is guaranteed to be compatible with is 16.15.0 (see the g:copilot_node_command entry in the copilot readme).

- Install it with <code>nvm install 16.15.0</code>

- For this config, create an environment variable called <code>NvimCopilotNode</code> containing the fully-qualified name of your v16.15.0 node.exe file. If this is not set, copilot will look for a default Node path if it exists. Versions above v16.15.0 are not guaranteed to be supported

- For this config, copilot can be disabled by creating an environment variable called <code>DisableCopilot</code> and setting it to <code>true</code>

##### tsserver/ESLint/prettier

- This config opts for global installation where possible. This is to ensure a fallback is always present for the eslint LSP if <code>eslint --init</code> has not been run

- Run the following installation commands (being sure to include the -g flags) in the order listed:

  - <code>npm i -g npm install -g typescript-language-server typescript</code>

    - tsserver should then work with the provided lsp config. It will operate in single file mode unless a jsconfig.json file is present

  - <code>npm i -g eslint</code>

  - <code>npm i -g vscode-langservers-extracted</code>

    - Because ESLint is installed globally, the eslint langserver should be able to interface with it once a .eslintrc file is in your directory. It should still work after running eslint --init

  - <code>npm install -g --save-dev prettier</code>

  - This config uses ALE to interface with Prettier, with the intention of avoiding using ESLint for formatting. To test that the ESLint LSP and prettier are both working:

    - Create a Javascript project where the .eslintrc file is configured to error on single-quoted strings

    - Write a snippet of Javascript code with double quoted strings. The ESLint LSP should product a diagnostic error due to the double-quoted strings

    - Write the file, you should see the strings be changed to single-quoted due to EslintFixAll being run. But, because prettier is configured for double-quoted strings by default, the automated ALEFix command should then change the strings back to double-quoted

    - To troubleshoot, try running eslint and prettier directly from the command line to make sure they respond

  - To handle contradictory rules between eslint and prettier:

    - In the root directory of your project (global install does not work), run: <code>npm install --save-dev eslint-config-prettier</code>

    - The eslint-config-prettier repo describes how to configure and check your .eslintrc files to use it

    - To test that it's properly installed for your project, run <code>npx eslint-config-prettier main.js</code> . If you get an error that the prettier config is missing, eslint-config-prettier is not properly installed

- ALE is used here only for prettier. But by default, ALE will attempt to use any detected plugin on any valid filetype. Therefore, in set.lua, g.ale_linters_explicit is set to 1. Filetypes that use ALEFix on save are then defined either in the LSP config or ftplugin files

  - If the .prettierrc file is invalid, ALEFix will not run. If ALEFix does nothing, run prettier from the command line to see if if outputs any config errors

##### lua_ls

- Go to the lua_ls releases page and download the latest zipped copy for Windows: https://github.com/LuaLS/lua-language-server/releases

- Unzip the file to your desired location

- The executable is located in the bin folder. Create a PATH variable pointing to it

- This config pulls in all Vim runtime files in all projects. For non-Vim work, the appropriate line in lsp.lua needs to be commented out

##### pylsp

- Install Python using the installer from the org's official website

- Windows might have pre-placed Python files already in C:\Users\\%username%\AppData\Local\Microsoft\WindowsApps. These files and their associated paths can interfere with your Python installation

  - To check for these, search for "app execution aliases" in the task bar and open "Manage app execution aliases"

  - If you see any aliases related to Python or Python 3, de-select them

- Check that pip and wheel are installed by typing <code>pip</code> and <code>wheel</code> into the terminal without options. If either of them are missing:

  - Place this script into your Python install directory and run it with Python: https://bootstrap.pypa.io/get-pip.py

  - The script's output should confirm that pip and wheel were installed

  - If the output warns that pip and/or wheel are not added to PATH, manually add them

    - It might also be possible that there are conflicting paths to pip and wheel in your environment variables. If those are present, remove the incorrect paths

  - If you get an SSL error when installing pip/wheel:

    - Run this command instead to install them: <code>py get-pip.py --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org</code>

    - Get the filepaths pip looks at for configuration using this command: <code>pip config -v list</code>

    - In one of the listed directories, make a pip.ini file containing the following:
      <code><pre>[global]
      trusted-host = pypi.python.org
      &nbsp;&nbsp;&nbsp;&nbsp;pypi.python.org
      &nbsp;&nbsp;&nbsp;&nbsp;files.pythonhosted.org</pre></code>

- Install pylsp by running <code>pip install python-lsp-server[all]</code> (the [all] syntax will install the various libraries and linters that make pylsp actually functional)

- Confirm that pyslp is installed by running <code>pylsp --help</code>

##### OmniSharp

- Go to the OmniSharp releases page: https://github.com/OmniSharp/omnisharp-roslyn/releases

- Under the latest version, look for the Windows file targeted for your processor type with a .NET version in the filename. The files without .NET versions do not contain the .dll file that interfaces with Neovim. Do not download a file with http in the name (Neovim uses JSON for its LSP interface)

- Unzip the file contents to your desired location

- To allow the OmniSharp-Extensions to work, in the same folder as your OmniSharp.dll file, create an omnisharp.json file containing the following:

  <code><pre>{
  &nbsp;&nbsp;"RoslynExtensionsOptions": {
  &nbsp;&nbsp;&nbsp;&nbsp;"enableDecompilationSupport": true
  &nbsp;&nbsp;}
  }
  </pre></code>

  - The OmniSharp extentens are used for decompiling the .Net libraries. Otherwise, going to definition of built-in .NET libraries is impossible

- For this config, create an <code>OmniSharpDLL</code> system environment variable containing the fully-qualified name of your OmniSharp.dll file. If this is not present, OmniSharp will fail to attach

- If the LSP fails to attach, try typing <code>dotnet</code> in your command line without options to make sure it's available

##### rust-analyzer/taplo

- Download <code>rustup-init.exe</code> from <code>rustup.rs</code>. Run the file to install rustup

  - This will also install clippy and RustFmt

- Once rustup is installed, run the following to install rust-analyzer: <code>rustup component add rust-analyzer</code>

- To install taplo: <code>cargo install --features lsp --locked taplo-cli</code>

- clippy is configured to run on save. Neovim has a built-in RustFmt function that uses the rust.vim plugin to interact with the installed copy of RustFmt

- This config has all cargo features enabled for rust-analyzer

##### Marksman

- Download the latest marksman.exe file from the repo's releases page, placing it in your location of choice: https://github.com/artempyanykh/marksman/releases

- Create a PATH variable pointing to its location

- For this config, a "MainBrowser" environment variable can be created for Markdown Preview containing the fully-qualified name of the Browser you want to use. If this variable does not exist, Markdown Preview will attempt to use your default browser

### Other Setup Notes

- For Telescope, ripgrep is required for certain functions and fd is recommended

  - Their Github repos contain compiled binaries

  - After placing them on your computer, update your PATH. They should then be recognized by Telescope

- To be able to install fzf, just install cmake using the Windows binary distribution

- Treesitter requires a C compiler to be installed and defined in path in order to build. If you do not have one, the easiest solution is to download Zig for Windows, which will automatically install and set paths for the necessary files

- Using nvim or configuring Undotree through a symlink can cause inconsistent behavior with whether Undotree names the file history based on the symlink or the absolute file path. Avoiding symlinks with Neovim is recommended if using Undotree

### Windows Terminal Notes

This config is targeted for Windows Terminal

- Installing through Windows Store is easiest, as the default cmd will be automatically replaced

  - Alternatively, the project's Github repo contains manual installation instructions

- Windows Terminal uses shift to override the mouse settings of the program running in the terminal Window. It does not currently have an option to disable this

- By default, Windows Terminal binds ctrl+v to Paste, overwriting Visual Block Mode. This binding can be removed in Windows Terminal in favor of an alternative like ctrl+shift+v

  - Ctrl+q is also bound by default in Neovim as an equivalent of ctrl+v, but this config has that disabled in keymaps

- A nerd font is required for viewing symbols (https://www.nerdfonts.com/)

- After installing your font of choice, restart Windows Terminal then go to Settings to select it. Otherwise, the font will show as available but not actually be recognized

- The appearance of Neovim in WinTerm is affected by the font size, the padding, and whether or not the scroll bar is enabled. The easiest way to adjust the Windows terminal settings is to set Windows terminal so the background is transluscent (decrease opacity below 100%) and set Neovim to have a solid background. This way you can see where Neovim ends and WinTerm's padding begins

- The guicursor style configs work in Windows Terminal. However, any guihighlight settings are overwritten by Windows Terminal's cursor color settings, so no highlight customization is present here

- This config might not work properly in the GUI or a different terminal environment

### Config Notes

- Does not rely on any pre-build distributions

- Mouse is disabled by enabling it in NeoVim then using keymaps to disable all mouse actions. Except for the WinTerm shift override, the mouse should be non-functional

- Includes fix for Harpoon tabline not highlighting properly on Windows

- In this config, Undotree's path is configured using the native system path for the user's home directory + Neovim's defaul nvim-data path
