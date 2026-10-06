local uv = vim.uv

local M = {}

---@param client uv.uv_tcp_t

local function sanitize_name(name)
    local clean = name:gsub("[^%w]", "_")
    clean = clean:gsub("_+", "_")
    clean = clean:gsub("^_", ""):gsub("_$", "")
    return clean
end

local function on_connection(client)
    local buffer = ""
    client:read_start(function(error, chunk)
        assert(not error, error)
        if chunk then
            buffer = buffer .. chunk
        else
            client:shutdown()
            client:close()

            local content = string.match(buffer, "^.+\r\n(.+)$")
            assert(content, "cphelper.nvim: did not receive content from extension")

            vim.schedule(function()
                local request = vim.json.decode(content)
                if vim.g["cph#url_register"] then
                    vim.fn.setreg(vim.g["cph#url_register"], request.url)
                end

                -- 1. Determine sanitized filename and path
                local prob_title = sanitize_name(request.name or "problem")
                local ext = "." .. (vim.g["cph_language"] or "cpp")
                local filename = prob_title .. ext
                local base_dir = vim.g["cph_directory"] or vim.fn.getcwd()
                local full_filepath = base_dir .. "/" .. filename

                -- 2. Create problem source file if not present
                if vim.fn.filereadable(full_filepath) == 0 then
                    local f = io.open(full_filepath, "w")
                    if f then
                        f:write("// Problem: " .. (request.name or "") .. "\n")
                        f:write("// URL: " .. (request.url or "") .. "\n\n")
                        f:close()
                    end
                end

                -- 3. Open problem file in editor
                vim.cmd("edit " .. vim.fn.fnameescape(full_filepath))

                -- 4. Store test cases persistently in .cph/.<filename>.prob
                local cph_dir = base_dir .. "/.cph"
                if vim.fn.isdirectory(cph_dir) == 0 then
                    vim.fn.mkdir(cph_dir, "p")
                end

                local prob_file = cph_dir .. "/." .. filename .. ".prob"
                local prob_data = {
                    name = request.name,
                    url = request.url,
                    timeLimit = request.timeLimit or 1000,
                    tests = request.tests or {},
                }

                local pf = io.open(prob_file, "w")
                if pf then
                    pf:write(vim.json.encode(prob_data))
                    pf:close()
                end

                print("Received: " .. filename .. " (" .. #(request.tests or {}) .. " test cases)")
            end)
        end
    end)
end

function M.receive()
    local port = vim.g["cph_port"] or 10043
    print("Listening on port " .. port)
    local server = uv.new_tcp()
    if not server then
        vim.api.nvim_echo({ { "could not create server" } }, true, { err = true })
        return
    else
        M.server = server
    end
    local bind_success, bind_error = M.server:bind("127.0.0.1", port)
    if not bind_success then
        vim.api.nvim_echo({ { "could not bind to port: " .. tostring(bind_error) } }, true, { err = true })
        return
    end
    M.server:listen(128, function(err)
        assert(not err, err)
        local client = uv.new_tcp()
        assert(client, "cphelper.nvim: could not create client")
        M.server:accept(client)
        on_connection(client)
    end)
end

function M.stop()
    if M.server then
        M.server:shutdown()
    end
end

return M
