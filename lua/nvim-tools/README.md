NOTE: This repository is not intended to be used as a library or dependency. While breaking changes will be labeled in commit titles, no advance notice or deprecation cycles should be expected.

The various components are designed to be easy to copy and paste into your own code:
- Functions only operate on the data explicitly passed to them (no module-level state)
- Custom annotations are only used in the modules in which they are declared
- Inner helper functions are either local to the module or required explicitly within the function body
- Highly coupled behaviors (such as the config framework in the `init` module) are kept together at module scope. They are provided as templates to build your own behaviors into
