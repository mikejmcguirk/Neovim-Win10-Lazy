All triple-line comments should be treated as potential doc text.

The default presumption should be that a continuous group of triple comments are a block, and that a blink or non-triple line ends it.
- Exception: If we do [[@brief or --@raw or something

Support:
- nodoc
- inline doc
- Proper line wrapping

I am not actually interested in being hyper-flexible on how the generated docs look. This should be an opinionated docgen. If only because it makes my life simpler

For fun() definitions, probably just let them bleed over 78, since it's hard to know where they should actually end.

## MANDATORY

- Support proper formatting and line wrapping. Should *never* require manual intervention from the user.

## GOALS

Support the following annotations:
- nodoc
- inlinedoc

## CONSTRAINTS

- Display options and hooks should be minimal to non-existent. They add to what is already enormously challenging, and I have an opinionated idea of what vimdoc should look like.
  * Following from this is the overall idea that output should be controlled with tags rather than in the Lua Code itself
- The docs should be generated and ordered exactly how the files are presented.
- For now at least, we are assuming that we are generating one file per run. Multi-file adds complexity.
