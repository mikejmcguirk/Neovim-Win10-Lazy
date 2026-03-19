## TODO:

- [ ] Beforehand
  - [ ] Finish farsight, then fix rancher and lampshade
  - [ ] Research todo-comments
    - To help better understand the full scope of the problem
    - Are there other similar plugins?
  - [ ] Research https://github.com/spywhere/vscode-mark-jump

- [ ] Init Module
  - [ ] Module structure
    - [ ] Research how other plugins handle config table merging and verification

    - [ ] `require("annotator").config` should provide a publicly available table
      - When metatable support is added to vim.g and vim.b variables, this will reduce the friction of transitioning
      - For table options, the user should be able to directly extend them, rather than getting a copy of the option, extending it, then writing the new table back

      - [ ] The config table should have a metatable that validates changes
        - [ ] If an edit is made to a specific config field, it should be validated
          - [ ] This needs to handle overwriting values/refs as well as extending tables
        - [ ] If the arg to config is a new table, it should be merged into the current config with validation

      - [ ] `checkhealth` should be able to verify that the config table is in a valid state

    - [ ] `default_config` should be stored separately and privately
      - [ ] `get_default_config` should be available to get a deep copy of it
      - [ ] `reset_config` should be available to go back to defaults

    - [ ] Then also have buf_config[buf], guarded by a metatable
      - Each buf_config key overwrites the default, including with tables
      - If a buf_config table or key is not present, the global config is used
      - When running functions, buf_config should be checked first

  - [ ] Options
    * [ ] If `cms` cannot be found for a buffer, optionally treat MARK as a relaxed annotation
    * [ ] Set default maps?
    * [ ] Relaxed annotations
      * This is fine because, if the user wants to do something like swapping "PEFF" for "PERFORMANCE" it should be easily accessible.
    * [ ] Strict annotations
      * I'm less sure about this because this option should not be edited frivolously, but if you have an annotation you want to assign by filetype, you should be able to set the opt with an autocmd rather than having to remake the keymap
    * [ ] Setup integrations
      * I'm assuming you would need to check the integrations for stuff like grep settings. But if this ends up just being whether or not to make the Plug mappings, the option can be `setup_integration_plugs` or something

  - [ ] All public APIs should be run through this module, so you can always do `require("annotator").foo()`
    - [ ] All defaults should then use the public APIs, to avoid complexity when dealing with how direct calling private modules differs from using the public interfaces

- [ ] Plug mappings

  - [ ] Assigned by default
    - [ ] Navigate strict annotations `[k,]k`
    - [ ] Navigate to first/last strict annotation `[K, ]K`

  - [ ] Not assigned by default
    - [ ] Navigate relaxed annotations
    - [ ] Add borders
    - [ ] Add MARK
    - [ ] Add TODO
    - [ ] Add PERF
    - [ ] Look at todo-comments and others for any sensible plugs to add here

  - [ ] Integrations (not assigned by default)
    - [ ] Fzf-lua grep strict cur buf
    - [ ] Fzf-lua grep strict cwd
    - [ ] Telescope grep strict cur buf
    - [ ] Telescope grep strict cwd
    - [ ] snacks grep strict cur buf
    - [ ] snacks grep strict cwd
    - [ ] rancher grep strict cur buf
    - [ ] rancher grep strict cwd
    - [ ] Fzf-lua grep relaxed cur buf
    - [ ] Fzf-lua grep relaxed cwd
    - [ ] Telescope grep relaxed cur buf
    - [ ] Telescope grep relaxed cwd
    - [ ] snacks grep relaxed cur buf
    - [ ] snacks grep relaxed cwd
    - [ ] rancher grep relaxed cur buf
    - [ ] rancher grep relaxed cwd

- [ ] Polish
  - [ ] Add `desc` values to Plug and default mappings
  - [ ] Verify that the `require("annotator")` call in /plugin.lua does not require other files

## DOCUMENT:

- [ ] Strict vs. Relaxed matching
  * Strict: Looks for exact semantics and tolerates false negatives
    + [ ] Requires a `commentstring` value to be present
    + [ ] When searching unloaded buffers, if `cms` cannot be found using `vim.filetype.get_option()`, results from the buffer will be discarded
  * Relaxed: Only looks for if the annotation is in a comment. Tolerates false positives
    + [ ] When searching unloaded buffers, all results containing the annotation are accepted

+ [ ] For any annotations the user adds or deletes, they should be able to do so without the colon

## MID:

## LOW:

## PR:

- [ ] For vanilla Vim - Change the vim.vim ftplugin `cms` to `" %s`
  - Their code uses this format
  - This would fit the recommendation from the Vim documentation
  - [ ] Check if this formatting is to address a complexity I'm not aware of
    - For example, not misinterpreting double-quoted strings in command contexts

## NON:

- Don't ship a built-in external finder interface. Multiple other plugins address this problem
- Don't identify strict annotations based on the surrounding TS structure
  * This would create inconsistencies when reading results from unloaded buffers
