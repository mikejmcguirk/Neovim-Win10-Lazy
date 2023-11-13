# Motions Notes

### Normal Mode

General

| Input             | Result                                                           |
| :---------------- | :--------------------------------------------------------------- |
| @:                | Repeat previous command                                          |
| :%norm            | Perform a normal mode command on all lines in a file             |
| \<C-c\> , \<C-[\> | Alternative returns to normal mode                               |
| g \<C-g\>         | Get col, line, word, and byte positions/counts in current buffer |

Buffers

| Input                | Result                     |
| :------------------- | :------------------------- |
| :e                   | Edit/reload a file         |
| :set ma , modifiable | Set buffer to modifiable   |
| :set noma            | Set buffer to unmodifiable |

Windows

| Input                     | Result                                                |
| :------------------------ | :---------------------------------------------------- |
| \<C-w\>s , :split         | Horizontal split                                      |
| \<C-w\>v , :vsplit , :vsp | Vertical split                                        |
| \<C-w\> R , r             | Rotate window up/left or down/right                   |
| \<C-w\> H , J , K , L     | Rotate window to the very left, bottom, top, or right |
| \<C-w\>w                  | Goto next window (z shape)                            |
| \<C-w\>q                  | Quit window                                           |
| \<C-w\>o                  | Close all but the current window                      |
| \<C-w\>=                  | Make windows roughly the same size                    |

Vertical

| Input    | Result                                                                            |
| :------- | :-------------------------------------------------------------------------------- |
| gg , G   | Preceded by a count, goes to absolute line number. Defaults to top/bottom of file |
| :100     | Go to line 100                                                                    |
| {count}% | Jump to count % through the file                                                  |

Horizontal

| Input  | Result                                                                                  |
| :----- | :-------------------------------------------------------------------------------------- |
| \_ , ^ | First non-whitespace character                                                          |
| g\_    | Go to the last non-blank character                                                      |
| e , ge | Next/previous end of word (e will be to end of current word first if not already there) |
| E , gE | Next/previous end of word (space separated)                                             |
| ; , ,  | Repeat seach function forward/backward                                                  |
| %      | Jump between matching {} or ()                                                          |

Searches

| Input    | Result                                                  |
| :------- | :------------------------------------------------------ |
| /pattern | Search forward for a pattern                            |
| ?pattern | Search backward for a pattern                           |
| \*       | Search forward for word under cursor                    |
| \#       | Search backward for word under cursor                   |
| \c       | Add this escape to a search to make it case insensitive |
| \<C-g\>  | Next result while in search mode                        |
| \<C-t\>  | Previous result while in search mode                    |

Copypasta

| Input       | Result                                                                                        |
| :---------- | :-------------------------------------------------------------------------------------------- |
| ]p          | If yanked linewise, paste after linewise and maintain current indentation, otherwise normal p |
| [p, [P , ]P | If yanked linewise, past before linewise and maintain current indentation, otherwise normal P |
| :-10t.      | Copy the line 10 lines above the current line and paste it below the current line             |
| :+8t.       | Copy the line 8 lines after the current line and paste it below                               |
| :-10m.      | Copy the line 10 lines above the current line to the one below                                |
| :+8m.       | Copy the line 8 lines after the current line to the one below                                 |

Deleting

| Input     | Result                                                            |
| :-------- | :---------------------------------------------------------------- |
| dvj       | Like vjd. v forces the operator to work charwise                  |
| d/pattern | Will delete upto but NOT including the next instance of "pattern" |
| x         | Delete character (writes to clipboard)                            |
| X         | Delete character before cursor (writes to clipboard)              |

Mass Deletion

| Input         | Result                         |
| :------------ | :----------------------------- |
| :g/pattern/d  | Remove lines matching pattern  |
| :g!/pattern/d | Remove lines that do NOT match |

Replacing

| Input      | Result                                                    |
| :--------- | :-------------------------------------------------------- |
| R          | Replace mode                                              |
| gR         | Virtual replace mode (a Tab replaces multiple characters) |
| r          | Replace character                                         |
| gr         | Virtual replace single character                          |
| ~          | Change case                                               |
| g~{motion} | Change case of motion                                     |
| g~iw       | Toggle case of current word                               |
| g~~        | Toggle case current line                                  |
| g~$        | Toggle case to end of current line                        |

Moving Text

| Input       | Result                                                                   |
| :---------- | :----------------------------------------------------------------------- |
| \< , \>     | Enter tab mode                                                           |
| \<\< , \>\> | Move one tab level                                                       |
| .           | Indent to the right the amount of lines specified in the last \> command |
| ==          | Auto-indent                                                              |
| 4==         | Indent current line and the next three                                   |
| =ap         | Auto-indent a whole paragraph                                            |
| J           | Move previous line to end of current one                                 |
| gwl         | Wrap text to colored column                                              |

Substitution

| Input                            | Result                                                          |
| :------------------------------- | :-------------------------------------------------------------- |
| :<zero-width-space>s/old/new/    | Basic substitution                                              |
| :%s                              | Substitute in whole file                                        |
| g                                | Include all in current line (needed even in visual mode)        |
| i                                | Modifier to ignore case                                         |
| n                                | Modifier to report number of matches without substituting       |
| c                                | Modifier to ask for confirmation                                |
| e                                | Modifier to suppress errors                                     |
| \\%V                             | In visual mode, insert into text to match only within selection |
| & (as part of replace)           | Insert the matched text                                         |
| :&                               | Repeat last substitution but replace flags                      |
| :&&                              | Keep flags                                                      |
| :%&                              | Repeat on file, reset flags                                     |
| :%&&                             | Repeat on file, keep flags                                      |
| & (as a flag)                    | Must be first. Repeat flags of previous substitution            |
| I                                | Don't ignore case or use smart case                             |
| :g/MATCH/#\|s/MATCH/REPLACE/g\|# | Print out all substitutions for review                          |

Regex
Input | Result
|:--- |:---
. | Any character
$ | Anchor to end of line
[a-zA-Z0-9] | Alphanumeric characters
\\s | Symbol for whitespace characters excluding newlines
\\S | Symbol for non-whitespace characters
\\(._\\) | In substitutions, lets you store a back reference. This one will store any amount (_) of any characters except newlines (.)
\\(\\w.\*\\) | Fightin' one-eyed Kirby but excludes leading whitespace
\\(.\\) | FOEK to grab one character
\\{#\\} | Fighting One-Eyed Metaknight. This back reference lets you grab a specific number of some specified character. So if you wanted to create a backreference to three characters, you could do \\(.\\{3\\}\\)
\\{0,4\\} | This lets you specify a range of characters. In this case 0-4
\\1 | When using the FOEK, use this in the new pattern to restore the old text. Can do \\2 if you have more than one backreference
\\U | Uppercase the entire used backreference
\\L | Lowercase the entire used backreference
\\e , \\E | Stop changing case

# Insert Mode

| Input   | Result                                          |
| :------ | :---------------------------------------------- |
| \<C-o\> | Go to normal mode to run one command            |
| \<C-w\> | Delete previous word                            |
| \<C-u\> | Delete everything on current line before cursor |
| \<C-t\> | Shift line a tabwidth out                       |
| \<C-d\> | Shfit line a tabwidth in                        |

# Visual Mode

| Input    | Result                                                                |
| :------- | :-------------------------------------------------------------------- |
| v        | Enter visual mode                                                     |
| V        | Enter visual line mode (works in normal visual and visual block mode) |
| gv       | Reselect last visual block mode selection                             |
| ggVG     | Select all text                                                       |
| \<C-v\>  | Enter visual block mode                                               |
| o        | Move to other corner of block                                         |
| O        | Move to other end of block (visual block mode)                        |
| =        | Auto-indent                                                           |
| C , R    | Delete and replace entire line                                        |
| r        | Then type a character. Replaces entire selection with character       |
| u , U    | lowercase/uppercase all text                                          |
| J        | Join highlighted lines                                                |
| \<C-a\>  | Autoincrement numbered list                                           |
| g\<C-a\> | As a group, make a numbered list increment upward                     |
| i(       | Selects everything within paranthesis                                 |
| a(       | Selects everything within and including paranthesis                   |
| iw       | Select inner word                                                     |
