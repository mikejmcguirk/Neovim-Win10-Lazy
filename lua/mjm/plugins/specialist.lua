vim.cmd.packadd({ vim.fn.escape("specialist.nvim", " "), bang = true, magic = { file = false } })

-- TODO: The cw custom comand does not stop at delimiters like quotes
-- "$"
-- if you cw on $, it will also take out the quote boundary
-- In the part where it determines what words are, delimiters need to be considered separately
-- TODO: @param
-- if you cw on the p it takes you before the @
-- and with ] from end of line
