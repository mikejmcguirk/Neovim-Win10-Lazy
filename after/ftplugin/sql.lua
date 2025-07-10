-- FUTURE: Fix lack of auto indent when doing something like INSERT INTO()
-- My guess is that it's setup in the default ftplugin but I'm not sure
-- But then it will indent out the closing parens so I have no clue

vim.cmd([[setlocal comments=:-- commentstring=--\ %s]]) -- Because default ftplugin is diabled
