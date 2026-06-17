TODO: Need a version of union that works as a list filter thing. Union doesn't work here because Union keeps elements from `t1` if they are only in `t1`. Whereas here we need to see if it's in at least one of the vararg lists.

## M.difference

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

## M.difference_to

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.intersect

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.intersect_to

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.intersection

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.intersection_to

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.subtract

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.subtract_to

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.all

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.any

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.cmp

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.common_prefix

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.consistent

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.contains

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.diverse

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.every

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.excluded

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.find

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.indices

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.locate

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.max

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.min

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.none

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.one

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.only

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.position

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.positions

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.same

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.seek

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.select

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.selectors

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.uniform

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.fold

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.fold2

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.reduce

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.scan

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.combine

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.fill

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.filter_map

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.filter_map_to

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.filter_map_accum

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.group_by

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.transduce

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.filter_map_two

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.filter_map_two_to

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.intersperse

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.intersperse_to

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.merge_to

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.reverse

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.reverse_to

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.rotate

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.rotate_to

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.zip

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.zip_longest

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.zip_with

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.

## M.cycle

- [ ] Categorization

  - [ ] Is the function in the right category?
  - [ ] Should it be removed because it's a subset of something else?
    - [ ] Does the proper superset function need to be created?
      - [ ] If so, add the proper checklist
  - [ ] Do additional complementary logic types need to be created?
    - [ ] If so, add the proper checklist
  - [ ] Make sure everything is in its proper categorization. Make new ones if needed
    * Example: find/position need to be taken out of eval

- [ ] Other Factoring

  - [ ] Remove:
    - Basically continuing my work with fold and the like.
    - [ ] Extra error returns
    - [ ] Extra params
    - [ ] Extra strategy function params
    - [ ] Extra strategy function returns

  - [ ] Inline trivial functionality
  - [ ] Remove schroedingery helper logic
  - [ ] Specific logic for len zero lists.
    - [ ] Should match the function's "type"
        * Example: Different types of eval functions should have consistent boolean returns.
        * Example: nil vs. empty table

  - [ ] Outline nontrivial, common functionality
    * Example: Cases like "merge_sorted do".
    * Exception: Cases like clear. Self-reference is fine if it's pre-existent and doesn't add non-trivial overhead

  - [ ] Formatting/naming
    - [ ] `v` params should be `val`.
    - [ ] Replace `return nil` with `return`.
    - [ ] The returns on zero lists should be consistent with the function's "type"
    - [ ] Favor type consistency.
      * Exception, for something like locate or position, it is better to return nil than zero idx, because the latter would be un-idiomatic for Lua.
    - [ ] If the function makes a new table:
      - [ ] `_to` naming
      - [ ] Verify no write to t (no side effects)

  - [ ] The copy() trick should never be intended behavior. Make sure every in place function has a new list counterpart.

- [ ] Docs

  - [ ] Proper top-level description
    - [ ] If a values are copied, note that they are shallow-copied.
  - [ ] Proper variable documentation
    - [ ] Add a `see` note for variables that use |iter-indexing|.
    - [ ] If modified in place, needs `Modified in place!`.
    - [ ] Is spacing consistent in fun() types?
    - [ ] If returning a self-reference, document that that.
  - [ ] Proper generic usage
    - [ ] In-place modifiers should have the same return type
      - Because static analyzers don't pick up on the changes + bad practice in general
    - [ ] If multiple lists, are they the same or multiple types?

  - [ ] At least one usage example
  - [ ] Reference other relevant functions

  - [ ] Are type formats consistent?
    - Example: `key_fn` should look the same everywhere it's used
  - [ ] Is `|lua-list|` used?
  - [ ] Do params, var names, and types use back ticks?

  - [ ] Proper formatting for what docgen *should* do.
