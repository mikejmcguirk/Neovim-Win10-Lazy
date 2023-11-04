# Normal Mode

### Normal Mode File/Program Management

General

| Input             | Result                                                           |
| :---------------- | :--------------------------------------------------------------- |
| @:                | Repeat previous command                                          |
| \<Esc\>           | Exit command mode                                                |
| :%norm            | Perform a normal mode command on all lines in a file             |
| \<C-c\> , \<C-[\> | Alternative returns to normal mode. Ctrl+C has unique properties |
| g \<C-g\>         | Get col, line, word, and byte positions/counts in current buffer |

How to Quit Vim

| Input         | Result                          |
| :------------ | :------------------------------ |
| :w            | Write                           |
| :q            | Quit                            |
| :wq , :x , ZZ | Write and quit                  |
| :q! , ZQ      | Force quit                      |
| :qa           | Quit all                        |
| :qa!          | Quit all without saving         |
| :wa           | Write all                       |
| :wqa          | Write and quit all open buffers |

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
| set wrap!                 | Toggle line wrap                                      |

Tabs

| Input | Result       |
| :---- | :----------- |
| :tabe | New tab      |
| gt    | Next tab     |
| gT    | Previous tab |

### Normal Mode General

| Input | Result                 |
| :---- | :--------------------- |
| .     | Repeat previous motion |

### Normal Mode Navigation

General

| Input         | Result                |
| :------------ | :-------------------- |
| h , j , k , l | Left, down, up, right |

Vertical

| Input    | Result                                                                            |
| :------- | :-------------------------------------------------------------------------------- |
| gg , G   | Preceded by a count, goes to absolute line number. Defaults to top/bottom of file |
| :100     | Go to line 100                                                                    |
| { , }    | Go backward/forward a paragraph (next blank line)                                 |
| {count}% | Jump to count % through the file                                                  |

Horizontal

| Input  | Result                                                                                           |
| :----- | :----------------------------------------------------------------------------------------------- |
| 0 / $  | Beginning/end of line                                                                            |
| \_ , ^ | First non-whitespace character                                                                   |
| g\_    | Go to the last non-blank character                                                               |
| w , b  | Go to next/previous word (b will go to the beginning of current word first if not already there) |
| W , B  | Go to next/previous word (space separated)                                                       |
| e , ge | Next/previous end of word (e will be to end of current word first if not already there)          |
| E , gE | Next/previous end of word (space separated)                                                      |
| f , F  | Search foward/backward horizontally to the specified character                                   |
| t , T  | Search forward/backward to before the specified character                                        |
| ; , ,  | Repeat seach function forward/backward                                                           |
| %      | Jump between matching {} or ()                                                                   |

Searches

| Input    | Result                                                              |
| :------- | :------------------------------------------------------------------ |
| /pattern | Search forward for a pattern                                        |
| ?pattern | Search backward for a pattern                                       |
| \*       | Searches for word cursor is on (Also works in Visual Mode)          |
| \#       | Searches backward for word cursor is on (Also works in Visual Mode) |
| \c       | Add this escape to a search to make it case insensitive             |
| n        | Move forward through search results                                 |
| N        | Move backward through search results                                |
| :noh     | Clear search                                                        |
| \<C-g\>  | Next result while in search mode                                    |
| \<C-t\>  | Previous result while in search mode                                |

Marks

| Input   | Result                                      |
| :------ | :------------------------------------------ |
| m{a-z}  | Set mark at cursor position                 |
| m{A-Z}  | Sets a global mark that works between files |
| `{a-z}  | Go to mark exactly                          |
| '{a-z}  | Go to begining of line where mark was set   |
| :marks  | Show all marks                              |
| \<C-o\> | Goto last cursor position in jump list      |
| \<C-i\> | Goto next cursor position in jump list      |

Scrolling

| Input             | Result                           |
| :---------------- | :------------------------------- |
| \<C-d\> , \<C-u\> | Scroll down/up half a page       |
| \<C-e\> , \<C-y\> | Scoll down/up one line           |
| zz                | Center view on current line      |
| zt                | Current line on top of window    |
| zb                | Current line on bottom fo window |

### Normal Mode Text Manipulation

General

| Input   | Result |
| :------ | :----- |
| u       | undo   |
| \<C-r\> | redo   |

Copypasta

| Input       | Result                                                                                        |
| :---------- | :-------------------------------------------------------------------------------------------- |
| y           | Enter yank mode                                                                               |
| yy          | Yank line                                                                                     |
| Y           | Yank to the end of the line, add count to yank more lines below                               |
| yw          | Yank word                                                                                     |
| y$          | Yank to end of line                                                                           |
| yi(         | Yank the current (or next) text within () NOT including the ()                                |
| ya(         | Yank the current (or next) text within () including the ()                                    |
| p           | Paste after cursor                                                                            |
| P           | Paste after cursor                                                                            |
| gp , gP     | Paste then move cursor to just after pasted text                                              |
| \"+y        | Yank to clipboard                                                                             |
| \"+p        | Paste to clipboard                                                                            |
| ]p          | If yanked linewise, paste after linewise and maintain current indentation, otherwise normal p |
| [p, [P , ]P | If yanked linewise, past before linewise and maintain current indentation, otherwise normal P |
| :-10t.      | Copy the line 10 lines above the current line and paste it below the current line             |
| :+8t.       | Copy the line 8 lines after the current line and paste it below                               |
| :-10m.      | Copy the line 10 lines above the current line to the one below                                |
| :+8m.       | Copy the line 8 lines after the current line to the one below                                 |

Deleting

| Input     | Result                                                                      |
| :-------- | :-------------------------------------------------------------------------- |
| d         | Enter delete mode (writes to clipboard)                                     |
| dd        | Delete line                                                                 |
| dw        | Delete to end of word                                                       |
| dvj       | Like vjd. v forces the operator to work charwise                            |
| D         | Delete to end of line                                                       |
| 0D        | Delete whole line                                                           |
| 5dd , d5d | Delete five lines                                                           |
| dfc       | Will delete up to and including the next c in the line (works with F, t, T) |
| d/pattern | Will delete upto but NOT including the next instance of "pattern"           |
| d1k       | Delete current line and one line above it                                   |
| di( , dib | If in paranthesis, deletes everything within                                |
| di{ , diB | If in curly braces, deletes everything within                               |
| diw       | Delete inner word                                                           |
| daw       | Delete word and whitespace                                                  |
| diW       | Delete inner word spacewise                                                 |
| daW       | Delete inner word spacewise and trailing whitespace                         |
| dip       | Delete inner paragraph                                                      |
| dap       | Delete paragraph and surrounding whitespace                                 |
| dit       | Delete inside matching tags                                                 |
| dat       | Delete matching tags and contents                                           |
| x         | Delete character (writes to clipboard)                                      |
| X         | Delete character before cursor (writes to clipboard)                        |

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
| guiw       | Lowercase current word                                    |
| gUiw       | Uppercase current word                                    |
| g~iw       | Toggle case of current word                               |
| guu        | Lowercase current line                                    |
| gUU        | Uppercase current line                                    |
| g~~        | Toggle case current line                                  |
| g~$        | Toggle case to end of currentl ine                        |
| gggqG      | Apply vim default formatting to whole buffer              |

Delete and Replace

| Input | Result                                              |
| :---- | :-------------------------------------------------- |
| c     | Mode to cut text to clipboard and enter insert mode |
| cc    | Replace line                                        |
| cw    | Replace word                                        |
| c$    | Replace to end of line                              |
| 3cl   | Remove three letters and enter insert mode          |

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

| Input                            | Result                                                                                                                                                                                        |
| :------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| :<zero-width-space>s/old/new/    | Basic substitution                                                                                                                                                                            |
| :%s                              | Substitute in whole file                                                                                                                                                                      |
| g                                | Modifier to go to end of current line (or whole selection in visual mode). Even when substituting the whole file, only the first occurence per line will be replaced unless this is specified |
| i                                | Modifier to ignore case                                                                                                                                                                       |
| n                                | Modifier to report number of matches without substituting                                                                                                                                     |
| c                                | Modifier to ask for confirmation                                                                                                                                                              |
| e                                | Modifier to suppress errors                                                                                                                                                                   |
| \\%V                             | In visual mode, insert into text to match only within selection                                                                                                                               |
| & (as part of replace)           | Insert the matched text                                                                                                                                                                       |
| :&                               | Repeat last substitution but replace flags                                                                                                                                                    |
| :&&                              | Keep flags                                                                                                                                                                                    |
| :%&                              | Repeat on file, reset flags                                                                                                                                                                   |
| :%&&                             | Repeat on file, keep flags                                                                                                                                                                    |
| & (as a flag)                    | Must be first. Repeat flags of previous substitution                                                                                                                                          |
| I                                | Don't ignore case or use smartcase                                                                                                                                                            |
| :g/MATCH/#\|s/MATCH/REPLACE/g\|# | Print out all substitutions for review                                                                                                                                                        |

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
| i       | Enter insert mode                               |
| I       | Insert at start of line                         |
| A       | Insert at end of line                           |
| o       | Insert on new next line                         |
| O       | Insert on new next line above                   |
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
