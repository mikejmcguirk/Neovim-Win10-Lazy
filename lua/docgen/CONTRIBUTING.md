## Function Contracts

- Parser Object Module
  * `get_fmt` functions:
    + Must not contain trailing whitespace
    + Leading whitespace must be intended (such as bulleted lists within description text)
    + Must not contain trailing or leading newlines
    + Must not change module or instance table data
    + Must not handle indenting
    + Groups of items, like function params or fields, must be returned as lists so the caller can handle rendering
    + For returns with newline characters:
      + Must not contain trailing or leading newlines
      + Line breaks within the string must be only one or two newlines
      + Line breaks must be intentional and correct

+ Renderer Module:
  + No trailing whitespace
  + Leading whitespace must be correct
  + Functions must not partly-perform some aspect of the rendering process.
    + Example: If a function performs indenting, it must expect that the input data has not been indented, and it must expect that the caller will not perform further indenting
  + Must not change the Parser Object's internals

+ TS Parsing Module:
  + Do not handle indenting
  + No trailing whitespace
  + Leading whitespace must be intentional
  + For returns with newline characters:
    + Must not contain trailing or leading newlines
    + Line breaks within the string must be only one or two newlines
    + Line breaks must be intentional and correct
  + Returns must be strings
  + Input data must not be changed, only re-formatted or discarded
    + Exception, converting bullet point characters

+ Util Module
  + Should be pure or close to pure functions
    + No side effects
    + If a parameter is edited in place, the only return should be a status indicator or a copy of the reference to the edited param.

## Guidelines

- When building strings, manually inserting newlines should be avoided. This makes it harder to reason about the string's intended layout by looking at the final table.concat() call.
- Calls to wrap() should not be performed recursively.

## References

- https://github.com/neovim/tree-sitter-vimdoc
- https://neovim.io/doc/user/helphelp/#help-writing
- https://github.com/nanotee/vimdoc-notes
- Runtime files for the "help" filetype
