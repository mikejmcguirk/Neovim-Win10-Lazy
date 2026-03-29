## Overall

- [ ] Make sure everything has vim.validate in the params. It is easier for the user to remove than add them
  - Exceptions:
    - Validation functions (since they are, themselves, validators)

#### FUTURE:

- [ ] When https://github.com/neovim/neovim/issues/38420 releases, update everything to use it. Targets:
  * [ ] Option changes using misc.append_if_missing

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
