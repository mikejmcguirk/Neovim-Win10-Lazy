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

## Guidelines

- Never interact with the Parser Object's internals outside its module
  * Exception: Reading the data from its provided iterators such as fields, params, or returns
- Within the Parser Object module, use direct access for simple reads and writes. Build interfaces for tasks that involve logic
- Prefer using table.concat by newline for function returns. This imposes a performance cost in intermediate concatenation, but creates simpler assumptions for callers
