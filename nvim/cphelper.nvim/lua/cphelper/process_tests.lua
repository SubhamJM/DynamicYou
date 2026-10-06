local run = require("cphelper.run_test")
local def = require("cphelper.definitions")

local function pad(contents, opts)
    vim.validate("contents", contents, "table")
    vim.validate("opts", opts, "table", true)
    opts = opts or {}
    local left_padding = (" "):rep(opts.pad_left or 1)
    local right_padding = (" "):rep(opts.pad_right or 1)
    for i, line in ipairs(contents) do
        contents[i] = string.format("%s%s%s", left_padding, line:gsub("\r", ""), right_padding)
    end
    if opts.pad_top then
        for _ = 1, opts.pad_top do
            table.insert(contents, 1, "")
        end
    end
    if opts.pad_bottom then
        for _ = 1, opts.pad_bottom do
            table.insert(contents, "")
        end
    end
    return contents
end

local function display_right(contents)
    local api = vim.api
    local bufnr = api.nvim_create_buf(false, true)
    local width = 0
    for _, value in pairs(contents) do
        width = math.max(width, string.len(value))
    end
    width = math.max(width + 5, 45)
    local height = math.floor(vim.o.lines * 0.9)
    if not vim.g["cph#vsplit"] then
        api.nvim_open_win(bufnr, true, {
            border = vim.g["cph#border"] or "rounded",
            style = "minimal",
            relative = "editor",
            row = math.floor(((vim.o.lines - height) / 2) - 1),
            col = math.floor(vim.o.columns - width - 1),
            width = width,
            height = height,
        })
    else
        vim.cmd("vsplit")
        api.nvim_win_set_buf(0, bufnr)
        api.nvim_win_set_width(0, width)
        api.nvim_set_option_value("number", false, { win = 0 })
        api.nvim_set_option_value("relativenumber", false, { win = 0 })
        api.nvim_set_option_value("cursorline", false, { win = 0 })
        api.nvim_set_option_value("cursorcolumn", false, { win = 0 })
        api.nvim_set_option_value("spell", false, { win = 0 })
        api.nvim_set_option_value("list", false, { win = 0 })
        api.nvim_set_option_value("signcolumn", "auto", { win = 0 })
    end
    contents = pad(contents, { pad_top = 1 })
    api.nvim_set_option_value("foldmethod", "indent", { win = 0 })
    api.nvim_buf_set_lines(bufnr, 0, -1, true, contents)
    api.nvim_set_option_value("shiftwidth", 2, { buf = bufnr })
    return bufnr
end

-- Helper to fetch metadata and test cases from .cph/.<filename>.prob
local function get_prob_filepath()
    local buf_name = vim.api.nvim_buf_get_name(0)
    local dir = vim.fn.fnamemodify(buf_name, ":h")
    local file = vim.fn.fnamemodify(buf_name, ":t")
    return dir .. "/.cph/." .. file .. ".prob"
end

local function load_prob_data()
    local prob_file = get_prob_filepath()
    if vim.fn.filereadable(prob_file) == 1 then
        local f = io.open(prob_file, "r")
        if f then
            local text = f:read("*a")
            f:close()
            return vim.json.decode(text)
        end
    end
    return nil
end

