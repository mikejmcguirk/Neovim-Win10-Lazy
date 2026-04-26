- For plugins that grep:
  * Only support rg out of the box
  * Provide interfaces for other grepprgs/plugins
    + fzf-lua
    + telescope
    + snacks
    + Future grep plugin

- In any case where it's logical for an option to control plugin behavior, it should do so, at least by default
  * The function's opts table should also provide a method for overriding the default option
    * The method should be appropriate based on the option
      + For fdo, a simple boolean can be provided
      + If overriding swb, an alternative option value would need to be provided

- Plug maps should fall into two categories:
  * "Main" Plug maps
    + These represent the default and most prominently advertised behavior of the plugin
    + Main Plug maps should never contain opts that override config. Because any API should check against config, default behavior should therefore be set in config
    + Because config and the APIs should already be documented, Plug documentation should only need to be minimal
      + Counterpoint: It should be possible for the user to understand the fundamentals of what the Plug does without having to look in other places
  * "Alt" Plug maps
    + These provide some kind of desirable, but non-default behavior out of the box
    + These mappings can override config
    + The differences from the defaults should be documented

- When designing interfaces, Neovim's patterns should be respected, its limitations not so much
  * Example: When Neovim's internal functions are used in mappings, fdo is ignored. This is so users can implement their own behavior
    + The more principled solution would be for respect_fdo or something like that to be a maparg
    + I had previously tried to implement this behavior by putting fdo handling into the default on_jump callback function. This was a bad idea
    + While jump behavior should use the fdo option (or a user-override), it adds friction to pocket it within the callback

+ Set pcmark behaviors:
  + Never set pcmark
  + Set pcmark if we go past w0 or w$
  + Set pcmark if we change lines
  + Always set pcmark
