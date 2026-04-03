## Overall

#### TODO:

- [ ] Do I have the README store locally on both machines? Shows unpushed on laptop.
- [ ] Make sure everything has vim.validate in the params. It is easier for the user to remove than add them
  - Exceptions:
    - Validation functions (since they are, themselves, validators)

#### FUTURE:

- [ ] When https://github.com/neovim/neovim/issues/38420 releases, update everything to use it. Targets:
  * [ ] Option changes using misc.append_if_missing

## Config

#### TODO:

- [ ] Type annotate everything properly since Lua_Ls doesn't auto-detect them.
  - [ ] Including fields in both metatables
  - [ ] Make them class exact? Unsure if I want to double-define the self methods though
- [ ] Use this module as the template example for the docgen
  - [ ] Make sure metatable class documentation is correct

#### DOCUMENT:

- [ ] Invalid buf_ids in buf_config hard error
- [ ] The main config does not allow setting nil and does not allow for niling itself out. The buf configs do allow this
- [ ] Explicitly setting a buf config to nil clears it

#### MID:

- [ ] When :file or :saveas is used to change the name of a buffer, the new buffer inherits the original buf_id, and the old file/filename are given a new buffer number. It could be interesting to use some sort of logic to make sure that the old buffer id is given a copy of the new file/old buffer id's buf_config.
  - Counterpoint: Since I don't want to have config for config, adding the above behavior means the user is locked into it if they don't want to be, whereas, if this is not default behavior, the user can opt into it themselves if they want to.
- [ ] It would be good if buf_configs were pro-actively managed to remove nil configs.
  - The problem is I don't know where to do it except on read, which slows down something that is presumably performance dependent
  - Maybe use vim.schedule?

#### LOW:

- [ ] Is it possible to have a Root_Proxy that solely contains the __call method?
  - Problems: Both the __call method itself as well as __newindex rely on being able to use __call recursively
- [ ] Is it possible to put proxies on the non-config sub-tables in a way that (a) isn't contrived and (b) doesn't hurt PERF.
- [ ] In Buf config, when doing an __index, it is theoretically possible to check if the config has no values and nil it out if not. But since reads are performed during user operations, we do not want to take a detour to free memory (slow, and potentially triggers garbage collection).
- [ ] It might be faster, for deleting autocmds, to check a cache for the group id rather than re-constructing the name string. I'm not sure this matters enough to justify maintaining the state.
  - [ ] Counterpoint: This also might matter for __newindex, meaning we're saving more perf
    - [ ] Counter-counterpoint: I think it's a mistake to make too many assumptions about state and how state is built

#### FUTURE:

- When g/b variables are able to store metatables, in order to handle pre-init user configs, the config module should first create the default config, then use its __call metamethod on the pre-existing g/b variables to bring in the meta-data.

#### MAYBE:

###### Buf Config

- Allow non-integer datatypes for the key in __newindex. At least for now, I would prefer as many guardrails as possible around this metatable, since it deals with recursive behavior.
- Provide a return value in __newindex so you can get a quick indicator of what happened.
  * The underlying table state change could be nil > nil, value > nil, nil > value, value > new_value. Depending on the input, the different nil state changes could be intended or un-intended.
    + Given that, would rather hold on this idea until a concrete use case.
- In theory, you could have a function like create_from_default() that creates a buf_config from the default. There might be other ideas about initialize buf configs. But as of right now, I think the current tools are sufficiently composable.

#### NON:

- If the filename is changed using `:file` or `:saveas`, do not use an autocmd to copy the config to the new buf-id/old file. Because I don't want to have config for config, this locks the user into a behavior they might not want (it is theoretically possible for the user to delete the autocmd group, but this is contrived and touchy). As is currently the case, the user can add this behavior if they want.
- Similarly, be cautious about adding new automatic config delete conditions. If the user, say, wants to add BufDelete, they can make their own autocmd.
- Don't auto-create new buf_configs if you __index into a nil buf_config
  * Actual Lua tables don't behave this way, so it's an anti-pattern
  * This behavior would then require a bespoke accessor function to check if a config exists and is not empty before actually reading the value(s) from it
  * Correctly handling "gc" for empty buf configs is tricky. Don't want to introduce conditions under which tables can be needlessly created

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
