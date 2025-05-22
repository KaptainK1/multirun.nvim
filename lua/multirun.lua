---@tag multirun

---@brief [[
--- multirun.nvim is a plugin for running multiple dotnet projects at the same time.
---
--- Getting started with multirun:
---   1. Run DotnetStartPicker to select the command you want to perform
---   2. After selecting a command, a file picker is opened
---   3. Select multiple projects that you want to run (or a single one)
---   4. Projects will be ran in a new tab, each project with its own window and buffer
---   5. To stop running projects, run DotnetStopRunningProjects
---   6. Repeat!
---
---@brief ]]

local M = {}

local builtin = require("telescope.builtin")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values

local files = {}
local project_window = -1
local pids = {}
local commands = {
	Build = "build",
	Run = "run",
	BuildAndRun = "build and run",
}
local selected_cmd = commands.Run

---@param pid number: pid to remove from the table
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

---@note command for stopping all running processes and closes the windown and buffers
M.dotnet_stop_projects = vim.api.nvim_create_user_command("DotnetStopRunningProjects", function()
	for _, pid in ipairs(pids) do
		vim.uv.kill(pid, "sigterm")
		--vim.system({ "kill", "-15", pid }, { text = true })
	end
	pids = {}
end, { nargs = 0 })

---@param project string: project file to be acted on
---@param no_build string: --no-build parameter for dotnet run command
---@param on_stdout function: function to be passed to vim.system command for stdout
local function run_command(project, no_build, on_stdout)
	local running_process = {}

	local on_stderr = function(err, data)
		vim.inspect(err)
		vim.inspect(data)
	end

	local on_exit = function()
		vim.schedule(function()
			vim.cmd.DotnetCloseProjectWindows()
		end)

		if running_process.pid ~= nil then
			remove_pid(running_process.pid)
		end
	end

	running_process = vim.system(
		{ "dotnet", "run", no_build, "--project", project },
		{ text = true, stdout = on_stdout, stderr = on_stderr },
		on_exit
	)
	table.insert(pids, running_process.pid)
end

---@note command to close project windows and buffers WITHOUT SAVING.
M.close_project_windows = vim.api.nvim_create_user_command("DotnetCloseProjectWindows", function()
	if project_window ~= -1 then
		local project_wins = vim.api.nvim_tabpage_list_wins(project_window)
		for _, win in ipairs(project_wins) do
			local buf = vim.api.nvim_win_get_buf(win)
			vim.bo.buflisted = false
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		project_window = -1
	end
end, { nargs = 0 })

---@param project string: project file to be acted on
---@param on_exit function: function to be passed to vim.system command for when the command exits
---@param on_stdout function: function to be passed to vim.system command for stdout
local function build_command(project, on_exit, on_stdout)
	on_stdout = on_stdout or function(err, data)
		print(vim.inspect(data))
	end

	on_exit = on_exit or function(obj)
		print(vim.inspect(obj))
	end

	vim.system({ "dotnet", "build", project }, { text = true, stdout = on_stdout }, on_exit)
end

---@param project string: project file to be acted on
---@param no_build string: --no-build parameter for dotnet run command
---@param on_stdout function: function to be passed to vim.system command for stdout
local function build_and_run_command(project, no_build, on_stdout)
	local on_exit = function()
		vim.schedule(function()
			run_command(project, no_build, on_stdout)
		end)
	end

	build_command(project, on_exit, on_stdout)
end

local function execute_command()
	vim.api.nvim_command("tabe")
	local tabs = vim.api.nvim_list_tabpages()
	local last_tab = table.getn(tabs)
	project_window = tabs[last_tab]
	local create_new_window = false

	for _, project in pairs(files) do
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

		local on_stdout = function(err, data)
			if not data or data ~= "" then
				print(vim.inspect(err))
				if data == nil then
					print(vim.inspect(data))
				else
					local str = data:gsub("[\n\r]", " ")
					vim.schedule(function()
						if buf == nil then
							error("buffer not valid")
						else
							vim.api.nvim_buf_set_lines(buf, -1, -1, true, { str })
						end
					end)
				end
			end
		end

		if selected_cmd == commands.BuildAndRun then
			no_build = "--no-build"
			build_and_run_command(project, no_build, on_stdout)
		elseif selected_cmd == commands.Run then
			run_command(project, no_build, on_stdout)
		else
			build_command(project, nil, on_stdout)
		end
	end
end

local function run_selection(prompt_bufnr, map)
	actions.select_default:replace(function()
		local cur_picker = action_state.get_current_picker(prompt_bufnr)
		local selections = cur_picker:get_multi_selection()
		files = {}

		for _, value in ipairs(selections) do
			table.insert(files, value[1])
		end

		actions.close(prompt_bufnr)
		execute_command()
	end)
	return true
end

--- @note runs the previously selected command with the previously selected files
M.dotnet_run = vim.api.nvim_create_user_command("DotnetRunProject", function()
	if table.getn(files) < 1 then
		print("no files selected. Run command DotnetStartPicker to launch pickers")
	else
		execute_command()
	end
end, { nargs = 0 })

local function start_project_picker(opts)
	opts.find_command = { "fd", "--type", "f", "--glob", "--absolute-path", "*.csproj" }
	opts.prompt_title = "CS Projects"
	opts.attach_mappings = run_selection
	builtin.find_files(opts)
end

--- @note opens command picker then file picker. Commands are: Run, BuildAndRun, and Build
--- @enum Run will build then run the project, runs the dotnet run command so should be used for separate Projects
--- @enum BuildAndRun will execute a build command separatly then Run command once the build is done. Runs the dotnet run --nobuild command
--- @enum Build runs the build command for the selected project
M.run = vim.api.nvim_create_user_command("DotnetStartPicker", function()
	local opts = require("telescope.themes").get_dropdown({})
	pickers
		.new(opts, {
			prompt_title = "Dotnet Commands",
			finder = finders.new_table({
				results = { commands.Build, commands.Run, commands.BuildAndRun },
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					print(vim.inspect(selection))
					selected_cmd = selection[1]
					start_project_picker(opts)
				end)
				return true
			end,
		})
		:find()
end, { nargs = 0 })

return M
