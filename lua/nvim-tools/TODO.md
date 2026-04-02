## Overall

- [ ] Make sure everything has vim.validate in the params. It is easier for the user to remove than add them
  - Exceptions:
    - Validation functions (since they are, themselves, validators)

#### FUTURE:

- [ ] When https://github.com/neovim/neovim/issues/38420 releases, update everything to use it. Targets:
  * [ ] Option changes using misc.append_if_missing

## Init

#### TODO:

- [ ] Need to decide how I want the config to render to the user and why.
  - The technical delineations are:
    - For any particular level of the config, do you need to use :get() to get a clean view
      * This needs to be consistent at all levels, including the top level
      * Cannot be different per level like LSP Config, because config is, conceptually, a continuous object, rather than lsp.config, which itself is understood as a container for sub-configs
      * You could, in theory, solve this problem with a "global" config, but that is not appropriate for all plugins (such as lampshade)
      * Also remember that this conceptual answer needs to answer the buf config question
    - The solution here must properly handle the g/b question. You need to be able to plug a metatable into the g/b config tables and have it function the way the config tables do now
      * The solution also needs to work such that, in the g/b configuration, you can load the defaults and the meta into g/b tables and never have to hold them in a config file, meaning those tables don't have to be in a separate file needing a require
        + Why not do that now?
  - And then the conceptual issues are:
    * One view of the config object is that we are representing it to the user as a straight table with validation, even though that is certainly not what the internals are
      + This strikes me as fundamentally deceptive
        + There are two views a user could have of this. One is that they know it's a metatable hack but want the interface to resemble a normal table. The other just wants the metatable part of it out of mind, and is willing to be decieved about it because it gives their brain permission to avoid the question
    * Even if you are more open about the meta-table architecture, it also can't be obtrusive. The user/plugin need to be able to get info cleanly without having to mentally parse through the metatable nonsense
    * Another question relates to hackability. It should be relatively tractable for a user to hack into the plugin if they want. It should not be supported behavior, but it allows for experimentation
    * Clarity. What makes vim.lsp.config work is that accessing the meta structure gives you the meta structure. The individual configs the individual configs
      + Which is why I actually don't like a lot of the wrapper functions being put around it, because it sorta muddies the waters of what is being resolved and when
    * Avoiding redundancy. config() also returning the table is obviously good but confusing
      + lsp.config just errors
    * Setting is one of the biggest conceptualy confusions where it looks like a bare table but doesn't actually act like one
      + Points toward only using call functions to set tbh
  - Possible solution:
    * config() is a validated table merge
    * direct gets are direct gets
    * direct *sets* are also direct sets
    * Reasoning:
      + This makes the architecture much simpler, as all you need is one proxy with an underlying _config table. This makes the proxy mostly a pass-through
      + The result is simpler to read
      + This gets you to "hackability" since you can directly set bad values
        + Would also make testing easier
      + A broad mental model for all of this is basically that, the reason a lot of plugins do config the way they do right now is because they want config to be encapsulated. Preventing direct user editing. By moving to g/b space, encapsulation becomes harder to model since those tables are user space and therefore directly editable. The problem with the current model is that it's getting into both validation and encapsulation, which realistically it can't really do. You can, but it creates confusion. Whereas a simple meta-table is much clearer in terms of what it's trying to do
    * Alternative aspects:
      + Just don't allow direct set by default. If the user/test-runner wants to direct set through _config they can, but just don't allow it through config

## Buf

#### TODO:

- [ ] Add an algorithmic save function
  - [ ] TODO scoped under the presumption that not all corner cases will be covered. Those can be prioritized down
  - [x] Should appropriately handle errors while saving
  - [ ] If there's no file on disk, should that file be created? Or is that an abort?
    - I think the way I have it right now is probably best, in that it should not insist upon itself if the file's not on disk. If/when bcd is added, I think an opt to use that to save to disk would make sense. Add a FUTURE note somewhere
- Canned script for creating a temp-buffer for window and tab opening purposes. See the code I have in vim-dadbod

#### MID:

buf_open improvements:
- [ ] open_buf
  - [ ] do_set_buf options
    - [ ] It should be possible to provide your own post-load, pre filetype options
      - Idea: A callback is provided with buf as a param that's run in the proper window context. You can write your own custom options to set in there. Maybe provide a boolean for if this overwrites or appends to the default behavior
      - More Complex Idea: Do these option sets from a table. Allow the user to specify their own table along with merge behavior or total removal of the default
        * Problem: How do you handle setting opts based on programmatic conditions? You could use some kind of table function arg, but this is starting to sound goofy.
      - [ ] Make sure that ftdetect is handled for buftypes that are non-specific
    - Like the ones that already exist, new options for this function should be layerable and composable, rather than creating new path dependencies

#### LOW:

- [ ] Smarter `open_buf` filetype detection:
  - With help and qf buftypes, the current trade-off is to sacrifice potential nuance in behavior and performance for reliability, both in avoiding filetypedetect and making sure ftlugins are always able to overwrite post-load settings
  - It may be possible, based on the previous buf/win settings, to let one of both of the FileType and filetypedetect events fire
  - This is tough because
    * Vim tracks if ftdetect occurred based on, seemingly, a few different backend settings. I would prefer not to get them and their meanings mixed up
    * `do_ecmd` and `open_buffer` do not have the same behavior. I would need to cross-reference both of them to get the result I'm looking for
    * At least for now, I have yet to see a use case that strengthens the cost/benefit analysis

#### MAYBE:

open_buf
- An opt could be provided for setting the pcmark, but I don't know what the use case is
