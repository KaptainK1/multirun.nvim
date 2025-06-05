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
local config = {
	auto_close_project_window = true,
}

function M.setup(opts)
	opts = opts or {}
	config.auto_close_project_window = opts.auto_close_project_window or true
end

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

---@param project_path string: path to one of the project files to use as a starting point to find a sln file by searching up the dir tree
local function find_sln_file(project_path)
	local sln_files = vim.fs.find(function(name, path)
		return name:match(".*%.sln%$")
	end, {
		limit = 1,
		type = "file",
		upward = true,
		path = project_path,
	})

	return sln_files[1]
end

---@note command for stopping all running processes and closes the windown and buffers
function M.multirun_stop_projects()
	for _, pid in ipairs(pids) do
		vim.uv.kill(pid, "sigterm")
		--vim.system({ "kill", "-15", pid }, { text = true })
	end
	pids = {}
end

---@note command for stopping all running processes and closes the windown and buffers
vim.api.nvim_create_user_command("MultirunStopRunningProjects", function()
	M.multirun_stop_projects()
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
			if config.auto_close_project_window then
				vim.cmd.MultirunCloseProjectWindows()
			end
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
function M.multirun_close_project_windows()
	if project_window ~= -1 then
		local project_wins = vim.api.nvim_tabpage_list_wins(project_window)
		for _, win in ipairs(project_wins) do
			local buf = vim.api.nvim_win_get_buf(win)
			vim.bo.buflisted = false
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		project_window = -1
	end
end

---@note command to close project windows and buffers WITHOUT SAVING.
vim.api.nvim_create_user_command("MultirunCloseProjectWindows", function()
	M.multirun_close_project_windows()
end, { nargs = 0 })

local function create_window(create_new_window, title)
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
	end
	vim.api.nvim_win_set_buf(win, buf)
	vim.api.nvim_buf_call(buf, function()
		vim.api.nvim_cmd({ cmd = "file", args = { title }, bang = false }, { output = false })
	end)
	return buf
end

---@param solution string: project file to be acted on
local function build_and_run_command(solution)
	local on_exit = function()
		vim.schedule(function()
			local create_new_window = false
			for _, project in ipairs(files) do
				local buf = create_window(create_new_window, project)
				create_new_window = true
				local on_stdout_run = function(err, data)
					if not data or data ~= "" then
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
				run_command(project, "--no-build", on_stdout_run)
			end
		end)
	end

	local buf = create_window(false, solution)
	local on_stdout_build = function(err, data)
		if not data or data ~= "" then
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

	vim.system({ "dotnet", "build", solution }, { text = true, stdout = on_stdout_build }, on_exit)
end

local function execute_command()
	if config.auto_close_project_window then
		vim.cmd.MultirunCloseProjectWindows()
	end
	if table.getn(files) < 1 then
		print("no files selected. Run command MultirunStart to launch pickers")
		return
	end
	vim.api.nvim_command("tabe")
	local tabs = vim.api.nvim_list_tabpages()
	local last_tab = table.getn(tabs)
	project_window = tabs[last_tab]
	if selected_cmd == commands.BuildAndRun then
		local sln = find_sln_file(files[1])
		build_and_run_command(sln)
	else
		local create_new_window = false

		for _, project in pairs(files) do
			local buf = create_window(create_new_window, project)
			create_new_window = true

			local on_stdout = function(err, data)
				if not data or data ~= "" then
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

			if selected_cmd == commands.Run then
				run_command(project, "", on_stdout)
			else
				vim.system({ "dotnet", "build", project }, { text = true, stdout = on_stdout })
			end
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
function M.multirun_previous()
	if table.getn(files) < 1 then
		print("no files selected. Run command DotnetStartPicker to launch pickers")
	else
		execute_command()
	end
end

--- @note runs the previously selected command with the previously selected files
vim.api.nvim_create_user_command("MultirunPrevious", function()
	M.multirun_previous()
end, { nargs = 0 })

local function start_project_picker(opts)
	opts.find_command = { "fd", "--type", "f", "--glob", "--absolute-path", "*.csproj" }
	opts.prompt_title = "CS Projects"
	opts.attach_mappings = run_selection
	builtin.find_files(opts)
end

function M.multirun()
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
					selected_cmd = selection[1]
					start_project_picker(opts)
				end)
				return true
			end,
		})
		:find()
end

--- @note opens command picker then file picker. Commands are: Run, BuildAndRun, and Build
--- @enum Run will build then run the project, runs the dotnet run command so should be used for separate Projects
--- @enum BuildAndRun will execute a build command separatly then Run command once the build is done. Runs the dotnet run --nobuild command
--- @enum Build runs the build command for the selected project
vim.api.nvim_create_user_command("MultirunStart", function()
	M.multirun()
end, { nargs = 0 })

return M
