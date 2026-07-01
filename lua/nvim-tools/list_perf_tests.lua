local M = {}

function M.insert_at_test()
    local insert = table.insert
    local ntt = require("nvim-tools.table")
    local insert_at = ntt.i_insert_at

    -- High-resolution timer (ns). Works in Neovim; falls back gracefully.
    local hrtime
    do
        local uv = vim and (vim.uv or vim.loop)
        if uv and type(uv.hrtime) == "function" then
            hrtime = uv.hrtime
        else
            hrtime = function()
                return os.clock() * 1e9
            end
        end
    end

    -- Phases chosen so we can see scaling behavior as the table grows.
    -- Each phase continues on the *same* growing table (classic array insert benchmark).
    local phases = {
        { name = "    1 -    100", from = 1, to = 100 },
        { name = "  101 -   1000", from = 101, to = 1000 },
        { name = " 1001 -  10000", from = 1001, to = 10000 },
        { name = "10001 - 100000", from = 10001, to = 100000 },
    }
    local num_phases = #phases
    local phase_counts = { 100, 900, 9000, 90000 }

    -- Aggregators (nanoseconds). Outer loop lets you increase iterations later for stable averages.
    local ti_totals_ns = { 0, 0, 0, 0 }
    local ia_totals_ns = { 0, 0, 0, 0 }
    local run_count = 0
    local total_runs = 6

    for _ = 1, total_runs do
        run_count = run_count + 1
        local adds = {}
        for i = 0, 99999 do
            adds[#adds + 1] = math.random(1, i)
        end

        -- table.insert baseline
        do
            local tbl = {}
            local ins_num = 1
            for p = 1, num_phases do
                local ph = phases[p]
                local t0 = hrtime()
                for i = ph.from, ph.to do
                    insert(tbl, adds[ins_num], i)
                    ins_num = ins_num + 1
                end

                ti_totals_ns[p] = ti_totals_ns[p] + (hrtime() - t0)
            end
        end

        -- insert_at under test (assumes signature insert_at(tbl, pos, value) — same as table.insert 3-arg form)
        do
            local tbl = {}
            local ins_num = 1
            for p = 1, num_phases do
                local ph = phases[p]
                local t0 = hrtime()
                for i = ph.from, ph.to do
                    insert_at(tbl, i, adds[ins_num])
                    ins_num = ins_num + 1
                end
                ia_totals_ns[p] = ia_totals_ns[p] + (hrtime() - t0)
            end
        end
    end

    -- Results
    print("insert_at vs table.insert — random-position insert benchmark")
    print(("="):rep(78))
    print(
        string.format(
            "Averaged over %d run(s). Positions chosen uniformly from 1..#t+1 (includes append).",
            run_count
        )
    )
    print("")

    local header = string.format(
        "%-18s %10s %12s %14s %10s",
        "Phase",
        "Inserts",
        "Total (ms)",
        "Avg (µs/ins)",
        "Ratio"
    )
    print(header)
    print(("-"):rep(78))

    for p = 1, num_phases do
        local n = phase_counts[p]
        local ti_ns = ti_totals_ns[p] / run_count
        local ia_ns = ia_totals_ns[p] / run_count

        local ti_ms = ti_ns / 1e6
        local ia_ms = ia_ns / 1e6
        local ti_us = (ti_ns / n) / 1000
        local ia_us = (ia_ns / n) / 1000
        local ratio = ti_us / ia_us -- >1.0 means insert_at was faster on average

        print(
            string.format("table.insert  %s %10d %12.2f %14.2f", phases[p].name, n, ti_ms, ti_us)
        )
        print(
            string.format(
                "insert_at     %s %10d %12.2f %14.2f   (%.2fx)",
                phases[p].name,
                n,
                ia_ms,
                ia_us,
                ratio
            )
        )
        print("")
    end

    print(
        "Ratio = (table.insert time) / (insert_at time). >1.0 → insert_at faster for that phase size."
    )
    print(
        "Note: Full 100k run is O(N²) work in the worst case; expect it to take a few seconds on modern hardware."
    )
end

-- insert_at vs table.insert — random-position insert benchmark
-- ==============================================================================
-- Averaged over 6 run(s). Positions chosen uniformly from 1..#t+1 (includes append).
--
-- Phase                 Inserts   Total (ms)  Avg (µs/ins)      Ratio
-- ------------------------------------------------------------------------------
-- table.insert      1 -    100        100         0.02           0.15
-- insert_at         1 -    100        100         0.02           0.25   (0.62x)
--
-- table.insert    101 -   1000        900         0.25           0.28
-- insert_at       101 -   1000        900         0.20           0.22   (1.25x)
--
-- table.insert   1001 -  10000       9000        21.12           2.35
-- insert_at      1001 -  10000       9000        15.30           1.70   (1.38x)
--
-- table.insert  10001 - 100000      90000      2165.01          24.06
-- insert_at     10001 - 100000      90000      1425.29          15.84   (1.52x)
--
-- Ratio = (table.insert time) / (insert_at time). >1.0 → insert_at faster for that phase size.
-- Note: Full 100k run is O(N²) work in the worst case; expect it to take a few seconds on modern hardware.

function M.rm_at_test()
    local remove = table.remove
    local ntt = require("nvim-tools.table")
    local rm_at = ntt.i_rm_at

    -- High-resolution timer (ns)
    local hrtime
    do
        local uv = vim and (vim.uv or vim.loop)
        if uv and type(uv.hrtime) == "function" then
            hrtime = uv.hrtime
        else
            hrtime = function()
                return os.clock() * 1e9
            end
        end
    end

    local N = 100000

    -- Helper to create a fresh 100k table (values don't matter, only structure)
    local function make_big(n)
        local t = {}
        for i = 1, n do
            t[i] = i
        end
        return t
    end

    -- Removal phases (shrinking). Mirrors the insert benchmark structure but in reverse.
    local phases = {
        { name = "100k →  10k", removes = 90000 },
        { name = " 10k →   1k", removes = 9000 },
        { name = "  1k →   100", removes = 900 },
        { name = "  100 →     1", removes = 99 },
    }
    local num_phases = #phases

    local tr_totals_ns = { 0, 0, 0, 0 } -- table.remove
    local ra_totals_ns = { 0, 0, 0, 0 } -- rm_at
    local run_count = 0
    local total_runs = 6

    for _ = 1, total_runs do
        run_count = run_count + 1
        local removes = {}
        local n_offset = N + 1
        for i = 1, 100000 do
            removes[#removes + 1] = math.random(1, n_offset - i)
        end

        -- table.remove baseline (start fresh 100k each run)
        do
            local tbl = make_big(N)
            local rm_num = 1
            for p = 1, num_phases do
                local ph = phases[p]
                local t0 = hrtime()
                for _ = 1, ph.removes do
                    remove(tbl, removes[rm_num])
                    rm_num = rm_num + 1
                end

                tr_totals_ns[p] = tr_totals_ns[p] + (hrtime() - t0)
            end
        end

        -- rm_at under test (assumes rm_at(tbl, pos) — mutates, removes & shifts)
        do
            local tbl = make_big(N)
            local rm_num = 1
            for p = 1, num_phases do
                local ph = phases[p]
                local t0 = hrtime()
                for _ = 1, ph.removes do
                    rm_at(tbl, removes[rm_num])
                    rm_num = rm_num + 1
                end

                ra_totals_ns[p] = ra_totals_ns[p] + (hrtime() - t0)
            end
        end
    end

    -- Results
    print("rm_at vs table.remove — random-position remove benchmark (shrinking from 100k)")
    print(("="):rep(80))
    print(
        string.format(
            "Averaged over %d run(s). Each run starts with a fresh 100k-element table.",
            run_count
        )
    )
    print("Positions chosen uniformly from 1..#t (valid remove indices).")
    print("")

    local header = string.format(
        "%-18s %10s %12s %14s %10s",
        "Phase",
        "Removes",
        "Total (ms)",
        "Avg (µs/rem)",
        "Ratio"
    )
    print(header)
    print(("-"):rep(80))

    local remove_counts = { 90000, 9000, 900, 99 }

    for p = 1, num_phases do
        local n = remove_counts[p]
        local tr_ns = tr_totals_ns[p] / run_count
        local ra_ns = ra_totals_ns[p] / run_count

        local tr_ms = tr_ns / 1e6
        local ra_ms = ra_ns / 1e6
        local tr_us = (tr_ns / n) / 1000
        local ra_us = (ra_ns / n) / 1000
        local ratio = tr_us / ra_us -- >1.0 means rm_at was faster

        print(
            string.format("table.remove  %s %10d %12.2f %14.2f", phases[p].name, n, tr_ms, tr_us)
        )
        print(
            string.format(
                "rm_at         %s %10d %12.2f %14.2f   (%.2fx)",
                phases[p].name,
                n,
                ra_ms,
                ra_us,
                ratio
            )
        )
        print("")
    end

    print("Ratio = (table.remove time) / (rm_at time). >1.0 → rm_at faster for that phase.")
    print(
        "Note: First phase (100k→10k) is the most expensive on average because of large shifts."
    )
end

-- rm_at vs table.remove — random-position remove benchmark (shrinking from 100k)
-- ================================================================================
-- Averaged over 6 run(s). Each run starts with a fresh 100k-element table.
-- Positions chosen uniformly from 1..#t (valid remove indices).
--
-- Phase                 Removes   Total (ms)  Avg (µs/rem)      Ratio
-- --------------------------------------------------------------------------------
-- table.remove  100k →  10k      90000      1175.32          13.06
-- rm_at         100k →  10k      90000      1176.62          13.07   (1.00x)
--
-- table.remove   10k →   1k       9000        12.57           1.40
-- rm_at          10k →   1k       9000        12.29           1.37   (1.02x)
--
-- table.remove    1k →   100        900         0.18           0.20
-- rm_at           1k →   100        900         0.18           0.20   (0.99x)
--
-- table.remove    100 →     1         99         0.02           0.15
-- rm_at           100 →     1         99         0.03           0.29   (0.53x)
--
-- Ratio = (table.remove time) / (rm_at time). >1.0 → rm_at faster for that phase.
-- Note: First phase (100k→10k) is the most expensive on average because of large shifts.

function M.drain_test()
    local remove = table.remove
    local ntt = require("nvim-tools.table")
    local drain = ntt.i_drain

    -- High-resolution timer (ns)
    local hrtime
    do
        local uv = vim and (vim.uv or vim.loop)
        if uv and type(uv.hrtime) == "function" then
            hrtime = uv.hrtime
        else
            hrtime = function()
                return os.clock() * 1e9
            end
        end
    end

    local N = 100000

    -- Helper to create a fresh 100k table (values don't matter, only structure)
    local function make_big(n)
        local t = {}
        for i = 1, n do
            t[i] = i
        end
        return t
    end

    -- Removal phases (shrinking). Mirrors the insert benchmark structure but in reverse.
    local phases = {
        { name = "100k →  10k", removes = 90000 },
        { name = " 10k →   1k", removes = 9000 },
        { name = "  1k →   100", removes = 900 },
        { name = "  100 →     1", removes = 99 },
    }
    local num_phases = #phases

    local tr_totals_ns = { 0, 0, 0, 0 } -- table.remove
    local ra_totals_ns = { 0, 0, 0, 0 } -- drain
    local run_count = 0
    local total_runs = 6

    for _ = 1, total_runs do
        run_count = run_count + 1
        local removes = {}
        local n_offset = N + 1
        for i = 1, 100000 do
            removes[#removes + 1] = math.random(1, n_offset - i)
        end

        -- table.remove baseline (start fresh 100k each run)
        do
            local tbl = make_big(N)
            local rm_num = 1
            for p = 1, num_phases do
                local ph = phases[p]
                local t0 = hrtime()
                for _ = 1, ph.removes do
                    remove(tbl, removes[rm_num])
                    rm_num = rm_num + 1
                end

                tr_totals_ns[p] = tr_totals_ns[p] + (hrtime() - t0)
            end
        end

        -- drain under test (assumes drain(tbl, pos) — mutates, removes & shifts)
        do
            local tbl = make_big(N)
            local rm_num = 1
            for p = 1, num_phases do
                local ph = phases[p]
                local t0 = hrtime()
                for _ = 1, ph.removes do
                    ---@diagnostic disable-next-line: unused-local
                    local foo = drain(tbl, removes[rm_num])
                    rm_num = rm_num + 1
                end

                ra_totals_ns[p] = ra_totals_ns[p] + (hrtime() - t0)
            end
        end
    end

    -- Results
    print("drain vs table.remove — random-position remove benchmark (shrinking from 100k)")
    print(("="):rep(80))
    print(
        string.format(
            "Averaged over %d run(s). Each run starts with a fresh 100k-element table.",
            run_count
        )
    )
    print("Positions chosen uniformly from 1..#t (valid remove indices).")
    print("")

    local header = string.format(
        "%-18s %10s %12s %14s %10s",
        "Phase",
        "Removes",
        "Total (ms)",
        "Avg (µs/rem)",
        "Ratio"
    )
    print(header)
    print(("-"):rep(80))

    local remove_counts = { 90000, 9000, 900, 99 }

    for p = 1, num_phases do
        local n = remove_counts[p]
        local tr_ns = tr_totals_ns[p] / run_count
        local ra_ns = ra_totals_ns[p] / run_count

        local tr_ms = tr_ns / 1e6
        local ra_ms = ra_ns / 1e6
        local tr_us = (tr_ns / n) / 1000
        local ra_us = (ra_ns / n) / 1000
        local ratio = tr_us / ra_us -- >1.0 means drain was faster

        print(
            string.format("table.remove  %s %10d %12.2f %14.2f", phases[p].name, n, tr_ms, tr_us)
        )
        print(
            string.format(
                "drain         %s %10d %12.2f %14.2f   (%.2fx)",
                phases[p].name,
                n,
                ra_ms,
                ra_us,
                ratio
            )
        )
        print("")
    end

    print("Ratio = (table.remove time) / (drain time). >1.0 → drain faster for that phase.")
    print(
        "Note: First phase (100k→10k) is the most expensive on average because of large shifts."
    )
end

-- drain vs table.remove — random-position remove benchmark (shrinking from 100k)
-- ================================================================================
-- Averaged over 6 run(s). Each run starts with a fresh 100k-element table.
-- Positions chosen uniformly from 1..#t (valid remove indices).
--
-- Phase                 Removes   Total (ms)  Avg (µs/rem)      Ratio
-- --------------------------------------------------------------------------------
-- table.remove  100k →  10k      90000      1176.04          13.07
-- drain         100k →  10k      90000      1168.71          12.99   (1.01x)
--
-- table.remove   10k →   1k       9000        12.16           1.35
-- drain          10k →   1k       9000        12.28           1.36   (0.99x)
--
-- table.remove    1k →   100        900         0.18           0.20
-- drain           1k →   100        900         0.18           0.20   (0.98x)
--
-- table.remove    100 →     1         99         0.01           0.10
-- drain           100 →     1         99         0.02           0.17   (0.59x)
--
-- Ratio = (table.remove time) / (drain time). >1.0 → drain faster for that phase.
-- Note: First phase (100k→10k) is the most expensive on average because of large shifts.

return M
