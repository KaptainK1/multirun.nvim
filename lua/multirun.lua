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

local function remove_pid(pid)
	local index = -1

	for i, value in ipairs(pids) do
		if value == pid then
			index = i
			break
		end
	end

	if index ~= -1 then
		table.remove(pids, index)
	end
end

vim.api.nvim_create_user_command("DotnetBuild", "!dotnet build", { bang = true })

M.dotnet_stop_projects = vim.api.nvim_create_user_command("DotnetStopRunningProjects", function()
	for _, pid in ipairs(pids) do
		vim.uv.kill(pid, "sigterm")
		--vim.system({ "kill", "-15", pid }, { text = true })
	end
	pids = {}
end, { nargs = 0 })

local function run_command(bufnr, project, no_build)
	local running_process = {}
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
		vim.schedule(function()
			local project_wins = vim.api.nvim_tabpage_list_wins(project_window)
			for _, win in ipairs(project_wins) do
				local buf = vim.api.nvim_win_get_buf(win)
				vim.bo.buflisted = false
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end)
		if running_process.pid ~= nil then
			remove_pid(running_process.pid)
			print(vim.inspect(pids))
		end
	end

	running_process = vim.system(
		{ "dotnet", "run", no_build, "--project", project },
		{ text = true, stdout = on_strout, stderr = on_stderr },
		on_exit
	)
	table.insert(pids, running_process.pid)
end

local function build_and_run(bufnr, project, no_build)
	local on_exit = function()
		vim.schedule(function()
			run_command(bufnr, project, no_build)
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
	local create_new_window = false

	for _, value in pairs(files) do
		--switch to project_window tabpage
		local pagenr = vim.api.nvim_tabpage_get_number(project_window)
		vim.api.nvim_command(pagenr .. "tabn")

		--since tabe creates a new win and buf, skip creating a new one first time around
		local buf = 0
		local win = 0
		if create_new_window then
			buf = vim.api.nvim_create_buf(true, false)
			win = vim.api.nvim_open_win(buf, false, {
				split = "right",
				win = 0,
			})
		else
			win = vim.api.nvim_tabpage_get_win(project_window)
			buf = vim.api.nvim_win_get_buf(win)
			create_new_window = true
		end

		vim.api.nvim_win_set_buf(win, buf)
		local no_build = ""
		if run_build_sep then
			no_build = "--no-build"
			build_and_run(buf, value, no_build)
		else
			run_command(buf, value, no_build)
		end
	end
end

--
local function run_selection(prompt_bufnr, map)
	actions.select_default:replace(function()
		local cur_picker = action_state.get_current_picker(prompt_bufnr)
		local selections = cur_picker:get_multi_selection()
		files = {}

		for _, value in ipairs(selections) do
			table.insert(files, value[1])
		end

		actions.close(prompt_bufnr)
		run(shared_sln)
	end)
	return true
end

M.dotnet_build_and_run = vim.api.nvim_create_user_command("DotnetBuildAndRunProject", function()
	run(true)
end, { nargs = 0 })

M.dotnet_run = vim.api.nvim_create_user_command("DotnetRunProject", function()
	run(false)
end, { nargs = 0 })

--picker to get all csproj files
M.start_picker = vim.api.nvim_create_user_command("DotnetStartPicker", function()
	local opts = require("telescope.themes").get_dropdown({})
	opts.find_command = { "fd", "--type", "f", "--glob", "--absolute-path", "*.csproj" }
	opts.prompt_title = "CS Projects"
	opts.attach_mappings = run_selection
	builtin.find_files(opts)
end, { nargs = 0 })

return M
