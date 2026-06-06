Full-featured Vimdoc generator for LuaCATs annotations. Simply run it with a list of
files to get properly tagged and formatted docs.

Supports the following features:
  - Help tags are automatically generated based on the directory structure of the target files
  - `@tag` annotations for defining additional helptags
  - `@inlinedoc` and `@nodoc` to control display
  - Automatic table of contents generation
  - Descriptive text is parsed as markdown and automatically formatted, including line
    wrapping
  - `@deprecated` tags allow for a one-line description
  - Optional output logging
  - Async file read

## Requirements

Neovim built with LuaJIT. Supported versions:
- Nightly
- Current (`0.12`) and previous release (`0.11`)

## Installation

Clone the repo.

## CI Usage

## Attribution

This is a fork of the Neovim core's doc generator. Accordingly, this project is also released
under an Apache 2.0 license, with notices in the files containing modified core code.
