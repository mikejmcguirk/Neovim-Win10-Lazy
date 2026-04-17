## Design/Usage Notes

- The functions contained within should be thought of as "reference implementations" of what they are trying to accomplish, moreso than something to be directly used. For hot paths especially, certain parts of particular functions might be better off omitted or outlined. The goal is to show a complete implementation of how something might be implemented, so the irrelevant parts can be cut.

- vim.validate is typically present at the beginning of each function, under the presumption that it is easier to remove if unwanted than to re-add
  * Exception: Functions explicitly designated as validators
  * Note: If possible, functions that call sub-functions that use vim.validate will try to skip adding an extra, unnecessary layer. But this is not guaranteed

- It is not necessarily the case for any particular function in here that it is designed to be the most usable in an applied context. The purpose of the contained functions is to provide the basis on which those applied functions can be created, whatever amount of modification is required.

NOTE: This repository is not intended to be used as a library or dependency. While breaking changes will be labeled in commit titles, no advance notice or deprecation cycles should be expected.

The various components are designed to be easy to copy and paste into your own code:
- Functions only operate on the data explicitly passed to them (no module-level state)
- Custom annotations are only used in the modules in which they are declared
- Inner helper functions are either local to the module or required explicitly within the function body
- Highly coupled behaviors (such as the config framework in the `init` module) are kept together at module scope. They are provided as templates to build your own behaviors into
