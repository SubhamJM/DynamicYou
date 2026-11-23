-- Workspace groups and layout-aware window actions.
local M = {}

local function scrolling()
    local w = hl.get_active_window()
    return w and not w.floating and hl.get_config("general.layout") == "scrolling"
end

function M.workspace(action, group, n)
    return function()
        local ws = hl.get_active_workspace()
        if not ws then return end
        local id = math.max(1, tonumber(ws.id) or 1)
        local target = group and ((n - 1) * 10 + (id - 1) % 10 + 1)
            or (math.floor((id - 1) / 10) * 10 + n)
        if action == "focus" then
            hl.dispatch(hl.dsp.focus({ workspace = target }))
        else
            hl.dispatch(hl.dsp.window.move({ workspace = target, follow = action ~= "silent" }))
        end
    end
end

function M.resize(x, y)
    return function()
        local w = hl.get_active_window()
        if not w or not w.size then return end
        if scrolling() and x ~= 0 then
            hl.dispatch(hl.dsp.layout("colresize " .. (x > 0 and "+" or "") .. tostring(x / 100)))
        else
            hl.dispatch(hl.dsp.window.resize({ x = w.size.x * x / 100, y = w.size.y * y / 100, relative = true }))
        end
    end
end

function M.center()
    return function()
        hl.dispatch(scrolling() and hl.dsp.layout("center") or hl.dsp.window.center())
    end
end

function M.size(x, y)
    return function()
        if scrolling() then
            hl.dispatch(hl.dsp.layout("colresize " .. tostring(x / 100)))
            hl.dispatch(hl.dsp.layout("center"))
        else
            local m = hl.get_active_monitor()
            if not m then return end
            hl.dispatch(hl.dsp.window.resize({ x = math.floor(m.width / (m.scale or 1) * x / 100), y = math.floor(m.height / (m.scale or 1) * y / 100), relative = false }))
            hl.dispatch(hl.dsp.window.center())
        end
    end
end

function M.split()
    return function()
        hl.dispatch(hl.dsp.layout(scrolling() and "consume_or_expel prev" or "togglesplit"))
    end
end

function M.preselect(direction)
    return function()
        hl.dispatch(hl.dsp.layout(scrolling() and (direction == "l" and "consume" or "expel") or ("preselect " .. direction)))
    end
end

return M
