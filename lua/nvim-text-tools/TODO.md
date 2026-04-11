## General

#### TODO:

- [ ] When creating/deleting checkboxes, the cursor should be shifted the same amount the overall line is

- [ ] This is, fundamentally, a combination of bullets and check boxes. But because I haven't though at all about how the bullets programming would be done, and haven't looked deeply into the check box programming, I'm not sure where the conceptual and technical lines between the two are.

- [ ] Create a text object that selects the line excluding the bullet and check box
  - `vi-`
- [ ] `vi-` and `va` should perform list navigation similar to treesitter incremental selection
  - [ ] `vi-` from normal mode should select the current line sans the bullet and checkbox
  - [ ] `va-` would then expand to higher list levels, with `vi-` going down a list level
  - [ ] `[-` and `]-` would move between siblings
    - [ ] Do `[_` and `]_` work for grow selection?
  - [ ] It would be interesting if treesitter were used to do this
    - It also might be easier/more principled

- [ ] Should my `i_` and `a_` text objects be included here?
  - It feels like they could be migrated if a better place were found for them
    * This idea also feels fundamentally goofy