local function iterate_cases(case_numbers)
    local prob_data = load_prob_data()
    if not prob_data or not prob_data.tests or #prob_data.tests == 0 then
        return 0, 0, { "No test cases found in .cph for this file!" }
    end

    local current_filepath = vim.api.nvim_buf_get_name(0)
    local ft = vim.filetype.match({ filename = current_filepath })
    local basename = vim.fn.fnamemodify(current_filepath, ":t:r")
    local original_cwd = vim.uv.cwd()
    local compiled_binary_path = original_cwd .. "/" .. basename

    -- Ensure run command is a table for vim.system
    local run_cmd_table
    if ft == "python" then
        run_cmd_table = { "python3", original_cwd .. "/" .. vim.fn.fnamemodify(current_filepath, ":t") }
    else
        run_cmd_table = { compiled_binary_path }
    end

    local ac, cases = 0, 0
    local display = {}

    local tests_to_run = {}
    if #case_numbers == 0 then
        for i, _ in ipairs(prob_data.tests) do
            table.insert(tests_to_run, i)
        end
    else
        for _, num in ipairs(case_numbers) do
            local idx = tonumber(num)
            if idx and prob_data.tests[idx] then
                table.insert(tests_to_run, idx)
            end
        end
    end

    -- Write temp files to run with cphelper.run_test, then clean up
    local tmp_dir = vim.fn.tempname()
    vim.fn.mkdir(tmp_dir, "p")

    for _, idx in ipairs(tests_to_run) do
        local test = prob_data.tests[idx]
        local in_file = tmp_dir .. "/input" .. idx
        local out_file = tmp_dir .. "/output" .. idx

        local fi = io.open(in_file, "w")
        if fi then
            fi:write(test.input or "")
            fi:close()
        end

        local fo = io.open(out_file, "w")
        if fo then
            fo:write(test.output or "")
            fo:close()
        end

        vim.cmd("lcd " .. vim.fn.fnameescape(tmp_dir))
        local case_display, success = run.run_test(tostring(idx), run_cmd_table)
        vim.cmd("lcd " .. vim.fn.fnameescape(original_cwd))

        vim.list_extend(display, case_display)
        ac = ac + success
        cases = cases + 1
    end

    -- Clean up temporary test files
    vim.fn.delete(tmp_dir, "rf")

    -- Clean up the compiled executable binary after tests finish
    if ft ~= "python" and vim.fn.filereadable(compiled_binary_path) == 1 then
        vim.fn.delete(compiled_binary_path)
    end

    return ac, cases, display
end

local function display_results(ac, cases, display)
    local header = "   RESULTS: " .. ac .. "/" .. cases .. " AC"
    if ac == cases and cases > 0 then
        header = header .. " 🎉🎉"
    end
    local contents = { "", header, "" }
    for _, line in ipairs(display) do
        table.insert(contents, line)
    end
    local bufnr = display_right(contents)
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", "Results", { buf = bufnr })
    local highlights = {
        ["Status: AC"] = "DiffAdd",
        ["Status: WA"] = "Error",
        ["Status: RTE"] = "Error",
        ["Case #\\d\\+"] = "DiffChange",
        ["Input:"] = "CphUnderline",
        ["Expected output:"] = "CphUnderline",
        ["Received output:"] = "CphUnderline",
        ["Error:\n"] = "CphUnderline",
    }
    for match, group in pairs(highlights) do
        vim.fn.matchadd(group, match)
    end
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<esc>", "<cmd>bd<CR>", { noremap = true })
    vim.api.nvim_buf_set_keymap(bufnr, "n", "q", "<cmd>bd<CR>", { noremap = true })
end

local M = {}

--- Compile and test
--- @param args string[] #case numbers to test. If not provided, then all cases are tested
function M.process(args)
    local current_filepath = vim.api.nvim_buf_get_name(0)
    local ft = vim.filetype.match({ filename = current_filepath })
    local filename = vim.fn.fnamemodify(current_filepath, ":t")
    local basename = vim.fn.fnamemodify(current_filepath, ":r")

    local cmd
    if ft == "cpp" then
        cmd = { "g++", "-O3", "-Wall", "-Wextra", "-std=c++17", filename, "-o", basename }
    elseif ft == "c" then
        cmd = { "gcc", "-O3", filename, "-o", basename }
    elseif ft == "rust" then
        cmd = { "rustc", "-O", filename, "-o", basename }
    elseif ft == "python" then
        M.process_retests(args)
        return
    else
        cmd = def.compile_cmd[ft]
        if type(cmd) == "string" then
            cmd = vim.split(cmd, "%s+", { trimempty = true })
        end
    end

    if cmd ~= nil then
        vim.system(
            cmd,
            {},
            function(out)
                if out.stderr and out.stderr ~= "" then
                    vim.schedule(function()
                        vim.api.nvim_echo({ { out.stderr } }, true, { err = true })
                    end)
                end
                if out.code == 0 then
                    vim.schedule(function()
                        local ac, cases, results = iterate_cases(args)
                        display_results(ac, cases, results)
                    end)
                end
            end
        )
    else
        M.process_retests(args)
    end
end

--- Retest without compiling
--- @param args string[] #case numbers to test. If not provided, then all cases are tested
function M.process_retests(args)
    local ac, cases, display = iterate_cases(args)
    display_results(ac, cases, display)
end

return M
