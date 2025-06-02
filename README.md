# What is Multirun ?
Multirun is a neovim dotnet plugin that supports running, building, and stopping multiple dotnet projects at the same time. A single tab window will be opened and each project will have a window with a buffer in the tab.

## How does it differ than easy dotnet?
Multirun only aims at running the dotnet run or dotnet build commands on multiple projects (or single projects) simaltanously. If other dotnet commands are needed then use easy dotnet too

## Getting Started
### Prerequisites
- fd
  - https://github.com/sharkdp/fd
- telescope
  - https://github.com/nvim-telescope/telescope.nvim
### Running
Run the MultirunStart command (or keymap) to launch the picker
 - The first picker will be the command to run
   - build
     - builds the selected projects
   - run
     - will build and run the selected projects and dependencies
     - equalivent to running dotent run commands
     - use this when the projects are in separate solutions (no shared code)
   - build and run
     - will run a single build command separatly then execute the run command for each project
     - run command is equalivent to dotnet run --no-build
     - use this when the projects to run are apart of the same solution

 - The second picker will be the projects to run
   - utilizes telescopes multiselection feature by pressing Tab to select multiple files
   - when pressing enter, the commands will be executed

- To Stop the running commands execute MultirunStopRunningProjects or the keymap
- To rerun the previous command on the previously selected projects run MultirunPrevious or keymap (this skips the picker)
- To Close the project window execute MultirunCloseProjectWindows or keymap

## Commands
There are 4 commands available to be ran as a user command or with a keymap
- Multirun
  - Opens the command and project file pickers then executes the commands
- MultirunPrevious
  - Runs the previously selected command on the previously selected files
- MultirunCloseProjectWindows
  - Closes the project window, but does not stop the running projects
- MultirunStopRunningProjects

## Setup
 - one configuration for enabling auto cleanup of the project tab when a new command is executed or projects are stopped.

 With lazy
 ```nvim
{
			"KaptainK1/multirun.nvim",
			dependencies = {
				"nvim-telescope/telescope.nvim",
			},
			config = function()
				require("multirun").setup({
					 auto_close_project_window = true,
				})
	
				local multirun = require("multirun")
				vim.keymap.set("n", "<leader>mr", function()
					multirun.multirun({ opts = {} })
				end, { desc = "[M]ultirun [R]un" })
				vim.keymap.set("n", "<leader>mp", function()
					multirun.multirun_previous({ opts = {} })
				end, { desc = "[M]ultirun [P]revious" })
				vim.keymap.set("n", "<leader>mc", function()
					multirun.multirun_close_project_windows({ opts = {} })
				end, { desc = "[M]ultirun [C]lose Window" })
				vim.keymap.set("n", "<leader>ms", function()
					multirun.multirun_stop_projects({ opts = {} })
				end, { desc = "[M]ultirun [S]top Projects" })
			end,
		},
 ```
