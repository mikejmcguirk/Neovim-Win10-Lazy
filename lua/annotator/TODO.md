## TODO:

- [ ] Config
  - [ ] Module structure
    - [ ] Research how other plugins handle config table merging and verification
    - [ ] `require("annotator").config` should provide a publicly available table
      - When metatable support is added to vim.g and vim.b variables, this will reduce the friction of transitioning
      - For table options, the user should be able to directly extend them, rather than getting a copy of the option, extending it, then writing the new table back
      - [ ] The config table should have a metatable that validates changes
        - [ ] The metatable needs to be able to handle both direct value changes as well as edits to list values
      - [ ] `checkhealth` should be able to verify that the config table is in a valid state
    - [ ] `default_config` should be stored separately and privately
      - [ ] `get_default_config` should be available to get a deep copy of it
    - [ ] Both config and default_config should use the same `@class`

  - [ ] Options
    * [ ] If `cms` cannot be found for a buffer, optionally treat MARK as a relaxed annotation

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
