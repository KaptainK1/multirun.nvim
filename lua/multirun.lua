local M = {}

local builtin = require("telescope.builtin")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local files = {}
local project_window
local pids = {}
local shared_sln = true

M.setup = function(opts)
	opts = opts or {}
	opts.shared_sln = opts.shared_sln or true
	shared_sln = opts.shared_sln
end

vim.api.nvim_create_user_command("DotnetBuild", "!dotnet build", { bang = true })

vim.api.nvim_create_user_command("KillRunningProjects", function()
	for _, pid in ipairs(pids) do
		vim.uv.kill(pid, "sigterm")
	end

	local project_wins = vim.api.nvim_tabpage_list_wins(project_window)
	for _, win in ipairs(project_wins) do
		vim.api.nvim_win_close(win, false)
	end
end, { nargs = 0 })

local function rum_command(bufnr, project, no_build)
	local on_strout = function(err, data)
		if not data or data ~= "" then
			print(vim.inspect(err))
			if data == nil then
				print(vim.inspect(data))
			else
				local str = data:gsub("[\n\r]", " ")
				vim.schedule(function()
					if bufnr == nil then
						error("buffer not valid")
					else
						vim.api.nvim_buf_set_lines(bufnr, -1, -1, true, { str })
					end
				end)
			end
		end
	end

	local on_stderr = function(err, data)
		vim.inspect(err)
		vim.inspect(data)
	end

	local on_exit = function()
		print("project " .. project .. " killed.")
	end

	local obj = vim.system(
		{ "dotnet", "run", no_build, "--project", project },
		{ text = true, stdout = on_strout, stderr = on_stderr },
		on_exit
	)
	table.insert(pids, obj.pid)
end

local function build_and_run(bufnr, project, no_build)
	local on_exit = function()
		vim.schedule(function()
			rum_command(bufnr, project, no_build)
		end)
	end

	local on_stdout = function(err, data)
		print(vim.inspect(data))
	end

	vim.system({ "dotnet", "build", project }, { text = true, stdout = on_stdout }, on_exit)
end

local function run(run_build_sep)
	vim.api.nvim_command("tabe")
	local tabs = vim.api.nvim_list_tabpages()
	local last_tab = table.getn(tabs)
	project_window = tabs[last_tab]

	for _, value in pairs(files) do
		--switch to project_window tabpage
		local pagenr = vim.api.nvim_tabpage_get_number(project_window)
		vim.api.nvim_command(pagenr .. "tabn")

		local buf = vim.api.nvim_create_buf(true, false)
		local win = vim.api.nvim_open_win(buf, false, {
			split = "left",
			win = 0,
		})

		vim.api.nvim_win_set_buf(win, buf)
		local no_build = ""
		if run_build_sep then
			no_build = "--no-build"
			build_and_run(buf, value, no_build)
		else
			rum_command(buf, value, no_build)
		end
	end
end

--
local function run_selection(prompt_bufnr, map)
	actions.select_default:replace(function()
		local cur_picker = action_state.get_current_picker(prompt_bufnr)
		local selections = cur_picker:get_multi_selection()

		for _, value in ipairs(selections) do
			table.insert(files, value[1])
		end

		actions.close(prompt_bufnr)
		run(shared_sln)
	end)
	return true
end

--picker to get all csproj files
M.startup_picker = function(opts)
	opts = opts or {}
	opts.find_command = { "fd", "--type", "f", "--glob", "--absolute-path", "*.csproj" }
	opts.prompt_title = "CS Projects"
	opts.attach_mappings = run_selection
	builtin.find_files(opts)
end

vim.api.nvim_create_user_command("DotnetBuildAndRunProject", function()
	run(true)
end, { nargs = 0 })

vim.api.nvim_create_user_command("RunProject", function()
	run(false)
end, { nargs = 0 })

M.setup()
M.startup_picker(require("telescope.themes").get_dropdown({}))
return M
