vim.pack.add({
	{
		src = "https://github.com/akinsho/toggleterm.nvim",
	},
})

local toggleterm = require("toggleterm")
local terms = require("toggleterm.terminal")

toggleterm.setup({
	size = function(term)
		if term.direction == "horizontal" then
			return 15
		elseif term.direction == "vertical" then
			return vim.o.columns * 0.4
		end
	end,

	open_mapping = nil,

	hide_numbers = true,

	shade_terminals = true,

	shading_factor = 2,

	start_in_insert = true,

	insert_mappings = true,

	persist_size = true,

	persist_mode = true,

	direction = "horizontal",

	close_on_exit = true,

	-- Always open fish shell
	shell = vim.fn.executable("fish") == 1 and "fish" or vim.o.shell,

	float_opts = {
		border = "rounded",
	},
})

----------------------------------------------------
-- Terminal Navigation Helpers
----------------------------------------------------

-- Cycle between terminal instances (direction: 1 for next, -1 for prev)
local function cycle_terminal(direction)
	local all = terms.get_all(true)
	if #all == 0 then
		vim.cmd("ToggleTerm")
		return
	end
	if #all == 1 then
		if not all[1]:is_open() then
			all[1]:open()
		end
		all[1]:focus()
		return
	end

	local current_id = terms.get_focused_id()
	local current_idx = nil
	for idx, term in ipairs(all) do
		if term.id == current_id then
			current_idx = idx
			break
		end
	end

	if not current_idx then
		for idx, term in ipairs(all) do
			if term:is_open() then
				current_idx = idx
				break
			end
		end
		if not current_idx then
			all[1]:open()
			all[1]:focus()
			return
		end
	end

	local next_idx = current_idx + direction
	if next_idx > #all then
		next_idx = 1
	elseif next_idx < 1 then
		next_idx = #all
	end

	local current_term = all[current_idx]
	local target_term = all[next_idx]

	if target_term:is_open() then
		target_term:focus()
	else
		if current_term and current_term:is_open() then
			current_term:close()
		end
		target_term:open()
		target_term:focus()
	end
end

----------------------------------------------------
-- Terminal Window Navigation Keymaps (in terminal mode)
----------------------------------------------------

local function set_terminal_keymaps(bufnr)
	local opts = { buffer = bufnr, silent = true }

	-- Exit terminal mode quickly
	vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], opts)

	-- Navigate between split windows directly from terminal mode
	vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
	vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
	vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
	vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
	vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)

	-- Cycle between terminal instances from terminal mode
	vim.keymap.set("t", "<M-n>", function()
		cycle_terminal(1)
	end, opts)
	vim.keymap.set("t", "<M-p>", function()
		cycle_terminal(-1)
	end, opts)
end

vim.api.nvim_create_autocmd("TermOpen", {
	pattern = "term://*",
	callback = function(args)
		set_terminal_keymaps(args.buf)
	end,
})

----------------------------------------------------
-- Toggle & Instance Keymaps (Normal Mode)
----------------------------------------------------

local map = vim.keymap.set

-- Ctrl + ` Toggle Default Terminal
map({ "n", "t" }, "<C-`>", "<cmd>ToggleTerm<CR>", { silent = true, desc = "Toggle Terminal" })
map("n", "<leader>tt", "<cmd>ToggleTerm<CR>", { silent = true, desc = "Toggle Terminal" })

-- Open Multiple Terminal Instances
map("n", "<leader>tn", "<cmd>TermNew<CR>", { silent = true, desc = "New Terminal Instance" })
map("n", "<leader>th", "<cmd>ToggleTerm direction=horizontal<CR>", { silent = true, desc = "Horizontal Terminal" })
map("n", "<leader>tv", "<cmd>ToggleTerm direction=vertical<CR>", { silent = true, desc = "Vertical Terminal" })
map("n", "<leader>tf", "<cmd>ToggleTerm direction=float<CR>", { silent = true, desc = "Floating Terminal" })
map("n", "<leader>ta", "<cmd>ToggleTermToggleAll<CR>", { silent = true, desc = "Toggle All Terminals" })

-- Numbered Terminal Instances (1-4)
map("n", "<leader>t1", "<cmd>1ToggleTerm<CR>", { silent = true, desc = "Terminal 1" })
map("n", "<leader>t2", "<cmd>2ToggleTerm<CR>", { silent = true, desc = "Terminal 2" })
map("n", "<leader>t3", "<cmd>3ToggleTerm<CR>", { silent = true, desc = "Terminal 3" })
map("n", "<leader>t4", "<cmd>4ToggleTerm<CR>", { silent = true, desc = "Terminal 4" })

-- Navigate Around Terminals
map("n", "<leader>ts", "<cmd>TermSelect<CR>", { silent = true, desc = "Select Terminal" })
map("n", "<leader>t]", function()
	cycle_terminal(1)
end, { silent = true, desc = "Next Terminal" })
map("n", "<leader>t[", function()
	cycle_terminal(-1)
end, { silent = true, desc = "Previous Terminal" })
map("n", "]t", function()
	cycle_terminal(1)
end, { silent = true, desc = "Next Terminal" })
map("n", "[t", function()
	cycle_terminal(-1)
end, { silent = true, desc = "Previous Terminal" })
