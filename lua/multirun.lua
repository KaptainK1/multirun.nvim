local M = {}

local builtin = require("telescope.builtin")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local files = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local project_window = nil
local pids = {}
local shared_sln = true

vim.api.nvim_create_user_command("DotnetBuild", "!dotnet build", { bang = true })

vim.api.nvim_create_user_command("KillRunningProjects", function()
	local on_stdout = function(err, data)
		print(vim.inspect(data))
	end

	for _, pid in ipairs(pids) do
		print("pid from kill >>> " .. vim.inspect(pid))
		vim.schedule(function()
			vim.system({ "kill", "-9", pid }, { text = true, stdout = on_stdout })
		end)
	end
end, { nargs = 0 })

vim.api.nvim_create_user_command("DotnetBuildAndRunProject", function(opts)
	local on_exit = function()
		vim.schedule(function()
			vim.cmd.RunProject(opts.fargs[1], opts.fargs[2])
		end)
	end

	local on_stdout = function(err, data)
		print(vim.inspect(data))
	end

	local obj = vim.system({ "dotnet", "build", opts.fargs[1] }, { text = true, stdout = on_stdout }, on_exit)
end, { nargs = "*" })

vim.api.nvim_create_user_command("RunProject", function(opts)
	local on_strout = function(err, data)
		if not data or data ~= "" then
			print(vim.inspect(err))
			if data == nil then
				print(vim.inspect(data))
			else
				local str = data:gsub("[\n\r]", " ")
				vim.schedule(function()
					local bufnr = tonumber(opts.fargs[2])
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
		print("Project " .. opts.fargs[1] .. " killed.")
	end

	local no_build = ""

	if shared_sln then
		no_build = "--no-build"
	end

	local obj = vim.system(
		{ "dotnet", "run", no_build, "--project", opts.fargs[1] },
		{ text = true, stdout = on_strout, stderr = on_stderr },
		on_exit
	)
	print(obj.pid)
	table.insert(pids, obj.pid)
end, { nargs = "*" })

--
local function run_selection(prompt_bufnr, map)
	actions.select_default:replace(function()
		local test = action_state.get_current_picker(prompt_bufnr)
		local values2 = test:get_multi_selection()

		for _, value in ipairs(values2) do
			table.insert(files, value[1])
		end

		actions.close(prompt_bufnr)

		vim.api.nvim_command("tabe")
		local tabs = vim.api.nvim_list_tabpages()
		local last_tab = table.getn(tabs)
		project_window = tabs[last_tab]

		print(vim.inspect("tab >>> " .. project_window))
		for key, value in pairs(files) do
			--switch to project_window tabpage
			local pagenr = vim.api.nvim_tabpage_get_number(project_window)
			vim.api.nvim_command(pagenr .. "tabn")

			local buf = vim.api.nvim_create_buf(true, false)
			local win = vim.api.nvim_open_win(buf, false, {
				split = "left",
				win = 0,
			})

			vim.api.nvim_win_set_buf(win, buf)
			if shared_sln then
				vim.cmd.DotnetBuildAndRunProject(value, buf)
			else
				vim.cmd.RunProject(value, buf)
			end
		end
	end)
	return true
end

--picker to get all csproj files
local startup_picker = function(opts)
	opts = opts or {}
	opts.find_command = { "fd", "--type", "f", "--glob", "--absolute-path", "*.csproj" }
	opts.prompt_title = "CS Projects"
	opts.attach_mappings = run_selection
	builtin.find_files(opts)
end

--test picker to get all multi selections and add them to the files table
local colors = function(opts)
	opts = opts or {}
	pickers
		.new(opts, {
			prompt_title = "colors",
			finder = finders.new_table({
				results = { "red", "green", "blue" },
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local test = action_state.get_current_picker(prompt_bufnr)
					--local values = test.get_multi_selection()
					--blueprint(vim.inspect(test))
					--print(vim.inspect(test._multi._entries))
					local values = test._multi._entries

					local values2 = test:get_multi_selection()
					--print(vim.inspect(values2))
					--print(values)
					--print(vim.inspect(values))
					--print(vim.inspect(table.getn(values2)))

					for _, value in ipairs(values2) do
						table.insert(files, value[1])
					end

					print(vim.inspect(table.getn(files)))
					local str = ""
					for key, value in pairs(files) do
						str = str .. value
					end

					print(vim.inspect(str))
					actions.close(prompt_bufnr)
				end)
				return true
			end,
		})
		:find()
end

-- to execute the function
--colors(require("telescope.themes").get_dropdown({}))
main_buffer = vim.api.nvim_get_current_buf()
startup_picker(require("telescope.themes").get_dropdown({}))
return M
