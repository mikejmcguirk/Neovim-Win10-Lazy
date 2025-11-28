-- MID: https://docs.astral.sh/ruff/rules/ - Which of these are useful?
-- LOW: Need a solution to put these in project folders. In case I want to put a Python project on
-- Github. The problem is manually syncing things with the template file is an obnoxious amount
-- of work

return {
    init_options = {
        settings = {
            lint = {
                select = { "ANN", "TC", "F", "E", "W" },
            },
        },
    },
}
