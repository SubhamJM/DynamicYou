local M = {}

-- Helper to find the .cph file for a given buffer
local function get_prob_filepath(source_bufnr)
    local buf_name = vim.api.nvim_buf_get_name(source_bufnr)
    local dir = vim.fn.fnamemodify(buf_name, ":h")
    local file = vim.fn.fnamemodify(buf_name, ":t")
    return dir .. "/.cph/." .. file .. ".prob"
end

local function load_prob_data(source_bufnr)
    local prob_file = get_prob_filepath(source_bufnr)
    if vim.fn.filereadable(prob_file) == 1 then
        local f = io.open(prob_file, "r")
        if f then
            local text = f:read("*a")
            f:close()
            return vim.json.decode(text) or { tests = {} }
        end
    end
    return { tests = {} }
end

local function save_prob_data(source_bufnr, data)
    local prob_file = get_prob_filepath(source_bufnr)
    local dir = vim.fn.fnamemodify(prob_file, ":h")
    if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
    end
    local f = io.open(prob_file, "w")
    if f then
        f:write(vim.json.encode(data))
        f:close()
    end
end

--- Edit or add a test case persistently
--- @param case string Test case index (1-based)
function M.edittc(case)
    local idx = tonumber(case)
    if not idx then
        print("Invalid case index")
        return
    end

    -- Capture current problem buffer before creating new windows
    local source_bufnr = vim.api.nvim_get_current_buf()
    local prob_data = load_prob_data(source_bufnr)
    prob_data.tests = prob_data.tests or {}
    local current_test = prob_data.tests[idx] or { input = "", output = "" }

    -- Create temporary buffers for input and expected output
    local in_buf = vim.api.nvim_create_buf(false, true)
    local out_buf = vim.api.nvim_create_buf(false, true)

    local in_lines = vim.split(current_test.input or "", "\n", { plain = true })
    local out_lines = vim.split(current_test.output or "", "\n", { plain = true })

    vim.api.nvim_buf_set_lines(in_buf, 0, -1, false, in_lines)
    vim.api.nvim_buf_set_lines(out_buf, 0, -1, false, out_lines)

    -- Name the buffers using API to avoid Vim # expansion issues
    vim.api.nvim_buf_set_name(in_buf, "cph://input_" .. idx)
    vim.api.nvim_buf_set_name(out_buf, "cph://output_" .. idx)

    -- Open a new tab page with side-by-side splits
    vim.cmd("tabnew")
    local main_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(main_win, in_buf)

    vim.cmd("vsplit")
    local out_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(out_win, out_buf)

    -- Auto-save test cases when this tab is closed
    vim.api.nvim_create_autocmd("TabClosed", {
        once = true,
        callback = function()
            local updated_in = table.concat(vim.api.nvim_buf_get_lines(in_buf, 0, -1, false), "\n")
            local updated_out = table.concat(vim.api.nvim_buf_get_lines(out_buf, 0, -1, false), "\n")

            prob_data.tests[idx] = {
                input = updated_in,
                output = updated_out,
            }
            save_prob_data(source_bufnr, prob_data)
            print("Saved Case " .. idx .. " to .cph")
        end,
    })
end

--- Delete test cases from .cph/.<filename>.prob
--- @param cases string[] Test case indices
function M.deletetc(cases)
    local source_bufnr = vim.api.nvim_get_current_buf()
    local prob_data = load_prob_data(source_bufnr)
    if not prob_data.tests then return end

    local to_delete = {}
    for _, c in ipairs(cases) do
        local n = tonumber(c)
        if n then to_delete[n] = true end
    end

    local new_tests = {}
    for i, test in ipairs(prob_data.tests) do
        if not to_delete[i] then
            table.insert(new_tests, test)
        end
    end

    prob_data.tests = new_tests
    save_prob_data(source_bufnr, prob_data)
    print("Deleted specified test cases from .cph")
end

return M
